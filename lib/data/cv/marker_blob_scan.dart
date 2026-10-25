// Quét ô vuông đen (mốc) trong 1 vùng ảnh xám — THUẬT TOÁN DÙNG CHUNG giữa
// hai đường: chụp (`OmrScanService._locateDarkBlobInRect`) và LIVE overlay
// (luồng preview Y) để viền xanh từng ô = "chính phép quét này sẽ đọc được
// mốc khi chụp".
//
// R7 (2026-10-25 log9): đổi ý nghĩa viền xanh. Trước đây xanh = "detector
// thấy 1 ứng viên gần tâm ô" — trên cảnh quay phiếu qua màn hình, danh sách
// ứng viên gồm glyph/chữ/viền nên ô viền xanh chưa chắc đọc được mốc. Thời
// đó ô còn tự nhảy (snap theo quad rác) — bây giờ ô CỐ ĐỊNH, giáo viên chỉ
// DI CHUYỂN CAMERA; đèn xanh từng ô tính bằng chính phép quét khi chụp.

import 'dart:math' as math;
import 'dart:ui';

/// Kết quả tìm blob tối trong 1 ô ghim (hệ PIXEL của ảnh đang quét).
final class MarkerLocate {
  const MarkerLocate({
    required this.centroid,
    required this.side,
    required this.fill,
  });

  /// Tâm khối pixel tối (= tâm mốc thật).
  final Offset centroid;

  /// Cỡ cạnh ước lượng từ bbox khối tối (px).
  final double side;

  /// Tỉ lệ pixel tối trên khối bbox (0..1) — mốc là khối ĐẶC.
  final double fill;
}

/// Phóng chữ nhật TỈ LỆ [factor]× quanh tâm (kẹp [0..1]) — dùng cho cửa sổ
/// quét chống lệch FOV giữa preview và ảnh chụp (R5).
Rect expandFractionRect(Rect r, double factor) {
  final cx = r.left + r.width / 2;
  final cy = r.top + r.height / 2;
  final hw = r.width / 2 * factor;
  final hh = r.height / 2 * factor;
  return Rect.fromLTRB(
    (cx - hw).clamp(0.0, 1.0).toDouble(),
    (cy - hh).clamp(0.0, 1.0).toDouble(),
    (cx + hw).clamp(0.0, 1.0).toDouble(),
    (cy + hh).clamp(0.0, 1.0).toDouble(),
  );
}

