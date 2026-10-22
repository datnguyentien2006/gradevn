import '../entities/contest.dart';
import '../entities/sheet_spec.dart';

/// Quy tắc chấm — tái tạo hành vi `findAutoCorrect` / `u0` của tài liệu tham khảo
/// (docs/reference-analysis.md §7): điểm của mỗi câu bằng trọng số riêng.
final class ScoringRule {
  /// Chấm đều: mỗi câu cùng trọng số = maxScore / questionCount.
  ScoringRule.uniform({
    required int questionCount,
    required double maxScore,
  })  : _weights = List<double>.filled(
          questionCount,
          maxScore / questionCount,
        ),
        isUniform = true;

  /// Trọng số riêng cho từng câu (ví dụ 2 điểm câu khó).
  ScoringRule.weighted(List<double> weights)
      : _weights = List<double>.unmodifiable(weights),
        isUniform = false;

  final List<double> _weights;
  final bool isUniform;

  double weightAt(int questionIndex) => _weights[questionIndex];

  /// Số câu (độ dài bảng trọng số).
  int get questionCount => _weights.length;

  /// Điểm tối đa tổng — tổng các trọng số.
  double get maxTotal => _weights.fold(0.0, (a, b) => a + b);

  /// Chấm điểm một phiếu (hỗ trợ từng phần dạng bộ đề).
  factory ScoringRule.forContest(Contest contest) {
    if (contest.formType == SheetFormType.ministry &&
        contest.partOneCount != null &&
        contest.partTwoCount != null &&
        contest.partThreeCount != null &&
        contest.partOneWeight != null &&
        contest.partTwoWeight != null &&
        contest.partThreeWeight != null) {
      final weights = <double>[];
      final segments = <(int, double)>[
        (
          contest.partOneCount!,
          contest.partOneWeight! /
              contest.partOneCount!
        ),
        (
          contest.partTwoCount!,
          contest.partTwoWeight! /
              contest.partTwoCount!
        ),
        (
          contest.partThreeCount!,
          contest.partThreeWeight! /
              contest.partThreeCount!
        ),
      ];
      for (final (count, perQuestion) in segments) {
        weights.addAll(List<double>.filled(count, perQuestion));
      }
      return ScoringRule.weighted(weights);
    }
    return ScoringRule.uniform(
      questionCount: contest.questionCount,
      maxScore: contest.maxScore,
    );
  }
}
