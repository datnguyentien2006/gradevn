// Kiểm thử bộ căn chỉnh ảnh chụp (M3): phát hiện khung → nắn phẳng → giải mã
// khớp kết quả fixture gốc. Đây là "bài thi" cho đường ảnh chụp thật.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/scan_service.dart';
import 'package:gradevn/data/cv/sheet_alignment.dart';
import 'package:gradevn/data/cv/sheet_painter.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/domain/services/sheet_layout.dart';
import 'package:image/image.dart' as img;

import '../fixtures/fixture_builder.dart';

const _photoSize = Size(1600, 2100);

final _standardSpec = SheetSpec(
  formType: SheetFormType.standard,
  orientation: SheetOrientation.portrait,
  questionCount: 40,
  answerChoices: 4,
  maxScore: 10,
);

/// Dựng "ảnh chụp tổng hợp": phiếu fixture nằm trong một tứ giác như [_quadFor]
/// giữa nền sáng, thêm bóng tối chéo + nhiễu hạt + mờ nhẹ (mô phỏng ảnh điện thoại).
Uint8List _distort(
  Uint8List fixturePng,
  AlignmentQuad targetQuad, {
  int speckleSeed = 7,
  double shadowFactor = 0.0,
}) {
  final src = img.decodeImage(fixturePng)!;
  final w = _photoSize.width.toInt();
  final h = _photoSize.height.toInt();
  final out = img.Image(width: w, height: h);
  img.fill(out, color: img.ColorRgb8(236, 234, 228)); // nền bàn sáng

  // Homography: HỘP KHUNG NGOÀI trên trang chuẩn → tứ giác trên ảnh chụp.
  // (Bộ dò sẽ phát hiện đúng hộp khung này trên ảnh chụp, nên cơ chế warp khớp
  // như thật.) Chiều dựng méo là chiều này; đọc ảnh bằng chiều ngược.
  final frame = const FrameSpec().outerRect(omrPageSize);
  final frameCorners = [
    Offset(frame.left, frame.top),
    Offset(frame.right, frame.top),
    Offset(frame.right, frame.bottom),
    Offset(frame.left, frame.bottom),
  ];
  final toPhoto = solveHomography(frameCorners, targetQuad.corners);
  final inv = solveHomography(targetQuad.corners, frameCorners);
  // Tự kiểm: hai chiều này phải gần đúng nghịch đảo của nhau ở tâm.
  final c = applyHomography(toPhoto, frame.center.dx, frame.center.dy);
  final back = applyHomography(inv, c.dx, c.dy);
  assert((back.dx - frame.center.dx).abs() < 0.5 && (back.dy - frame.center.dy).abs() < 0.5);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final s = applyHomography(inv, x.toDouble(), y.toDouble());
      if (s.dx < 0 || s.dy < 0 || s.dx >= src.width || s.dy >= src.height) {
        continue; // nền bàn giữ nguyên
      }
      final u = s.dx.clamp(0.0, (src.width - 1).toDouble());
      final v = s.dy.clamp(0.0, (src.height - 1).toDouble());
      final color = _bilinear(src, u, v);
      if (shadowFactor > 0) {
        // Bóng tối loang theo trục chéo (giả lập bóng tay / góc chụp).
        final k = 1.0 - shadowFactor * ((x + y) / (w + h));
        out.setPixelRgb(
          x,
          y,
          (color.r * k).round().clamp(0, 255),
          (color.g * k).round().clamp(0, 255),
          (color.b * k).round().clamp(0, 255),
        );
      } else {
        out.setPixelRgb(x, y, color.r, color.g, color.b);
      }
    }
  }

  // Nhiễu hạt (bụi / nhiễu cảm biến), tất định theo seed.
  final random = math.Random(speckleSeed);
  final total = (w * h * 0.0015).round();
  for (var i = 0; i < total; i++) {
    final x = random.nextInt(w);
    final y = random.nextInt(h);
    final v = 70 + random.nextInt(50);
    out.setPixelRgb(x, y, v, v, v);
  }
  img.gaussianBlur(out, radius: 1); // mờ nhẹ như ảnh chụp thật
  return img.encodePng(out, level: 3);
}

img.ColorRgb8 _bilinear(img.Image src, double u, double v) {
  final x0 = u.floor();
  final y0 = v.floor();
  final x1 = math.min(src.width - 1, x0 + 1);
  final y1 = math.min(src.height - 1, y0 + 1);
  final fx = u - x0;
  final fy = v - y0;
  final a = src.getPixel(x0, y0);
  final b = src.getPixel(x1, y0);
  final c = src.getPixel(x0, y1);
  final d = src.getPixel(x1, y1);
  int lerp(num v1, num v2, double t) => (v1 + (v2 - v1) * t).round();
  return img.ColorRgb8(
    lerp(lerp(a.r, b.r, fx), lerp(c.r, d.r, fx), fy),
    lerp(lerp(a.g, b.g, fx), lerp(c.g, d.g, fx), fy),
    lerp(lerp(a.b, b.b, fx), lerp(c.b, d.b, fx), fy),
  );
}

