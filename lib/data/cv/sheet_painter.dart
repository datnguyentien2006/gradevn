// Bộ vẽ phiếu trả lời dùng CHUNG cho nhiều nơi, chỉ có 1 nguồn sự thật hình học:
//
// - test/fixtures/fixture_builder.dart: fixture hồi quy M2 (bong bóng + khung).
// - renderBlankSheet(): sinh ảnh phiếu trống để in thử (M3 — in ra giấy thật).
// - renderMarkedSheet(): phủ kết quả lên ảnh phiếu đã căn phẳng (màn hình xem lại).
//
// Thuật toán vẽ là THIẾT KẾ GỐC của GradeVN (không sao chép ứng dụng tham khảo):
// bong bóng là vành xám + lõi đặc khi được tô; khung mép giấy là dải đen liền
// dùng làm mốc căn chỉnh ảnh chụp (phát hiện ở M3).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:image/image.dart' as img;

import '../../domain/services/sheet_layout.dart';

/// Xám của vành bong bóng chưa tô (chuẩn hoá với fixture M2).
const int bubbleRingGray = 95;

/// Tham số khung căn chỉnh in nghiêng quanh 4 mép giấy.
final class FrameSpec {
  const FrameSpec({
    this.insetRatio = 0.017,
    this.thickness = 5,
    this.gray = 20,
  });

  /// Khoảng cách từ mép trang đến mép ngoài khung (tỉ lệ cạnh nhỏ trang).
  final double insetRatio;

  /// Độ dày dải khung (pixel, theo độ phân giải trang chuẩn).
  final double thickness;

  /// Độ xám của khung (0 = đen).
  final int gray;

  /// Hộp mép ngoài khung trên trang chuẩn [page].
  Rect outerRect(Size page) {
    final inset = math.min(page.width, page.height) * insetRatio;
    return Rect.fromLTWH(
      inset,
      inset,
      page.width - 2 * inset,
      page.height - 2 * inset,
    );
  }
}

/// Vẽ một bong bóng tròn: vành xám 2px; nếu [filled] thì tô đen lõi.
void drawBubble(
  img.Image image,
  Rect cell, {
  required bool filled,
  int ringGray = bubbleRingGray,
}) {
  final cx = (cell.left + cell.width / 2).round();
  final cy = (cell.top + cell.height / 2).round();
  final radius = (math.min(cell.width, cell.height) * 0.36).round();
  final ring = img.ColorRgb8(ringGray, ringGray, ringGray);
  img.drawCircle(image, x: cx, y: cy, radius: radius, color: ring);
  img.drawCircle(image, x: cx, y: cy, radius: radius - 1, color: ring);
  if (filled) {
    final fillRadius = (math.min(cell.width, cell.height) * 0.20).round();
    img.fillCircle(
      image,
      x: cx,
      y: cy,
      radius: fillRadius,
      color: img.ColorRgb8(0, 0, 0),
    );
  }
}

/// Vẽ khung căn chỉnh quanh mép trang (theo [FrameSpec]).
void drawFrame(img.Image image, {required Size page, FrameSpec spec = const FrameSpec()}) {
  final scale = image.width / page.width;
  final outer = spec.outerRect(page);
  final ox = (outer.left * scale).round();
  final oy = (outer.top * scale).round();
  final ow = (outer.width * scale).round();
  final oh = (outer.height * scale).round();
  final t = (spec.thickness * scale).round().clamp(1, 50);
  final color = img.ColorRgb8(spec.gray, spec.gray, spec.gray);

  img.fillRect(image, x1: ox, y1: oy, x2: ox + ow - 1, y2: oy + t - 1, color: color);
  img.fillRect(image, x1: ox, y1: oy + oh - t, x2: ox + ow - 1, y2: oy + oh - 1, color: color);
  img.fillRect(image, x1: ox, y1: oy, x2: ox + t - 1, y2: oy + oh - 1, color: color);
  img.fillRect(image, x1: ox + ow - t, y1: oy, x2: ox + ow - 1, y2: oy + oh - 1, color: color);
}

