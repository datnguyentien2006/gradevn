import 'package:drift/drift.dart';

import '../../domain/entities/class_room.dart';
import '../../domain/entities/contest.dart';
import '../../domain/entities/graded_sheet.dart';
import '../../domain/repositories/repositories.dart';
import '../db/app_database.dart';
import 'mappers.dart';

final class DriftClassRoomRepository implements ClassRoomRepository {
  DriftClassRoomRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ClassRoom>> watchAll() =>
      (_db.select(_db.classRooms)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch()
          .map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<ClassRoom?> byId(int id) async {
    final row = await (_db.select(_db.classRooms)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<int> insert(ClassRoom classRoom) =>
      _db.into(_db.classRooms).insert(classRoom.toCompanion());

  @override
  Future<void> update(ClassRoom classRoom) =>
      (_db.update(_db.classRooms)..where((t) => t.id.equals(classRoom.id)))
          .write(classRoom.toCompanion());

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.classRooms)..where((t) => t.id.equals(id))).go();
}

final class DriftStudentRepository implements StudentRepository {
  DriftStudentRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Student>> watchByClass(int classId) =>
      (_db.select(_db.students)
            ..where((t) => t.classId.equals(classId))
            ..orderBy([(t) => OrderingTerm.asc(t.code)]))
          .watch()
          .map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<Student?> byCode(int classId, String code) async {
    final row = await (_db.select(_db.students)
          ..where((t) => t.classId.equals(classId) & t.code.equals(code)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<int> insert(Student student) =>
      _db.into(_db.students).insert(student.toCompanion());

  @override
  Future<int> insertMany(List<Student> students) async {
    await _db.batch((batch) {
      for (final s in students) {
        batch.insert(_db.students, s.toCompanion());
      }
    });
    return students.length;
  }

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.students)..where((t) => t.id.equals(id))).go();
}

final class DriftContestRepository implements ContestRepository {
  DriftContestRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Contest>> watchAll() =>
      (_db.select(_db.contests)..orderBy([(t) => OrderingTerm.desc(t.examDate)]))
          .watch()
          .map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<Contest?> byId(int id) async {
    final row = await (_db.select(_db.contests)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<int> insert(Contest contest) =>
      _db.into(_db.contests).insert(contest.toCompanion());

  @override
  Future<void> update(Contest contest) =>
      (_db.update(_db.contests)..where((t) => t.id.equals(contest.id)))
          .write(contest.toCompanion());

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.contests)..where((t) => t.id.equals(id))).go();
}

final class DriftAnswerKeyRepository implements AnswerKeyRepository {
  DriftAnswerKeyRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<AnswerKey>> watchByContest(int contestId) =>
      (_db.select(_db.answerKeys)
            ..where((t) => t.contestId.equals(contestId))
            ..orderBy([(t) => OrderingTerm.asc(t.examCode)]))
          .watch()
          .map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<AnswerKey?> byExamCode(int contestId, String examCode) async {
    final row = await (_db.select(_db.answerKeys)
          ..where((t) => t.contestId.equals(contestId) & t.examCode.equals(examCode)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<int> insert(AnswerKey key) =>
      _db.into(_db.answerKeys).insert(
            key.toCompanion(),
            mode: InsertMode.insertOrReplace,
          );

  @override
  Future<void> insertMany(int contestId, List<(String, String)> keys) =>
      _db.batch((batch) {
        for (final (examCode, answerSequence) in keys) {
          batch.insert(
            _db.answerKeys,
            AnswerKeysCompanion.insert(
              contestId: contestId,
              examCode: examCode,
              answerSequence: answerSequence,
            ),
          );
        }
      });

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.answerKeys)..where((t) => t.id.equals(id))).go();
}

final class DriftGradedSheetRepository implements GradedSheetRepository {
  DriftGradedSheetRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<GradedSheet>> watchByContest(int contestId) =>
      (_db.select(_db.gradedSheets)
            ..where((t) => t.contestId.equals(contestId))
            ..orderBy([(t) => OrderingTerm.desc(t.gradedAt)]))
          .watch()
          .map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<GradedSheet?> byId(int id) async {
    final row = await (_db.select(_db.gradedSheets)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<int> insert(GradedSheet sheet) =>
      _db.into(_db.gradedSheets).insert(sheet.toCompanion());

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.gradedSheets)..where((t) => t.id.equals(id))).go();
}
