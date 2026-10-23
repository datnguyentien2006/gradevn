// R3 — KIỂM CHỨNG MỐC ROUND-TRIP + chống false-positive (bằng chứng
// detector chọn ĐÚNG 4 ô vuông góc, không phải bong bóng/chữ số/nền tối).
//
// ignore_for_file: avoid_print — benchmark in thống kê như omr_pipeline_test.
// Nội dung:
//  * verifyWarpedMarkers trên trang chuẩn fixture → passed, sai lệch ≤ 3 px.
//  * scanPhoto trả kèm [WarmedMarkerCheck] rồi check passed (đường ống thật).
//  * Mốc lệch 15 px trang chuẩn → passed=false (bắt phiếu nắn lệch).
//  * Phiếu TÔ ĐẦY bong bóng + lưới số: quad VẪN là 4 mốc góc — bong bóng
//    (blob tròn đặc) có thể vào candidates nhưng không thể đổi chỗ 4 góc.
//  * Chữ số/chữ in mảnh (viền rỗng, fill thấp) không trở thành candidate.
//  * Ô vuông xoay ±30° từng mốc: vẫn nhận, tâm đúng.
//  * Dải nền bàn tối lớn (desk) không lọt candidate (lọc maxSide).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/scan_service.dart';
import 'package:gradevn/data/cv/sheet_alignment.dart';
import 'package:gradevn/domain/services/sheet_layout.dart';
import 'package:image/image.dart' as img;

import '../fixtures/fixture_builder.dart';

