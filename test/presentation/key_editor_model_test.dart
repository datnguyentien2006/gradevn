// Test KeyEditorModel (R1): trạng thái chọn/tắt theo FormSpec của kỳ thi —
// mã đề ghép '001', bảng chữ A–E, ô E không có trên phiếu → vẫn chọn được
// (chỉ tô xám trên UI), dãy đáp án câu trống ghi '-'.

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/presentation/models/key_editor_model.dart';

Contest _contest({int answerChoices = 4}) => Contest(
      id: 1,
      name: 'Kiểm tra 45 phút',
      examDate: DateTime(2026, 10, 23),
      questionCount: 40,
      answerChoices: answerChoices,
    );

void main() {
  group('KeyEditorConfig.fromContest (cấu hình dẫn ra từ FormSpec)', () {
    test('phiếu chuẩn 4 lựa chọn: 3 chữ số mã đề, A–E hiện đủ, E không trên phiếu', () {
      final config = KeyEditorConfig.fromContest(_contest());
      expect(config.examSlots, 3);
      expect(config.questionCount, 40);
      expect(config.letters, ['A', 'B', 'C', 'D', 'E']);
      expect(config.eOnPaper, isFalse);
    });

    test('kỳ thi ≥ 5 lựa chọn: E có thật trên phiếu', () {
      final config = KeyEditorConfig.fromContest(_contest(answerChoices: 5));
      expect(config.eOnPaper, isTrue);
    });
  });

  group('KeyEditorModel — mã đề', () {
    late KeyEditorModel model;
    setUp(() {
      model = KeyEditorModel.fromConfig(KeyEditorConfig.fromContest(_contest()));
    });

    test('ban đầu: chưa chọn gì, mã đề "???", chưa hoàn chỉnh', () {
      expect(model.examCode, '???');
      expect(model.isCodeComplete, isFalse);
      expect(model.unansweredCount, 40);
    });

    test('chọn từng chữ số → mã đề ghép trực tiếp', () {
      model.toggleDigit(0, 0);
      model.toggleDigit(1, 0);
      model.toggleDigit(2, 1);
      expect(model.examCode, '001');
      expect(model.isCodeComplete, isTrue);
      expect(model.digitAt(0), 0);
      expect(model.digitAt(2), 1);
    });

    test('nhấn lại ô đã chọn → bỏ chọn', () {
      model.toggleDigit(0, 0);
      model.toggleDigit(0, 0);
      expect(model.digitAt(0), isNull);
      expect(model.examCode, '???');
    });

    test('chọn chữ số khác cùng vị trí → thay thế', () {
      model.toggleDigit(2, 1);
      model.toggleDigit(2, 7);
      expect(model.digitAt(2), 7);
    });

    test('clearAll về trạng thái ban đầu', () {
      model.toggleDigit(0, 0);
      model.toggleAnswer(0, 'A');
      model.clearAll();
      expect(model.examCode, '???');
      expect(model.answerAt(0), isNull);
    });
  });

  group('KeyEditorModel — trả lời', () {
    late KeyEditorModel model;
    setUp(() {
      model = KeyEditorModel.fromConfig(KeyEditorConfig.fromContest(_contest()));
    });

    test('tô đáp án theo key: chọn + nhấn lại để bỏ', () {
      model.toggleAnswer(0, 'A');
      model.toggleAnswer(1, 'B');
      expect(model.answerAt(0), 'A');
      expect(model.answerAt(1), 'B');
      expect(model.unansweredCount, 38);
      model.toggleAnswer(0, 'A');
      expect(model.answerAt(0), isNull);
    });

    test('E vẫn chọn được trên model kể cả phiếu không có ô E', () {
      expect(model.eOnPaper, isFalse);
      model.toggleAnswer(2, 'E');
      expect(model.answerAt(2), 'E');
      model.toggleAnswer(2, 'E');
      expect(model.answerAt(2), isNull);
    });

    test('dãy đáp án: câu chưa chọn ghi "-"', () {
      model.toggleAnswer(0, 'D');
      expect(model.answerSequence.startsWith('D'), isTrue);
      expect(model.answerSequence.length, 40);
      expect(model.answerSequence.split('-').length - 1, 39);
    });

    test('save-ready: mã đề đủ + trả lời đủ', () {
      for (var slot = 0; slot < 3; slot++) {
        model.toggleDigit(slot, 0);
      }
      for (var q = 0; q < 40; q++) {
        model.toggleAnswer(q, 'ABCD'[q % 4]);
      }
      expect(model.isCodeComplete, isTrue);
      expect(model.unansweredCount, 0);
      expect(model.answerSequence, 'ABCD' * 10);
    });
  });
}
