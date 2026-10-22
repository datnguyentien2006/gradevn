// Hồi quy luồng M3 "ảnh chụp → quét → chấm → gắn học sinh".
//
// Test chạy trên CHÍNH ảnh fixture (có khung căn chỉnh) nên đi qua đủ
// detect → warp → decode → grade, không dùng dữ liệu giả đã giải mã.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/scan_flow.dart';
import 'package:gradevn/data/cv/scan_service.dart';
import 'package:gradevn/data/cv/student_info_ocr.dart';
import 'package:gradevn/domain/entities/class_room.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:image/image.dart' as img;

import '../fixtures/fixture_builder.dart';

void main() {
  setUpAll(ensureFixtures);

  test('processPhoto: quét + chấm + gắn học sinh theo SBD (standard40)', () async {
    final fixture = standardFixture();
    final contest = _contestFromFixture(fixture);
    final keys = <AnswerKey>[_keyFor(fixture)];
    final students = <Student>[
      const Student(id: 5, classId: 1, code: '413', fullName: 'Nguyễn Văn A'),
      const Student(id: 6, classId: 1, code: '999', fullName: 'Trần Thị B'),
    ];

    final graded = await processPhoto(
      _bytesOf(fixture.name),
      contest: contest,
      keys: keys,
      candidateStudents: students,
    );

    expect(graded, isNotNull);
    final result = graded!;
    // Đáp án decode khớp chính xác fixture đã tô.
    expect(result.photo.scan.answers, fixture.answers);
    // Key khớp mã đề in trên phiếu '000001' → chuẩn hoá '1'.
    expect(result.usedKey?.id, keys.single.id);
    expect(result.usedExamCode, fixture.examCodeRaw);
    expect(result.usedBestGuessKey, isFalse);
    // SBD lưới số '000413' → chuẩn hoá '413' → gắn đúng học sinh.
    expect(result.student?.fullName, 'Nguyễn Văn A');
    // Điểm khớp sidecar (tính độc lập trong generator).
    final expected = readExpectedJson(fixture.name)['expected'] as Map<String, dynamic>;
    expect(result.result.score, closeTo((expected['score'] as num).toDouble(), 1e-9));
    expect(result.result.correctCount, expected['correctCount']);
    expect(result.result.unansweredCount, 2);
  });

  test('phiếu bộ đề (ministry20): chấm điểm + điểm từng phần khớp sidecar', () {
    final fixture = ministryFixture();
    final contest = _contestFromFixture(fixture);
    final photo = _scanOf(fixture, contest);
    expect(photo, isNotNull);

    final graded = gradeScan(
      contest: contest,
      keys: <AnswerKey>[_keyFor(fixture)],
      candidateStudents: const <Student>[],
      chosen: photo!.scan.answers,
      studentCodeRaw: photo.scan.studentCodeRaw,
      examCodeRaw: photo.scan.examCodeRaw,
      photo: photo,
    );

    final expected = readExpectedJson(fixture.name)['expected'] as Map<String, dynamic>;
    expect(graded.result.score,
        closeTo((expected['score'] as num).toDouble(), 1e-9));
    final expectedParts = expected['partScores'] as Map<String, dynamic>;
    expect(graded.result.partScores.length, expectedParts.length);
    for (final entry in expectedParts.entries) {
      expect(graded.result.partScores[entry.key],
          closeTo((entry.value as num).toDouble(), 1e-9),
          reason: 'Sai điểm phần ${entry.key}');
    }
    // Không có danh sách lớp → không gắn học sinh, nhưng vẫn đọc được SBD.
    expect(graded.student, isNull);
    expect(graded.photo.scan.studentCode, '888');
  });

  test('không có key nào: điểm 0, mọi câu đều null (không ném lỗi)', () {
    final fixture = standardFixture();
    final contest = _contestFromFixture(fixture);
    final photo = _scanOf(fixture, contest)!;

    final graded = gradeScan(
      contest: contest,
      keys: const <AnswerKey>[],
      candidateStudents: const <Student>[],
      chosen: photo.scan.answers,
      studentCodeRaw: photo.scan.studentCodeRaw,
      examCodeRaw: photo.scan.examCodeRaw,
      photo: photo,
    );

    expect(graded.usedKey, isNull);
    expect(graded.usedBestGuessKey, isFalse);
    expect(graded.result.score, 0);
    expect(graded.result.correctFlags.every((f) => f == null), isTrue);
    expect(graded.result.correctCount, 0);
  });

  test('mã đề đọc mờ: đoán key có điểm khớp cao nhất', () {
    final fixture = standardFixture();
    final contest = _contestFromFixture(fixture);
    final photo = _scanOf(fixture, contest)!;
    // Key đúng + một key "nhiễu" chỉ khớp vài câu.
    final correctKey = _keyFor(fixture);
    final noiseKey = AnswerKey(
      id: 99,
      contestId: contest.id,
      examCode: 'B777',
      answerSequence: List<String>.filled(fixture.answers.length, 'B').join(),
    );

    final graded = gradeScan(
      contest: contest,
      keys: <AnswerKey>[noiseKey, correctKey],
      candidateStudents: const <Student>[],
      chosen: photo.scan.answers,
      studentCodeRaw: photo.scan.studentCodeRaw,
      examCodeRaw: '??????', // không đọc được mã đề
      photo: photo,
    );

    expect(graded.usedKey?.id, correctKey.id);
    expect(graded.usedBestGuessKey, isTrue);
    expect(graded.usedExamCode, correctKey.examCode);
  });

  test('ảnh không có khung căn chỉnh → null (gợi ý cắt/chụp lại)', () async {
    final blank = img.Image(width: 600, height: 800);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));
    final bytes = Uint8List.fromList(img.encodePng(blank));
    final contest = _contestFromFixture(standardFixture());

    final graded = await processPhoto(
      bytes,
      contest: contest,
      keys: const <AnswerKey>[],
      candidateStudents: const <Student>[],
    );
    expect(graded, isNull);
  });

  test('OCR thông tin học sinh bản no-op không ảnh hưởng luồng chấm', () async {
    const ocr = NoOpStudentInfoOcr();
    final info = Uint8List.fromList(<int>[137, 80, 78, 71]);
    expect(await ocr.readStudentCode(info), isNull);
  });
}

Uint8List _bytesOf(String fixtureName) =>
    File('$fixturesRoot/generated/$fixtureName.png').readAsBytesSync();

PhotoScan? _scanOf(FixtureDefinition fixture, Contest contest) =>
    const OmrScanService().scanPhoto(
      _bytesOf(fixture.name),
      spec: contest.sheetSpec,
    );

AnswerKey _keyFor(FixtureDefinition fixture) => AnswerKey(
      id: 7,
      contestId: 1,
      examCode: fixture.examCodeRaw,
      answerSequence: fixture.answerKey,
    );

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
