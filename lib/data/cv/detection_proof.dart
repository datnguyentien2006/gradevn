// R3 — BẤNG CHỨNG DEBUG cho luồng phát hiện mốc — chỉ chạy trong build
// DEBUG (nơi gọi bắt buộc bọc kDebugMode; bản release không đụng code này).
//
//  * [annotateDetectionProof] vẽ: ứng viên = ô vuông đỏ nhỏ + nhãn (c0, c1…),
//    quad 4 mốc = đa giác xanh lá — đè lên ẢNH CHỤP GỐC (px thực).
//  * [saveDetectionProof] chạy decode + detect (khi thiếu dữ liệu) + annotate
//    + ghi tệp TOÀN BỘ TRONG ISOLATE, trả về đường dẫn PNG đã ghi. Kết quả
//    được adb-pull về máy dev và commit vào `docs/evidence/`.
//
// Mục tiêu (điểm nghi ngờ #R3-2): chứng minh trên ảnh THẬT rằng detector
// THẬT SỰ chọn 4 ô vuông đen mốc (không phải bong bóng/keyboard) và quad
// sau nắn trùng vị trí chuẩn (WarpedMarkerCheck ≤ 6 px).

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'sheet_alignment.dart' show AlignmentQuad, SheetMarkerDetector;

/// Vẽ overlay kết quả phân tích lên ảnh chụp gốc, trả PNG bytes.
Uint8List annotateDetectionProof({
  required Uint8List photoBytes,
  required List<Offset> candidates,
  AlignmentQuad? quad,
}) {
  final image = img.decodeImage(photoBytes);
  if (image == null) {
    throw const FormatException('Không giải mã được ảnh chụp để annotate.');
  }
  final red = img.ColorRgb8(0xE5, 0x2A, 0x2A);
  final green = img.ColorRgb8(0x18, 0xA5, 0x45);

  // Quad ghim/detect: đa giác đóng tl→tr→br→bl.
  if (quad != null) {
    final pts = <Offset>[quad.tl, quad.tr, quad.br, quad.bl, quad.tl];
    for (var i = 0; i + 1 < pts.length; i++) {
      _thickLine(image, pts[i], pts[i + 1], green, 6);
    }
  }

  // Ứng viên: ô vuông đỏ + nhãn c<i> (kẹp biên).
  for (var i = 0; i < candidates.length; i++) {
    final c = candidates[i];
    final x0 = (c.dx - 7).clamp(0, image.width - 1).toInt();
    final y0 = (c.dy - 7).clamp(0, image.height - 1).toInt();
    final x1 = (c.dx + 7).clamp(0, image.width - 1).toInt();
    final y1 = (c.dy + 7).clamp(0, image.height - 1).toInt();
    img.fillRect(image, x1: x0, y1: y0, x2: x1, y2: y1, color: red);
    img.drawString(
      image,
      'c$i',
      font: img.arial14,
      x: (c.dx + 10).clamp(0, image.width - 40).toInt(),
      y: (c.dy - 8).clamp(0, image.height - 14).toInt(),
      color: red,
    );
  }
  return img.encodePng(image, level: 3);
}

/// Đoạn thẳng dày (Bresenham + quét lift theo bề dày vuông) — dùng map API
/// thẳng của package:image cho đoạn dài, kẹp biên.
void _thickLine(
  img.Image image,
  Offset from,
  Offset to,
  img.ColorRgb8 color,
  int thickness,
) {
  final half = thickness / 2;
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;
  final len = (dx * dx + dy * dy);
  if (len <= 0) {
    _disc(image, from, half.toInt(), color);
    return;
  }
  // Đi dọc cạnh bằng bước đều; vẽ đĩa nhỏ mỗi bước → nét dày tròn mép.
  final steps = (math.sqrt(len) / 1.2).ceil();
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    _disc(
      image,
      Offset(from.dx + dx * t, from.dy + dy * t),
      half.ceil(),
      color,
    );
  }
}

void _disc(img.Image image, Offset center, int radius, img.ColorRgb8 color) {
  for (var dy = -radius; dy <= radius; dy++) {
    for (var dx = -radius; dx <= radius; dx++) {
      if (dx * dx + dy * dy > radius * radius) continue;
      final x = (center.dx + dx).clamp(0, image.width - 1).toInt();
      final y = (center.dy + dy).clamp(0, image.height - 1).toInt();
      image.setPixelRgb(x, y, color.r, color.g, color.b);
    }
  }
}

/// Dữ liệu isolate (plain-data): bytes + toạ độ thuần.
final class _ProofJob {
  const _ProofJob({
    required this.photoBytes,
    required this.directoryPath,
    required this.timestamp,
    required this.candidates,
    required this.quad,
  });

  final Uint8List photoBytes;
  final String directoryPath;
  final int timestamp;
  final List<Offset>? candidates;
  final AlignmentQuad? quad;
}

/// Thân isolate: (detect khi thiếu) → annotate → ghi tệp → đường dẫn.
String? _proofJob(_ProofJob job) {
  var candidates = job.candidates;
  var quad = job.quad;
  if (candidates == null || quad == null) {
    final detection = const SheetMarkerDetector().detect(job.photoBytes);
    candidates ??= detection.candidates;
    quad ??= detection.quad;
  }
  final png = annotateDetectionProof(
    photoBytes: job.photoBytes,
    candidates: candidates,
    quad: quad,
  );
  final dir = Directory(job.directoryPath);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final path = p.join(dir.path, 'proof_${job.timestamp}.png');
  File(path).writeAsBytesSync(png, flush: true);
  return path;
}

/// Bọc isolate — gọi từ màn chụp trong kDebugMode; ảnh hỏng ném
/// FormatException (nơi gọi try/catch + debugPrint).
Future<String?> saveDetectionProof({
  required Uint8List photoBytes,
  required String directoryPath,
  required int timestamp,
  List<Offset>? candidates,
  AlignmentQuad? quad,
}) {
  final job = _ProofJob(
    photoBytes: photoBytes,
    directoryPath: directoryPath,
    timestamp: timestamp,
    candidates: candidates,
    quad: quad,
  );
  return Isolate.run(() => _proofJob(job));
}
