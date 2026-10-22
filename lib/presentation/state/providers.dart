import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cv/scan_service.dart';
import '../../data/cv/student_info_ocr.dart';
import '../../data/db/app_database.dart';
import '../../data/import_export/xlsx_service.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../domain/entities/class_room.dart';
import '../../domain/entities/contest.dart';
import '../../domain/entities/graded_sheet.dart';
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

final scanServiceProvider = Provider<OmrScanService>((ref) => const OmrScanService());

/// OCR thông tin học sinh — bản no-op (lưới số trên phiếu đã mã hoá SBD).
final studentInfoOcrProvider = Provider<StudentInfoOcr>((ref) => const NoOpStudentInfoOcr());

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

final gradedSheetsByContestProvider = StreamProvider.family<List<GradedSheet>, int>(
  (ref, contestId) => ref.watch(gradedSheetRepositoryProvider).watchByContest(contestId),
);

// --- Future providers (đọc một lần theo id — màn chi tiết M3) ---

final gradedSheetByIdProvider = FutureProvider.family<GradedSheet?, int>(
  (ref, id) => ref.watch(gradedSheetRepositoryProvider).byId(id),
);

final contestByIdProvider = FutureProvider.family<Contest?, int>(
  (ref, id) => ref.watch(contestRepositoryProvider).byId(id),
);
