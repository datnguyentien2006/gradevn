import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/domain/services/sheet_layout.dart';

void main() {
  group('SheetLayout', () {
    const page = Size(1240, 1754);

    test('phiếu chuẩn 40 câu: 4 khối 10×4, phủ đủ 40 câu', () {
      const spec = SheetSpec(
        formType: SheetFormType.standard,
        orientation: SheetOrientation.portrait,
        questionCount: 40,
        answerChoices: 4,
        maxScore: 10,
      );
      final layout = SheetLayout.forSpec(spec, page: page);

      expect(layout.totalQuestions, 40);
      expect(layout.answerBlocks.length, 4);
      for (final block in layout.answerBlocks) {
        expect(block.rows, 10);
        expect(block.columns, 4);
      }
      expect(layout.answerBlocks.map((b) => b.firstQuestionIndex), <int>[0, 10, 20, 30]);

      // Câu đầu và câu cuối lấy được toạ độ.
      final first = layout.answerCellRect(0, 0);
      final last = layout.answerCellRect(39, 3);
      expect(first.width, closeTo(layout.answerBlocks.first.cellWidth, 1e-9));
      expect(first.left, closeTo(layout.answerBlocks.first.rect.left, 1e-9));
      expect(last.left, greaterThan(page.width / 2));

      // Mọi ô đều nằm trong trang.
      for (var q = 0; q < 40; q++) {
        for (var c = 0; c < 4; c++) {
          final r = layout.answerCellRect(q, c);
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(page.width));
          expect(r.bottom, lessThanOrEqualTo(page.height));
        }
      }
    });

    test('phiếu bộ đề: tổng số câu = số câu các phần', () {
      const spec = SheetSpec(
        formType: SheetFormType.ministry,
        orientation: SheetOrientation.portrait,
        questionCount: 0,
        answerChoices: 4,
        maxScore: 10,
        partOneCount: 4,
        partTwoCount: 10,
        partThreeCount: 6,
        partOneWeight: 4,
        partTwoWeight: 5,
        partThreeWeight: 1,
      );
      final layout = SheetLayout.forSpec(spec, page: page);
      expect(layout.totalQuestions, 20);
      expect(layout.answerBlocks.length, 2);
      expect(layout.answerBlocks.first.rows, 10);
      expect(layout.answerBlocks.last.rows, 10);
    });

    test('khối cuối có thể ít hàng hơn rowsPerAnswerBlock', () {
      const spec = SheetSpec(
        formType: SheetFormType.standard,
        orientation: SheetOrientation.portrait,
        questionCount: 25,
        answerChoices: 5,
        maxScore: 10,
      );
      final layout = SheetLayout.forSpec(spec, page: page);
      expect(layout.answerBlocks.length, 3);
      expect(layout.answerBlocks.last.rows, 5);
      expect(layout.answerBlocks.last.columns, 5);
      expect(layout.answerCellRect(24, 4), isNotNull);
      expect(() => layout.answerCellRect(25, 0), throwsRangeError);
    });

    test('lưới chữ số 6×10 nằm trong trang và không chồng lên khối đáp án', () {
      const spec = SheetSpec(
        formType: SheetFormType.standard,
        orientation: SheetOrientation.portrait,
        questionCount: 40,
        answerChoices: 4,
        maxScore: 10,
      );
      final layout = SheetLayout.forSpec(spec, page: page);

      for (final grid in <Rect>[layout.studentCodeGrid, layout.examCodeGrid]) {
        expect(grid.left, greaterThanOrEqualTo(0));
        expect(grid.right, lessThanOrEqualTo(page.width));
        expect(grid.top, greaterThanOrEqualTo(0));
        expect(grid.bottom, lessThan(layout.answerBlocks.first.rect.top));
      }
      expect(layout.studentCodeGrid.right, lessThan(layout.examCodeGrid.left));

      final cell = SheetLayout.digitCellRect(layout.studentCodeGrid, 0, 0);
      expect(cell.width, closeTo(layout.studentCodeGrid.width / 10, 1e-9));
      expect(cell.height, closeTo(layout.studentCodeGrid.height / 6, 1e-9));
      final last = SheetLayout.digitCellRect(layout.studentCodeGrid, 5, 9);
      expect(last.right, closeTo(layout.studentCodeGrid.right, 1e-6));
      expect(last.bottom, closeTo(layout.studentCodeGrid.bottom, 1e-6));
    });

    test('bố cục co giãn theo kích thước trang', () {
      const spec = SheetSpec(
        formType: SheetFormType.standard,
        orientation: SheetOrientation.portrait,
        questionCount: 40,
        answerChoices: 4,
        maxScore: 10,
      );
      final small = SheetLayout.forSpec(spec, page: const Size(620, 877));
      final large = SheetLayout.forSpec(spec, page: const Size(2480, 3508));
      expect(large.answerBlocks.first.cellWidth, closeTo(small.answerBlocks.first.cellWidth * 4, 1e-6));
      expect(large.answerCellRect(0, 0).left, closeTo(small.answerCellRect(0, 0).left * 4, 1e-6));
    });
  });
}
