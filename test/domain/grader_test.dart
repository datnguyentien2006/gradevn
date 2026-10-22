import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/domain/services/grader.dart';
import 'package:gradevn/domain/value_objects/scoring_rule.dart';

Contest _contest({
  SheetFormType formType = SheetFormType.standard,
  int questionCount = 10,
  double maxScore = 10,
  int? p1,
  int? p2,
  int? p3,
  double? w1,
  double? w2,
  double? w3,
}) =>
    Contest(
      id: 1,
      name: 'Fixture',
      examDate: DateTime(2026, 10, 1),
      questionCount: questionCount,
      maxScore: maxScore,
      formType: formType,
      partOneCount: p1,
      partTwoCount: p2,
      partThreeCount: p3,
      partOneWeight: w1,
      partTwoWeight: w2,
      partThreeWeight: w3,
    );

void main() {
  group('Grader.computeFlags', () {
    final rule = ScoringRule.uniform(questionCount: 10, maxScore: 10);

    test('đúng/sai/bỏ trống', () {
      final flags = const Grader().computeFlags(
        rule: rule,
        keyAnswers: 'ABCDABCDAB',
        chosen: <String?>['A', 'B', 'C', 'D', 'A', 'B', 'C', 'D', 'A', 'B'],
      );
      // 0:A✓ 1:B✓ 2:C✓ 3:D✓ 4:A✓ 5:B✓ 6:C✓ 7:D✓ 8:A✓ 9:B✓
      expect(flags.every((f) => f == true), isTrue);
    });

    test('sai, bỏ trống, key ngắn và ký tự key không hợp lệ', () {
      final flags = const Grader().computeFlags(
        rule: rule,
        keyAnswers: 'AB-D',
        chosen: <String?>['B', 'B', 'C', 'C', 'A', 'B', 'C', 'D', 'A', 'B'],
      );
      expect(flags.length, 10);
      expect(flags[0], isFalse); // B ≠ A
      expect(flags[1], isTrue);
      expect(flags[2], isNull); // key '-'
      expect(flags[3], isFalse); // key 'D', chosen 'C'
      expect(flags[4], isNull); // ngoài key
    });

    test('chosen ngắn hơn key → phần thiếu coi như bỏ trống', () {
      final flags = const Grader().computeFlags(
        rule: rule,
        keyAnswers: 'ABCD',
        chosen: <String?>['A'],
      );
      expect(flags[0], isTrue);
      expect(flags.sublist(1).every((f) => f == null), isTrue);
    });
  });

  group('Grader chấm điểm', () {
    test('đều: 8 đúng / 1 sai / 1 trống → 8.0', () {
      final result = const Grader().gradeForContest(
        contest: _contest(questionCount: 10, maxScore: 10),
        keyAnswers: 'ABCDABCDAB',
        chosen: <String?>[
          'A', 'B', 'C', 'D', 'A', 'B', 'C', 'B', 'A', null,
        ],
      );
      // câu 7 sai, câu 8 sai? 'A' vs key 'A' → đúng. Sửa: câu 7 chọn B (key D) sai, câu 8 A đúng, câu 9 trống.
      expect(result.correctCount, 8);
      expect(result.incorrectCount, 1);
      expect(result.unansweredCount, 1);
      expect(result.score, 8.0);
    });

    test('làm tròn 2 chữ số thập phân', () {
      final rule = ScoringRule.uniform(questionCount: 3, maxScore: 1);
      final result = const Grader().grade(
        rule: rule,
        correctFlags: <bool?>[true, false, false],
      );
      expect(result.score, 0.33);
    });

    test('trọng số riêng từng câu', () {
      final rule = ScoringRule.weighted(<double>[2.0, 1.0, 0.5]);
      final result = const Grader().grade(
        rule: rule,
        correctFlags: <bool?>[true, true, false],
      );
      expect(result.score, 3.0);
    });

    test('phiếu bộ đề: điểm từng phần + tổng', () {
      final contest = _contest(
        formType: SheetFormType.ministry,
        questionCount: 20,
        maxScore: 10,
        p1: 4,
        p2: 10,
        p3: 6,
        w1: 4,
        w2: 5,
        w3: 1,
      );
      final key = 'A' * 20;
      final chosen = <String?>[
        'A', 'A', 'A', 'B', // phần I: 3 đúng
        'A', 'A', 'A', 'A', 'A', 'B', 'A', 'A', 'A', 'A', // phần II: 9 đúng
        'B', 'B', 'B', null, 'A', 'A', // phần III: 2 đúng + 1 trống
      ];
      final result = const Grader().gradeForContest(
        contest: contest,
        keyAnswers: key,
        chosen: chosen,
      );
      expect(result.partScores['1'], 3.0); // 3 câu × 1 điểm
      expect(result.partScores['2'], 4.5); // 9 câu × 0.5 điểm
      // computePartScores làm tròn 2 chữ số như round2 (khớp sidecar fixture):
      // phần III: 2 câu × 1/6 = 0.3333… → 0.33.
      expect(result.partScores['3'], closeTo(0.33, 0.0001));
      // Tổng: round2(3 + 4.5 + 2/6) = 7.83 (tính từ tổng thô, không cộng phần đã làm tròn).
      expect(result.score, closeTo(7.83, 0.0001));
    });

    test('phiếu bộ đề thiếu cấu hình phần → partScores rỗng, vẫn chấm được', () {
      final contest = _contest(
        formType: SheetFormType.ministry,
        questionCount: 5,
        maxScore: 5,
        p1: 5,
        p2: null,
        p3: null,
      );
      final result = const Grader().gradeForContest(
        contest: contest,
        keyAnswers: 'AAAAA',
        chosen: <String?>['A', 'A', 'A', 'A', 'A'],
      );
      expect(result.partScores, isEmpty);
      expect(result.score, 5.0);
    });
  });

  group('Chọn key', () {
    final keys = <AnswerKey>[
      const AnswerKey(id: 1, contestId: 1, examCode: '001', answerSequence: 'ABCD'),
      const AnswerKey(id: 2, contestId: 1, examCode: 'A02', answerSequence: 'DCBA'),
    ];

    test('selectKey khớp sau khi chuẩn hoá số 0 đầu', () {
      expect(Grader.selectKey(keys, '000001')!.id, 1);
      expect(Grader.selectKey(keys, 'A02')!.id, 2);
      expect(Grader.selectKey(keys, '002'), isNull);
      expect(Grader.selectKey(keys, '???'), isNull);
      expect(Grader.selectKey(keys, ''), isNull);
    });

    test('bestScoringKey chọn key nhiều câu đúng nhất', () {
      final chosen = <String?>['A', 'B', 'C', 'D'];
      expect(Grader.bestScoringKey(keys: keys, chosen: chosen)!.id, 1);
      expect(Grader.bestScoringKey(keys: keys, chosen: <String?>['D', 'C', 'B', 'A'])!.id, 2);
      expect(Grader.bestScoringKey(keys: const [], chosen: chosen), isNull);
    });
  });
}