void main() {
  setUpAll(ensureFixtures);

  final fixture = standardFixture();
  final layout = fixture.layout; // page = SheetLayout.standardPage
  final cornerCenters = layout.cornerMarkerCenters;

  test('round-trip trang chuẩn: fixture thẳng đã ở vị trí chuẩn → passed', () {
    final bytes = renderFixture(fixture);
    final check = verifyWarpedMarkers(bytes, layout: layout);
    expect(check.passed, isTrue,
        reason: 'sai lệch từng góc: ${check.offsets}');
    expect(check.maxOffset, lessThan(3.0));
  });

  test('scanPhoto đường ống thật trả check + passed (trang chuẩn)', () {
    final scan = const OmrScanService().scanPhoto(
      renderFixture(fixture),
      spec: fixture.spec,
    );
    expect(scan, isNotNull);
    expect(scan!.verification, isNotNull);
    expect(scan.verification!.passed, isTrue,
        reason: '${scan.verification!.offsets}');
    // Phải giữ ứng viên đ detector cho bằng chứng debug.
    expect(scan.detectedCandidates, isNotEmpty);
  });

  test('mốc lệch 15 px trang chuẩn → kiểm chứng TỪ CHỐI (rơi CropReview)', () {
    final image = _displacedMarkersPage(layout, shift: 15);
    final check = verifyWarpedMarkers(
      Uint8List.fromList(img.encodePng(image, level: 3)),
      layout: layout,
    );
    expect(check.passed, isFalse);
    expect(check.maxOffset, greaterThan(10.0));
  });

  test('PHIẾU TÔ ĐẦY bong bóng + lưới số: 4 mốc góc không bị đè lựa chọn', () {
    final image = img.decodePng(renderFixture(fixture))!;
    // Tô ĐẦY MỌI bong bóng (A..D × 40 câu) + vớt cả lưới SBD/mã đề mọi hàng.
    for (final block in layout.answerBlocks) {
      for (var row = 0; row < block.rows; row++) {
        for (var col = 0; col < block.columns; col++) {
          _fillCircle(image, block.center(row, col), block.cellSize / 2);
        }
      }
    }
    for (var v = 0; v < 10; v++) {
      for (var slot = 0; slot < layout.studentCodeGrid.slots; slot++) {
        _fillCircle(
            image, layout.studentCodeGrid.center(slot, v), layout.studentCodeGrid.cellSize / 2);
      }
      for (var slot = 0; slot < layout.examCodeGrid.slots; slot++) {
        _fillCircle(
            image, layout.examCodeGrid.center(slot, v), layout.examCodeGrid.cellSize / 2);
      }
    }
    final bytes = Uint8List.fromList(img.encodePng(image, level: 3));
    final detection =
        const SheetMarkerDetector().detect(bytes, template: layout.template);
    expect(detection.quad, isNotNull,
        reason: '4 mốc góc vẫn phải thắng bầu chọn dù hàng trăm bong bóng tô');
    final quad = detection.quad!;
    // Mỗi góc của quad phải trùng mốc chuẩn trong ~6 px trang chuẩn.
    for (var i = 0; i < 4; i++) {
      final d = (quad.corners[i] - cornerCenters[i]).distance;
      expect(d, lessThan(6.0), reason: 'góc $i lệch $d px');
    }
  });

  test('chữ số/chữ in mảnh (viền rỗng) không lọt candidate', () {
    final image = _letterNoisePage(layout);
    final detection =
        const SheetMarkerDetector().detect(Uint8List.fromList(img.encodePng(image, level: 3)));
    expect(detection.candidates, isEmpty,
        reason: 'viền mảnh fill thấp phải bị lọc fill ≥ 0.5');
    expect(detection.quad, isNull);
  });

  for (final angle in [-30.0, 30.0]) {
    test('ô mốc XOAY $angle° từng góc: vẫn nhận, tâm đúng', () {
      final image = _rotatedMarkersPage(layout, angle: angle * math.pi / 180);
      final detection =
          const SheetMarkerDetector().detect(Uint8List.fromList(img.encodePng(image, level: 3)));
      expect(detection.quad, isNotNull, reason: 'ô xoay tới ±30° vẫn phải qua lọc');
      final quad = detection.quad!;
      for (var i = 0; i < 4; i++) {
        final d = (quad.corners[i] - cornerCenters[i]).distance;
        expect(d, lessThan(6.0), reason: 'góc $i lệch $d px');
      }
    });
  }

  test('dải nền bàn tối lớn (desk) không lọt candidate', () {
    final image = _deskBandPage(layout);
    final detection =
        const SheetMarkerDetector().detect(Uint8List.fromList(img.encodePng(image, level: 3)));
    expect(detection.quad, isNotNull);
    // Cản: không candidate nào có tâm trong dải tối bên phải.
    final bandX = image.width - 120.0;
    for (final c in detection.candidates) {
      expect(c.dx, lessThan(bandX),
          reason: 'candidate ${c.dx.toStringAsFixed(0)},${c.dy.toStringAsFixed(0)} rơi vào dải nền tối');
    }
  });

  test('Benchmark kiểm chứng round-trip (để ghi PROJECT_NOTES)', () {
    final bytes = renderFixture(fixture);
    // Đo 5 lần, lấy trung vị — ổn định hơn giữa-nội bộ máy CI.
    final samples = <double>[];
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      final check = verifyWarpedMarkers(bytes, layout: layout);
      sw.stop();
      expect(check.passed, isTrue);
      samples.add(sw.elapsedMicroseconds / 1000.0);
    }
    samples.sort();
    print('Benchmark verifyWarpedMarkers (trang chuẩn): '
        '${samples[0].toStringAsFixed(1)} / ${samples[2].toStringAsFixed(1)} / '
        '${samples[4].toStringAsFixed(1)} ms — trung vị ${samples[2].toStringAsFixed(1)} ms');
  });
}

// ---------------------------------------------------------------------------
// Trang canvas chuẩn + vẽ mốc/bong bóng/chữ số tổng hợp
// ---------------------------------------------------------------------------

/// Trang trắng chuẩn với 4 mốc góc BỊ DỊCH [shift] px so với vị trí chuẩn
/// (mô phỏng warp nhắm/n_INTERNAL pin lệch) — kiểm chứng phải từ chối.
img.Image _displacedMarkersPage(SheetLayout layout, {required double shift}) {
  final image = img.Image(width: layout.page.width.toInt(), height: layout.page.height.toInt());
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final side = layout.template.markerSide * layout.scale;
  for (final c in layout.cornerMarkerCenters) {
    final dx = c.dx + (c.dx < layout.page.width / 2 ? -shift : shift);
    final dy = c.dy + (c.dy < layout.page.height / 2 ? -shift : shift);
    _fillCircleRect(image, Offset(dx, dy), side);
  }
  return image;
}

