import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'schema.dart';

part 'app_database.g.dart';

/// Cài đặt ở tầng `data/`: DB drift cho toàn bộ dữ liệu offline.
@DriftDatabase(tables: [
  ClassRooms,
  Students,
  Contests,
  AnswerKeys,
  GradedSheets,
  AppSettings,
])
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Schema v1: chưa cần nâng cấp nào.
        },
      );
}

/// Mở DB cho môi trường chạy (Android/iOS). Dùng `AppDatabase.forTest()` trong test.
Future<AppDatabase> openAppDatabase({
  String? databaseDirectory,
}) async {
  final dir = databaseDirectory ??
      (await getApplicationSupportDirectory()).path;
  final file = File(p.join(dir, 'gradevn.sqlite'));
  return AppDatabase(NativeDatabase(file));
}

/// DB trong bộ nhớ phục vụ unit test.
AppDatabase inMemoryAppDatabase() =>
    AppDatabase(NativeDatabase.memory());