/// Tìm blob tối trong 1 vùng ảnh xám.
///
/// [region] = vùng quét (px nguyên của ảnh); [grayAt] trả độ xám 0..255.
///
/// Thuật toán (khớp R6b/R6d của đường chụp):
///  1. Ngưỡng đen = phân vị 75 × 0.5 của cửa sổ ("mức trang giấy") — bezel
///     đen quanh trang không kéo lệch ngưỡng (khác mean tuane cũ).
///  2. Mask + BFS thành phần liên thông trên lưới bước subsample.
///  3. Giữ khối gần-ĐẶC (fill ≥ 0.5) gần-vuông (aspect 0.55..1.8) đủ to
///     (area ≥ 8 ở lưới bước).
///  4. Tâm tham chiếu = TÂM CỬA SỔ: mốc ghim nằm giữa ô; rác cạnh trang
///     (icon taskbar khi ô để sát mép, glyph chữ) thường ở RIA. Khối gần
///     tâm nhất thắng (có cộng hưởng nhẹ theo diện tích — `area × 0.01`).
/// R9 (2026-10-25 log12): tham số hoá NGƯỠNG để hai đường dùng chung code
/// nhưng RUỘT riêng: đường chụp giữ mặc định R6b (fill 0.5 / aspect
/// 0.55..1.8 / area ≥ 8, không giới hạn cỡ); luồng live đèn xanh SHĂT
/// HƠN (fill 0.6, aspect chặt, CỠ khối phải thuộc dải cỡ "ô đen in" theo
/// ô ghim) — chữ đậm/glyph/dải bezel không được phép xanh.
MarkerLocate? locateDarkBlobInRegion({
  required int width,
  required int height,
  required Rect region,
  required int Function(int x, int y) grayAt,
  double minFill = 0.5,
  double aspectMin = 0.55,
  double aspectMax = 1.8,
  int minAreaCells = 8,
  double minSidePx = 0.0,
  double maxSidePx = double.infinity,
}) {
  final x0 = region.left.clamp(0.0, width - 1.0).toInt();
  final y0 = region.top.clamp(0.0, height - 1.0).toInt();
  final x1 = region.right.clamp(x0 + 8.0, width.toDouble()).toInt();
  final y1 = region.bottom.clamp(y0 + 8.0, height.toDouble()).toInt();
  final rw = x1 - x0;
  final rh = y1 - y0;
  if (rw < 8 || rh < 8) return null;

  // Bước lấy mẫu giữ khối lượng tính toán ổn định bất kể ô to nhỏ.
  final step = math.max(1, math.min(rw, rh) ~/ 48);

  // Histogram độ sáng cửa sổ → mức "trang giấy" = phân vị 75.
  final hist = List<int>.filled(256, 0);
  var count = 0;
  for (var y = y0; y < y1; y += step) {
    for (var x = x0; x < x1; x += step) {
      hist[grayAt(x, y)]++;
      count++;
    }
  }
  if (count == 0) return null;
  var acc = 0;
  var pageLevel = 255;
  for (var v = 255; v >= 0; v--) {
    acc += hist[v];
    if (acc >= count * 0.25) {
      pageLevel = v;
      break;
    }
  }
  final threshold = (pageLevel * 0.5).clamp(30.0, 200.0).toDouble();

  // Mask đặc trên lưới bước [step] → thành phần liên thông (BFS 4 láng
  // giềng): giữ khối gần-vuông gần-đặc nhất.
  final gw = (rw + step - 1) ~/ step;
  final gh = (rh + step - 1) ~/ step;
  final mask = List<bool>.filled(gw * gh, false);
  for (var gy = 0; gy < gh; gy++) {
    final yy = y0 + gy * step;
    for (var gx = 0; gx < gw; gx++) {
      mask[gy * gw + gx] = grayAt(x0 + gx * step, yy) < threshold;
    }
  }

  final visited = List<bool>.filled(gw * gh, false);
  final stack = <int>[];
  MarkerLocate? best;
  var bestDist = double.infinity;
  final cxImg = x0 + rw / 2.0;
  final cyImg = y0 + rh / 2.0;

  for (var start = 0; start < mask.length; start++) {
    if (!mask[start] || visited[start]) continue;
    visited[start] = true;
    stack.add(start);
    var minX = start % gw, maxX = minX, minY = start ~/ gw, maxY = minY;
    var area = 0;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final iy = i ~/ gw;
      final ix = i % gw;
      area++;
      if (ix < minX) minX = ix;
      if (ix > maxX) maxX = ix;
      if (iy < minY) minY = iy;
      if (iy > maxY) maxY = iy;
      if (ix + 1 < gw && mask[i + 1] && !visited[i + 1]) {
        visited[i + 1] = true;
        stack.add(i + 1);
      }
      if (ix > 0 && mask[i - 1] && !visited[i - 1]) {
        visited[i - 1] = true;
        stack.add(i - 1);
      }
      if (iy + 1 < gh && mask[i + gw] && !visited[i + gw]) {
        visited[i + gw] = true;
        stack.add(i + gw);
      }
      if (iy > 0 && mask[i - gw] && !visited[i - gw]) {
        visited[i - gw] = true;
        stack.add(i - gw);
      }
    }

    final bw = maxX - minX + 1;
    final bh = maxY - minY + 1;
    if (area < minAreaCells) continue; // nhỏ hơn mốc in ở mọi cỡ ảnh hợp lệ
    final fill = area / (bw * bh);
    if (fill < minFill) continue; // mốc là khối ĐẶC — glyph/viền rỉ ra
    final aspect = bw / bh;
    if (aspect < aspectMin || aspect > aspectMax) {
      continue; // cột chữ/dải bezel dẹt (R9: ngưỡng tham số hoá)
    }
    final side = (bw + bh) / 2 * step;
    // R9: cỡ khối phải là CỠ "ô đen in trên phiếu" theo tham chiếu người gọi.
    if (side < minSidePx || side > maxSidePx) continue;
    final centroid = Offset(
      x0 + (minX + maxX + 1) / 2 * step,
      y0 + (minY + maxY + 1) / 2 * step,
    );
    // Gần tâm nhứt thắng; bằng cách nào thì khối to hơn thắng.
    final dist = (centroid - Offset(cxImg, cyImg)).distance - area * 0.01;
    if (dist < bestDist) {
      bestDist = dist;
      best = MarkerLocate(
        centroid: centroid,
        side: side,
        fill: fill,
      );
    }
  }
  return best;
}
