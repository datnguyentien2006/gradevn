import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/import_export/xlsx_service.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../domain/entities/class_room.dart';
import '../../domain/entities/contest.dart';
import '../../domain/repositories/repositories.dart';

/// Provider cơ sở: DB drift (override với in-memory trong test).
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Trong main(): override databaseProvider với DB thật.'),
);

final classRoomRepositoryProvider =
    Provider<ClassRoomRepository>((ref) => DriftClassRoomRepository(ref.watch(databaseProvider)));

final studentRepositoryProvider =
    Provider<StudentRepository>((ref) => DriftStudentRepository(ref.watch(databaseProvider)));

final contestRepositoryProvider =
    Provider<ContestRepository>((ref) => DriftContestRepository(ref.watch(databaseProvider)));

final answerKeyRepositoryProvider =
    Provider<AnswerKeyRepository>((ref) => DriftAnswerKeyRepository(ref.watch(databaseProvider)));

final gradedSheetRepositoryProvider = Provider<GradedSheetRepository>(
    (ref) => DriftGradedSheetRepository(ref.watch(databaseProvider)));

final spreadsheetServiceProvider =
    Provider<SpreadsheetService>((ref) => const ExcelPlusSpreadsheetService());

// --- Stream providers (Riverpod 3: watch(stream) chưa phải AsyncValue) ---

final classesProvider = StreamProvider<List<ClassRoom>>(
  (ref) => ref.watch(classRoomRepositoryProvider).watchAll(),
);

final studentsByClassProvider = StreamProvider.family<List<Student>, int>(
  (ref, classId) => ref.watch(studentRepositoryProvider).watchByClass(classId),
);

final contestsProvider = StreamProvider<List<Contest>>(
  (ref) => ref.watch(contestRepositoryProvider).watchAll(),
);

final keysByContestProvider = StreamProvider.family<List<AnswerKey>, int>(
  (ref, contestId) => ref.watch(answerKeyRepositoryProvider).watchByContest(contestId),
);
