import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/db/app_database.dart';
import 'package:gradevn/data/repositories/drift_repositories.dart';
import 'package:gradevn/domain/entities/class_room.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/domain/entities/graded_sheet.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';

void main() {
  late AppDatabase db;
  late DriftClassRoomRepository classRepo;
  late DriftStudentRepository studentRepo;
  late DriftContestRepository contestRepo;
  late DriftAnswerKeyRepository keyRepo;
  late DriftGradedSheetRepository sheetRepo;

  setUp(() {
    db = inMemoryAppDatabase();
    classRepo = DriftClassRoomRepository(db);
    studentRepo = DriftStudentRepository(db);
    contestRepo = DriftContestRepository(db);
    keyRepo = DriftAnswerKeyRepository(db);
    sheetRepo = DriftGradedSheetRepository(db);
  });

  tearDown(() => db.close());

  test('class CRUD', () async {
    final c = ClassRoom(id: 0, name: '10A1', description: 'Lớp 10');
    final id = await classRepo.insert(c);
    expect(id, greaterThan(0));
    final byId = await classRepo.byId(id);
    expect(byId!.name, '10A1');

    await classRepo.update(ClassRoom(id: id, name: '10A2', description: null));
    expect((await classRepo.byId(id))!.name, '10A2');

    await classRepo.delete(id);
    expect(await classRepo.byId(id), isNull);
  });

  test('students: insert + byCode + insertMany', () async {
    final classId = await classRepo.insert(ClassRoom(id: 0, name: '10B'));
    await studentRepo.insert(Student(id: 0, classId: classId, code: '001', fullName: 'A'));
    await studentRepo.insertMany([
      Student(id: 0, classId: classId, code: '002', fullName: 'B'),
      Student(id: 0, classId: classId, code: '003', fullName: 'C'),
    ]);
    final a = await studentRepo.byCode(classId, '001');
    expect(a!.fullName, 'A');
    expect(null, await studentRepo.byCode(classId, '999'));

    final all = await studentRepo.watchByClass(classId).first;
    expect(all.length, 3);
  });

  test('contest CRUD với enum mapping', () async {
    final contest = Contest(
      id: 0,
      name: 'Giữa kỳ',
      examDate: DateTime(2026, 11, 2),
      questionCount: 50,
      answerChoices: 4,
      maxScore: 10,
      formType: SheetFormType.fifty,
      orientation: SheetOrientation.landscape,
    );
    final id = await contestRepo.insert(contest);
    final loaded = await contestRepo.byId(id);
    expect(loaded!.formType, SheetFormType.fifty);
    expect(loaded.orientation, SheetOrientation.landscape);
    expect(loaded.questionCount, 50);

    await contestRepo.update(Contest(
      id: id,
      name: 'Giữa kỳ II',
      examDate: loaded.examDate,
      formType: SheetFormType.ministry,
      partOneCount: 4,
      partTwoCount: 10,
      partThreeCount: 6,
      partOneWeight: 4,
      partTwoWeight: 5,
      partThreeWeight: 1,
    ));
    final updated = await contestRepo.byId(id);
    expect(updated!.formType, SheetFormType.ministry);
    expect(updated.partTwoCount, 10);
  });

  test('keys: insertMany + byExamCode + unique upsert', () async {
    final contestId = await contestRepo.insert(
      Contest(id: 0, name: 'K', examDate: DateTime(2026, 10, 3)),
    );
    await keyRepo.insertMany(contestId, [
      ('A01', 'ABCD'),
      ('A02', 'BCDA'),
    ]);
    final a01 = await keyRepo.byExamCode(contestId, 'A01');
    expect(a01!.answerSequence, 'ABCD');

    // Thêm lại cùng mã đề → upsert (không ném lỗi unique).
    await keyRepo.insert(AnswerKey(
      id: 0,
      contestId: contestId,
      examCode: 'A01',
      answerSequence: 'DDDD',
    ));
    final a01b = await keyRepo.byExamCode(contestId, 'A01');
    expect(a01b!.answerSequence, 'DDDD');
  });

  test('graded sheets: insert + watch decode', () async {
    final contestId = await contestRepo.insert(
      Contest(id: 0, name: 'K', examDate: DateTime(2026, 10, 3)),
    );
    final sheet = GradedSheet(
      contestId: contestId,
      examCode: 'A01',
      studentCode: '0413',
      chosen: [for (var i = 0; i < 4; i++) i == 3 ? null : 'ACBD'[i]],
      correctFlags: [true, false, true, null],
      score: 6.5,
      partScores: {'1': 4, '2': 2.5},
      gradedAt: DateTime(2026, 10, 20, 8, 30),
    );
    final id = await sheetRepo.insert(sheet);
    final loaded = (await sheetRepo.watchByContest(contestId).first).single;
    expect(id, greaterThan(0));
    expect(loaded.studentCode, '0413');
    expect(loaded.chosen, <String?>['A', 'C', 'B', null]);
    expect(loaded.correctFlags, <bool?>[true, false, true, null]);
    expect(loaded.score, 6.5);
    expect(loaded.correctCount, 2);
    expect(loaded.incorrectCount, 1);
    expect(loaded.unansweredCount, 1);
    expect(loaded.partScores['1'], 4);
  });
}
