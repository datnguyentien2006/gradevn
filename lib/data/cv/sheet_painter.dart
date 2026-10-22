// Bộ vẽ phiếu trả lời TN40 — THIẾT KẾ GỐC, hình học duy nhất từ SheetTemplate
// (đo từ docs/reference-sheets/PhieuTN40cau.jpg — xem sheet_template.dart).
//
// Hai bộ vẽ:
//  - [renderScanSheet] (thuần package:image, KHÔNG dùng font): phiếu "quét được"
//    gồm 12 ô vuông mốc đen + vòng bong bóng + chữ số 7-đoạn trong lưới số +
//    nhãn chữ A..E/số câu bằng glyph nét — dùng cho test/fixture (deterministic,
//    chạy được cả dưới dart run lẫn flutter test).
//  - [renderBlankSheet] (dart:ui + font hệ thống): bản in THẬT đầy đủ nhãn tiếng
//    Việt cho người dùng. Dùng trên thiết bị/app (test không so khớp pixel hàm này).
//  - [renderMarkedSheet] phủ kết quả lên ảnh phiếu ĐÃ NẮN (PNG xám).
//
// Chống lệch hình học: mọi toạ độ đi qua [SheetLayout] (template × trang chuẩn).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../../domain/services/sheet_layout.dart';

/// Xám vòng viền bong bóng chưa tô.
const int bubbleRingGray = 80;

/// Xám chữ số 7-đoạn in trong lưới số (nhạt hơn viền; gần "mực tay" thật).
const int glyphGray = 125;

// ---------------------------------------------------------------------------
// Glyph 7-đoạn (chữ số 0-9, chữ A-E) — đơn vị 0..1 trong hộp glyph.
// ---------------------------------------------------------------------------

const Map<String, List<List<double>>> _glyphSegments = {
  '0': [[0.15, 0, 0.85, 0], [0.85, 0, 0.85, 1], [0.85, 1, 0.15, 1], [0.15, 1, 0.15, 0]],
  '1': [[0.25, 0.2, 0.6, 0], [0.6, 0, 0.6, 1], [0.25, 1, 0.95, 1]],
  '2': [[0.12, 0, 0.88, 0], [0.88, 0, 0.88, 0.5], [0.88, 0.5, 0.12, 0.5], [0.12, 0, 0.12, 0.5], [0.12, 0.5, 0.12, 1], [0.12, 1, 0.88, 1]],
  '3': [[0.12, 0, 0.88, 0], [0.88, 0, 0.88, 1], [0.12, 0.5, 0.88, 0.5], [0.12, 1, 0.88, 1]],
  '4': [[0.12, 0, 0.12, 0.5], [0.88, 0, 0.88, 1], [0.12, 0.5, 0.88, 0.5]],
  '5': [[0.88, 0, 0.12, 0], [0.12, 0, 0.12, 0.5], [0.12, 0.5, 0.88, 0.5], [0.88, 0.5, 0.88, 1], [0.12, 1, 0.88, 1]],
  '6': [[0.88, 0, 0.12, 0], [0.12, 0, 0.12, 1], [0.12, 1, 0.88, 1], [0.88, 1, 0.88, 0.5], [0.12, 0.5, 0.88, 0.5]],
  '7': [[0.12, 0, 0.88, 0], [0.88, 0, 0.88, 0.5], [0.88, 0.5, 0.35, 1]],
  '8': [[0.15, 0, 0.85, 0], [0.15, 1, 0.85, 1], [0.15, 0, 0.15, 1], [0.85, 0, 0.85, 1], [0.15, 0.5, 0.85, 0.5]],
  '9': [[0.88, 1, 0.12, 1], [0.12, 0, 0.12, 0.5], [0.88, 0, 0.88, 1], [0.12, 0.5, 0.88, 0.5], [0.12, 0, 0.88, 0]],
  'A': [[0.12, 0, 0.12, 1], [0.88, 0, 0.88, 1], [0.12, 0, 0.88, 0], [0.12, 0.5, 0.88, 0.5]],
  'B': [[0.15, 0, 0.15, 1], [0.15, 0, 0.85, 0.12], [0.85, 0.12, 0.85, 0.42], [0.85, 0.42, 0.15, 0.5], [0.15, 0.5, 0.85, 0.58], [0.85, 0.58, 0.85, 0.88], [0.85, 0.88, 0.15, 1]],
  'C': [[0.92, 0.08, 0.92, 0.92], [0.12, 0.2, 0.12, 0.8], [0.12, 0.2, 0.92, 0.08], [0.12, 0.8, 0.92, 0.92]],
  'D': [[0.15, 0, 0.15, 1], [0.15, 0, 0.75, 0.15], [0.75, 0.15, 0.85, 0.5], [0.85, 0.5, 0.75, 0.85], [0.75, 0.85, 0.15, 1]],
  'E': [[0.2, 0, 0.2, 1], [0.2, 0, 0.85, 0], [0.2, 0.5, 0.75, 0.5], [0.2, 1, 0.85, 1]],
};

