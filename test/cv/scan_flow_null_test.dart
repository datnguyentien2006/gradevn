// R2 — Luồng NULL: lưới MÃ ĐỀ hoặc SỐ BÁO DANH hoàn toàn trống (không đọc
// được CHỮ SỐ nào) → BỎ CHẤM ngay: không chọn key, không chạy bộ chấm, UI
// nhận GradedScan.graded = false hiển thị "NULL (…)".
//
// A. Unit thẳng trên [gradeScan] với raw giả lập (không phụ thuộc ảnh).
//    Kiểm tra ĐỦ dấu hiệu "không hề chấm" (usedKey null, best-guess false,
//    cờ all null) — hàm gradeScan không có điểm cắm Grader thay được, nên
//    hợp đồng "không chọn key + cờ all null + điểm 0" là chứng chỉ.
// B. End-to-end trên ảnh fixture in lưới TRỐNG (detect → warp → decode):
//    decodeDigits cho lưới trống = '???' / '??????' → isBlankCode TRUE.
import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/scan_flow.dart';
import 'package:gradevn/data/cv/scan_service.dart';
import 'package:gradevn/domain/entities/class_room.dart';
import 'package:gradevn/domain/entities/contest.dart';

import '../fixtures/fixture_builder.dart';

Contest _contestFromFixture(FixtureDefinition fixture) {
  final spec = fixture.spec;
  return Contest(
    id: 1,
    name: fixture.name,
    examDate: DateTime(2026, 1, 1),
    classRoomId: 1,
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

AnswerKey _keyFor(FixtureDefinition fixture, {int id = 7}) {
  return AnswerKey(
    id: id,
    contestId: 1,
    examCode: fixture.examCodeRaw,
    answerSequence: fixture.answerKey,
  );
}

const _studentA =
    Student(id: 5, classId: 1, code: '413', fullName: 'Nguyễn Văn A');

/// Hợp đồng "phiếu bị bỏ chấm" — mọi dấu hiệu tổng thể.
void _expectSkipped(
  GradedScan graded, {
  required UngradedReason reason,
  required String usedExamCode,
}) {
  expect(graded.graded, isFalse);
  expect(graded.ungradedReason, reason);
  expect(graded.usedKey, isNull, reason: 'bỏ chấm thì không được chọn key');
  expect(graded.usedBestGuessKey, isFalse,
      reason: 'bỏ chấm thì không đoán key theo điểm');
  expect(graded.usedExamCode, usedExamCode);
  // Không hề chấm: mọi cờ null, điểm 0, thống kê 0/0/0.
  expect(graded.result.correctFlags, everyElement(isNull));
  expect(graded.result.score, 0);
  expect(graded.result.correctCount, 0);
  expect(graded.result.incorrectCount, 0);
}

void main() {
  setUpAll(ensureFixtures);

  group('A. unit gradeScan (raw đọc từ lưới)', () {
    final fixture = standardFixture();
    final contest = _contestFromFixture(fixture);
    final photo = const OmrScanService().scanPhoto(
      renderFixture(fixture),
      spec: fixture.spec,
    )!;

    test('mã đề trống (\'???\') → bỏ chấm, lý do mã đề, lưu mã đề \'\'', () {
      final graded = gradeScan(
        contest: contest,
        keys: <AnswerKey>[_keyFor(fixture)],
        candidateStudents: <Student>[_studentA],
        chosen: photo.scan.answers,
        studentCodeRaw: photo.scan.studentCodeRaw,
        examCodeRaw: '???',
        photo: photo,
      );
      _expectSkipped(graded,
          reason: UngradedReason.examCode, usedExamCode: '');
      // SBD đọc được → vẫn gắn học sinh (không phải bước chấm).
      expect(graded.student?.fullName, 'Nguyễn Văn A');
    });

    test('SBD trống (\'??????\') → bỏ chấm, lý do SBD, vẫn lưu mã đề', () {
      final graded = gradeScan(
        contest: contest,
        keys: <AnswerKey>[_keyFor(fixture)],
        candidateStudents: <Student>[_studentA],
        chosen: photo.scan.answers,
        studentCodeRaw: '??????',
        examCodeRaw: '001',
        photo: photo,
      );
      _expectSkipped(graded,
          reason: UngradedReason.studentCode, usedExamCode: '1');
      // SBD trống → không gắn ai.
      expect(graded.student, isNull);
    });

    test('cả hai trống → ưu tiên lý do mã đề', () {
      final graded = gradeScan(
        contest: contest,
        keys: <AnswerKey>[_keyFor(fixture)],
        candidateStudents: const <Student>[],
        chosen: photo.scan.answers,
        studentCodeRaw: '??????',
        examCodeRaw: '???',
        photo: photo,
      );
      _expectSkipped(graded,
          reason: UngradedReason.examCode, usedExamCode: '');
    });

    test('raw chỉ khoảng trắng cũng coi là trống (không có chữ số bất kỳ)',
        () {
      final graded = gradeScan(
        contest: contest,
        keys: <AnswerKey>[_keyFor(fixture)],
        candidateStudents: const <Student>[],
        chosen: photo.scan.answers,
        studentCodeRaw: photo.scan.studentCodeRaw,
        examCodeRaw: '   ',
        photo: photo,
      );
      expect(graded.graded, isFalse);
    });

    test('mã đề đọc MỘT PHẦN (\'?01\') → vẫn chấm bình thường (không NULL)',
        () {
      final graded = gradeScan(
        contest: contest,
        keys: <AnswerKey>[_keyFor(fixture)],
        candidateStudents: <Student>[_studentA],
        chosen: photo.scan.answers,
        studentCodeRaw: photo.scan.studentCodeRaw,
        examCodeRaw: '?01',
        photo: photo,
      );
      expect(graded.graded, isTrue);
      expect(graded.ungradedReason, isNull);
      // Bộ chấm thật sự chạy (fixture có câu khớp key).
      expect(graded.result.correctCount, greaterThan(0));
    });
  });

  group('B. end-to-end ảnh fixture lưới trống', () {
    final fixture = standardFixture();

    test('phiếu in MÃ ĐỀ trống (\'???\') → decode ra lưới trống → bỏ chấm',
        () {
      final blankExam = _withRaws(fixture, examCodeRaw: '???');
      final photo = const OmrScanService().scanPhoto(
        renderFixture(blankExam),
        spec: blankExam.spec,
      );
      expect(photo, isNotNull);
      expect(photo!.scan.examCodeRaw, '???');
      expect(photo.scan.examCodeEmpty, isTrue);

      final graded = gradeScan(
        contest: _contestFromFixture(blankExam),
        keys: <AnswerKey>[_keyFor(blankExam)],
        candidateStudents: const <Student>[],
        chosen: photo.scan.answers,
        studentCodeRaw: photo.scan.studentCodeRaw,
        examCodeRaw: photo.scan.examCodeRaw,
        photo: photo,
      );
      _expectSkipped(graded,
          reason: UngradedReason.examCode, usedExamCode: '');
    });

    test('phiếu in SỐ BÁO DANH trống (\'??????\') → decode trống → bỏ chấm',
        () {
      final blankSbd = _withRaws(fixture, studentCodeRaw: '??????');
      final photo = const OmrScanService().scanPhoto(
        renderFixture(blankSbd),
        spec: blankSbd.spec,
      );
      expect(photo, isNotNull);
      expect(photo!.scan.studentCodeRaw, '??????');
      expect(photo.scan.studentCodeEmpty, isTrue);

      final graded = gradeScan(
        contest: _contestFromFixture(blankSbd),
        keys: <AnswerKey>[_keyFor(blankSbd)],
        candidateStudents: <Student>[_studentA],
        chosen: photo.scan.answers,
        studentCodeRaw: photo.scan.studentCodeRaw,
        examCodeRaw: photo.scan.examCodeRaw,
        photo: photo,
      );
      _expectSkipped(graded,
          reason: UngradedReason.studentCode, usedExamCode: '1');
    });
  });
}

/// Bonus: bản sao fixture với lưới SBD/mã đề thay raw khác (in trống).
FixtureDefinition _withRaws(
  FixtureDefinition fixture, {
  String? studentCodeRaw,
  String? examCodeRaw,
}) {
  if (studentCodeRaw == null && examCodeRaw == null) return fixture;
  return FixtureDefinition(
    name: fixture.name,
    spec: fixture.spec,
    answers: fixture.answers,
    answerKey: fixture.answerKey,
    studentCodeRaw: studentCodeRaw ?? fixture.studentCodeRaw,
    examCodeRaw: examCodeRaw ?? fixture.examCodeRaw,
    noisy: fixture.noisy,
  );
}
