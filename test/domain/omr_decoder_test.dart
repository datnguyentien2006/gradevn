import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/domain/services/omr_decoder.dart';

DensityBlock _block(List<List<double>> rows) => DensityBlock(rows);

List<double> _row(List<double> values, {int columns = 4}) {
  final row = List<double>.filled(columns, 0.01);
  for (var i = 0; i < values.length && i < columns; i++) {
    row[i] = values[i];
  }
  return row;
}

void main() {
  group('OmrDecoder.decodeAnswers', () {
    const spec = SheetSpec(
      formType: SheetFormType.standard,
      orientation: SheetOrientation.portrait,
      questionCount: 12,
      answerChoices: 4,
      maxScore: 10,
    );

    test('chọn ô đậm nhất; dưới ngưỡng = null; tôn trọng totalQuestions', () {
      final block0 = _block([
        _row([0.1, 0.6, 0.1, 0.1]), // B
        _row([0.05, 0.08, 0.07, 0.06]), // trống
        _row([0.35, 0.1, 0.1, 0.34]), // A (hoà sát → cột nhỏ hơn)
        for (var i = 0; i < 7; i++) _row([0.0, 0.0, 0.0, 0.0]), // trống
      ]);
      final block1 = _block([
        _row([0.1, 0.1, 0.1, 0.9]), // D (câu 10)
        _row([0.1, 0.8, 0.1, 0.1]), // B (câu 11)
        _row([0.9, 0.9, 0.9, 0.9]), // ngoài phạm vi 12 câu → bỏ qua
      ]);

      final decoder = const OmrDecoder();
      final answers = decoder.decodeAnswers(
        blocks: [block0, block1],
        spec: spec,
        totalQuestions: 12,
      );

      expect(answers.length, 12);
      expect(answers[0], 'B');
      expect(answers[1], isNull);
      expect(answers[2], 'A');
      expect(answers[5], isNull);
      expect(answers[10], 'D');
      expect(answers[11], 'B');
    });

    test('ngưỡng thấp hơn → nhận diện được ô mờ', () {
      final block = _block([
        _row([0.2, 0.0, 0.0, 0.0]),
      ]);
      const strict = OmrDecoder();
      const lax = OmrDecoder(markThreshold: 0.15);
      expect(strict.decodeAnswers(blocks: [block], spec: spec, totalQuestions: 1).first, isNull);
      expect(lax.decodeAnswers(blocks: [block], spec: spec, totalQuestions: 1).first, 'A');
    });

    test('decodeBlock trả độ tin cậy từng câu', () {
      final block = _block([
        _row([0.0, 0.0, 0.75, 0.0]),
        _row([0.02, 0.01, 0.0, 0.0]),
      ]);
      final decoded = const OmrDecoder().decodeBlock(block);
      expect(decoded.answers, <String?>['C', null]);
      expect(decoded.confidences, <double>[0.75, 0.02]);
    });

    test('blocks ít hơn số câu → các câu còn lại null', () {
      final answers = const OmrDecoder().decodeAnswers(
        blocks: [
          _block([_row([0.9, 0, 0, 0])]),
        ],
        spec: spec,
        totalQuestions: 3,
      );
      expect(answers, <String?>['A', null, null]);
    });
  });

  group('OmrDecoder.decodeDigits', () {
    test('mỗi hàng chọn cột đậm nhất; hàng trống = ?', () {
      final grid = DensityBlock(List.generate(6, (row) {
        final values = List<double>.filled(10, 0.01);
        if (row == 0) values[0] = 0.8;
        if (row == 1) values[4] = 0.7;
        if (row == 2) values[1] = 0.6;
        if (row == 3) values[3] = 0.9;
        // hàng 4, 5 để trống
        return values;
      }));
      expect(const OmrDecoder().decodeDigits(grid), '0413??');
    });

    test('hàng nhiều ô tô → chọn ô đậm nhất', () {
      final values = List<double>.filled(10, 0.05);
      values[2] = 0.4;
      values[8] = 0.9;
      final grid = DensityBlock([values]);
      expect(const OmrDecoder().decodeDigits(grid), '8');
    });
  });

  group('OmrDecoder.normalizeCode', () {
    test('bỏ số 0 vô nghĩa với chuỗi toàn số', () {
      expect(OmrDecoder.normalizeCode('000123'), '123');
      expect(OmrDecoder.normalizeCode('000001'), '1');
      expect(OmrDecoder.normalizeCode('000'), '0');
      expect(OmrDecoder.normalizeCode('0'), '0');
    });

    test('chuỗi chữ/số: trim + viết hoa', () {
      expect(OmrDecoder.normalizeCode(' a01 '), 'A01');
      expect(OmrDecoder.normalizeCode('abc12'), 'ABC12');
      expect(OmrDecoder.normalizeCode(''), '');
    });
  });

  test('DensityBlock từ chối dữ liệu rỗng', () {
    expect(() => DensityBlock([]), throwsA(isA<AssertionError>()));
    expect(() => DensityBlock([<double>[]]), throwsA(isA<AssertionError>()));
  });
}
