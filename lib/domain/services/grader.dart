import '../entities/contest.dart';
import '../entities/sheet_spec.dart';
import '../value_objects/scoring_rule.dart';
import 'omr_decoder.dart';

/// Kết quả chấm một phiếu (phần logic thuần, không phụ thuộc UI/DB).
final class GradingResult {
  const GradingResult({
    required this.correctFlags,
    required this.score,
    this.partScores = const <String, double>{},
  });

  /// Theo từng câu: true = đúng, false = sai, null = bỏ trống/không có đáp án.
  final List<bool?> correctFlags;

  /// Tổng điểm đã làm tròn 2 chữ số thập phân.
  final double score;

  /// Điểm từng phần ('1','2','3') với phiếu bộ đề; rỗng với phiếu chuẩn.
  final Map<String, double> partScores;

  int get correctCount => correctFlags.where((f) => f == true).length;
  int get incorrectCount => correctFlags.where((f) => f == false).length;
  int get unansweredCount => correctFlags.where((f) => f == null).length;
  int get totalQuestions => correctFlags.length;
}

/// Chấm điểm phiếu trả lời theo đáp án (key) — logic thuần, đã kiểm thử đầy đủ.
///
/// Quy ước:
/// - Ký tự key không hợp lệ (' ', '-', '?') → câu đó không tính điểm (null).
/// - Câu để trống trên phiếu → null (0 điểm, không tính là sai).
/// - Điểm làm tròn 2 chữ số thập phân; trọng số lấy từ [ScoringRule].
final class Grader {
  const Grader();

  GradingResult grade({
    required ScoringRule rule,
    required List<bool?> correctFlags,
    Map<String, double> partScores = const <String, double>{},
  }) {
    var sum = 0.0;
    for (var i = 0; i < correctFlags.length; i++) {
      if (correctFlags[i] == true) sum += rule.weightAt(i);
    }
    return GradingResult(
      correctFlags: List<bool?>.unmodifiable(correctFlags),
      score: round2(sum),
      partScores: Map<String, double>.unmodifiable(partScores),
    );
  }

  /// Chấm một kỳ thi: tính cờ đúng/sai theo key rồi cộng điểm theo trọng số.
  GradingResult gradeForContest({
    required Contest contest,
    required String keyAnswers,
    required List<String?> chosen,
  }) {
    final rule = ScoringRule.forContest(contest);
    final flags = computeFlags(rule: rule, keyAnswers: keyAnswers, chosen: chosen);
    final partScores = computePartScores(contest: contest, rule: rule, flags: flags);
    return grade(rule: rule, correctFlags: flags, partScores: partScores);
  }

  /// So khớp từng câu giữa key và lựa chọn đã giải mã.
  List<bool?> computeFlags({
    required ScoringRule rule,
    required String keyAnswers,
    required List<String?> chosen,
  }) {
    final key = keyAnswers.trim().toUpperCase();
    final flags = <bool?>[];
    for (var i = 0; i < rule.questionCount; i++) {
      final keyChar = i < key.length ? key[i] : '';
      final valid = RegExp(r'[A-Z]').hasMatch(keyChar);
      if (!valid) {
        flags.add(null);
        continue;
      }
      final pick = i < chosen.length ? chosen[i] : null;
      flags.add(pick == null ? null : pick.toUpperCase() == keyChar);
    }
    return flags;
  }

  /// Điểm từng phần cho phiếu bộ đề (Phần I/II/III).
  ///
  /// Với phiếu chuẩn trả về map rỗng. Với phiếu bộ đề thiếu cấu hình phần,
  /// trả về map rỗng thay vì ném lỗi (dữ liệu cũ có thể chưa đủ trường).
  Map<String, double> computePartScores({
    required Contest contest,
    required ScoringRule rule,
    required List<bool?> flags,
  }) {
    if (contest.formType != SheetFormType.ministry) return const <String, double>{};
    final p1 = contest.partOneCount;
    final p2 = contest.partTwoCount;
    final p3 = contest.partThreeCount;
    if (p1 == null || p2 == null || p3 == null) return const <String, double>{};

    final parts = <String, int>{'1': p1, '2': p2, '3': p3};
    final scores = <String, double>{};
    var start = 0;
    for (final entry in parts.entries) {
      var partSum = 0.0;
      final end = (start + entry.value).clamp(0, flags.length);
      for (var i = start; i < end; i++) {
        if (flags[i] == true) partSum += rule.weightAt(i);
      }
      scores[entry.key] = round2(partSum);
      start += entry.value;
    }
    return scores;
  }

  /// Làm tròn 2 chữ số thập phân (tránh sai số nhị phân khi hiển thị 0.1+0.2).
  static double round2(double value) => (value * 100).roundToDouble() / 100;

  /// Chọn key khớp mã đề đã giải mã; so khớp sau khi chuẩn hoá.
  static AnswerKey? selectKey(List<AnswerKey> keys, String decodedExamCode) {
    final target = OmrDecoder.normalizeCode(decodedExamCode);
    if (target.isEmpty || target.contains('?')) return null;
    for (final key in keys) {
      if (OmrDecoder.normalizeCode(key.examCode) == target) return key;
    }
    return null;
  }

  /// Chọn key cho điểm cao nhất khi không đọc được mã đề (đọc mờ).
  ///
  /// Trả về null nếu danh sách key rỗng.
  static AnswerKey? bestScoringKey({
    required List<AnswerKey> keys,
    required List<String?> chosen,
  }) {
    if (keys.isEmpty) return null;
    AnswerKey? best;
    var bestCorrect = -1;
    for (final key in keys) {
      final seq = key.answerSequence.toUpperCase();
      var correct = 0;
      for (var i = 0; i < seq.length && i < chosen.length; i++) {
        if (chosen[i] != null && chosen[i]!.toUpperCase() == seq[i]) correct++;
      }
      if (correct > bestCorrect) {
        bestCorrect = correct;
        best = key;
      }
    }
    return best;
  }
}
