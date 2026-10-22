// Thuật toán CĂN CHỈNH ảnh chụp phiếu — THIẾT KẾ GỐC của GradeVN.
//
// Quan sát: phiếu có dải khung đen liền quanh 4 mép (xem sheet_painter.dart
// / FrameSpec). Ảnh chụp điện thoại làm phiếu bị dịch/chếch/nghiêng nhẹ →
// trước khi đo mật độ phải đưa ảnh về đúng bố cục trang chuẩn.
//
// Các bước (thuần Dart, không OpenCV):
//  1. Thu nhỏ ảnh (≈ targetDownscaleWidth px rộng) cho nhẹ.
//  2. Ngưỡng hoá "tối" theo độ sáng trung bình toàn ảnh (bám theo điều kiện
//     sáng, đỡ bị gradient gradient sáng/tối đánh lừa).
//  3. Profile: hàng/cột có dải tối chạy gần hết chiều dài → đó là 4 mép khung
//     (mọi tạp điểm lẻ đều không đủ "chạy dài").
//  4. Tinh chỉnh 4 góc ở độ phân giải đầy đủ: quanh ước lượng mỗi góc, chọn
//     điểm tối có cả "đoạn ngang tối" và "đoạn dọc tối" chạm tới nó.
//  5. Giải homography 4 góc → 4 góc trang chuẩn, warp lại bằng nội suy song
//     tuyến (iceiling: hoạ ngược ảnh đích → ảnh gốc).
//
// Ảnh chụp phải đặt phiếu trên nền đủ sáng, khung không bị che quá nhiều —
// chỉ dẫn chụp ở ScanScreen cũng nhắc điều kiện này.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as img;

import '../../domain/services/sheet_layout.dart';
import 'sheet_painter.dart';

/// 4 góc khung phiếu trên ảnh gốc: [tl, tr, br, bl] (theo kim đồng hồ).
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

/// Chạy dải tối liên tiếp theo chiều (dx,dy) kể từ (x,y), bỏ luôn điểm đầu.
int _darkRun(bool Function(int, int) isDark, int x, int y, int dx, int dy, int cap) {
  var run = 0;
  var cx = x + dx;
  var cy = y + dy;
  while (run < cap && isDark(cx, cy)) {
    run++;
    cx += dx;
    cy += dy;
  }
  return run;
}

/// Phát hiện khung phiếu trên ảnh chụp → 4 góc; null khi không tìm thấy.
final class FrameAlignmentDetector {
  const FrameAlignmentDetector({
    this.targetDownscaleWidth = 180,
    this.minFrameRunRatio = 0.55,
  });

  final int targetDownscaleWidth;
  final double minFrameRunRatio;

