/// Bố cục phiếu TN 40 câu (đo trực tiếp từ `docs/reference-sheets/PhieuTN40cau.jpg`,
/// ảnh scan 3125×4421 px) — THEO DẠNG **khung mốc** (marker frame):
/// gốc toạ độ = tâm ô vuông đen trên-trái; 1 đơn vị = 1 px của ảnh scan tham chiếu.
///
/// Cách đo: connected-components trên ảnh nhị phân → 12 ô vuông đen đặc
/// (6 ô lớn 87 px ở 2 biên dọc × 3 hàng; 6 ô nhỏ 63 px ở 2 biên trong × 3 hàng),
/// rồi centroid từng bong bóng (SBD / mã đề / 40 câu) đo chính xác từng ô.
///
/// Toàn bộ hình học của pipeline/render/fixture đều dẫn ra từ template này —
/// một nguồn sự thật duy nhất (FormSpec data-driven: template mới cắm sau).
final class SheetTemplate {
  const SheetTemplate({
    required this.id,
    required this.frameWidth,
    required this.frameHeight,
    required this.markerSide,
    required this.smallMarkerSide,
    required this.bubbleDiameter,
    required this.digitValueRows,
    required this.studentSlots,
    required this.examSlots,
    required this.sbdSlotCols,
    required this.examSlotCols,
    required this.answerGroups,
    this.extraMarkers = const <MarkerPoint>[],
  });

  final String id;

  /// Cạnh khung mốc (tâm 4 ô vuông lớn góc). Toàn bộ toạ độ dưới đây tính
  /// theo hệ này: x ∈ [0..frameWidth], y ∈ [0..frameHeight].
  final double frameWidth;
  final double frameHeight;

  /// Cạnh ô vuông mốc lớn (in ở 2 biên) và ô mốc nhỏ (bên trong).
  final double markerSide;
  final double smallMarkerSide;

  /// Đường kính bong bóng (bbox bao cả vòng viền).
  final double bubbleDiameter;

  /// Lưới chữ số: mỗi cột 1 lưới (chữ số của SBD/mã đề), mỗi hàng 1 giá trị.
  final int digitValueRows;
  final int studentSlots; // SBD: 6 chữ số
  final int examSlots; // MÃ ĐỀ: 3 chữ số

  /// Tâm cột chữ số của lưới SBD / MÃ ĐỀ.
  final List<double> sbdSlotCols;
  final List<double> examSlotCols;

  /// Các nhóm câu: 4 nhóm × 10 câu.
  final List<AnswerGroupSpec> answerGroups;

  /// Các mốc phụ (không dùng cho homography, dùng để kiểm chứng/tinh chỉnh).
  final List<MarkerPoint> extraMarkers;

  /// 4 tâm ô vuông lớn ở 4 góc (thứ tự tl, tr, br, bl).
  List<MarkerPoint> get cornerMarkers => <MarkerPoint>[
        const MarkerPoint(0, 0),
        MarkerPoint(frameWidth, 0),
        MarkerPoint(frameWidth, frameHeight),
        MarkerPoint(0, frameHeight),
      ];

  /// Lề giấy quanh khung mốc (đơn vị template). Trang giấy bao gồm cả lề này
  /// để mốc không bị cắt mép khi in/quét (đo từ ảnh tham chiếu ≈ 420/500 px).
  static const double pageMarginX = 420;
  static const double pageMarginY = 500;

  /// Toàn trang giấy (khung mốc + 2 lề): 3151 × 4409 đơn vị (instance).
  double get pageWidthUnits => frameWidth + 2 * pageMarginX;
  double get pageHeightUnits => frameHeight + 2 * pageMarginY;

  /// Điểm ngưỡng tối đa 1 lưới: số câu = số nhóm × số hàng (40 câu).
  int get totalQuestions =>
      answerGroups.fold(0, (sum, g) => sum + g.rows);

  /// Ví dụ thực tế duy nhất hiện có: phiếu TN 40 câu.
  static SheetTemplate get tn40Standard => const SheetTemplate(
        id: 'tn40',
        frameWidth: 2311,
        frameHeight: 3409,
        markerSide: 87,
        smallMarkerSide: 63,
        bubbleDiameter: 80,
        digitValueRows: 10,
        studentSlots: 6,
        examSlots: 3,
        sbdSlotCols: [308.5, 402.0, 495.5, 589.0, 682.5, 776.0],
        examSlotCols: [978.5, 1072.0, 1165.5],
        answerGroups: [
          AnswerGroupSpec(
            firstQuestion: 0,
            colX: [1552.0, 1645.5, 1739.0, 1832.5],
            row0Y: 1008.5,
            rowPitch: 108.6,
          ),
          AnswerGroupSpec(
            firstQuestion: 10,
            colX: [405.5, 498.3, 591.2, 684.0],
            row0Y: 2207.0,
            rowPitch: 108.7,
          ),
          AnswerGroupSpec(
            firstQuestion: 20,
            colX: [978.5, 1071.8, 1165.2, 1258.5],
            row0Y: 2207.0,
            rowPitch: 108.7,
          ),
          AnswerGroupSpec(
            firstQuestion: 30,
            colX: [1552.0, 1645.5, 1739.0, 1832.5],
            row0Y: 2207.0,
            rowPitch: 108.7,
          ),
        ],
        extraMarkers: [
          // Ô lớn giữa (cùng cỡ với ô góc).
          MarkerPoint(0, 1705),
          MarkerPoint(2311, 1705),
          // Ô nhỏ (bên trong, 2 × 3).
          MarkerPoint(871, 904.5),
          MarkerPoint(1448, 904.5),
          MarkerPoint(871, 2101.5),
          MarkerPoint(1448, 2101.5),
          MarkerPoint(871, 3297),
          MarkerPoint(1448, 3297),
        ],
      );

  // Lưới chữ số — hàng giá trị v (0..9).
  static const double digitRow0Y = 1008.5;
  static const double digitRowPitch = 108.6;

  /// Tâm hàng giá trị [value] (0..9) của lưới chữ số.
  double digitValueRowY(int value) => digitRow0Y + value * digitRowPitch;
}

/// Tâm mốc (đơn vị khung mốc chuẩn).
final class MarkerPoint {
  const MarkerPoint(this.x, this.y);

  final double x;
  final double y;
}

/// Nhóm 10 câu: mỗi câu 1 hàng, lựa chọn A..D mỗi câu 1 cột.
final class AnswerGroupSpec {
  const AnswerGroupSpec({
    required this.firstQuestion,
    required this.colX,
    required this.row0Y,
    required this.rowPitch,
  });

  /// Câu đầu tiên (0-based toàn trang).
  final int firstQuestion;

  /// Tâm cột lựa chọn A..D.
  final List<double> colX;

  /// Tâm hàng của câu đầu tiên trong nhóm.
  final double row0Y;
  final double rowPitch;

  int get rows => 10;
  int get columns => colX.length;
}
