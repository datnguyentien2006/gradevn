import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/domain/services/sheet_layout.dart';

void main() {
  group('SheetTemplate TN40 (hình học measured)', () {
    final template = SheetTemplate.tn40Standard;

    test('thông số chuẩn: 4 nhóm × 10 câu, lưới 6/3 lưới chữ số', () {
      expect(template.answerGroups.length, 4);
      expect(template.totalQuestions, 40);
      expect(template.studentSlots, 6);
      expect(template.examSlots, 3);
      expect(template.digitValueRows, 10);
      expect(template.answerGroups.map((g) => g.firstQuestion), <int>[0, 10, 20, 30]);
    });

    test('trang giấy = khung mốc + 2 lề; tỉ lệ ~A4', () {
      expect(template.pageWidthUnits, closeTo(3151, 1e-9));
      expect(template.pageHeightUnits, closeTo(4409, 1e-9));
      expect(template.pageWidthUnits / template.pageHeightUnits, closeTo(0.7147, 0.01));
    });

    test('tọa độ nhóm khớp giá trị đo từ PhieuTN40cau.jpg', () {
      final g1 = template.answerGroups[0];
      expect(g1.colX.first, closeTo(1552, 0.01));
      expect(g1.row0Y, closeTo(1008.5, 0.01));
      final g2 = template.answerGroups[1];
      expect(g2.colX.first, closeTo(405.5, 0.01));
      expect(g2.row0Y, closeTo(2207, 0.01));
    });
  });

  group('SheetLayout (trang chuẩn)', () {
    // Trang chuẩn xử lý 1576×2205 = (3151+... )/2 (khung mốc + lề).
    final page = SheetLayout.standardPage;

    SheetLayout build() {
      const spec = SheetSpec(
        formType: SheetFormType.standard,
        orientation: SheetOrientation.portrait,
        questionCount: 40,
        answerChoices: 4,
        maxScore: 10,
      );
      return SheetLayout.forSpec(spec, page: page);
    }

    test('phiếu chuẩn 40 câu: 4 khối 10×4 theo thứ tự câu', () {
      final layout = build();
      expect(layout.totalQuestions, 40);
      expect(layout.answerBlocks.length, 4);
      expect(
        layout.answerBlocks.map((b) => b.firstQuestionIndex),
        <int>[0, 10, 20, 30],
      );
      for (final block in layout.answerBlocks) {
        expect(block.rows, 10);
        expect(block.columns, 4);
      }
      expect(layout.rowsPerAnswerBlock, 10);
    });

    test('tâm ô khớp công thức quy đổi (mốc + lề) theo template', () {
      final layout = build();
      final template = layout.template;
      final sx = page.width / template.pageWidthUnits;
      final sy = page.height / template.pageHeightUnits;

      final c0 = layout.answerBlocks[0].center(0, 0);
      expect(c0.dx, closeTo((SheetTemplate.pageMarginX + 1552.0) * sx, 0.01));
      expect(c0.dy, closeTo((SheetTemplate.pageMarginY + 1008.5) * sy, 0.01));

      final c39 = layout.answerBlocks[3].center(9, 3);
      expect(c39.dx,
          closeTo((SheetTemplate.pageMarginX + 1832.5) * sx, 0.01));
      expect(c39.dy,
          closeTo((SheetTemplate.pageMarginY + 2207 + 9 * 108.7) * sy, 0.05));

      // Bước cột/hàng theo template.
      expect(
        layout.answerBlocks[0].colPitch,
        closeTo((1645.5 - 1552.0) * sx, 0.01),
      );
      expect(layout.answerBlocks[0].rowPitch, closeTo(108.6 * sy, 0.01));
    });

    test('mọi ô đáp án đều nằm trong trang giấy', () {
      final layout = build();
      for (var q = 0; q < 40; q++) {
        for (var c = 0; c < 4; c++) {
          final r = layout.answerCellRect(q, c);
          expect(r.left, greaterThanOrEqualTo(0), reason: 'q=$q c=$c');
          expect(r.top, greaterThanOrEqualTo(0), reason: 'q=$q c=$c');
          expect(r.right, lessThanOrEqualTo(page.width), reason: 'q=$q c=$c');
          expect(r.bottom, lessThanOrEqualTo(page.height), reason: 'q=$q c=$c');
        }
      }
    });

    test('answerCellRect ánh xạ đúng câu vào nhóm', () {
      final layout = build();
      // Câu 25 (index 24) thuộc nhóm 3 (firstQuestion 20, row 4).
      final viaHelper = layout.answerCellRect(24, 2);
      final viaBlock = layout.answerBlocks[2].cellRect(4, 2);
      expect(viaHelper, viaBlock);
      expect(() => layout.answerCellRect(40, 0), throwsRangeError);
    });

    test('lưới chữ số: SBD 6 lưới, mã đề 3 lưới × 10 giá trị', () {
      final layout = build();
      expect(layout.studentCodeGrid.slots, 6);
      expect(layout.examCodeGrid.slots, 3);
      expect(layout.studentCodeGrid.rows, 10);

      // Cột đầu của SBD: tâm rel 308.5; hàng giá trị 0: rel 1008.5.
      final first = layout.studentCodeGrid.center(0, 0);
      final sx = page.width / layout.template.pageWidthUnits;
      final sy = page.height / layout.template.pageHeightUnits;
      expect(first.dx,
          closeTo((SheetTemplate.pageMarginX + 308.5) * sx, 0.01));
      expect(first.dy,
          closeTo((SheetTemplate.pageMarginY + 1008.5) * sy, 0.01));

      // Lưới chữ số nằm TRÊN khối đáp án góc trái (trước hàng 2207).
      expect(
        layout.studentCodeGrid.valueRowCenters.last,
        lessThan(layout.answerBlocks[1].row0CenterY),
      );
      // SBD nằm bên trái lưới mã đề.
      expect(
        layout.studentCodeGrid.slotCenters.last,
        lessThan(layout.examCodeGrid.slotCenters.first),
      );
    });

    test('mốc góc trên trang chuẩn đối xứng qua lề', () {
      final layout = build();
      final centers = layout.cornerMarkerCenters;
      expect(centers.length, 4);
      // TL tại (420,500)*scale; TR tại (2731,500); BL tại (420,3909); BR (2731,3909).
      final sy = page.height / layout.template.pageHeightUnits;
      expect(centers[0], Offset((420 + 0) * layout.scale, 500 * sy));
      expect(centers[1].dx, closeTo((420 + 2311) * layout.scale, 0.01));
      expect(centers[2].dx, closeTo((420 + 2311) * layout.scale, 0.01));
      expect(centers[2].dy, closeTo((500 + 3409) * sy, 0.01));
      expect(centers[3].dx, closeTo((420 + 0) * layout.scale, 0.01));
    });

    test('specOrDefault chuẩn 40 câu khi layout không nhận spec', () {
      final layout = SheetLayout.forTemplate(
        SheetTemplate.tn40Standard,
        page: page,
      );
      expect(layout.specOrDefault.formType, SheetFormType.standard);
      expect(layout.specOrDefault.questionCount, 40);
      expect(layout.totalQuestions, 40);
    });

    test('tổng câu phiếu bộ đề = tổng các phần', () {
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
      expect(SheetLayout.totalQuestionsFor(spec), 20);
    });

    test('bố cục co giãn tuyến tính theo kích thước trang', () {
      final small = build();
      final large = SheetLayout.forTemplate(
        SheetTemplate.tn40Standard,
        page: page * 2,
        spec: small.specOrDefault,
      );
      expect(large.answerBlocks.first.cellSize,
          closeTo(small.answerBlocks.first.cellSize * 2, 1e-6));
      expect(large.answerCellRect(0, 0).left,
          closeTo(small.answerCellRect(0, 0).left * 2, 1e-6));
    });
  });
}
