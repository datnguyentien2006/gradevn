import 'dart:io';

import 'package:excel_plus/excel_plus.dart' as xl;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as sf;

/// Kết quả đọc 1 dòng key từ file XLSX.
final class ParsedKey {
  const ParsedKey({required this.examCode, required this.answerSequence});

  final String examCode;
  final String answerSequence;

  @override
  String toString() => 'ParsedKey($examCode: $answerSequence)';
}

/// Kết quả đọc 1 dòng học sinh.
final class ParsedStudent {
  const ParsedStudent({required this.code, required this.fullName});

  final String code;
  final String fullName;

  @override
  String toString() => 'ParsedStudent($code: $fullName)';
}

/// 1 dòng kết quả chấm để xuất ra XLSX.
final class ResultRow {
  const ResultRow({
    required this.studentCode,
    required this.examCode,
    required this.score,
    this.partOne,
    this.partTwo,
    this.partThree,
    this.studentName,
  });

  final String? studentCode;
  final String examCode;
  final double score;
  final double? partOne;
  final double? partTwo;
  final double? partThree;
  final String? studentName;
}

/// Giao diện đọc/ghi bảng tính (cho phép thay thế khi unit test).
abstract interface class SpreadsheetService {
  /// Đọc mã đề/khóa đáp án: mỗi hàng = (cột A mã đề, cột B là dãy đáp án
  /// hoặc cột B..N mỗi ô 1 đáp án; ô trống → câu bỏ).
  Future<List<ParsedKey>> readKeys(String filePath);

  /// Đọc học sinh: mỗi hàng = (cột A mã số, cột B họ tên).
  Future<List<ParsedStudent>> readStudents(String filePath);

  /// Ghi bảng kết quả ra .xlsx: tiêu đề kỳ thi + cột (SBD, Mã đề, Điểm, Phần I/II/III).
  Future<void> writeResults({
    required String filePath,
    required String contestName,
    required List<ResultRow> rows,
  });

  /// Ghi các mã đề ra .xlsx (định dạng chuẩn để đọc lại bằng readKeys).
  Future<void> writeKeys({
    required String filePath,
    required List<ParsedKey> keys,
  });
}

/// Chuyển ô excel thành chuỗi. Hàng trả về là `Data` (bọc CellValue); kiểu
/// sealed CellValue riêng lẻ phải tách từng loại.
String _cellText(Object? cell) {
  if (cell == null) return '';
  final Object? raw = cell is xl.Data ? cell.value : cell;
  if (raw == null) return '';
  switch (raw.runtimeType) {
    case const (xl.TextCellValue):
      return (raw as xl.TextCellValue).value.text ?? '';
    case const (xl.IntCellValue):
      return (raw as xl.IntCellValue).value.toString();
    case const (xl.DoubleCellValue):
      return (raw as xl.DoubleCellValue).value.toString();
    case const (xl.BoolCellValue):
      return (raw as xl.BoolCellValue).value ? '1' : '0';
    default:
      return '';
  }
}

/// Ghi chú kiến trúc: dùng `excel_plus` (fork đang được bảo trì của gói `excel`)
/// để ĐỌC file .xlsx/.xls — gói `excel` gốc xung đột ràng buộc `xml` với
/// syncfusion_flutter_xlsio (deviation đã ghi PROJECT_NOTES.md).
/// GHI file .xlsx bằng syncfusion_flutter_xlsio.
final class ExcelPlusSpreadsheetService implements SpreadsheetService {
  const ExcelPlusSpreadsheetService();

  xl.Excel _open(String filePath) =>
      xl.Excel.decodeBytes(File(filePath).readAsBytesSync());

