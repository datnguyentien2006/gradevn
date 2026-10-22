import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/scan_service.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/domain/services/grader.dart';

import 'fixture_builder.dart';

/// Hồi quy đầy đủ: PNG fixture → pipeline → giải mã → so khớp JSON sidecar → chấm điểm.
void main() {
  setUpAll(ensureFixtures);

  for (final fixture in allFixtures()) {
    test('fixture ${fixture.name}: giải mã + mã hoá + chấm điểm đúng sidecar', () {
      final bytes = File('$fixturesRoot/generated/${fixture.name}.png').readAsBytesSync();
      final scan = OmrScanService().scan(bytes, layout: fixture.layout);

      // 1) Đáp án từng câu
      expect(scan.answers, fixture.answers, reason: 'Đáp án giải mã lệch');

      // 2) Số báo danh / mã đề
      expect(scan.studentCodeRaw, fixture.studentCodeRaw);
      expect(scan.examCodeRaw, fixture.examCodeRaw);
      expect(scan.studentCode, _normalizeCode(fixture.studentCodeRaw));
      expect(scan.examCode, _normalizeCode(fixture.examCodeRaw));

      // 3) JSON sidecar phải khớp với định nghĩa fixture trong code
      final json = readExpectedJson(fixture.name);
      final jsonAnswers = (json['answers'] as List<dynamic>).cast<String?>();
      expect(jsonAnswers, fixture.answers);
      expect(json['answerKey'], fixture.answerKey);
      expect(json['studentCodeRaw'], fixture.studentCodeRaw);
      expect(json['examCodeRaw'], fixture.examCodeRaw);

      // 4) Chấm điểm theo key và đối chiếu điểm kỳ vọng (tính độc lập trong generator)
      final contest = _contestFromFixture(fixture);
      final result = const Grader().gradeForContest(
        contest: contest,
        keyAnswers: fixture.answerKey,
        chosen: scan.answers,
      );
      final expected = json['expected'] as Map<String, dynamic>;
      expect(result.score, closeTo((expected['score'] as num).toDouble(), 1e-9));
      expect(result.correctCount, expected['correctCount']);
      final expectedParts = expected['partScores'] as Map<String, dynamic>;
      expect(result.partScores.length, expectedParts.length);
      for (final entry in expectedParts.entries) {
        expect(
          result.partScores[entry.key],
          closeTo((entry.value as num).toDouble(), 1e-9),
          reason: 'Sai điểm phần ${entry.key}',
        );
      }
    });
  }

  test('benchmark: xử lý 1 phiếu < 2000 ms (mục tiêu M2)', () {
    final bytes = File('$fixturesRoot/generated/standard40.png').readAsBytesSync();
    final fixture = standardFixture();
    final service = const OmrScanService();

    // Làm nóng (JIT) rồi đo 3 lần.
    service.scan(bytes, layout: fixture.layout);
    final times = <int>[];
    for (var i = 0; i < 3; i++) {
      final stopwatch = Stopwatch()..start();
      final scan = service.scan(bytes, layout: fixture.layout);
      stopwatch.stop();
      times.add(stopwatch.elapsedMilliseconds);
      expect(scan.answers, fixture.answers);
    }
    times.sort();
    final median = times[times.length ~/ 2];
    stdout.writeln(
      'Benchmark OMR (1240×1754, 40 câu): '
      '${times.join(' / ')} ms — trung vị $median ms',
    );
    expect(median, lessThan(2000),
        reason: 'Vượt ngân sách 2 s/phiếu → phải chuyển opencv_dart');
  });

  test('tuning mặc định tách được ô tô và ô trống (biên độ an toàn)', () {
    final bytes = File('$fixturesRoot/generated/standard40.png').readAsBytesSync();
    final fixture = standardFixture();
    final scan = OmrScanService().scan(bytes, layout: fixture.layout);

    final marked = <double>[];
    final empty = <double>[];
    var index = 0;
    for (var b = 0; b < scan.answerBlocks.length; b++) {
      final block = scan.answerBlocks[b];
      for (var row = 0; row < block.rows; row++) {
        final letter = fixture.answers[index];
        for (var col = 0; col < block.columns; col++) {
          final density = block.at(row, col);
          if (letter != null && 'ABCDEFGHIJ'[col] == letter) {
            marked.add(density);
          } else {
            empty.add(density);
          }
        }
        index++;
      }
    }
    expect(marked, isNotEmpty);
    expect(empty, isNotEmpty);
    final minMarked = marked.reduce((a, b) => a < b ? a : b);
    final maxEmpty = empty.reduce((a, b) => a > b ? a : b);
    expect(minMarked, greaterThan(0.45), reason: 'Có ô tô quá nhạt');
    expect(maxEmpty, lessThan(0.20), reason: 'Có ô trống bị đo thành mực');
  });
}

/// Chuẩn hoá mã giống OmrDecoder (độc lập để test chéo).
String _normalizeCode(String raw) {
  final cleaned = raw.trim().toUpperCase();
  if (cleaned.isEmpty) return '';
  if (RegExp(r'^\d+$').hasMatch(cleaned)) {
    final stripped = cleaned.replaceFirst(RegExp(r'^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
  }
  return cleaned;
}

Contest _contestFromFixture(FixtureDefinition fixture) {
  final spec = fixture.spec;
  return Contest(
    id: 1,
    name: fixture.name,
    examDate: DateTime(2026, 1, 1),
    questionCount: spec.questionCount,
    answerChoices: spec.answerChoices,
    maxScore: spec.maxScore,
    formType: spec.formType,
    orientation: spec.orientation,
    partOneCount: spec.partOneCount,
    partTwoCount: spec.partTwoCount,
    partThreeCount: spec.partThreeCount,
    partOneWeight: spec.partOneWeight,
    partTwoWeight: spec.partTwoWeight,
    partThreeWeight: spec.partThreeWeight,
  );
}