  AlignmentQuad? detect(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;
    final gray = img.grayscale(decoded);
    final w = gray.width;
    final h = gray.height;
    if (w < 80 || h < 80) return null;

    final f = math.max(1, w ~/ targetDownscaleWidth);
    final dw = w ~/ f;
    final dh = h ~/ f;

    // Độ xám nhanh theo pixel (mảng bytes, dải RGB đã grayscale hoá bằng
    // lệnh grayscale nên r=g=b).
    final channels = gray.numChannels;
    final bytes = gray.getBytes();
    int grayAt(int x, int y) {
      final idx = (y * w + x) * channels;
      return idx < bytes.length ? bytes[idx] : 255;
    }

    // Ngưỡng tối theo độ sáng toàn ảnh (lấy mẫu theo bậc f cho gọn).
    var sum = 0;
    var count = 0;
    for (var y = 0; y < h; y += f) {
      for (var x = 0; x < w; x += f) {
        sum += grayAt(x, y);
        count++;
      }
    }
    if (count == 0) return null;
    final mean = sum / count;
    final dark = (mean * 0.55).clamp(40.0, 160.0);

    // Profile: số pixel tối theo hàng / cột (đếm trên ảnh gốc cho mượt).
    final rowDark = List<double>.filled(dh, 0);
    final colDark = List<double>.filled(dw, 0);
    for (var y = 0; y < h; y++) {
      final ry = y ~/ f;
      for (var x = 0; x < w; x++) {
        if (grayAt(x, y) < dark) {
          rowDark[ry] += 1;
          colDark[x ~/ f] += 1;
        }
      }
    }

    // 4 mép: hàng/cột "tối gần hết chiều dài" → chính là dải khung.
    final topIdx = _firstEdge(rowDark, dw);
    final leftIdx = _firstEdge(colDark, dh);
    final rightIdx = _lastEdge(colDark, dh);
    final bottomIdx = _lastEdge(rowDark, dw);
    if (topIdx == null || leftIdx == null || rightIdx == null || bottomIdx == null) {
      return null;
    }

    // Khung phải chiếm phần lớn ảnh (tránh "khung" của bàn/nền tối).
    final fw = (rightIdx - leftIdx) * f;
    final fh = (bottomIdx - topIdx) * f;
    if (fw < w * 0.4 || fh < h * 0.4) return null;

    // Tinh chỉnh 4 góc: mỗi góc = điểm tối "xuyên ra xa nhất" theo đúng đường
    // chéo của mình (tl nhỏ nhất x+y, tr nhỏ nhất (W−1−x)+y, v.v.) TRONG SỐ
    // điểm tối có cả dải ngang lẫn dải dọc chạm tới (lọc tạp điểm lẻ).
    // Không dùng cửa sổ quanh seed vì mép nghiêng thật làm seed lệch xa hơn
    // cửa sổ được phép — điểm chéo cực trị luôn tìm được góc đúng.
    bool isDark(int x, int y) => x >= 0 && y >= 0 && x < w && y < h && grayAt(x, y) < dark;

    Offset? tl;
    Offset? tr;
    Offset? br;
    Offset? bl;
    double bestTl = double.infinity;
    double bestTr = double.infinity;
    double bestBr = double.infinity;
    double bestBl = double.infinity;
    final frameScale = w / SheetLayout.standardPage.width;
    // Độ dày khung ước lượng trên ảnh này (FrameSpec.thickness theo trang chuẩn).
    final tEst = const FrameSpec().thickness * frameScale;
    // minRun nới lỏng 1px so với độ dày khung, kẹp trong [2..8].
    final minRun = math.max(2, math.min(8, tEst.round() - 1));
    // search bounds: quét quanh vùng khung, chừa mép ảnh chụp lố ra ngoài.
    final window = math.max(24, f * 5);
    final x1 = math.max(0, leftIdx * f - window);
    final x2 = math.min(w - 1, rightIdx * f + window);
    final y1 = math.max(0, topIdx * f - window);
    final y2 = math.min(h - 1, bottomIdx * f + window);
    for (var y = y1; y <= y2; y++) {
      for (var x = x1; x <= x2; x++) {
        if (!isDark(x, y)) continue;
        final runH = math.max(
          _darkRun(isDark, x, y, 1, 0, minRun),
          _darkRun(isDark, x, y, -1, 0, minRun),
        );
        if (runH < minRun) continue;
        final runV = math.max(
          _darkRun(isDark, x, y, 0, 1, minRun),
          _darkRun(isDark, x, y, 0, -1, minRun),
        );
        if (runV < minRun) continue;
        // Điểm chéo: mỗi góc chọn điểm cực trị theo hướng tương ứng.
        final sTl = (x + y).toDouble();
        final sTr = (w - 1 - x + y).toDouble();
        final sBr = (w - 1 - x + h - 1 - y).toDouble();
        final sBl = (x + h - 1 - y).toDouble();
        if (sTl < bestTl) {
          bestTl = sTl;
          tl = Offset(x.toDouble(), y.toDouble());
        }
        if (sTr < bestTr) {
          bestTr = sTr;
          tr = Offset(x.toDouble(), y.toDouble());
        }
        if (sBr < bestBr) {
          bestBr = sBr;
          br = Offset(x.toDouble(), y.toDouble());
        }
        if (sBl < bestBl) {
          bestBl = sBl;
          bl = Offset(x.toDouble(), y.toDouble());
        }
      }
    }
    if (tl == null || tr == null || br == null || bl == null) return null;
    return AlignmentQuad(tl, tr, br, bl);
  }

