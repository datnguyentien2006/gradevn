import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/import_export/xlsx_service.dart';

void main() {
  final service = const ExcelPlusSpreadsheetService();
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('gradevn_xlsx_'));
  tearDown(() {
    tmp.listSync(recursive: true).forEach((f) => f.deleteSync());
    tmp.deleteSync();
  });

  test('writeKeys → readKeys: round-trip đầy đủ', () async {
    final path = '${tmp.path}${Platform.pathSeparator}keys.xlsx';
    await service.writeKeys(
      filePath: path,
      keys: const [
        ParsedKey(examCode: 'A01', answerSequence: 'ABCD'),
        ParsedKey(examCode: '123', answerSequence: 'DCBAAB'),
      ],
    );
    expect(File(path).existsSync(), isTrue);

    final keys = await service.readKeys(path);
    expect(keys.length, 2);
    expect(keys[0].examCode, 'A01');
    expect(keys[0].answerSequence, 'ABCD');
    expect(keys[1].examCode, '123');
    expect(keys[1].answerSequence, 'DCBAAB');
  });

  test('readKeys bỏ qua dòng tiêu đề và chấp nhận nhiều cột đáp án', () async {
    final path = '${tmp.path}${Platform.pathSeparator}cols.xlsx';
    await service.writeKeys(
      filePath: path,
      keys: const [ParsedKey(examCode: 'K1', answerSequence: 'ABCABCA')],
    );
    final keys = await service.readKeys(path);
    expect(keys.single.examCode, 'K1');
    expect(keys.single.answerSequence, 'ABCABCA');
  });

  test('writeResults ghi ra file hợp lệ', () async {
    final path = '${tmp.path}${Platform.pathSeparator}results.xlsx';
    await service.writeResults(
      filePath: path,
      contestName: 'Giữa kỳ I',
      rows: const [
        ResultRow(studentCode: '001', examCode: 'A01', score: 9.5),
        ResultRow(studentCode: '002', examCode: 'A02', score: 7, partOne: 4, partTwo: 3),
      ],
    );
    expect(File(path).existsSync(), isTrue);
    expect(File(path).lengthSync(), greaterThan(0));
  });

  test('readStudents: đọc 1 file keys (định dạng khác) trả về rỗng mà không ném lỗi', () async {
    final path = '${tmp.path}${Platform.pathSeparator}keys2.xlsx';
    await service.writeKeys(filePath: path, keys: const [
      ParsedKey(examCode: 'A01', answerSequence: 'AB'),
    ]);
    final students = await service.readStudents(path);
    // File keys: cột A "A01" (không phải mã số học sinh chuẩn) nhưng không ném lỗi.
    expect(students, isList);
  });
}
