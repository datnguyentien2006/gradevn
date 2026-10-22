import '../entities/sheet_spec.dart';

/// Kỳ thi (contest): metadata + cấu hình phiếu.
class Contest {
  const Contest({
    required this.id,
    required this.name,
    required this.examDate,
    this.classRoomId,
    this.questionCount = 40,
    this.answerChoices = 4,
    this.maxScore = 10.0,
    this.formType = SheetFormType.standard,
    this.orientation = SheetOrientation.portrait,
    this.partOneCount,
    this.partTwoCount,
    this.partThreeCount,
    this.partOneWeight,
    this.partTwoWeight,
    this.partThreeWeight,
  });

  final int id;
  final String name;
  final DateTime examDate;
  final int? classRoomId;
  final int questionCount;
  final int answerChoices;
  final double maxScore;
  final SheetFormType formType;
  final SheetOrientation orientation;
  final int? partOneCount;
  final int? partTwoCount;
  final int? partThreeCount;
  final double? partOneWeight;
  final double? partTwoWeight;
  final double? partThreeWeight;

  /// Biên dịch kỳ thi thành spec cho engine OMR.
  SheetSpec get sheetSpec => SheetSpec(
        formType: formType,
        orientation: orientation,
        questionCount: questionCount,
        answerChoices: answerChoices,
        maxScore: maxScore,
        partOneCount: partOneCount,
        partTwoCount: partTwoCount,
        partThreeCount: partThreeCount,
        partOneWeight: partOneWeight,
        partTwoWeight: partTwoWeight,
        partThreeWeight: partThreeWeight,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Contest && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Contest#$id($name)';
}

/// Mã đề → dãy đáp án. Một kỳ thi có thể có nhiều mã đề (nhiều key).
class AnswerKey {
  const AnswerKey({
    required this.id,
    required this.contestId,
    required this.examCode,
    required this.answerSequence,
    this.createdAt,
  });

  final int id;
  final int contestId;

  /// Mã đề in trên phiếu (ví dụ "A001", "123").
  final String examCode;

  /// Dãy đáp án — mỗi ký tự là lựa chọn A/B/C/D/… hoặc ' '? / '-' nếu câu bỏ.
  final String answerSequence;
  final DateTime? createdAt;

  int get answerCount => answerSequence.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AnswerKey && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AnswerKey#$id(exam=$examCode)';
}