/// Trang trắng + các "chữ" in mảnh (hộp viền rỗng) — fill thấp, không đặc.
img.Image _letterNoisePage(SheetLayout layout) {
  final image = img.Image(width: layout.page.width.toInt(), height: layout.page.height.toInt());
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final paint = img.ColorRgb8(20, 20, 20);
  for (var y1 = 200; y1 < image.height - 200; y1 += 140) {
    for (var x1 = 200; x1 < image.width - 200; x1 += 160) {
      final w = 34;
      final h = 46;
      img.drawRect(
        image,
        x1: x1, y1: y1, x2: x1 + w, y2: y1 + h,
        thickness: 6,
        color: paint,
      );
    }
  }
  return image;
}

/// Trang trắng + 4 mốc góc ĐƯỢC XOAY [angle] quanh TÂM TỪNG Ô (±30° hợp lệ
/// theo lọc bbox/fill của detector).
img.Image _rotatedMarkersPage(SheetLayout layout, {required double angle}) {
  final image = img.Image(width: layout.page.width.toInt(), height: layout.page.height.toInt());
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final side = layout.template.markerSide * layout.scale;
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  for (final c in layout.cornerMarkerCenters) {
    final corners = <Offset>[];
    for (final (sx, sy) in [(0, 0), (0, 1), (1, 1), (1, 0)]) {
      final px = (sx - 0.5) * side;
      final py = (sy - 0.5) * side;
      corners.add(Offset(
        c.dx + px * cos - py * sin,
        c.dy + px * sin + py * cos,
      ));
    }
    _fillQuad(image, corners);
  }
  return image;
}

/// Trang trắng + 4 mốc góc + DẢI NỀN TỐI lớn bên phải (mô phỏng mặt bàn tối).
img.Image _deskBandPage(SheetLayout layout) {
  final image = img.Image(width: layout.page.width.toInt(), height: layout.page.height.toInt());
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  // Dải tối: gần như toàn khối — bbox vượt maxSide nên không được nhận.
  img.fillRect(
    image,
    x1: image.width - 100, y1: 0, x2: image.width - 1, y2: image.height - 1,
    color: img.ColorRgb8(40, 40, 40),
  );
  final side = layout.template.markerSide * layout.scale;
  for (final c in layout.cornerMarkerCenters) {
    _fillCircleRect(image, c, side);
  }
  return image;
}

/// Cạnh ô mốc: hình vuông đặc (bbox = [side]).
void _fillCircleRect(img.Image image, Offset center, double side) {
  final half = (side / 2).floor();
  img.fillRect(
    image,
    x1: (center.dx - half).floor(), y1: (center.dy - half).floor(),
    x2: (center.dx + half).floor(), y2: (center.dy + half).floor(),
    color: img.ColorRgb8(15, 15, 15),
  );
}

/// Bong bóng đặc (mô phỏng tô đậm): đĩa tròn radius.
void _fillCircle(img.Image image, Offset center, double radius) {
  final r = radius.toInt();
  for (var dy = -r; dy <= r; dy++) {
    final w = (math.sqrt(math.max(0, r * r - dy * dy))).floor();
    final y = (center.dy + dy).toInt();
    if (y < 0 || y >= image.height) continue;
    final x0 = (center.dx - w).clamp(0, image.width - 1).toInt();
    final x1 = (center.dx + w).clamp(0, image.width - 1).toInt();
    for (var x = x0; x <= x1; x++) {
      image.setPixelRgb(x, y, 15, 15, 15);
    }
  }
}

/// Fill tứ giác lồi bất kỳ (ô vuông xoay) bằng rasterize theo dòng.
void _fillQuad(img.Image image, List<Offset> poly) {
  var minY = double.infinity;
  var maxY = -double.infinity;
  for (final p in poly) {
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  final y0 = minY.floor().clamp(0, image.height - 1);
  final y1 = maxY.ceil().clamp(0, image.height - 1);
  for (var y = y0; y <= y1; y++) {
    // Giao đoạn ngang cấp y với các cạnh của tứ giác.
    var xMin = double.infinity;
    var xMax = -double.infinity;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      if ((a.dy <= y && b.dy > y) || (b.dy <= y && a.dy > y)) {
        final t = (y - a.dy) / (b.dy - a.dy);
        final x = a.dx + t * (b.dx - a.dx);
        if (x < xMin) xMin = x;
        if (x > xMax) xMax = x;
      }
    }
    if (xMax < xMin) continue;
    final xa = xMin.floor().clamp(0, image.width - 1);
    final xb = xMax.ceil().clamp(0, image.width - 1);
    for (var x = xa; x <= xb; x++) {
      image.setPixelRgb(x, y, 15, 15, 15);
    }
  }
}
