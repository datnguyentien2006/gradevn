// Model thuần của trình nhập mã đề (R1): toàn bộ trạng thái + logic chọn
// ô đều nằm ở đây — không phụ thuộc Flutter widget, unit-test trực tiếp.
//
// Config dẫn ra từ kỳ thi + FormSpec (template chuẩn):
// - Số chữ số của mã đề = số cột lưới "MÃ ĐỀ" của template (`examSlots`).
// - Bảng chữ luôn hiện đủ A–E; ô E chỉ "có thật trên phiếu" khi
//   `contest.answerChoices >= 5` — nếu không, E được tô xám kèm ghi chú.

import 'package:flutter/foundation.dart';

import '../../domain/entities/contest.dart';
import '../../domain/services/sheet_template.dart';

/// Cấu hình trình nhập, dịch từ [Contest] (FormSpec data-driven).
final class KeyEditorConfig {
  const KeyEditorConfig({
    required this.examSlots,
    required this.questionCount,
    required this.letters,
    required this.eOnPaper,
  });

  /// Dựng từ kỳ thi: số cột mã đề lấy từ template chuẩn, chữ A–E luôn đủ,
  /// "E có trên phiếu" khi kỳ thi cho phép ≥ 5 lựa chọn.
  factory KeyEditorConfig.fromContest(Contest contest) {
    final template = SheetTemplate.tn40Standard;
    return KeyEditorConfig(
      examSlots: template.examSlots,
      questionCount: contest.questionCount,
      letters: const ['A', 'B', 'C', 'D', 'E'],
      eOnPaper: contest.answerChoices >= 5,
    );
  }

  /// Số vị trí chữ số của mã đề (template chuẩn: 3).
  final int examSlots;

  /// Số câu hỏi (số hàng đáp án).
  final int questionCount;

  /// Bảng chữ hiển thị trên từng hàng.
  final List<String> letters;

  /// Phiếu in có ô E (answerChoices ≥ 5); false → ô E tô xám kèm ghi chú.
  final bool eOnPaper;
}

/// Trạng thái trình nhập mã đề: chọn/tắt từng chữ số và từng chữ cái bằng
/// cách nhấn vào ô đã chọn lần nữa; mã đề ghép trực tiếp ra bản xem trước.
final class KeyEditorModel extends ChangeNotifier {
  KeyEditorModel.fromConfig(KeyEditorConfig config)
      : assert(config.examSlots > 0, 'Mã đề phải có ít nhất 1 chữ số'),
        assert(config.questionCount > 0, 'Kỳ thi phải có ít nhất 1 câu'),
        assert(config.letters.isNotEmpty, 'Bảng chữ không được rỗng'),
        examSlots = config.examSlots,
        questionCount = config.questionCount,
        letters = List.unmodifiable(config.letters),
        eOnPaper = config.eOnPaper,
        _digits = List<int?>.filled(config.examSlots, null, growable: false),
        _answers =
            List<String?>.filled(config.questionCount, null, growable: false);

  final int examSlots;
  final int questionCount;
  final List<String> letters;
  final bool eOnPaper;

  /// Số đã chọn của từng chữ số; null = chưa chọn.
  final List<int?> _digits;

  /// Chữ đã chọn của từng câu; null = chưa chọn.
  final List<String?> _answers;

  // ---- Đọc trạng thái ------------------------------------------------------

  /// Chữ số đang chọn của vị trí [slot]; null = chưa chọn.
  int? digitAt(int slot) => _digits[slot];

  /// Chữ đang chọn của câu [question] (0-based); null = chưa chọn.
  String? answerAt(int question) => _answers[question];

  /// Ô chữ số (slot, value) đang được chọn không.
  bool isDigitSelected(int slot, int value) => _digits[slot] == value;

  /// Ô chữ (question, letter) đang được chọn không.
  bool isAnswerSelected(int question, String letter) =>
      _answers[question] == letter;

  /// Mã đề ghép trực tiếp từ các vị trí; vị trí chưa chọn hiển thị '?'.
  String get examCode => [
        for (var slot = 0; slot < examSlots; slot++)
          _digits[slot] == null ? '?' : '${_digits[slot]}'
      ].join();

  /// Mã đề đã chọn đủ mọi vị trí.
  bool get isCodeComplete => _digits.every((d) => d != null);

  /// Số câu chưa chọn chữ nào.
  int get unansweredCount {
    var count = 0;
    for (final a in _answers) {
      if (a == null) count++;
    }
    return count;
  }

  /// Dãy đáp án đã ghép; câu chưa chọn ghi '-' (quy ước "không tính điểm").
  String get answerSequence => String.fromCharCodes([
        for (final a in _answers) a == null ? _blankCharCode : a.codeUnitAt(0)
      ]);

  static const int _blankCharCode = 0x2D; // '-'

  // ---- Hành động (nhấn lần nữa = bỏ chọn) --------------------------------

  /// Chọn/tắt chữ số [value] tại vị trí [slot] (0-based, giá trị 0..9).
  void toggleDigit(int slot, int value) {
    assert(slot >= 0 && slot < examSlots, 'Vị trí chữ số ngoài phạm vi');
    assert(value >= 0 && value <= 9, 'Chữ số ngoài 0..9');
    _digits[slot] = _digits[slot] == value ? null : value;
    notifyListeners();
  }

  /// Chọn/tắt chữ [letter] của câu [question] (0-based).
  void toggleAnswer(int question, String letter) {
    assert(question >= 0 && question < questionCount, 'Câu ngoài phạm vi');
    assert(letters.contains(letter), 'Bảng chữ không có $letter');
    _answers[question] = _answers[question] == letter ? null : letter;
    notifyListeners();
  }

  /// Xoá mọi lựa chọn (về trạng thái ban đầu).
  void clearAll() {
    for (var i = 0; i < examSlots; i++) {
      _digits[i] = null;
    }
    for (var i = 0; i < questionCount; i++) {
      _answers[i] = null;
    }
    notifyListeners();
  }
}
