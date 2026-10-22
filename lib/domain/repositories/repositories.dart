import '../entities/class_room.dart';
import '../entities/contest.dart';
import '../entities/graded_sheet.dart';

/// Interface dữ liệu Contest — cài đặt bằng drift ở `data/repositories` (M1).
abstract interface class ContestRepository {
  Stream<List<Contest>> watchAll();
  Future<Contest?> byId(int id);
  Future<int> insert(Contest contest);
  Future<void> update(Contest contest);
  Future<void> delete(int id);
}

abstract interface class AnswerKeyRepository {
  Stream<List<AnswerKey>> watchByContest(int contestId);
  Future<AnswerKey?> byExamCode(int contestId, String examCode);
  Future<int> insert(AnswerKey key);
  Future<void> delete(int id);
}

abstract interface class ClassRoomRepository {
  Stream<List<ClassRoom>> watchAll();
  Future<int> insert(ClassRoom classRoom);
  Future<void> update(ClassRoom classRoom);
  Future<void> delete(int id);
}

abstract interface class StudentRepository {
  Stream<List<Student>> watchByClass(int classId);
  Future<Student?> byCode(int classId, String code);
  Future<int> insert(Student student);
  Future<int> insertMany(List<Student> students);
  Future<void> delete(int id);
}

abstract interface class GradedSheetRepository {
  Stream<List<GradedSheet>> watchByContest(int contestId);
  Future<int> insert(GradedSheet sheet);
  Future<void> delete(int id);
}
