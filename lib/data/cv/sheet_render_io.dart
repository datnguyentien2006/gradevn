// R2 — Ghi ảnh phiếu đã chấm vào bộ nhớ máy: TRONG ISOLATE.
//
// Lý do: `renderMarkedSheet` để decode PNG 1240×1754 + vẽ + encodePng level 6,
// cộng hai lần ghi tệp — tổng ~1s trên PC, ~5 lần chậm hơn trên điện thoại.
// Chạy việc này trên thread UI (bản R1) là nguồn treo "app không phản hồi"
// ngay khi bấm "Lưu kết quả". File này bọc toàn bộ decode + render + ghi tệp
// vào một isolate, thread UI chỉ đổi lần gọi.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../domain/services/sheet_layout.dart';
import 'sheet_painter.dart' show renderMarkedSheet;

/// Đường dẫn hai ảnh đã ghi (gốc đã nắn + phiếu có gạch kết quả).
final class SavedSheetImages {
  const SavedSheetImages({required this.originalPath, required this.markedPath});

  /// Ảnh phiếu đã nắn phẳng (PNG xám, đầu vào của bước chấm).
  final String originalPath;

  /// Ảnh phiếu phủ gạch xanh/đỏ theo kết quả chấm (PNG màu).
  final String markedPath;
}

/// Dữ liệu đầu vào của isolate (plain-data — gửi qua port an toàn).
final class _SaveJob {
  const _SaveJob({
    required this.warpedBytes,
    required this.directoryPath,
    required this.timestamp,
    required this.layout,
    required this.correctFlags,
    required this.studentCodeRaw,
    required this.examCodeRaw,
  });

  final Uint8List warpedBytes;
  final String directoryPath;
  final int timestamp;
  final SheetLayout layout;
  final List<bool?> correctFlags;
  final String studentCodeRaw;
  final String examCodeRaw;
}

/// Thân isolate: tạo thư mục → render phiếu có gạch → ghi 2 tệp PNG.
SavedSheetImages _saveSheetJob(_SaveJob job) {
  final dir = Directory(job.directoryPath);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final ts = job.timestamp;
  final origPath = p.join(dir.path, 'orig_$ts.png');
  File(origPath).writeAsBytesSync(job.warpedBytes, flush: true);
  final marked = renderMarkedSheet(
    warpedGrayBytes: job.warpedBytes,
    layout: job.layout,
    correctFlags: job.correctFlags,
    studentCodeRaw: job.studentCodeRaw,
    examCodeRaw: job.examCodeRaw,
  );
  final markedPath = p.join(dir.path, 'marked_$ts.png');
  File(markedPath).writeAsBytesSync(marked, flush: true);
  return SavedSheetImages(originalPath: origPath, markedPath: markedPath);
}

/// Bọc isolate: render + ghi ảnh phiếu ngoài thread UI.
///
/// Ném lỗi đọc/ghi/decode như hàm đồng bộ — UI bọc try/catch như cũ.
Future<SavedSheetImages> saveScannedImages({
  required Uint8List warpedBytes,
  required SheetLayout layout,
  required List<bool?> correctFlags,
  required String studentCodeRaw,
  required String examCodeRaw,
  required String directoryPath,
  required int timestamp,
}) {
  final job = _SaveJob(
    warpedBytes: warpedBytes,
    directoryPath: directoryPath,
    timestamp: timestamp,
    layout: layout,
    correctFlags: correctFlags,
    studentCodeRaw: studentCodeRaw,
    examCodeRaw: examCodeRaw,
  );
  return Isolate.run(() => _saveSheetJob(job));
}