/// Sinh ảnh phiếu TRỐNG (mọi bong bóng đều chưa tô) để in ra giấy.
Uint8List renderBlankSheet(SheetLayout layout) {
  final image = img.Image(
    width: layout.page.width.toInt(),
    height: layout.page.height.toInt(),
  );
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  drawFrame(image, page: layout.page);

  void grid(Rect g) {
    for (var row = 0; row < SheetLayout.digitRows; row++) {
      for (var col = 0; col < SheetLayout.digitColumns; col++) {
        drawBubble(image, SheetLayout.digitCellRect(g, row, col), filled: false);
      }
    }
  }

  grid(layout.studentCodeGrid);
  grid(layout.examCodeGrid);

  for (final block in layout.answerBlocks) {
    for (var row = 0; row < block.rows; row++) {
      for (var col = 0; col < block.columns; col++) {
        drawBubble(image, block.cellRect(row, col), filled: false);
      }
    }
  }
  return img.encodePng(image, level: 6);
}

/// Phủ kết quả chấm lên ảnh phiếu đã được căn phẳng (xám) → PNG có màu.
///
/// - Câu đúng: lõi bong bóng tô xanh lá, câu sai: đỏ, câu trống: rìa nhạt.
/// - Lưới số: ô đã đọc được tô xanh dương; vị trí '?' tô cam.
Uint8List renderMarkedSheet({
  required Uint8List warpedGrayBytes,
  required SheetLayout layout,
  required List<bool?> correctFlags,
  required String studentCodeRaw,
  required String examCodeRaw,
}) {
  final image = img.decodeImage(warpedGrayBytes);
  if (image == null) {
    throw const FormatException('Không giải mã được ảnh phiếu để phủ kết quả.');
  }
  // Ảnh xám có r=g=b; vẽ màu trực tiếp trên đó vẫn đúng (vẽ đè RGB).
  final scaleX = image.width / layout.page.width;
  final scaleY = image.height / layout.page.height;
  Rect scaled(Rect r) => Rect.fromLTRB(
        r.left * scaleX,
        r.top * scaleY,
        r.right * scaleX,
        r.bottom * scaleY,
      );
  void tint(Rect cell, img.ColorRgb8 color, {int inset = 24}) {
    final s = scaled(cell);
    final pad = math.min(s.width, s.height) * inset / 100;
    img.fillRect(
      image,
      x1: (s.left + pad).round(),
      y1: (s.top + pad).round(),
      x2: (s.right - pad).round(),
      y2: (s.bottom - pad).round(),
      color: color,
    );
  }

  final correctColor = img.ColorRgb8(56, 142, 60);
  final wrongColor = img.ColorRgb8(211, 47, 47);
  final blankColor = img.ColorRgb8(176, 190, 197);
  final digitColor = img.ColorRgb8(48, 63, 159);
  final digitWrongColor = img.ColorRgb8(239, 108, 0);

  void grid(Rect g, String raw) {
    for (var row = 0; row < SheetLayout.digitRows; row++) {
      final parsed = row < raw.length ? int.tryParse(raw[row]) : null;
      final unreadable = row < raw.length && raw[row] == '?';
      if (parsed == null && !unreadable) continue;
      for (var col = 0; col < SheetLayout.digitColumns; col++) {
        final hit = parsed != null && parsed == col;
        if (parsed != null && !hit) continue;
        tint(
          SheetLayout.digitCellRect(g, row, col),
          hit ? digitColor : digitWrongColor,
          inset: hit ? 30 : 38,
        );
        if (hit) break;
      }
    }
  }

  grid(layout.studentCodeGrid, studentCodeRaw);
  grid(layout.examCodeGrid, examCodeRaw);

  for (var q = 0; q < layout.totalQuestions && q < correctFlags.length; q++) {
    final block = layout.answerBlocks.firstWhere(
      (b) => q >= b.firstQuestionIndex && q < b.firstQuestionIndex + b.rows,
    );
    final row = q - block.firstQuestionIndex;
    final flag = correctFlags[q];
    if (flag == null) {
      tint(block.cellRect(row, 0), blankColor, inset: 34);
      continue;
    }
    tint(block.cellRect(row, 0), flag ? correctColor : wrongColor, inset: 40);
  }
  return img.encodePng(image, level: 6);
}
