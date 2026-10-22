import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../entities/sheet_spec.dart';
import 'sheet_template.dart';

export 'sheet_template.dart' show AnswerGroupSpec, MarkerPoint, SheetTemplate;

/// Hình học phiếu: nguồn duy nhất của layout cho pipeline đo mật độ,
/// bộ render phiếu in và bộ fixture test.
final class SheetLayout {
  SheetLayout._({
    required this.template,
    required this.page,
    required this.spec,
    required this.answerBlocks,
    required this.studentCodeGrid,
    required this.examCodeGrid,
    required this.totalQuestions,
  });

  /// Tạo layout cho một spec (hiện phiếu TN 40 câu là template chuẩn; phiếu bộ
  /// đề dùng chung template này cho tới khi có phiếu in riêng do người dùng cung cấp).
  factory SheetLayout.forSpec(
    SheetSpec spec, {
    required Size page,
  }) =>
      SheetLayout.forTemplate(
        SheetTemplate.tn40Standard,
        page: page,
        spec: spec,
      );

  /// Tạo layout từ template với kích thước trang xử lý [page].
  ///
  /// `spec` chỉ quyết định số lựa chọn in trên phiếu (A..D); hình học theo
  /// template đo từ phiếu thật.
  factory SheetLayout.forTemplate(
    SheetTemplate template, {
    required Size page,
    SheetSpec? spec,
  }) {
    assert(template.answerGroups.isNotEmpty);
    final sx = page.width / template.pageWidthUnits;
    final sy = page.height / template.pageHeightUnits;

    // Điểm rel trong KHUNG MỘC → toạ độ trang giấy (cộng lề).
    Offset pagePoint(double relX, double relY) => Offset(
          (SheetTemplate.pageMarginX + relX) * sx,
          (SheetTemplate.pageMarginY + relY) * sy,
        );

    final choices = spec?.answerChoices ?? template.answerGroups.first.columns;
    final blocks = <AnswerBlockGeometry>[
      for (final group in template.answerGroups)
        AnswerBlockGeometry(
          firstQuestionIndex: group.firstQuestion,
          rows: group.rows,
          columns: math.min(choices, group.columns),
          firstColCenterX: pagePoint(group.colX.first, 0).dx,
          colPitch: _pitch(group.colX) * sx,
          row0CenterY: pagePoint(0, group.row0Y).dy,
          rowPitch: group.rowPitch * sy,
          cellSize: template.bubbleDiameter * sx,
        ),
    ];

    DigitGridGeometry digitGrid(List<double> slotCols) => DigitGridGeometry(
          slotCenters: [for (final relX in slotCols) pagePoint(relX, 0).dx],
          valueRowCenters: [
            for (var v = 0; v < template.digitValueRows; v++)
              pagePoint(0, template.digitValueRowY(v)).dy,
          ],
          cellSize: template.bubbleDiameter * sx,
        );

    final total =
        spec == null ? template.totalQuestions : totalQuestionsFor(spec);
    return SheetLayout._(
      template: template,
      page: page,
      spec: spec,
      answerBlocks: List.unmodifiable(blocks),
      studentCodeGrid: digitGrid(template.sbdSlotCols),
      examCodeGrid: digitGrid(template.examSlotCols),
      totalQuestions: total,
    );
  }

  static double _pitch(List<double> centers) => centers.length < 2
      ? 0
      : (centers.last - centers.first) / (centers.length - 1);

  /// Tổng số câu của một spec (phiếu nhiều phần: cộng số câu từng phần).
  static int totalQuestionsFor(SheetSpec spec) {
    if (spec.formType == SheetFormType.ministry) {
      return (spec.partOneCount ?? 0) +
          (spec.partTwoCount ?? 0) +
          (spec.partThreeCount ?? 0);
    }
    return spec.questionCount;
  }

  /// Cỡ trang chuẩn của pipeline (toàn trang giấy × 0.5 = 1576×2205).
  static Size get standardPage => const Size(1576, 2205);

  final SheetTemplate template;
  final Size page;

  /// Spec tạo ra layout này (null khi tạo trực tiếp từ template).
  final SheetSpec? spec;

  /// Spec hiệu lực của layout — mặc định: phiếu chuẩn 40 câu (A–D, thang 10).
  SheetSpec get specOrDefault =>
      spec ??
      const SheetSpec(
        formType: SheetFormType.standard,
        orientation: SheetOrientation.portrait,
        questionCount: 40,
        answerChoices: 4,
        maxScore: 10,
      );