/// Vẽ glyph (một ký tự) vào [image], tâm [center], cạnh [size] (px ảnh).
void drawGlyph(
  img.Image image,
  ui.Offset center,
  String text, {
  required double size,
  int gray = glyphGray,
}) {
  final segments = _glyphSegments[text];
  if (segments == null) return;
  final gw = size * 0.62;
  final gh = size * 0.7;
  final x0 = center.dx - gw / 2;
  final y0 = center.dy - gh / 2;
  final thickness = math.max(1, (size * 0.09).round());
  final color = img.ColorRgb8(gray, gray, gray);
  for (final seg in segments) {
    img.drawLine(
      image,
      x1: (x0 + seg[0] * gw).round(),
      y1: (y0 + seg[1] * gh).round(),
      x2: (x0 + seg[2] * gw).round(),
      y2: (y0 + seg[3] * gh).round(),
      color: color,
      thickness: thickness,
    );
  }
}

/// Vẽ chuỗi glyph (ví dụ "11", "40") — mỗi ký tự cách đều theo chiều ngang.
void drawGlyphText(
  img.Image image,
  ui.Offset center,
  String text, {
  required double size,
  int gray = glyphGray,
}) {
  for (var i = 0; i < text.length; i++) {
    final charSize = size;
    final offset = ui.Offset(
      center.dx + (i - (text.length - 1) / 2.0) * charSize * 0.62,
      center.dy,
    );
    drawGlyph(image, offset, text[i], size: charSize, gray: gray);
  }
}

// ---------------------------------------------------------------------------
// Hạt vẽ cơ bản (package:image)
// ---------------------------------------------------------------------------

/// Vẽ một ô bong bóng: vòng viền; [filled] = tô đặc lõi (học sinh tô).
void drawBubble(
  img.Image image,
  ui.Rect cell, {
  required bool filled,
  int ringGray = bubbleRingGray,
}) {
  final cx = (cell.left + cell.width / 2).round();
  final cy = (cell.top + cell.height / 2).round();
  final radius = (math.min(cell.width, cell.height) * 0.5 - 2).round();
  final ring = img.ColorRgb8(ringGray, ringGray, ringGray);
  img.drawCircle(image, x: cx, y: cy, radius: radius, color: ring);
  img.drawCircle(image, x: cx, y: cy, radius: radius - 2, color: ring);
  if (filled) {
    img.fillCircle(
      image,
      x: cx,
      y: cy,
      radius: radius - 3,
      color: img.ColorRgb8(0, 0, 0),
    );
  }
}

/// Ô vuông đen đặc (mốc căn chỉnh).
void drawMarker(img.Image image, ui.Rect rect, {int gray = 20}) {
  final color = img.ColorRgb8(gray, gray, gray);
  img.fillRect(
    image,
    x1: rect.left.round(),
    y1: rect.top.round(),
    x2: rect.right.round() - 1,
    y2: rect.bottom.round() - 1,
    color: color,
  );
}

ui.Rect _markerRect(SheetLayout layout, MarkerPoint m, double side) {
  final c = layout.toPage(m.x, m.y);
  final s = side * layout.scale;
  return ui.Rect.fromCenter(center: c, width: s, height: s);
}

/// Vẽ toàn bộ 12 ô vuông mốc của template.
void drawMarkers(img.Image image, SheetLayout layout) {
  final template = layout.template;
  for (final m in template.cornerMarkers) {
    drawMarker(image, _markerRect(layout, m, template.markerSide - 2));
  }
  for (final m in template.extraMarkers) {
    drawMarker(image, _markerRect(layout, m, template.smallMarkerSide - 2));
  }
}

