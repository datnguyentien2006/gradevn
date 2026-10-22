import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/domain/value_objects/scoring_rule.dart';

void main() {
  group('ScoringRule', () {
    test('uniform: mỗi câu bằng maxScore / questionCount', () {
      final rule = ScoringRule.uniform(questionCount: 40, maxScore: 10);
      expect(rule.weightAt(0), closeTo(0.25, 1e-9));
      expect(rule.weightAt(39), closeTo(0.25, 1e-9));
      expect(rule.maxTotal, closeTo(10, 1e-9));
      expect(rule.isUniform, isTrue);
    });

    test('weighted: trọng số riêng từng câu', () {
      final rule = ScoringRule.weighted([2, 1, 0.5]);
      expect(rule.weightAt(2), 0.5);
      expect(rule.maxTotal, 3.5);
      expect(rule.isUniform, isFalse);
    });

    test('forContest (bộ đề): 3 phần có trọng số riêng', () {
      final contest = Contest(
        id: 1,
        name: 'Đề Sở GD',
        examDate: DateTime(2026, 11, 1),
        questionCount: 0,
        formType: SheetFormType.ministry,
        partOneCount: 4,
        partTwoCount: 10,
        partThreeCount: 6,
        partOneWeight: 4,
        partTwoWeight: 5,
        partThreeWeight: 1,
      );
      final rule = ScoringRule.forContest(contest);
      expect(rule.weightAt(0), closeTo(1.0, 1e-9));   // Phần I: 4 điểm / 4 câu
      expect(rule.weightAt(3), closeTo(1.0, 1e-9));   // câu cuối phần I
      expect(rule.weightAt(4), closeTo(0.5, 1e-9));   // Phần II: 5 điểm / 10 câu
      expect(rule.weightAt(13), closeTo(0.5, 1e-9));  // câu cuối phần II
      expect(rule.weightAt(14), closeTo(1 / 6, 1e-9)); // Phần III: 1 điểm / 6 câu
      expect(rule.weightAt(19), closeTo(1 / 6, 1e-9));
      expect(rule.maxTotal, closeTo(10, 1e-9));
    });

    test('forContest (chuẩn): uniform theo maxScore', () {
      final contest = Contest(
        id: 2,
        name: 'Kiểm tra',
        examDate: DateTime(2026, 10, 1),
        questionCount: 20,
        maxScore: 10,
      );
      final rule = ScoringRule.forContest(contest);
      expect(rule.weightAt(0), closeTo(0.5, 1e-9));
      expect(rule.maxTotal, closeTo(10, 1e-9));
    });
  });
}