  /// Index profile đầu tiên đạt ngưỡng [minFrameRunRatio].
  ///
  /// Không đòi hàng kề cũng "tối": dải khung mảnh (≈5px) có thể gọn hơn bậc
  /// thu nhỏ f, nên hai hàng kề hợp lệ lại là nền trắng.
  int? _firstEdge(List<double> profile, int span) {
    final threshold = span * minFrameRunRatio;
    for (var i = 0; i < profile.length; i++) {
      if (profile[i] >= threshold) return i;
    }
    return null;
  }

  /// Tương tự [_firstEdge] nhưng theo chiều ngược (mép dưới / mép phải).
  int? _lastEdge(List<double> profile, int span) {
    final threshold = span * minFrameRunRatio;
    for (var i = profile.length - 1; i >= 0; i--) {
      if (profile[i] >= threshold) return i;
    }
    return null;
  }
}

/// Nắn thẳng: warp ảnh gốc theo [quad] (4 góc khung phiếu) thành trang chuẩn
/// [outputSize] (PNG màu).
///
/// QUAN TRỌNG: [quad] là 4 góc NGOÀI khung (khung nằm cách mép giấy
/// `FrameSpec.insetRatio`). Kết quả warp đưa 4 góc đó về đúng hộp
/// `FrameSpec.outerRect(outputSize)` — chứ KHÔNG phải toàn trang — nhờ vậy
/// toạ độ nội dung phiếu sau khi nắn vẫn khớp tuyệt đối với [SheetLayout].
///
/// Với từng điểm ảnh đích ta giải toạ độ nền (u,v) trong ảnh gốc qua
/// homography (hộp khung trang chuẩn → khung trên ảnh), rồi nội suy song
/// tuyến. Điểm ngoài biên ảnh gốc được kẹp vào mép (nền trắng).
final class PerspectiveWarper {
  const PerspectiveWarper();

  Uint8List warpRectify(
    Uint8List imageBytes, {
    required AlignmentQuad quad,
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

    // Đích: hộp khung trên trang chuẩn (KHÔNG phải toàn trang).
    final outer = const FrameSpec().outerRect(outputSize);
    final dstCorners = [
      Offset(outer.left, outer.top),
      Offset(outer.right, outer.top),
      Offset(outer.right, outer.bottom),
      Offset(outer.left, outer.bottom),
    ];
    final homo = solveHomography(dstCorners, quad.corners);

    for (var y = 0; y < oh; y++) {
      for (var x = 0; x < ow; x++) {
        final src = applyHomography(homo, x.toDouble(), y.toDouble());
        // Điểm ngoài biên ảnh gốc được kẹp vào mép (nền ngoài ảnh gốc trắng
        // sẽ được dần đổi thành màu mép ảnh) — chấp nhận được vì ảnh chụp
        // luôn lớn hơn khung phiếu.
        final g = _sampleGray(bytes, channels, w, h, src.dx, src.dy);
        out.setPixelRgb(x, y, g, g, g);
      }
    }
    return img.encodePng(out, level: 3);
  }
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
    return idx < bytes.length ? bytes[idx] : 255;
  }

  final g00 = at(x0, y0);
  final g10 = at(x1, y0);
  final g01 = at(x0, y1);
  final g11 = at(x1, y1);
  final top = g00 + (g10 - g00) * fracX;
  final bottom = g01 + (g11 - g01) * fracX;
  return (top + (bottom - top) * fracY).round().clamp(0, 255);
}
