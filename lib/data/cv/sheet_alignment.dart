// Thuật toán CĂN CHỈNH ảnh chụp phiếu — THIẾT KẾ GỐC của GradeVN (R1).
//
// Phiếu TN40 có 12 ô vuông đen ĐẶC in quanh nội dung (xem SheetTemplate):
// 4 ô lớn ở 4 góc khung + 2 ô lớn giữa 2 biên + 6 ô nhỏ bên trong. Pipeline
// căn chỉnh không đòi phiếu nằm gọn trong một khung chữ nhật nữa:
//
//  1. Thu nhỏ ảnh (≈ targetWidth px rộng cho khối lượng tính toán ổn định).
//  2. Ngưỡng hoá "tối" theo độ sáng trung bình toàn ảnh.
//  3. Connected components trên mask tối → lọc "ô vuông đặc": gần vuông
//     (aspect 0.7..1.4), fill ≥ 0.86 (ô tròn tô chỉ đạt π/4 ≈ 0.785), cỡ hợp lệ
//     theo template, và có ≥ 3/4 góc bbox tối (hình tròn thiếu góc).
//  4. Chọn 4 mốc góc: mỗi phần tư ảnh (theo tâm các ứng viên) lấy ứng viên
//     XA TÂM NHẤT → thứ tự tl/tr/br/bl. Ít hơn 4 mốc tin cậy → null
//     (UI rơi về CropReviewScreen: người dùng tự ghim 4 ô vuông).
//  5. Homography từ 4 TÂM MỐC về 4 góc trang chuẩn, warp bằng nội suy song
//     tuyến — tự xử lý xoay ±30°, chụp chếch, phiếu không chiếm trọn khung.
//
// Bản chất thuần Dart, không OpenCV; chạy trong isolate cùng pipeline đo.
//
// ignore_for_file: avoid_print — chỉ dùng trong nhánh `debug` để hiệu chỉnh
// ngưỡng phát hiện, không chạy khi chấm phiếu bình thường.

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as img;

import '../../domain/services/sheet_template.dart';

/// Đọc kích thước ảnh (R2): chỉ decode để lấy width/height — dùng trong
/// isolate, không bao giờ chạy trên thread UI. Ảnh hỏng → null.
Size? probeImageSize(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) return null;
  return Size(decoded.width.toDouble(), decoded.height.toDouble());
}

/// R2-fix (bug demo 2026-10-23): bọc spawn isolate trong hàm TOP-LEVEL.
///
/// Gọi `Isolate.run` trực tiếp từ initState (hàm instance của State) khiến
/// VM gửi KÈM chuỗi context bám cây widget — đồ thị tham chiếu chạm
/// `InheritedElement → MediaQueryData → PlatformDispatcher →
/// WidgetsFlutterBinding._firstFrameCompleter` (unsendable) → spawn ném
/// "object is unsendable: _AsyncCompleter" → mọi ảnh chụp camera rơi màn
/// "Không chọn được ảnh". Pattern đúng đã được kiểm chứng trong project:
/// hàm top-level gửi closure chỉ capture THAM SỐ thuần dữ liệu
/// (xem `processPhoto` — spawn thành công từ cùng luồng chụp).
Future<Size?> probeImageSizeAsync(Uint8List imageBytes) {
  return Isolate.run(() => probeImageSize(imageBytes));
}

/// 4 tâm mốc trên ảnh gốc: [tl, tr, br, bl] (theo kim đồng hồ).
final class AlignmentQuad {
  const AlignmentQuad(this.tl, this.tr, this.br, this.bl);

  final Offset tl;
  final Offset tr;
  final Offset br;
  final Offset bl;

  List<Offset> get corners => [tl, tr, br, bl];

  @override
  bool operator ==(Object other) =>
      other is AlignmentQuad &&
      other.tl == tl &&
      other.tr == tr &&
      other.br == br &&
      other.bl == bl;