/// Tứ giác phiếu trên ảnh chụp: mỗi góc được nén/giãn theo tỉ lệ của mép mình
/// (mô phỏng góc nhìn nghiêng) và dịch thêm (tilt) cho biến thể rhombus.
AlignmentQuad _quadFor(
  Rect region, {
  double topScale = 1.0,
  double bottomScale = 1.0,
  double tiltX = 0.0,
  double tiltY = 0.0,
}) {
  final halfW = region.width / 2;
  final halfH = region.height / 2;
  Offset corner(double signX, double signY, double scale) => Offset(
        region.center.dx + signX * halfW * scale + tiltX * signX,
        region.center.dy + signY * halfH * scale + tiltY * signY,
      );
  return AlignmentQuad(
    corner(-1, -1, topScale),
    corner(1, -1, topScale),
    corner(1, 1, bottomScale),
    corner(-1, 1, bottomScale),
  );
}

void main() {
  // ensureFixtures() trả về đường dẫn PNG; đọc bytes để đưa vào pipeline.
  final paths = ensureFixtures();
  Uint8List fixtureBytes(String name) {
    final file = File(paths[name]!);
    return file.readAsBytesSync();
  }

  final fixtures = <String, Uint8List>{
    for (final name in paths.keys) name: fixtureBytes(name),
  };
  final service = const OmrScanService();

  group('FrameAlignmentDetector', () {
    test('tìm đúng 4 góc khung ở ảnh fixture thẳng', () {
      final png = fixtures['standard40']!;
      final quad = const FrameAlignmentDetector().detect(png);
      expect(quad, isNotNull);
      // Khung mép trang theo insetRatio = 0.017 của cạnh ngắn (1240).
      const inset = 1240 * 0.017;
      expect((quad!.tl.dx - inset).abs(), lessThan(10));
      expect((quad.tl.dy - inset).abs(), lessThan(10));
      expect((quad.br.dx - (1240 - inset)).abs(), lessThan(10));
      expect((quad.br.dy - (1754 - inset)).abs(), lessThan(10));
    });

    test('trả về null với ảnh không có khung', () {
      final image = img.Image(width: 400, height: 400);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.drawCircle(image, x: 200, y: 200, radius: 80, color: img.ColorRgb8(0, 0, 0));
      final encoded = img.encodePng(image);
      final quad = const FrameAlignmentDetector().detect(encoded);
      expect(quad, isNull);
    });
  });

  group('PerspectiveWarper', () {
    test('nắn ảnh thẳng về đúng kích thước trang chuẩn', () {
      final png = fixtures['standard40']!;
      final quad = const FrameAlignmentDetector().detect(png)!;
      final warped = const PerspectiveWarper().warpRectify(
        png,
        quad: quad,
        outputSize: omrPageSize,
      );
      final decoded = img.decodeImage(warped)!;
      expect(decoded.width, omrPageSize.width.toInt());
      expect(decoded.height, omrPageSize.height.toInt());
    });
  });

  group('scanPhoto — ảnh chụp méo vẫn giải mã như bản thẳng', () {
    // Phiếu chiếm ~85% vùng giữa của ảnh chụp.
    final photoRect = Rect.fromCenter(
      center: Offset(_photoSize.width / 2, _photoSize.height / 2),
      width: _photoSize.width * 0.85,
      height: _photoSize.height * 0.85,
    );

    for (final variant in const <(String, double, double, double, double)>[
      ('keystone: mép trên thu nhỏ', 0.94, 1.0, 0.0, 0.0),
      ('keystone: mép dưới thu nhỏ', 1.0, 0.95, 0.0, 0.0),
      ('nghiêng vòm nhẹ hai bên', 0.96, 0.96, 6.0, 0.0),
    ]) {
      final (label, topScale, bottomScale, tiltX, tiltY) = variant;
      test('biến thể $label khớp phiên bản thẳng', () {
        final png = fixtures['standard40']!;
        final quad = const FrameAlignmentDetector().detect(png)!;
        final straight = const PerspectiveWarper().warpRectify(
          png,
          quad: quad,
          outputSize: omrPageSize,
        );
        final straightScan = service.scan(
          straight,
          layout: SheetLayout.forSpec(_standardSpec, page: omrPageSize),
          spec: _standardSpec,
        );
        final distortedQuad = _quadFor(
          photoRect,
          topScale: topScale,
          bottomScale: bottomScale,
          tiltX: tiltX,
        );
        final photo = _distort(straight, distortedQuad, shadowFactor: 0.18);
        final result = service.scanPhoto(photo, spec: _standardSpec);
        expect(result, isNotNull, reason: 'không tìm thấy khung trên ảnh "$label"');
        expect(result!.scan.answers, straightScan.answers);
        expect(result.scan.studentCode, straightScan.studentCode);
        expect(result.scan.examCode, straightScan.examCode);
      });
    }

    test('cả 3 fixture méo + bóng tối: decode khớp JSON expected', () {
      for (final entry in fixtures.entries) {
        final name = entry.key;
        final expected = readExpectedJson(name);
        final spec = SheetSpec(
          formType: SheetFormType.values
              .firstWhere((f) => f.name == expected['spec']['formType']),
          orientation: SheetOrientation.values
              .firstWhere((o) => o.name == expected['spec']['orientation']),
          questionCount: expected['spec']['questionCount'] as int,
          answerChoices: expected['spec']['answerChoices'] as int,
          maxScore: (expected['spec']['maxScore'] as num).toDouble(),
          partOneCount: expected['spec']['partOneCount'] as int?,
          partTwoCount: expected['spec']['partTwoCount'] as int?,
          partThreeCount: expected['spec']['partThreeCount'] as int?,
          partOneWeight: (expected['spec']['partOneWeight'] as num?)?.toDouble(),
          partTwoWeight: (expected['spec']['partTwoWeight'] as num?)?.toDouble(),
          partThreeWeight: (expected['spec']['partThreeWeight'] as num?)?.toDouble(),
        );
        final photoRectMild = Rect.fromCenter(
          center: Offset(_photoSize.width / 2, _photoSize.height / 2),
          width: _photoSize.width * 0.9,
          height: _photoSize.height * 0.9,
        );
        final quad = _quadFor(photoRectMild, topScale: 0.95);
        final photo = _distort(entry.value, quad, speckleSeed: 3, shadowFactor: 0.15);
        final result = service.scanPhoto(photo, spec: spec);
        expect(result, isNotNull, reason: 'fixture $name: không tìm thấy khung');
        expect(result!.scan.studentCodeRaw, expected['studentCodeRaw'],
            reason: 'fixture $name: lưới SBD lệch');
        expect(result.scan.examCodeRaw, expected['examCodeRaw'],
            reason: 'fixture $name: lưới mã đề lệch');
        final raw = expected['answers'] as List;
        for (var q = 0; q < raw.length; q++) {
          final wanted = raw[q];
          expect(
            result.scan.answers[q],
            wanted == null ? null : (wanted as String).toUpperCase(),
            reason: 'fixture $name câu ${q + 1} lệch',
          );
        }
      }
    });
  });

  group('renderBlankSheet / renderMarkedSheet', () {
    test('phiếu trống: không í câu nào được đọc là đã tô', () {
      final layout = SheetLayout.forSpec(_standardSpec, page: omrPageSize);
      final blank = renderBlankSheet(layout);
      final scan = service.scan(blank, layout: layout);
      expect(scan.answers, everyElement(isNull));
      // Lưới SBD/mã đề trống: mọi chữ số không đọc được ('?').
      expect(scan.studentCodeRaw, '??????');
      expect(scan.examCodeRaw, '??????');
    });

    test('renderMarkedSheet: ảnh có màu, có ô đúng (xanh lá) + ô chữ số (xanh dương)', () {
      final layout = SheetLayout.forSpec(_standardSpec, page: omrPageSize);
      final png = fixtures['standard40']!;
      final quad = const FrameAlignmentDetector().detect(png)!;
      final warped = const PerspectiveWarper().warpRectify(png, quad: quad, outputSize: omrPageSize);
      final scan = service.scan(warped, layout: layout);
      final flags = [for (var i = 0; i < scan.answers.length; i++) scan.answers[i] != null];
      final marked = renderMarkedSheet(
        warpedGrayBytes: warped,
        layout: layout,
        correctFlags: flags,
        studentCodeRaw: scan.studentCodeRaw,
        examCodeRaw: scan.examCodeRaw,
      );
      final image = img.decodeImage(marked)!;
      expect(image.width, omrPageSize.width.toInt());
      var hasGreen = false;
      var hasBlue = false;
      for (var y = 0; y < image.height && (!hasGreen || !hasBlue); y += 5) {
        for (var x = 0; x < image.width && (!hasGreen || !hasBlue); x += 5) {
          final p = image.getPixel(x, y);
          if (p.g > 120 && p.r < p.g - 20 && p.b < p.g - 20) hasGreen = true;
          if (p.b > 100 && p.r < p.b - 20 && p.g < p.b) hasBlue = true;
        }
      }
      expect(hasGreen, isTrue, reason: 'chưa có ô "đúng" tô xanh');
      expect(hasBlue, isTrue, reason: 'chưa có ô chữ số tô xanh');
    });
  });
}
