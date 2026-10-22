/// Loại phiếu đáp án (formContest trong phân tích tài liệu tham khảo).
///
/// `standard`  : phiếu dọc chuẩn (mặc định).
/// `fifty`     : phiếu 50 câu (hàng 2 cột, dạng "50").
/// `hundred20` : phiếu 120 câu (dạng "120").
/// `ministry`  : phiếu "bộ đề" của Sở/THPT quốc gia — nhiều phần (I/II/III),
///               mỗi phần số câu và điểm riêng.
enum SheetFormType { standard, fifty, hundred20, ministry }

/// Hướng phiếu khi quét.
enum SheetOrientation { portrait, landscape }

/// Mô tả hình học phiếu dùng cho lattice 11×6 (xem docs/reference-analysis.md §6).
/// Số liệu là thứ nguyên logic của grid — được tinh chỉnh lại bằng fixture ở M2.
class SheetGeometry {
  const SheetGeometry({
    required this.columnCells,
    required this.rowCells,
    this.cellInsetRatio = 0.05,
  });

  /// Số "cột logic" trong một khối: 11 (10 ô chữ số + lề) theo evidence.
  final int columnCells;

  /// Số "hàng logic" trong một khối: 6.
  final int rowCells;

  /// Tỉ lệ lề trong mỗi ô khi đo mật độ mực.
  final double cellInsetRatio;
}

/// Đặc điểm (spec) tổng hợp của một kỳ thi — đầu vào của engine quét OMR (M2/M3).
class SheetSpec {
  const SheetSpec({
    required this.formType,
    required this.orientation,
    required this.questionCount,
    required this.answerChoices,
    required this.maxScore,
    this.partOneCount,
    this.partTwoCount,
    this.partThreeCount,
    this.partOneWeight,
    this.partTwoWeight,
    this.partThreeWeight,
  }) : assert(formType != SheetFormType.ministry || partOneCount != null,
            'Phiếu nhiều phần cần số câu từng phần');

  final SheetFormType formType;
  final SheetOrientation orientation;
  final int questionCount;
  final int answerChoices;
  final double maxScore;

  /// Phiếu dạng "bộ đề": số câu của mỗi phần.
  final int? partOneCount;
  final int? partTwoCount;
  final int? partThreeCount;

  /// Điểm tối đa tương ứng mỗi phần (khi formType == ministry).
  final double? partOneWeight;
  final double? partTwoWeight;
  final double? partThreeWeight;

  SheetGeometry get geometry {
    switch (formType) {
      case SheetFormType.standard:
        return const SheetGeometry(columnCells: 11, rowCells: 6);
      case SheetFormType.fifty:
      case SheetFormType.hundred20:
      case SheetFormType.ministry:
        // Khối lattice dùng chung từ evidence (11 cột × 6 hàng).
        return const SheetGeometry(columnCells: 11, rowCells: 6);
    }
  }
}