  @override
  int get hashCode => Object.hash(tl, tr, br, bl);

  @override
  String toString() => 'AlignmentQuad(tl:$tl, tr:$tr, br:$br, bl:$bl)';
}

/// Kết quả phát hiện mốc: quad (null khi < 4 mốc tin cậy) + toàn bộ ứng viên
/// ô vuông (toạ độ ảnh gốc) để UI vẽ overlay trực tiếp.
final class MarkerDetection {
  const MarkerDetection({required this.quad, required this.candidates});

  final AlignmentQuad? quad;

  /// Tâm các ứng viên ô vuông (toạ độ ảnh gốc, px thật).
  final List<Offset> candidates;

  bool get hasAllMarkers => quad != null;
}

/// Ma trận homography 3×3 (9 phần tử, hàng-chính; h8 mặc định = 1).
typedef Homography3x3 = List<double>;

/// Giải homography đưa 4 điểm `from` (thứ tự tl,tr,br,bl) về 4 điểm `to`.
///
/// Hệ 8 ẩn (h8 chuẩn hoá = 1): x' = (h0x + h1y + h2)/(h6x + h7y + 1),
/// y' = (h3x + h4y + h5)/(h6x + h7y + 1).
/// Ném ArgumentError nếu hệ suy biến (4 điểm không tạo thành tứ giác hợp lệ).
Homography3x3 solveHomography(List<Offset> from, List<Offset> to) {
  if (from.length != 4 || to.length != 4) {
    throw ArgumentError('Cần đúng 4 cặp điểm (tl,tr,br,bl).');
  }
  final a = List.generate(
    8,
    (_) => List<double>.filled(8, 0, growable: false),
    growable: false,
  );
  final b = List<double>.filled(8, 0);
  for (var i = 0; i < 4; i++) {
    final sx = from[i].dx;
    final sy = from[i].dy;
    final dx = to[i].dx;
    final dy = to[i].dy;
    final r1 = 2 * i;
    final r2 = r1 + 1;
    a[r1][0] = sx;
    a[r1][1] = sy;
    a[r1][2] = 1;
    a[r1][6] = -sx * dx;
    a[r1][7] = -sy * dx;
    b[r1] = dx;
    a[r2][3] = sx;
    a[r2][4] = sy;
    a[r2][5] = 1;
    a[r2][6] = -sx * dy;
    a[r2][7] = -sy * dy;
    b[r2] = dy;
  }
  final solution = _solveLinear8(a, b);
  if (solution == null) {
    throw ArgumentError('Hệ homography suy biến (4 điểm gần thẳng hàng).');
  }
  return [...solution, 1.0];
}

/// Áp homography cho điểm ảnh (u,v) ở ảnh gốc → toạ độ ở ảnh đích.
Offset applyHomography(Homography3x3 h, double u, double v) {
  final w = h[6] * u + h[7] * v + 1;
  return Offset(
    (h[0] * u + h[1] * v + h[2]) / w,
    (h[3] * u + h[4] * v + h[5]) / w,
  );
}

/// Triệt tiêu Gauss–Jordan 8×8 (chọn pivot hàng) → null nếu suy biến.
List<double>? _solveLinear8(List<List<double>> a, List<double> b) {
  const n = 8;
  final m = [for (var i = 0; i < n; i++) [...a[i], b[i]]];
  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var row = col + 1; row < n; row++) {
      if (m[row][col].abs() > m[pivot][col].abs()) pivot = row;
    }
    if (m[pivot][col].abs() < 1e-9) return null;
    if (pivot != col) {
      final tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;
    }
    final diag = m[col][col];
    for (var j = col; j <= n; j++) {
      m[col][j] /= diag;
    }
    for (var row = 0; row < n; row++) {
      if (row == col) continue;
      final factor = m[row][col];
      if (factor == 0) continue;
      for (var j = col; j <= n; j++) {
        m[row][j] -= factor * m[col][j];
      }
    }
  }
  return [for (var i = 0; i < n; i++) m[i][n]];
}

