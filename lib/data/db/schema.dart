import 'package:drift/drift.dart';

/// Lớp học.
@DataClassName('ClassRoomRow')
class ClassRooms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
}

/// Học sinh của một lớp.
@DataClassName('StudentRow')
class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get classId => integer().references(ClassRooms, #id)();
  TextColumn get code => text()();
  TextColumn get fullName => text()();
}

/// Kỳ thi + cấu hình phiếu.
@DataClassName('ContestRow')
class Contests extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get examDate => dateTime()();
  IntColumn get classId => integer().nullable().references(ClassRooms, #id)();
  IntColumn get questionCount => integer().withDefault(const Constant(40))();
  IntColumn get answerChoices => integer().withDefault(const Constant(4))();
  RealColumn get maxScore => real().withDefault(const Constant(10.0))();

  // Form: enum được lưu thành int (0=standard, 1=fifty, 2=hundred20, 3=ministry).
  IntColumn get formType => integer().withDefault(const Constant(0))();
  IntColumn get orientation => integer().withDefault(const Constant(0))();

  // Các phần dạng bộ đề (nullable khi phiếu chuẩn).
  IntColumn get partOneCount => integer().nullable()();
  IntColumn get partTwoCount => integer().nullable()();
  IntColumn get partThreeCount => integer().nullable()();
  RealColumn get partOneWeight => real().nullable()();
  RealColumn get partTwoWeight => real().nullable()();
  RealColumn get partThreeWeight => real().nullable()();
}

/// Mã đề (key đáp án) của kỳ thi. Một kỳ thi có thể nhiều key.
@DataClassName('AnswerKeyRow')
class AnswerKeys extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contestId => integer().references(Contests, #id)();
  TextColumn get examCode => text()();
  TextColumn get answerSequence => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {contestId, examCode},
  ];
}

/// Phiếu đã chấm.
@DataClassName('GradedSheetRow')
class GradedSheets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contestId => integer().references(Contests, #id)();
  IntColumn get keyId => integer().nullable().references(AnswerKeys, #id)();
  IntColumn get studentId => integer().nullable().references(Students, #id)();
  TextColumn get examCode => text()();
  TextColumn get studentCode => text().withDefault(const Constant(''))();
  TextColumn get chosen => text()();       // đáp án decode: "ABDC-..." (' '|'-' = trống)
  TextColumn get correctFlags => text()(); // chuỗi '1'/'0'/'?' theo từng câu
  RealColumn get score => real()();
  RealColumn get partOneScore => real().nullable()();
  RealColumn get partTwoScore => real().nullable()();
  RealColumn get partThreeScore => real().nullable()();
  TextColumn get originalImagePath => text().nullable()();
  TextColumn get markedImagePath => text().nullable()();
  TextColumn get infoImagePath => text().nullable()();
  DateTimeColumn get gradedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Cài đặt ứng dụng (dưới dạng key–value đơn giản).
@DataClassName('SettingRow')
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {key},
  ];
}
