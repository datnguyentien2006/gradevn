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

/// R3 — CALIBRATION THỰC ĐỊA của 4 ô overlay trên màn CAMERA (2026-10-24,
/// đối chiếu ảnh tham chiếu TNMaker — đo trong không gian TOÀN MÀN DỌC
/// 720 × 1560 px; `landscape` là phép transpose chính xác cho màn NGANG
/// — cùng vị trí vật lý trên màn, chỉ đổi trục):
/// **R3.4** — màn chụp quay về DỌC: `forArea` tự chọn bản DỌC (720×1560);
/// bản NGANG giữ làm tham chiếu transpose.
///
/// **Dọc (portrait)** — không gian 720 × 1560:
///
/// | Vị trí     | x (trái→phải) | y (trên→dưới) | Kích thước |
/// |------------|---------------|---------------|-----------:|
/// | Trên-trái  | 0 → 156       | 64 → 266      | 157 × 203  |
/// | Trên-phải  | 563 → 719     | 64 → 266      | 157 × 203  |
/// | Dưới-trái  | 0 → 156       | 974 → 1177    | 157 × 203  |
/// | Dưới-phải  | 563 → 719     | 974 → 1177    | 157 × 203  |
///
/// **Ngang (landscape)** — không gian 1560 × 720 (transpose của bảng trên,
/// cùng vị trí vật lý trên màn): ô 203 × 157; cột ô x = 64 → 266 và
/// 974 → 1177; hàng ô y = 0 → 156 (sát mép trên) và 563 → 719 (sát mép dưới).
///
/// Biên INCLUSIVE (719 = 720 − 1, 1177 = đáy hàng dưới); lề trên 64 px =
/// đúng cao độ thanh trạng thái (khung không bị che); khoảng NHƯỜNG cho
/// nút chụp/hint/gallery nằm ở phía còn lại của màn. KHUNG Ô KHÔNG CÓ SỐ
/// (yêu cầu: y hệt TNMaker — ô chỉ là mục tiêu căn phiếu).
///
/// Ghi chú hướng camera: R3.4 — màn chụp GradeVN quay về DỌC (yêu cầu
/// người dùng): `forArea` chọn `portrait` (720×1560) khi vùng preview
/// dọc — bảng đo dọc là hình học gốc; `landscape` giữ làm tham chiếu
/// transpose. Mọi giá trị lưu TỈ LỆ (0..1) của vùng preview để áp dụng
/// cho mọi kích thước màn hình (không hardcode theo từng máy).
final class MarkerOverlayCalibration {
  const MarkerOverlayCalibration._({
    required this.measureWidth,
    required this.measureHeight,
    required this.boxWidthPx,
    required this.boxHeightPx,
    required this.innerLeft,
    required this.innerTop,
    required this.innerRight,
    required this.innerBottom,
  });

  final double measureWidth;
  final double measureHeight;
  final double boxWidthPx;
  final double boxHeightPx;

  /// Biên phủ của nhóm 4 ô trong không gian đo (biên INCLUSIVE):
  /// mép trái nhóm ô, mép trên, mép phải, mép dưới.
  final double innerLeft;
  final double innerTop;
  final double innerRight;
  final double innerBottom;

  /// DỌC — đo từ ảnh tham chiếu TNMaker xoay về dọc (720 × 1560).
  static final MarkerOverlayCalibration portrait = const
      MarkerOverlayCalibration._(
    measureWidth: 720,
    measureHeight: 1560,
    boxWidthPx: 157,
    boxHeightPx: 203,
    innerLeft: 0,
    innerTop: 64,
    innerRight: 719,
    innerBottom: 1177,
  );

  /// NGANG — transpose chính xác của [portrait] (1560 × 720): cùng vị trí
  /// vật lý của 4 ô trên màn hình vật lý; preview ngang khớp buffer.
  static final MarkerOverlayCalibration landscape = const
      MarkerOverlayCalibration._(
    measureWidth: 1560,
    measureHeight: 720,
    boxWidthPx: 203,
    boxHeightPx: 157,
    innerLeft: 64,
    innerTop: 0,
    innerRight: 1177,
    innerBottom: 719,
  );

  /// Chọn calibration theo HƯỚNG vùng preview hiện hành (screen shape).
  static MarkerOverlayCalibration forArea(Size area) =>
      area.width >= area.height ? landscape : portrait;

  /// Không gian đo gốc.
  Size get measureSize => Size(measureWidth, measureHeight);

  /// R3.4: cỡ ô tăng thêm [sizeInsetPx] px mỗi chiều so với bảng đo gốc —
  /// YÊU CẦU NGƯỜI DÙNG ("tăng thêm một vài pixel"). TÂM Ô KHÔNG ĐỔI
  /// ([centerFractions] không nhân inset) — ô phình đều quanh tâm cũ.
  /// Ghi chú: trên MỌI màn hình (khác 720×1560) luôn dùng TỈ LỆ (nhân với
  /// kích thước màn thật qua LayoutBuilder), nên "6 px" là 6 px của không
  /// gian đo tham chiếu — phóng to theo cùng tỉ lệ trên mọi máy.
  static const double sizeInsetPx = 6.0;

  /// Cỡ ô theo TỈ LỆ vùng preview: width × [widthFraction],
  /// height × [heightFraction] (đã gồm inset [sizeInsetPx]).
  double get widthFraction => (boxWidthPx + sizeInsetPx) / measureWidth;
  double get heightFraction => (boxHeightPx + sizeInsetPx) / measureHeight;

  /// Toạ độ tâm chuẩn hoá: quy về [0,1] của không gian đo.
  double _fracX(double px) => px / measureWidth;
  double _fracY(double py) => py / measureHeight;

  /// Tâm 4 ô overlay theo TỈ LỆ vùng preview, thứ tự tl, tr, br, bl
  /// (khi hiển thị theo hướng thật của màn). Tâm = biên trái + cỡ/2.
  List<Offset> get centerFractions => [
        Offset(_fracX(innerLeft + boxWidthPx / 2), // tl
            _fracY(innerTop + boxHeightPx / 2)),
        Offset(_fracX((innerRight + 1) - boxWidthPx / 2), // tr
            _fracY(innerTop + boxHeightPx / 2)),
        Offset(_fracX((innerRight + 1) - boxWidthPx / 2), // br
            _fracY((innerBottom + 1) - boxHeightPx / 2)),
        Offset(_fracX(innerLeft + boxWidthPx / 2), // bl
            _fracY((innerBottom + 1) - boxHeightPx / 2)),
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