/// Ứng viên ô vuông mốc ở ảnh THU NHỎ.
final class _SquareCandidate {
  _SquareCandidate({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  double get cx => (minX + maxX) / 2;
  double get cy => (minY + maxY) / 2;
  int get bw => maxX - minX + 1;
  int get bh => maxY - minY + 1;
}

/// Phát hiện 4 ô vuông mốc góc trên ảnh chụp phiếu; null khi thiếu mốc tin cậy.
final class SheetMarkerDetector {
  const SheetMarkerDetector({this.targetWidth = 640, this.debug = false});

  /// Bề rộng ảnh sau thu nhỏ — đủ nhìn ô mốc (≥ ~14 px) mà BFS vẫn nhanh.
  final int targetWidth;

  /// In thống kê khi chẩn đoán (build cục bộ khi hiệu chỉnh ngưỡng/lọc).
  final bool debug;

  MarkerDetection detect(
    Uint8List imageBytes, {
    SheetTemplate? template,
  }) {
    final tpl = template ?? SheetTemplate.tn40Standard;
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return const MarkerDetection(quad: null, candidates: []);
    }
    final w = decoded.width;
    final h = decoded.height;
    if (w < 120 || h < 120) {
      return const MarkerDetection(quad: null, candidates: []);
    }
    if (debug) print('detect: ảnh $w×$h');

    // Độ xám thô: lấy kênh đầu (ảnh chụp RGB; luminance đầy đủ không cần thiết
    // cho bước lọc ô vuông đen).
    final bytes = decoded.getBytes();
    final channels = decoded.numChannels;

    int grayAt(int x, int y) {
      if (x < 0 || y < 0 || x >= w || y >= h) return 255;
      final idx = (y * w + x) * channels;
      if (idx >= bytes.length) return 255;
      final r = bytes[idx];
      // Ảnh 1-2 kênh (xám) không có đủ RGB: dùng luôn kênh đầu.
      if (channels < 3 || idx + 2 >= bytes.length) return r;
      final g = bytes[idx + 1];
      final b = bytes[idx + 2];
      return (r * 299 + g * 587 + b * 114) ~/ 1000;
    }

    return _detectFromGray(grayAt, w: w, h: h, tpl: tpl);
  }

  /// Phát hiện mốc trên ẢNH XÁM THÔ (mỗi pixel 1 byte, liền mạch, không stride)
  /// — nhập vào trực tiếp từ luồng Y-plane của camera cho overlay "đủ 4 mốc".
  ///
  /// Chia sẻ chính xác cùng lõi thuật toán với [detect] (ngưỡng bám độ sáng,
  /// lọc ô vuông đặc, chọn góc bằng convex hull); nguồn PNG dùng [detect].
  MarkerDetection detectGray(
    Uint8List gray, {
    required int width,
    required int height,
    SheetTemplate? template,
  }) {
    final tpl = template ?? SheetTemplate.tn40Standard;
    if (width < 120 || height < 120) {
      return const MarkerDetection(quad: null, candidates: []);
    }
    if (debug) print('detectGray: ảnh $width×$height');

    int grayAt(int x, int y) {
      if (x < 0 || y < 0 || x >= width || y >= height) return 255;
      final idx = y * width + x;
      if (idx >= gray.length) return 255;
      return gray[idx];
    }

    return _detectFromGray(grayAt, w: width, h: height, tpl: tpl);
  }

  /// Lõi chung của [detect]/[detectGray]: ngưỡng bám độ sáng toàn ảnh →
  /// mask tối thu nhỏ → lọc ô vuông đặc → chọn 4 góc bằng convex hull.
  MarkerDetection _detectFromGray(
    int Function(int x, int y) grayAt, {
    required int w,
    required int h,
    required SheetTemplate tpl,
  }) {
    final f = math.max(1, (w / targetWidth).floor());
    final dw = w ~/ f;
    final dh = h ~/ f;

    // Ngưỡng "tối" bám độ sáng toàn ảnh (điều kiện sáng thay đổi).
    var sum = 0;
    var count = 0;
    for (var y = 0; y < h; y += f) {
      for (var x = 0; x < w; x += f) {
        sum += grayAt(x, y);
        count++;
      }
    }
    if (count == 0) {
      return const MarkerDetection(quad: null, candidates: []);
    }
    final mean = sum / count;
    if (debug) {
      print('detect: mean=$mean f=$f dst=$dw×$dh '
          'expectedSide=${(tpl.markerSide / tpl.pageWidthUnits * dw).toStringAsFixed(1)} '
          'threshold=adaptive(local_mean×0.8, cửa sổ≈2×mốc)');
    }

    // Cỡ ô mốc hợp lệ theo template (px ảnh thu nhỏ; tỉ lệ so với TRANG giấy).
    final expectedSide = tpl.markerSide / tpl.pageWidthUnits * dw;
    final minSide = math.max(5.0, expectedSide * 0.4);
    final maxSide = math.max(minSide * 2, expectedSide * 3.0);

    // R6a — NGƯỠNG THÍCH NGHI CỤC BỘ (thay ngưỡng toàn cục mean×0.55).
    // Hiện trường chụp MÀN HÌNH màn Outline + viền/bezel màn tối + bàn tối
    // kéo mean toàn ảnh xuống (vd. mean=108 → dark=60): mốc in trên trang
    // sáng (gray ~60–100) rớt ngưỡng toàn cục → mất mốc góc; đồng thời
    // vùng bezel đen PHẲNG ghép thành khối khổng lồ (bw=1080) nuốt mốc mép.
    // Nguyên tắc mới: pixel "tối" khi nó TỐI so với CỬA SỔ quanh nó
    // (integral image, cạnh cửa sổ ≈ 2× cạnh mốc kỳ vọng):
    //  - mốc đen đặc trên trang sáng → pixel ≈ 0 ≪ 0.8×localMean → tối ✓
    //  - nền đen phẳng (bezel) → pixel ≈ localMean → KHÔNG tối → không còn
    //    khối ghép khổng lồ ✓
    final graySmall = Uint8List(dw * dh);
    for (var dy = 0; dy < dh; dy++) {
      for (var dx = 0; dx < dw; dx++) {
        graySmall[dy * dw + dx] = grayAt(dx * f, dy * f) & 0xFF;
      }
    }

    final iw = dw + 1;
    final integral = List<int>.filled(iw * (dh + 1), 0);
    for (var y = 0; y < dh; y++) {
      var rowSum = 0;
      final out = (y + 1) * iw;
      final prev = y * iw;
      for (var x = 0; x < dw; x++) {
        rowSum += graySmall[y * dw + x];
        integral[out + x + 1] = integral[prev + x + 1] + rowSum;
      }
    }

    final winHalf = math.max(8, expectedSide.round());
    final mask = List<bool>.filled(dw * dh, false);
    for (var dy = 0; dy < dh; dy++) {
      final y0 = math.max(0, dy - winHalf);
      final y1 = math.min(dh - 1, dy + winHalf);
      final prevRow = y0 * iw;
      final outRow = (y1 + 1) * iw;
      for (var dx = 0; dx < dw; dx++) {
        final x0 = math.max(0, dx - winHalf);
        final x1 = math.min(dw - 1, dx + winHalf);
        final windowSum = integral[outRow + x1 + 1] -
            integral[prevRow + x1 + 1] -
            integral[outRow + x0] +
            integral[prevRow + x0];
        final localMean =
            windowSum / ((x1 - x0 + 1) * (y1 - y0 + 1));
        mask[dy * dw + dx] =
            graySmall[dy * dw + dx] < localMean * 0.8;
      }
    }

    final candidateList = _findSquareCandidates(
      mask,
      dw,
      dh,
      minSide,
      maxSide,
      debug: debug,
    );

    // Chọn 4 mốc góc: mỗi phần tư (theo tâm ứng viên) lấy ứng viên xa tâm nhất.
    // Toạ độ candidates sinh sống ở ảnh thu nhỏ → nhân [f] về ảnh gốc.
    final quad = _pickCornerQuad(candidateList, f);
    if (debug) {
      print('detect: candidates=${candidateList.length}');
      for (final c in candidateList) {
        print('  dst(${c.cx.toStringAsFixed(1)},${c.cy.toStringAsFixed(1)}) '
            'bw=${c.bw} bh=${c.bh}');
      }
      print('detect: quad=$quad');
    }
    return MarkerDetection(
      quad: quad,
      candidates: [
        for (final c in candidateList) Offset(c.cx * f, c.cy * f),
      ],
    );
  }

  /// Connected components (BFS 4 láng giềng) trên mask; lọc ô vuông đặc.
  List<_SquareCandidate> _findSquareCandidates(
    List<bool> mask,
    int dw,
    int dh,
    double minSide,
    double maxSide, {
    bool debug = false,
  }) {
    final visited = List<bool>.filled(dw * dh, false);
    final stack = <int>[];
    final result = <_SquareCandidate>[];

    for (var start = 0; start < mask.length; start++) {
      if (!mask[start] || visited[start]) continue;
      visited[start] = true;
      stack.add(start);
      var minX = start % dw, maxX = minX, minY = start ~/ dw, maxY = minY;
      var area = 0;
      while (stack.isNotEmpty) {
        final i = stack.removeLast();
        final iy = i ~/ dw;
        final ix = i % dw;
        area++;
        if (ix < minX) minX = ix;
        if (ix > maxX) maxX = ix;
        if (iy < minY) minY = iy;
        if (iy > maxY) maxY = iy;
        // 4 láng giềng.
        if (ix + 1 < dw) _visit(mask, visited, stack, i + 1);
        if (ix > 0) _visit(mask, visited, stack, i - 1);
        if (iy + 1 < dh) _visit(mask, visited, stack, i + dw);
        if (iy > 0) _visit(mask, visited, stack, i - dw);
      }

      final bw = maxX - minX + 1;
      final bh = maxY - minY + 1;
      final fill = area / (bw * bh);
      if (debug && area >= 6) {
        print(
          '  comp center=(${((minX + maxX) / 2).toStringAsFixed(1)},'
          '${((minY + maxY) / 2).toStringAsFixed(1)}) bw=$bw bh=$bh '
          'fill=${fill.toStringAsFixed(2)}',
        );
      }
      if (bw < minSide || bh < minSide || bw > maxSide || bh > maxSide) continue;
      // Gần vuông theo bbox (chấp nhận ô vuông xoay tới ±30°).
      final aspect = bw / bh;
      if (aspect < 0.7 || aspect > 1.4) continue;
      // Blob đặc. Ngưỡng 0.5 vì bbox của ô vuông xoay θ có fill = 1/(sinθ+cosθ)²
      // (θ=30° → ~0.54); ô tròn/đường viền bong bóng chỉ ~0.16, glyph ~0.2–0.45.
      if (fill < 0.5) continue;
      result.add(_SquareCandidate(
        minX: minX,
        minY: minY,
        maxX: maxX,
        maxY: maxY,
      ));
    }
    return result;
  }

  static void _visit(
    List<bool> mask,
    List<bool> visited,
    List<int> stack,
    int i,
  ) {
    if (mask[i] && !visited[i]) {
      visited[i] = true;
      stack.add(i);
    }
  }

  /// Phần tư ảnh → chọn mốc theo BẦU LỎI CONVEX HULL của ứng viên (đổi so
  /// với bản đầu R1). Lý do: bong bóng đã tô cũng là blob đặc cạnh mốc; nếu
  /// chọn theo "xa tâm của khối ứng viên" thì khối bong bóng kéo tâm lệch và
  /// chọn nhầm mốc. Mốc góc luôn là đỉnh CỰC của hull — bong bóng nằm bên
  /// trong, không thể vượt ra ngoài khung mốc → lấy đỉnh cực theo 4 hướng
  /// chéo của hull là đủ, độc lập với phân bố bong bóng.
  AlignmentQuad? _pickCornerQuad(
    List<_SquareCandidate> candidates,
    int f,
  ) {
    if (candidates.length < 4) return null;
    final hull = _convexHull([
      for (final c in candidates) Offset(c.cx * f, c.cy * f),
    ]);
    if (hull.length < 4) return null;

    Offset? tl, tr, br, bl;
    double bestTl = -double.infinity,
        bestTr = -double.infinity,
        bestBr = -double.infinity,
        bestBl = -double.infinity;
    for (final p in hull) {
      final tlScore = -p.dx - p.dy;
      final trScore = p.dx - p.dy;
      final brScore = p.dx + p.dy;
      final blScore = -p.dx + p.dy;
      if (tlScore > bestTl) {
        bestTl = tlScore;
        tl = p;
      }
      if (trScore > bestTr) {
        bestTr = trScore;
        tr = p;
      }
      if (brScore > bestBr) {
        bestBr = brScore;
        br = p;
      }
      if (blScore > bestBl) {
        bestBl = blScore;
        bl = p;
      }
    }
    final quadPoints = {tl, tr, br, bl};
    if (quadPoints.contains(null) || quadPoints.length < 4) {
      return null; // Hull quá dẹt: một đỉnh bị chọn cho 2 hướng → thiếu đỉnh.
    }
    // Tỉ lệ cạnh quad hợp lý (phiếu dựng đứng hoặc xoay đều chấp nhận).
    final top = (tr!.dx - tl!.dx).abs();
    final bottom = (br!.dx - bl!.dx).abs();
    final left = (bl.dy - tl.dy).abs();
    final right = (br.dy - tr.dy).abs();
    final meanW = (top + bottom) / 2;
    final meanH = (left + right) / 2;
    if (meanW <= 0 || meanH <= 0) return null;
    final ratio = meanH / meanW;
    // frameH/frameW = 1.47; xoay ±30° ratio dao động ~[0.9, 2.4].
    if (ratio < 0.8 || ratio > 2.4) return null;
    return AlignmentQuad(tl, tr, br, bl);
  }

  /// Convex hull (Andrew monotone chain), trả đỉnh theo thứ tự CCW bỏ trùng.
  static List<Offset> _convexHull(List<Offset> pts) {
    final sorted = [...pts]..sort((a, b) {
        final dx = a.dx.compareTo(b.dx);
        return dx != 0 ? dx : a.dy.compareTo(b.dy);
      });
    final lower = <Offset>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          _cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <Offset>[];
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          _cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  static double _cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
}

/// Nắn thẳng: warp ảnh gốc theo [quad] (4 TÂM MỐC góc) về [targetQuad]
/// (4 tâm mốc trên TRANG CHUẨN, theo [outputSize]) → PNG xám.
///
/// [quad] là 4 tâm ô vuông mốc góc ở ảnh gốc — kết quả warp đưa chúng về đúng
/// các tâm mốc tương ứng trên trang chuẩn, nhờ vậy toạ độ nội dung phiếu sau
/// khi nắn khớp tuyệt đối với [SheetLayout] (cùng hệ trang + lề). Xoay/chếch/
/// khoảng cách đều được homography xử lý; điểm ngoài biên ảnh gốc được kẹp
/// vào mép.
final class PerspectiveWarper {
  const PerspectiveWarper();

  Uint8List warpRectify(
    Uint8List imageBytes, {
    required AlignmentQuad quad,
    required AlignmentQuad targetQuad,
    required Size outputSize,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Không giải mã được ảnh để nắn phẳng.');
    }
    final w = decoded.width;
    final h = decoded.height;
    final channels = decoded.numChannels;
    final bytes = decoded.getBytes();

    final ow = outputSize.width.toInt();
    final oh = outputSize.height.toInt();
    final out = img.Image(width: ow, height: oh);

    final homo = solveHomography(targetQuad.corners, quad.corners);

    for (var y = 0; y < oh; y++) {
      for (var x = 0; x < ow; x++) {
        final src = applyHomography(homo, x.toDouble(), y.toDouble());
        final g = _sampleGray(bytes, channels, w, h, src.dx, src.dy);
        out.setPixelRgb(x, y, g, g, g);
      }
    }
    return img.encodePng(out, level: 3);
  }

  /// R15: nắn phẳng ẢNH XÁM PLANAR (byte/pixel, không stride) → mảng xám
  /// PLANAR. Đường nóng của luồng chụp thật: bỏ hẳn decode/encode trong
  /// pipeline (người dùng: "chấm 10-15s quá lâu") — ảnh nguồn đã decode
  /// 1 lần trước đó, kết quả là mảng xám mỗi pixel 1 byte để kiểm chứng +
  /// đo mật độ dùng chung, chỉ encode PNG 1 lần ở cuối (thay cho từng
  /// lần thử warp). Toạ độ lấy mẫu = chính `_sampleGray` của
  /// [warpRectify] (kênh đầu) → giá trị pixel đầu ra ĐỐI XỨNG hệ quả
  /// warp cũ, không đổi kết quả chấm.
  ({Uint8List gray, int width, int height}) warpGrayPlanar({
    required Uint8List srcGray,
    required int srcWidth,
    required int srcHeight,
    required AlignmentQuad quad,
    required AlignmentQuad targetQuad,
    required Size outputSize,
  }) {
    final ow = outputSize.width.toInt();
    final oh = outputSize.height.toInt();
    final out = Uint8List(ow * oh);
    final homo = solveHomography(targetQuad.corners, quad.corners);
    final h0 = homo[0], h1 = homo[1], h2 = homo[2];
    final h3 = homo[3], h4 = homo[4], h5 = homo[5];
    final h6 = homo[6], h7 = homo[7];

    // R17 (log22): nội suy női však loạt — warp chiếm 2251ms/bước (**release**),
    // chủ yếu do applyHomography tạo MỘT object Offset mỗi pixel (3.5 triệu
    // object
    // + clamp/floor qua extension) và bỏ round() khi gán. Lặp NỘI TÚI đây,
    // giữ ĐÚNG THỨ TỰ FLOAT của applyHomography:
    //   u = (h0×x + h1×y + h2) / (h6×x + h7×y + 1)   (x,y = trang chuẩn)
    // cùng công thức bilinear của _sampleGray (kênh 1) → pixel đầu ra ĐỐI
    // XỨNG bit-cho-bit với đường cũ, chấm không đổi.
    final srcW = srcWidth;
    final srcH = srcHeight;
    final wLast = srcW - 1;
    final hLast = srcH - 1;
    for (var y = 0; y < oh; y++) {
      final h1y = h1 * y;
      final h4y = h4 * y;
      final h7y = h7 * y;
      final rowBase = y * ow;
      for (var x = 0; x < ow; x++) {
        final den = (h6 * x + h7y + 1.0);
        var u = (h0 * x + h1y + h2) / den;
        var v = (h3 * x + h4y + h5) / den;
        u = u < 0 ? 0 : (u > wLast ? wLast.toDouble() : u);
        v = v < 0 ? 0 : (v > hLast ? hLast.toDouble() : v);
        final x0 = u.toInt();
        final y0 = v.toInt();
        final x1 = x0 >= wLast ? wLast : x0 + 1;
        final y1 = y0 >= hLast ? hLast : y0 + 1;
        final fracX = u - x0;
        final fracY = v - y0;
        final idx = y0 * srcW + x0;
        final g00 = srcGray[idx];
        final g10 = srcGray[idx + (x1 - x0)];
        final g01 = srcGray[idx + (y1 - y0) * srcW];
        final g11 = srcGray[idx + (y1 - y0) * srcW + (x1 - x0)];
        final top = g00 + (g10 - g00) * fracX;
        final bottom = g01 + (g11 - g01) * fracX;
        out[rowBase + x] =
            (top + (bottom - top) * fracY).round().clamp(0, 255);
      }
    }
    return (gray: out, width: ow, height: oh);
  }

  /// R2: nắn phẳng trả về ẢNH XÁM (img.Image) KHÔNG encode — dùng khi chỉ
  /// cần đo/kiểm (dò hướng quad overlay), tránh lãng phí encode PNG.
  img.Image warpToImage(
    Uint8List imageBytes, {

    required AlignmentQuad quad,
    required AlignmentQuad targetQuad,
    required Size outputSize,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Không giải mã được ảnh để nắn phẳng.');
    }
    final w = decoded.width;
    final h = decoded.height;
    final channels = decoded.numChannels;
    final bytes = decoded.getBytes();

    final ow = outputSize.width.toInt();
    final oh = outputSize.height.toInt();
    final out = img.Image(width: ow, height: oh);

    final homo = solveHomography(targetQuad.corners, quad.corners);

    for (var y = 0; y < oh; y++) {
      for (var x = 0; x < ow; x++) {
        final src = applyHomography(homo, x.toDouble(), y.toDouble());
        final g = _sampleGray(bytes, channels, w, h, src.dx, src.dy);
        out.setPixelRgb(x, y, g, g, g);
      }
    }
    return out;
  }
}

/// R2-fix (bug demo 2026-10-23): bọc spawn isolate cho nắn phẳng trong hàm
/// TOP-LEVEL — closure chỉ capture tham số thuần dữ liệu (bytes/quad/Size),
/// không chộp context bám cây widget như khi gọi Isolate.run trực tiếp từ
/// hàm instance của State. Ảnh hỏng → FormatException từ [PerspectiveWarper].
Future<Uint8List> warpRectifyAsync(
  Uint8List imageBytes, {
  required AlignmentQuad quad,
  required AlignmentQuad targetQuad,
  required Size outputSize,
}) {
  return Isolate.run(
    () => const PerspectiveWarper().warpRectify(
      imageBytes,
      quad: quad,
      targetQuad: targetQuad,
      outputSize: outputSize,
    ),
  );
}

/// Nội suy song tuyến độ xám (lấy kênh đầu), toạ độ kẹp trong biên ảnh.
int _sampleGray(
  Uint8List bytes,
  int channels,
  int w,
  int h,
  double x,
  double y,
) {
  final xc = x.clamp(0.0, (w - 1).toDouble());
  final yc = y.clamp(0.0, (h - 1).toDouble());
  final x0 = xc.floor();
  final y0 = yc.floor();
  final x1 = math.min(w - 1, x0 + 1);
  final y1 = math.min(h - 1, y0 + 1);
  final fracX = xc - x0;
  final fracY = yc - y0;

  int at(int px, int py) {
    final idx = (py * w + px) * channels;
    if (idx >= bytes.length) return 255;
    return bytes[idx];
  }

  final g00 = at(x0, y0);
  final g10 = at(x1, y0);
  final g01 = at(x0, y1);
  final g11 = at(x1, y1);
  final top = g00 + (g10 - g00) * fracX;
  final bottom = g01 + (g11 - g01) * fracX;
  return (top + (bottom - top) * fracY).round().clamp(0, 255);
}
