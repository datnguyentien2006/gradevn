import 'dart:ui' show Rect, Size;

import '../entities/sheet_spec.dart';

/// Hình học một khối đáp án trên phiếu: lưới `rows × columns` ô tròn.
///
/// Đây là thiết kế phiếu **gốc của GradeVN** (không sao chép hình học của ứng
/// dụng tham khảo): khối đáp án xếp thành 2 cột, mỗi khối tối đa 10 câu,
/// mỗi câu `answerChoices` lựa chọn. Cùng một `SheetLayout` được dùng bởi cả
/// bộ sinh fixture (test) và bộ đọc ảnh (pipeline) — nhờ vậy toạ độ luôn khớp.
final class AnswerBlockGeometry {
  const AnswerBlockGeometry({
    required this.rect,
    required this.rows,
    required this.columns,
    required this.cellWidth,
    required this.cellHeight,
    required this.firstQuestionIndex,
  });

  /// Hộp bao của cả khối (góc trên trái của ô (0,0)).
  final Rect rect;

  /// Số hàng (câu) trong khối.
  final int rows;

  /// Số cột (lựa chọn) trong khối.
  final int columns;

  final double cellWidth;
  final double cellHeight;

  /// Chỉ số câu đầu tiên của khối (0-based, tính cả phiếu).
  final int firstQuestionIndex;

  /// Ô của câu thứ `row`, lựa chọn thứ `col`.
  Rect cellRect(int row, int col) => Rect.fromLTWH(
        rect.left + col * cellWidth,
        rect.top + row * cellHeight,
        cellWidth,
        cellHeight,
      );
}

/// Bố cục tổng thể của một phiếu trả lời.
///
/// Toạ độ tính theo pixel của ảnh đã căn phẳng (sau warpPerspective ở M3).
/// Ở M2, ảnh fixture được render trực tiếp theo đúng bố cục này.
final class SheetLayout {
  SheetLayout._({
    required this.spec,
    required this.page,
    required this.rowsPerAnswerBlock,
    required this.answerBlocks,
    required this.studentCodeGrid,
    required this.examCodeGrid,
    required this.totalQuestions,
  });

  /// Tạo bố cục chuẩn cho một spec trên một trang có kích thước [page].
  factory SheetLayout.forSpec(
    SheetSpec spec, {
    required Size page,
    int rowsPerAnswerBlock = 10,
  }) {
    assert(rowsPerAnswerBlock > 0);
    final total = totalQuestionsFor(spec);
    final columns = spec.answerChoices;
    assert(columns > 0);

    // Tỉ lệ theo chiều rộng trang để bố cục co giãn theo độ phân giải ảnh.
    final cellW = page.width * 0.052;
    final cellH = cellW;
    final blockWidth = columns * cellW;
    final blockHeight = rowsPerAnswerBlock * cellH;

    final leftX = page.width * 0.10;
    final rightX = page.width * 0.90 - blockWidth;
    final startY = page.height * 0.19;
    final gapY = page.height * 0.030;

    final blocks = <AnswerBlockGeometry>[];
    for (var b = 0; b * rowsPerAnswerBlock < total; b++) {
      final isRight = b.isOdd;
      final rowIndex = b ~/ 2;
      final rows = (total - b * rowsPerAnswerBlock) < rowsPerAnswerBlock
          ? total - b * rowsPerAnswerBlock
          : rowsPerAnswerBlock;
      final top = startY + rowIndex * (blockHeight + gapY);
      blocks.add(
        AnswerBlockGeometry(
          rect: Rect.fromLTWH(isRight ? rightX : leftX, top, blockWidth, blockHeight),
          rows: rows,
          columns: columns,
          cellWidth: cellW,
          cellHeight: cellH,
          firstQuestionIndex: b * rowsPerAnswerBlock,
        ),
      );
    }

    final digitCell = page.width * 0.0245;
    final gridWidth = digitCell * digitColumns;
    final gridHeight = digitCell * digitRows;
    final studentGrid = Rect.fromLTWH(
      page.width * 0.08,
      page.height * 0.055,
      gridWidth,
      gridHeight,
    );
    final examGrid = Rect.fromLTWH(
      page.width * 0.90 - gridWidth,
      page.height * 0.055,
      gridWidth,
      gridHeight,
    );

    return SheetLayout._(
      spec: spec,
      page: page,
      rowsPerAnswerBlock: rowsPerAnswerBlock,
      answerBlocks: List.unmodifiable(blocks),
      studentCodeGrid: studentGrid,
      examCodeGrid: examGrid,
      totalQuestions: total,
    );
  }

  /// Tổng số câu của một spec (với phiếu nhiều phần, cộng số câu từng phần).
  static int totalQuestionsFor(SheetSpec spec) {
    if (spec.formType == SheetFormType.ministry) {
      return (spec.partOneCount ?? 0) +
          (spec.partTwoCount ?? 0) +
          (spec.partThreeCount ?? 0);
    }
    return spec.questionCount;
  }

  static const int digitRows = 6;
  static const int digitColumns = 10;

  final SheetSpec spec;
  final Size page;
  final int rowsPerAnswerBlock;

  /// Các khối đáp án, thứ tự trái→phải, trên→dưới.
  final List<AnswerBlockGeometry> answerBlocks;

  /// Lưới 6×10 cho số báo danh (mỗi hàng một chữ số).
  final Rect studentCodeGrid;

  /// Lưới 6×10 cho mã đề.
  final Rect examCodeGrid;

  /// Tổng số câu (đã tính cả trường hợp phiếu nhiều phần).
  final int totalQuestions;

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

  /// Ô của lưới chữ số: hàng = vị trí chữ số, cột = giá trị 0..9.
  static Rect digitCellRect(Rect grid, int row, int col) {
    final cellW = grid.width / digitColumns;
    final cellH = grid.height / digitRows;
    return Rect.fromLTWH(
      grid.left + col * cellW,
      grid.top + row * cellH,
      cellW,
      cellH,
    );
  }
}