void _drawBubblesAndGlyphs(img.Image image, SheetLayout layout) {
  const letters = ['A', 'B', 'C', 'D', 'E'];

  void digitGrid(DigitGridGeometry grid) {
    for (var slot = 0; slot < grid.slots; slot++) {
      for (var value = 0; value < grid.rows; value++) {
        final cell = grid.cellRect(slot, value);
        drawBubble(image, cell, filled: false);
        drawGlyph(image, grid.center(slot, value), '$value',
            size: cell.width * 0.55);
      }
    }
  }

  digitGrid(layout.studentCodeGrid);
  digitGrid(layout.examCodeGrid);

  for (final block in layout.answerBlocks) {
    // Nhãn chữ lựa chọn nằm trên hàng bong bóng đầu tiên.
    for (var col = 0; col < block.columns; col++) {
      final c = block.center(0, col).translate(0, -block.rowPitch * 0.85);
      drawGlyph(image, c, letters[col], size: block.cellSize * 0.55);
    }
    for (var row = 0; row < block.rows; row++) {
      for (var col = 0; col < block.columns; col++) {
        drawBubble(image, block.cellRect(row, col), filled: false);
      }
      // Số câu nằm bên trái lựa chọn đầu tiên.
      final c = block.center(row, 0).translate(-block.colPitch * 0.95, 0);
      drawGlyphText(
        image,
        c,
        '${block.firstQuestionIndex + row + 1}',
        size: block.cellSize * 0.52,
      );
    }
  }
}

/// Sinh ảnh phiếu QUÉT (đối xứng với pipeline: mốc + bong bóng + chữ số).
/// Không có nhãn Unicode — bản in đầy đủ dùng [renderBlankSheet].
Uint8List renderScanSheet(SheetLayout layout) {
  final image = img.Image(
    width: layout.page.width.toInt(),
    height: layout.page.height.toInt(),
  );
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  drawMarkers(image, layout);
  _drawBubblesAndGlyphs(image, layout);
  return img.encodePng(image, level: 6);
}

// ---------------------------------------------------------------------------
// renderBlankSheet — bản in THẬT (dart:ui + font hệ thống) cho người dùng.
// ---------------------------------------------------------------------------

/// Sinh ảnh phiếu TRỐNG (mọi bong bóng đều chưa tô) để in ra giấy.
/// Chạy trên dart:ui (app/thiết bị); nhãn tiếng Việt dùng font hệ thống.
Future<Uint8List> renderBlankSheet(SheetLayout layout) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Offset.zero & layout.page);

  void paintWhite() => canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, layout.page.width, layout.page.height),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );

  paintWhite();
  _paintHeader(canvas, layout);
  _paintUiMarkers(canvas, layout);
  _paintUiBubbles(canvas, layout);

  final picture = recorder.endRecording();
  final image = picture.toImageSync(
    layout.page.width.toInt(),
    layout.page.height.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  if (byteData == null) {
    throw StateError('Không nén được PNG phiếu trống.');
  }
  return byteData.buffer.asUint8List();
}

void _paintHeader(ui.Canvas canvas, SheetLayout layout) {
  final s = layout.scale; // px trang / đơn vị template (≈ 0.5)

  void text(String content,
      {required ui.Offset center, required double fontSize, bool bold = true}) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: fontSize,
      fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
    ))..addText(content);
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    canvas.drawParagraph(
      paragraph,
      ui.Offset(
        center.dx - paragraph.width / 2,
        center.dy - paragraph.height / 2,
      ),
    );
  }

  // Toạ độ rel (khung mốc; âm = vùng đầu trang phía trên mốc TL).
  text('PHIẾU TRẢ LỜI TRÁC NGHIỆM',
      center: layout.toPage(1520, -448), fontSize: 60 * s);
  text('SỞ GD-ĐT', center: layout.toPage(240, -368), fontSize: 40 * s);
  text('TRƯỜNG THPT', center: layout.toPage(300, -296), fontSize: 40 * s);
  text('BÀI KIỂM TRA', center: layout.toPage(380, -224), fontSize: 40 * s);
  text('HỌ VÀ TÊN', center: layout.toPage(250, -150), fontSize: 40 * s);
  text('LỚP', center: layout.toPage(1770, -150), fontSize: 40 * s);

  void dashed(ui.Offset a, ui.Offset b) {
    final paint = ui.Paint()
      ..color = const ui.Color(0xFF555555)
      ..strokeWidth = 2.2 * s;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    var t = 0.0;
    while (t < 1.0) {
      final seg = math.min(0.02, 1.0 - t);
      canvas.drawLine(
        ui.Offset(a.dx + dx * t, a.dy + dy * t),
        ui.Offset(a.dx + dx * (t + seg), a.dy + dy * (t + seg)),
        paint,
      );
      t += 0.03;
    }
  }

  ui.Offset rel(double relX, double relY) => layout.toPage(relX, relY);
  dashed(rel(340, -368) , rel(1420, -368));
  dashed(rel(420, -296), rel(1420, -296));
  dashed(rel(520, -224), rel(1420, -224));
  dashed(rel(360, -150), rel(1200, -150));
  dashed(rel(1840, -150), rel(2380, -150));

  // "Lưu ý" — ghi chú nhỏ bên trái, TRÊN hàng mốc TL (rel âm hết).
  void note(String content, double relY) => text(content,
      center: layout.toPage(540, relY), fontSize: 26 * s, bold: false);
  note('Lưu ý: tô đen ô đáp án tương ứng với câu trong đề.', -113);
  note('Bài kiểm tra được chấm bằng máy, tô đậm vừa khít khung tròn.', -88);
  note('TUYỆT ĐỐI không được sửa chữa đáp án.', -63);

  // Ô "ĐIỂM SỐ" góc phải đầu trang (phía trên mốc TR).
  text('ĐIỂM SỐ', center: layout.toPage(2380, -238), fontSize: 40 * s);
  final scoreBox = ui.Rect.fromCenter(
    center: layout.toPage(2380, -110),
    width: 640 * s,
    height: 200 * s,
  );
  canvas.drawRect(
    scoreBox,
    ui.Paint()
      ..color = const ui.Color(0xFF222222)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3 * s,
  );

  // Nhãn lưới số (trên hàng mốc nhỏ thứ nhất).
  text('SỐ BÁO DANH', center: layout.toPage(542, 930), fontSize: 42 * s);
  text('MÃ ĐỀ', center: layout.toPage(1072, 930), fontSize: 42 * s);
}