  @override
  Future<List<ParsedKey>> readKeys(String filePath) async {
    final wb = _open(filePath);
    final out = <ParsedKey>[];
    final tableNames = wb.tables.keys.toList();
    if (tableNames.isEmpty) return out;
    final sheet = wb[tableNames.first];
    for (final row in sheet.rows) {
      if (row.isEmpty) continue;
      final examCode = _cellText(row[0]).trim();
      if (examCode.isEmpty) continue;
      // Bỏ qua dòng tiêu đề.
      final lower = examCode.toLowerCase();
      if (lower.contains('mã') || lower.contains('code') || lower.contains('stt')) {
        continue;
      }
      // Các ô dữ liệu bắt đầu từ cột B.
      final answers = <String>[];
      for (var i = 1; i < row.length; i++) {
        final txt = _cellText(row[i]).trim();
        if (txt.isNotEmpty) answers.add(txt);
      }
      String answerSequence;
      if (answers.length <= 1) {
        // Dấu phân tách trong 1 ô: khoảng trắng / xuống dòng / dấu phẩy.
        final raw = answers.isEmpty ? '' : answers.first;
        answerSequence = raw
            .split(RegExp(r'[\s,;]+'))
            .where((t) => t.isNotEmpty)
            .join()
            .toUpperCase();
      } else {
        // Mỗi ô 1 đáp án.
        answerSequence = answers
            .map((s) => s.toUpperCase().replaceAll(RegExp(r'[\s,;]'), ''))
            .join();
      }
      if (answerSequence.isEmpty) continue;
      out.add(ParsedKey(examCode: examCode, answerSequence: answerSequence));
    }
    return out;
  }

  @override
  Future<List<ParsedStudent>> readStudents(String filePath) async {
    final wb = _open(filePath);
    final out = <ParsedStudent>[];
    final tableNames = wb.tables.keys.toList();
    if (tableNames.isEmpty) return out;
    final sheet = wb[tableNames.first];
    for (final row in sheet.rows) {
      if (row.isEmpty) continue;
      final code = _cellText(row[0]).trim();
      if (code.isEmpty) continue;
      final lower = code.toLowerCase();
      if (lower.contains('mã') ||
          lower.contains('sbd') ||
          lower.contains('code') ||
          lower.contains('stt')) {
        continue; // dòng tiêu đề
      }
      final name = _cellText(row.length > 1 ? row[1] : null).trim();
      out.add(ParsedStudent(code: code, fullName: name));
    }
    return out;
  }

  @override
  Future<void> writeResults({
    required String filePath,
    required String contestName,
    required List<ResultRow> rows,
  }) async {
    final wb = sf.Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = 'Kết quả';
    sheet.getRangeByIndex(1, 1).setText('Kỳ thi: $contestName');

    const headers = <String>['STT', 'SBD', 'Mã đề', 'Họ tên', 'Điểm', 'Phần I', 'Phần II', 'Phần III'];
    for (var c = 0; c < headers.length; c++) {
      sheet.getRangeByIndex(2, c + 1).setText(headers[c]);
    }
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rowIdx = i + 3;
      sheet.getRangeByIndex(rowIdx, 1).setNumber(i + 1.toDouble());
      sheet.getRangeByIndex(rowIdx, 2).setText(r.studentCode ?? '');
      sheet.getRangeByIndex(rowIdx, 3).setText(r.examCode);
      sheet.getRangeByIndex(rowIdx, 4).setText(r.studentName ?? '');
      sheet.getRangeByIndex(rowIdx, 5).setNumber(r.score);
      sheet.getRangeByIndex(rowIdx, 6).setNumber(r.partOne ?? 0);
      sheet.getRangeByIndex(rowIdx, 7).setNumber(r.partTwo ?? 0);
      sheet.getRangeByIndex(rowIdx, 8).setNumber(r.partThree ?? 0);
    }
    final bytes = wb.saveSync();
    await File(filePath).writeAsBytes(bytes);
    wb.dispose();
  }

  @override
  Future<void> writeKeys({
    required String filePath,
    required List<ParsedKey> keys,
  }) async {
    final wb = sf.Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = 'Mã đề';
    sheet.getRangeByIndex(1, 1).setText('Mã đề');
    sheet.getRangeByIndex(1, 2).setText('Dãy đáp án');
    for (var i = 0; i < keys.length; i++) {
      final rowIdx = i + 2;
      sheet.getRangeByIndex(rowIdx, 1).setText(keys[i].examCode);
      // Ghi sang định dạng 1 ô, cách nhau khoảng trắng, để readKeys đọc lại được.
      sheet.getRangeByIndex(rowIdx, 2).setText(
            keys[i].answerSequence.split('').join(' '),
          );
    }
    final bytes = wb.saveSync();
    await File(filePath).writeAsBytes(bytes);
    wb.dispose();
  }
}
