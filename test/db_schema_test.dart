import 'package:drift/drift.dart' show TableInfo, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/db/app_database.dart';

/// Kiểm tra schema v1 mở được + insert CRUD cơ bản + unique constraint key.
void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryAppDatabase());
  tearDown(() => db.close());

  test('schema v1 tạo đủ 6 bảng và mở được', () async {
    final tables = db.allTables.map((t) => (t as TableInfo).actualTableName).toSet();
    expect(
      tables,
      containsAll(<String>[
        'class_rooms',
        'students',
        'contests',
        'answer_keys',
        'graded_sheets',
        'app_settings',
      ]),
    );
  });

  test('insert lớp → học sinh → kỳ thi → key → phiếu chấm', () async {
    final classId = await db
        .into(db.classRooms)
        .insert(ClassRoomsCompanion.insert(name: '10A1'));
    final studentId = await db.into(db.students).insert(
          StudentsCompanion.insert(classId: classId, code: '001', fullName: 'Nguyễn Văn A'),
        );
    final contestId = await db.into(db.contests).insert(
          ContestsCompanion.insert(name: 'Giữa kỳ 1', examDate: DateTime(2026, 11, 5)),
        );
    final keyId = await db.into(db.answerKeys).insert(
          AnswerKeysCompanion.insert(
              contestId: contestId, examCode: 'A01', answerSequence: 'ABCD'),
        );
    final sheetId = await db.into(db.gradedSheets).insert(
          GradedSheetsCompanion.insert(
            contestId: contestId,
            keyId: Value(keyId),
            studentId: Value(studentId),
            examCode: 'A01',
            chosen: 'ABCA',
            correctFlags: '1110',
            score: 7.5,
          ),
        );

    // đọc lại
    final classes = await db.select(db.classRooms).get();
    final students = await db.select(db.students).get();
    final contests = await db.select(db.contests).get();
    final keys = await db.select(db.answerKeys).get();
    final sheets = await db.select(db.gradedSheets).get();

    expect(classes.single.name, '10A1');
    expect(students.single.classId, classId);
    expect(contests.single.name, 'Giữa kỳ 1');
    expect(keys.single.examCode, 'A01');
    expect(sheets.single.score, 7.5);

    await (db.delete(db.gradedSheets)..where((t) => t.id.equals(sheetId))).go();
    expect(await db.select(db.gradedSheets).get(), isEmpty);
  });

  test('(contestId, examCode) là unique cho answer_keys', () async {
    final contestId = await db.into(db.contests).insert(
          ContestsCompanion.insert(name: 'Ktra miệng', examDate: DateTime(2026, 10, 1)),
        );
    await db.into(db.answerKeys).insert(
          AnswerKeysCompanion.insert(contestId: contestId, examCode: 'M01', answerSequence: 'AB'),
        );
    expect(
      () => db.into(db.answerKeys).insert(
            AnswerKeysCompanion.insert(contestId: contestId, examCode: 'M01', answerSequence: 'CD'),
          ),
      throwsA(anything),
    );
  });

  test('cài đặt key-value với unique key', () async {
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(key: 'sensitivity', value: '0.5'),
        );
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(key: 'export_type', value: 'xlsx'),
        );
    final rows = await db.select(db.appSettings).get();
    expect(rows.map((r) => r.key), unorderedEquals(<String>['sensitivity', 'export_type']));
  });
}
