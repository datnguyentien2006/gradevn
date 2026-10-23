// R2 — Hình học overlay 4 ô vuông trên preview camera.
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
//  * Kiểm tra "đủ 4 mốc": [onConfidentMarkerCount].
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

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
