// R2/R3 — Hình học overlay 4 ô vuông trên preview camera.
//
// Thuần Dart (dart:ui Offset/Size + dart:math), không widget, không camera:
// unit-test trực tiếp. Nhiệm vụ:
//
//  * [CoverMapping] quy đổi khung hiển thị ↔ màn hình, theo cách
//    CameraPreview phủ kín (cover: lấy tỉ lệ lớn, phần lấn thừa bị cắt
//    đối xứng 2 bên → tâm khung trùng tâm màn hình).
//  * Ghim ô vuông vào ứng viên mốc: [snapSquareCenters] — mỗi ô lấy ứng
//    viên GẦN NHẤT trong bán kính cho phép; ứng viên đã bị ô khác chiếm
//    thì ô sau bỏ qua (mỗi mốc chỉ cho 1 ô).
//  * Kiểm tra "đủ 4 mốc": [onConfidentMarkerCount], và trạng thái KHOÁ
//    từng ô: [squareLockStates].
//  * R3 — PHÉP CHIẾU PHIẾU ẢO: [SheetProjection] dựng một hình chữ nhật
//    aspect-fit của TRANG GIẤY nguyên vẹn trong preview; 4 ô overlay được
//    ĐẶT tại vị trí chiếu của 4 ô vuông đen góc theo hình học template —
//    chúng đại diện cho chỗ 4 mốc CẦN nằm, không phải trang trí ở góc màn.
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// Ảnh xạ cover giữa khung preview hiển thị và màn hình.
final class CoverMapping {
  const CoverMapping({required this.frame, required this.screen});

  /// Khung hiển thị (pixel khung image stream, ở đúng chiều dọc).
  final Size frame;

  /// Màn hình (pixel lợi).
  final Size screen;

  double get _scale => math.max(
        screen.width / frame.width,
        screen.height / frame.height,
      );

  Offset get _offset => Offset(
        (screen.width - frame.width * _scale) / 2,
        (screen.height - frame.height * _scale) / 2,
      );

  /// Điểm khung → màn hình.
  Offset toScreen(Offset framePoint) => framePoint * _scale + _offset;

  /// Điểm màn hình → khung (kẹp biên khung cho an toàn).
  Offset toFrame(Offset screenPoint) {
    final p = (screenPoint - _offset) / _scale;
    return Offset(
      p.dx.clamp(0.0, frame.width),
      p.dy.clamp(0.0, frame.height),
    );
  }

  /// Tỉ lệ khung → ảnh chụp: điểm KHỈNH khi khung và ảnh cùng một góc nhìn.
  ///
  /// Ảnh chụp (takePicture) và khung preview đến từ cùng một cảm biến và cùng
  /// vùng nhìn (chưa có zoom riêng) → quy đổi theo TỈ LỆ trực tiếp theo cả
  /// hai trục. Xấp xỉ gần đúng (khung có thể bị cắt bớt FOV khác ảnh chụp);
  /// giáo viên luôn có thể kéo lại ô — xấp xỉ chỉ là ĐIỀM BẮT ĐẦU.
  Offset framePointToPhoto(Offset framePoint, Size photoFrame) => Offset(
        framePoint.dx / frame.width * photoFrame.width,
        framePoint.dy / frame.height * photoFrame.height,
      );
}

/// Ghim các ô vuông vào ứng viên mốc gần nhất.
///
/// [centers] là tâm ô vuông trên MÀN HÌNH; [candidates] là tâm mốc phát hiện
/// được cũng quy về MÀN HÌNH. Trả về danh sách theo chỉ số ô: tâm mới để
/// snap, hoặc null khi không có ứng viên phù hợp (GIỮ nguyên vị trí).
List<Offset?> snapSquareCenters(
  List<Offset> centers,
  List<Offset> candidates,
  double maxDistance,
) {
  final used = <Offset>{};
  return [
    for (final center in centers)
      _nearestFree(center, candidates, used, maxDistance),
  ];
}

Offset? _nearestFree(
  Offset center,
  List<Offset> candidates,
  Set<Offset> used,
  double maxDistance,
) {
  Offset? best;
  double? bestDist;
  for (final c in candidates) {
    if (used.contains(c)) continue;
    final d = (c - center).distance;
    if (d <= maxDistance && (bestDist == null || d < bestDist)) {
      best = c;
      bestDist = d;
    }
  }
  if (best != null) used.add(best);
  return best;
}