void _paintUiMarkers(ui.Canvas canvas, SheetLayout layout) {
  final template = layout.template;
  final paint = ui.Paint()..color = const ui.Color(0xFF141414);
  void paints(MarkerPoint m, double side) {
    final rect = _markerRect(layout, m, side - 2);
    canvas.drawRect(rect, paint);
  }
  for (final m in template.cornerMarkers) {
    paints(m, template.markerSide);
  }
  for (final m in template.extraMarkers) {
    paints(m, template.smallMarkerSide);
  }
}

void _paintUiBubbles(ui.Canvas canvas, SheetLayout layout) {
  final ring = ui.Paint()
    ..color = const ui.Color(0xFF3A3A3A)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = math.max(1.0, layout.page.width * 0.0025);
  const letters = ['A', 'B', 'C', 'D', 'E'];

  void drawUiText(String content, ui.Offset center, double fontSize) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: fontSize, textAlign: ui.TextAlign.center),
    )..addText(content);
    final paragraph =
        builder.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
    canvas.drawParagraph(
      paragraph,
      ui.Offset(
        center.dx - paragraph.width / 2,
        center.dy - paragraph.height / 2,
      ),
    );
  }

  for (final grid in [layout.studentCodeGrid, layout.examCodeGrid]) {
    for (var slot = 0; slot < grid.slots; slot++) {
      for (var value = 0; value < grid.rows; value++) {
        final c = grid.center(slot, value);
        canvas.drawCircle(c, grid.cellSize * 0.42, ring);
        drawUiText('$value', c, grid.cellSize * 0.6);
      }
    }
  }

  for (final block in layout.answerBlocks) {
    for (var col = 0; col < block.columns; col++) {
      final c = block.center(0, col).translate(0, -block.rowPitch * 0.85);
      canvas.drawCircle(c, block.cellSize * 0.40, ring);
      drawUiText(letters[col], c, block.cellSize * 0.55);
    }
    for (var row = 0; row < block.rows; row++) {
      for (var col = 0; col < block.columns; col++) {
        final c = block.center(row, col);
        canvas.drawCircle(c, block.cellSize * 0.42, ring);
      }
      final q = block.firstQuestionIndex + row + 1;
      final c = block.center(row, 0).translate(-block.colPitch * 0.95, 0);
      drawUiText('$q', c, block.cellSize * 0.55);
    }
  }
}

// ---------------------------------------------------------------------------
// Phủ kết quả chấm lên ảnh phiếu đã căn phẳng.
// ---------------------------------------------------------------------------

/// Phủ kết quả chấm lên ảnh phiếu đã được căn phẳng (xám) → PNG có màu.
///
/// - Câu đúng: ô bong bóng tô xanh lá, câu sai: đỏ, câu trống: nhạt.
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
  ui.Rect scaled(ui.Rect r) => ui.Rect.fromLTRB(
        r.left * scaleX,
        r.top * scaleY,
        r.right * scaleX,
        r.bottom * scaleY,
      );
  void tint(ui.Rect cell, img.ColorRgb8 color, {int inset = 24}) {
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

  void grid(DigitGridGeometry g, String raw) {
    for (var slot = 0; slot < g.slots; slot++) {
      final parsed = slot < raw.length ? int.tryParse(raw[slot]) : null;
      final unreadable = slot < raw.length && raw[slot] == '?';
      if (parsed == null && !unreadable) continue;
      for (var value = 0; value < g.rows; value++) {
        final hit = parsed != null && parsed == value;
        if (parsed != null && !hit) continue;
        tint(
          g.cellRect(slot, value),
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