  /// Các khối đáp án (thứ tự theo câu: khối 1 = câu 1..10, v.v.).
  final List<AnswerBlockGeometry> answerBlocks;

  /// Lưới số báo danh (6 lưới × 10 giá trị).
  final DigitGridGeometry studentCodeGrid;

  /// Lưới mã đề (3 lưới × 10 giá trị).
  final DigitGridGeometry examCodeGrid;

  /// Tổng số câu phải chấm.
  final int totalQuestions;

  /// Hệ số quy đổi template → trang chuẩn (theo chiều rộng).
  double get scale => page.width / template.pageWidthUnits;

  /// Số hàng mỗi khối đáp án (template TN40: 10).
  int get rowsPerAnswerBlock => answerBlocks.first.rows;

  /// Điểm rel trong KHUNG MỘC → toạ độ trang giấy (px trang chuẩn).
  Offset toPage(double relX, double relY) => Offset(
        (SheetTemplate.pageMarginX + relX) * (page.width / template.pageWidthUnits),
        (SheetTemplate.pageMarginY + relY) * (page.height / template.pageHeightUnits),
      );

  /// 4 tâm mốc góc trên trang chuẩn (tl, tr, br, bl) — đích của warp.
  List<Offset> get cornerMarkerCenters => [
        toPage(0, 0),
        toPage(template.frameWidth, 0),
        toPage(template.frameWidth, template.frameHeight),
        toPage(0, template.frameHeight),
      ];

  /// Ô của câu thứ [questionIndex], lựa chọn thứ [choiceIndex].
  Rect answerCellRect(int questionIndex, int choiceIndex) {
    for (final block in answerBlocks) {
      final row = questionIndex - block.firstQuestionIndex;
      if (row >= 0 && row < block.rows) {
        return block.cellRect(row, choiceIndex);
      }
    }
    throw RangeError('Câu $questionIndex nằm ngoài bố cục phiếu.');
  }
}

/// Khối đáp án trên trang chuẩn: mỗi câu 1 hàng, lựa chọn mỗi câu 1 cột.
final class AnswerBlockGeometry {
  const AnswerBlockGeometry({
    required this.firstQuestionIndex,
    required this.rows,
    required this.columns,
    required this.firstColCenterX,
    required this.colPitch,
    required this.row0CenterY,
    required this.rowPitch,
    required this.cellSize,
  });

  /// Câu đầu tiên của khối (0-based toàn trang).
  final int firstQuestionIndex;
  final int rows;
  final int columns;

  /// Tâm cột lựa chọn đầu tiên + bước cột (px trang chuẩn).
  final double firstColCenterX;
  final double colPitch;

  /// Tâm hàng câu đầu + bước hàng (px trang chuẩn).
  final double row0CenterY;
  final double rowPitch;

  /// Cạnh ô đo (đường kính bong bóng quy đổi).
  final double cellSize;

  /// Tâm bong bóng của ô (row, col).
  Offset center(int row, int col) => Offset(
        firstColCenterX + col * colPitch,
        row0CenterY + row * rowPitch,
      );

  /// Hộp ô đo (tâm bong bóng, cạnh [cellSize]).
  Rect cellRect(int row, int col) {
    final c = center(row, col);
    return Rect.fromCenter(center: c, width: cellSize, height: cellSize);
  }
}

/// Lưới chữ số: mỗi cột 1 lưới (một chữ số), mỗi hàng 1 giá trị 0..9.
final class DigitGridGeometry {
  const DigitGridGeometry({
    required this.slotCenters,
    required this.valueRowCenters,
    required this.cellSize,
  });

  /// X tâm từng lưới (một lưới mỗi chữ số).
  final List<double> slotCenters;

  /// Y tâm hàng giá trị (0..9).
  final List<double> valueRowCenters;
  final double cellSize;

  int get slots => slotCenters.length;
  int get rows => valueRowCenters.length;

  /// Tâm bong bóng (lưới [slot], giá trị [value]).
  Offset center(int slot, int value) => Offset(
        slotCenters[slot],
        valueRowCenters[value],
      );

  Rect cellRect(int slot, int value) {
    final c = center(slot, value);
    return Rect.fromCenter(center: c, width: cellSize, height: cellSize);
  }
}