/// Số ô đang nằm đè lên một ứng viên (trong bán kính [onDistance] px màn
/// hình) — đủ 4 ô để hiển thị "Đã đủ 4 mốc".
int onConfidentMarkerCount(
  List<Offset> centers,
  List<Offset> candidates,
  double onDistance,
) {
  var count = 0;
  for (final center in centers) {
    final nearest = candidates.fold<double>(
      double.infinity,
      (d, c) => math.min(d, (c - center).distance),
    );
    if (nearest <= onDistance) count++;
  }
  return count;
}

/// R3 — Trạng thái KHOÁ từng ô theo thứ tự chỉ số: ô i "khoá" khi tồn tại
/// một ứng viên mốc cách tâm ô ≤ [onDistance]. UI dùng danh sách này để
/// tô viền xanh cho ô đã bám đúng mốc (đôi-optional một ứng viên có thể
/// đứng gần 2 ô nhưng mỗi ô vẫn tự đánh giá độc lập như [snapSquareCenters]).
List<bool> squareLockStates(
  List<Offset> centers,
  List<Offset> candidates,
  double onDistance,
) {
  return [
    for (final center in centers)
      candidates.any((c) => (c - center).distance <= onDistance),
  ];
}

/// R3 — PHÉP CHIẾU PHIẾU ẢO lên preview camera.
///
/// Dựng một "khung phiếu ảo" (virtual sheet outline): hình chữ nhật
/// aspect-fit của TRANG GIẤY HOÀN CHỈNH (kể cả lề in quanh khung mốc —
/// `pageSize` là kích thước trang chuẩn của [SheetLayout]) đặt giữa vùng
/// preview, chừa lề `marginRatio` mỗi phía. 4 ô vuông overlay được vẽ tại
/// vị trí CHIẾU của 4 tâm mốc góc (`markerCenters` — toạ độ trang chuẩn,
/// thứ tự tl, tr, br, bl) và cỡ ô theo cạnh mốc in thật (`markerSide`).
///
/// Nhờ vậy overlay KHÔNG phải trang trí cố định ở góc màn hình: khi camera
/// dịch/hay đổi bao quát, toàn bộ nhóm ô dịch theo outline (khung chiếm
/// vùng preview, recompute theo kích thước vùng đo được); và khi detector
/// thấy mốc thật, ô snap/khoá về đúng chỗ in như ứng dụng tham chiếu.
final class SheetProjection {
  const SheetProjection({
    required this.pageSize,
    required this.markerCenters,
    required this.markerSide,
    required this.area,
    this.marginRatio = 0.08,
  });

  /// Kích thước TRANG GIẤY hoàn chỉnh (kể cả lề) dùng làm tỉ lệ khung.
  final Size pageSize;

  /// 4 tâm mốc góc theo toạ độ trang chuẩn (tl, tr, br, bl).
  final List<Offset> markerCenters;

  /// Cạnh ô vuông mốc in thật (px trang chuẩn).
  final double markerSide;

  /// Kích thước vùng preview trên màn hình (px logic).
  final Size area;

  /// Tỉ lệ lề trống quanh khung ảo mỗi phía (0..1 của chiều tương ứng).
  final double marginRatio;

  /// Khung ảo: aspect-fit của [pageSize] vào [area] (uniform scale), căn giữa.
  Rect get outlineRect {
    final availW = area.width * (1 - 2 * marginRatio);
    final availH = area.height * (1 - 2 * marginRatio);
    final scale = math.min(
      availW / pageSize.width,
      availH / pageSize.height,
    );
    return Rect.fromCenter(
      center: Offset(area.width / 2, area.height / 2),
      width: pageSize.width * scale,
      height: pageSize.height * scale,
    );
  }

  /// Tỉ lệ quy đổi trang chuẩn → màn hình (uniform vì outline aspect-fit).
  double get _pageScale => outlineRect.width / pageSize.width;

  /// 4 tâm mốc đã chiếu lên màn hình, cùng thứ tự với [markerCenters].
  List<Offset> get projectedMarkerCenters {
    final rect = outlineRect;
    return [
      for (final m in markerCenters)
        Offset(rect.left + m.dx * _pageScale, rect.top + m.dy * _pageScale),
    ];
  }

  /// Cạnh ô mốc in thật quy về px màn hình (theo tỉ lệ khung ảo).
  double get projectedMarkerSide => markerSide * _pageScale;
}
