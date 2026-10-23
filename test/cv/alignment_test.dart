// Test phát hiện 4 MỐC Ô VUÔNG + warp homography (R1).
//
// Fixture được biến dạng bằng phép affine (xoay ±30°, chếch/shear, thu phóng,
// chèn nền trắng lớn = phiếu không chiếm trọn khung, bóng đổ) rồi chạy
// TRỌN pipeline scanPhoto: detect mốc → warp → đo mật độ → giải mã.
// Ảnh đích của mọi phép biến dạng đều có đủ 4 mốc góc nguyên vẹn.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/scan_service.dart';
import 'package:gradevn/data/cv/sheet_alignment.dart';
import 'package:image/image.dart' as img;

import '../fixtures/fixture_builder.dart';

void main() {
  setUpAll(ensureFixtures);

  final fixtureBytes =
      File('test/fixtures/generated/standard40.png').readAsBytesSync();

  test('detector thuần: fixture thẳng tìm đủ ≥ 4 ứng viên và một quad', () {
    final detection = const SheetMarkerDetector().detect(fixtureBytes);
    expect(detection.candidates.length, greaterThanOrEqualTo(4));
    expect(detection.quad, isNotNull);
  });

  test('detector: ảnh trắng (không mốc) → quad null', () {
    final blank = img.Image(width: 900, height: 1200);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));
    final detection =
        const SheetMarkerDetector().detect(Uint8List.fromList(img.encodePng(blank)));
    expect(detection.quad, isNull);
  });

  test('detectGray: 4 ô vuông đen ở góc + vòng đen rỗng nhiễu → đủ quad', () {
    const squareSide = 40;
    const centers = [
      Offset(60, 60),
      Offset(740, 60),
      Offset(740, 1120),
      Offset(60, 1120),
    ];
    final gray = _syntheticGray(
      width: 800,
      height: 1180,
      squareSide: squareSide,
      squares: centers,
      rings: const [Offset(400, 300), Offset(400, 900)],
    );
    final detection =
        const SheetMarkerDetector().detectGray(gray, width: 800, height: 1180);
    expect(detection.quad, isNotNull, reason: 'Thấy đủ 4 ô vuông đặc ở 4 góc');
    final quad = detection.quad!;
    expect(quad.tl.dx, closeTo(60, 12));
    expect(quad.tl.dy, closeTo(60, 12));
    expect(quad.br.dx, closeTo(740, 12));
    expect(quad.br.dy, closeTo(1120, 12));
  });

  test('detectGray: ảnh nhiễu không có ô vuông → quad null', () {
    final gray = _syntheticGray(
      width: 800,
      height: 600,
      squareSide: 40,
      squares: const [],
      rings: const [Offset(200, 200), Offset(600, 400), Offset(400, 100)],
    );
    final detection =
        const SheetMarkerDetector().detectGray(gray, width: 800, height: 600);
    expect(detection.quad, isNull);
  });

  test('detectGray chia sẻ lõi với detect: quad trùng nhau trên fixture', () {
    final gray = _grayFromPng(fixtureBytes);
    final det = const SheetMarkerDetector().detect(fixtureBytes);
    final detGray = const SheetMarkerDetector()
        .detectGray(gray.data, width: gray.width, height: gray.height);
    if (det.quad == null) {
      expect(detGray.quad, isNull);
      return;
    }
    expect(detGray.quad, isNotNull, reason: 'Hai ngõ vào phải cùng cho kết quả');
    expect(detGray.quad!.tl.dx, closeTo(det.quad!.tl.dx, 2.0));
    expect(detGray.quad!.tr.dx, closeTo(det.quad!.tr.dx, 2.0));
    expect(detGray.quad!.br.dy, closeTo(det.quad!.br.dy, 2.0));
    expect(detGray.quad!.bl.dy, closeTo(det.quad!.bl.dy, 2.0));
  });

  test('warp nhận dạng: quad = tâm mốc chuẩn → đo/giải mã đúng fixture', () {
    final detection = const SheetMarkerDetector().detect(fixtureBytes);
    final quad = detection.quad!;
    // Fixture phóng ×2: tâm mốc tìm được phải đúng tỉ lệ ×2.
    final big = _distort(fixtureBytes, angleRad: 0, scale: 2.0);
    final det2 = const SheetMarkerDetector().detect(big);
    expect(det2.quad, isNotNull);
    final quad2 = det2.quad!;
    expect(quad2.tl.dx, closeTo(quad.tl.dx * 2, 4));
    expect(quad2.br.dy, closeTo(quad.br.dy * 2, 4));
  });

  for (final angle in [-30.0, 30.0]) {
    test('xoay $angle°: phát hiện mốc + nắn phẳng + giải mã đúng', () {
      final bytes = _distort(
        fixtureBytes,
        angleRad: angle * math.pi / 180,
        scale: 1.6,
      );
      final scan = const OmrScanService().scanPhoto(
        bytes,
        spec: standardFixture().spec,
      );
      expect(scan, isNotNull, reason: 'Phải tìm đủ 4 mốc ở ảnh xoay $angle°');
      expect(scan!.scan.answers, standardFixture().answers);
      expect(scan.scan.studentCode, '413');
      expect(scan.scan.examCode, '1');
    });
  }

  test('chụp chếch (xoay 12° + shear): vẫn giải mã đúng', () {
    final bytes = _distort(
      fixtureBytes,
      angleRad: 12 * math.pi / 180,
      scale: 1.2,
      shearX: 0.22,
      shearY: 0.10,
    );
    final scan =
        const OmrScanService().scanPhoto(bytes, spec: standardFixture().spec);
    expect(scan, isNotNull);
    expect(scan!.scan.answers, standardFixture().answers);
  });

  test('phiếu KHÔNG chiếm trọn khung (nền trắng quanh phiếu): vẫn đúng', () {
    final tilted = _distort(
      fixtureBytes,
      angleRad: -8 * math.pi / 180,
      scale: 1.0,
    );
    final padded = _padWhite(tilted, ratioX: 0.35, ratioY: 0.25, shiftX: 0.1, shiftY: 0.07);
    final scan =
        const OmrScanService().scanPhoto(padded, spec: standardFixture().spec);
    expect(scan, isNotNull);
    expect(scan!.scan.answers, standardFixture().answers);
  });

  test('bóng đổ/che khuất một phần (gradient đậm + dải tối): vẫn đúng', () {
    final bytes = _distort(
      fixtureBytes,
      angleRad: 5 * math.pi / 180,
      scale: 1.1,
      darkBand: true,
    );
    final scan =
        const OmrScanService().scanPhoto(bytes, spec: standardFixture().spec);
    expect(scan, isNotNull);
    expect(scan!.scan.answers, standardFixture().answers);
  });

  test('cắt mất mốc (thiếu mốc tin cậy) → null để rơi về CropReview', () {
    final bytes = _distort(
      fixtureBytes,
      angleRad: 0,
      scale: 1.2,
    );
    // Cắt 45% chiều cao từ dưới lên: cột mốc dưới (y≈66% trang) và các khối
    // đáp án phần dưới bị bỏ hẳn khỏi khung hình → 2 phần tư dưới trống
    // ứng viên → không đủ 4 mốc tin cậy.
    final image = img.decodePng(bytes)!;
    final cropped = img.copyCrop(
      image,
      x: 0,
      y: (image.height * 0.55).round(),
      width: image.width,
      height: (image.height * 0.45).round(),
    );
    final scan = const OmrScanService().scanPhoto(
      Uint8List.fromList(img.encodePng(cropped)),
      spec: standardFixture().spec,
    );
    expect(scan, isNull);
  });
}

// ---------------------------------------------------------------------------
// Helper biến dạng affine thuần Dart (dst→src resample bilinear).
// ---------------------------------------------------------------------------

/// Sinh ảnh "chụp" từ fixture: xoay [angleRad] + thu phóng [scale] + shear
/// (mô phỏng chụp chếch), có thể phủ dải tối mô phỏng bóng đổ.
Uint8List _distort(
  Uint8List fixturePng, {
  required double angleRad,
  required double scale,
  double shearX = 0,
  double shearY = 0,
  bool darkBand = false,
}) {
  final src = img.decodePng(fixturePng)!;
  final w = src.width.toDouble();
  final h = src.height.toDouble();

  // M = R(θ) · Sh · s (page → photo).
  final cos = math.cos(angleRad), sin = math.sin(angleRad);
  final m00 = scale * (cos - shearY * sin);
  final m01 = scale * (cos * shearX - sin);
  final m10 = scale * (sin + shearY * cos);
  final m11 = scale * (sin * shearX + cos);

  // 4 góc page qua M để tính bbox ảnh chụp.
  final corners = [
    [0.0, 0.0],
    [w, 0.0],
    [0.0, h],
    [w, h],
  ].map((c) {
    final x = m00 * c[0] + m01 * c[1];
    final y = m10 * c[0] + m11 * c[1];
    return [x, y];
  }).toList();
  final minX = corners.fold<double>(0, (m, c) => math.min(m, c[0]));
  final minY = corners.fold<double>(0, (m, c) => math.min(m, c[1]));
  final maxX = corners.fold<double>(0, (m, c) => math.max(m, c[0]));
  final maxY = corners.fold<double>(0, (m, c) => math.max(m, c[1]));

  final outW = (maxX - minX).ceil();
  final outH = (maxY - minY).ceil();
  final tx = -minX;
  final ty = -minY;

  return _resample(
    fixturePng,
    // dst→src: p_src = M⁻¹ (p_dst − t)
    [m00, m01, m10, m11, tx, ty],
    outW,
    outH,
  )._applyShade(darkBand);
}

/// Nhồi ảnh vào canvas trắng lớn hơn (phiếu không chiếm trọn khung).
Uint8List _padWhite(
  Uint8List png, {
  required double ratioX,
  required double ratioY,
  required double shiftX,
  required double shiftY,
}) {
  final image = img.decodePng(png)!;
  final w = (image.width * (1 + ratioX)).round();
  final h = (image.height * (1 + ratioY)).round();
  final canvas = img.Image(width: w, height: h);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(
    canvas,
    image,
    dstX: (image.width * shiftX).round(),
    dstY: (image.height * shiftY).round(),
  );
  return Uint8List.fromList(img.encodePng(canvas, level: 3));
}

/// Resample bilinear dst→src với ma trận [a b; c d] + dịch (e,f).
Uint8List _resample(
  Uint8List png,
  List<double> matrix,
  int outW,
  int outH,
) {
  final src = img.decodePng(png)!;
  final w = src.width;
  final h = src.height;
  final a = matrix[0], m01 = matrix[1], m10 = matrix[2], d = matrix[3];
  final e = matrix[4], f = matrix[5];
  final det = a * d - m01 * m10;
  final i00 = d / det, i01 = -m01 / det, i10 = -m10 / det, i11 = a / det;

  final out = img.Image(width: outW, height: outH);
  for (var y = 0; y < outH; y++) {
    for (var x = 0; x < outW; x++) {
      final rx = i00 * x + i01 * y - (i00 * e + i01 * f);
      final ry = i10 * x + i11 * y - (i10 * e + i11 * f);
      if (rx < -1 || ry < -1 || rx > w || ry > h) {
        out.setPixelRgb(x, y, 255, 255, 255);
        continue;
      }
      final c = _bilinear(src, rx, ry);
      out.setPixelRgb(x, y, c[0], c[1], c[2]);
    }
  }
  return Uint8List.fromList(img.encodePng(out, level: 3));
}

List<int> _bilinear(img.Image image, double x, double y) {
  final x0 = x.floor().clamp(-1, image.width - 1);
  final y0 = y.floor().clamp(-1, image.height - 1);
  final x1 = x0 + 1, y1 = y0 + 1;
  final fx = (x - x0).clamp(0.0, 1.0);
  final fy = (y - y0).clamp(0.0, 1.0);
  int ch(int px, int py, int channel) {
    if (px < 0 || py < 0 || px >= image.width || py >= image.height) {
      return 255;
    }
    final p = image.getPixel(px, py);
    return switch (channel) {
      0 => p.r.toInt(),
      1 => p.g.toInt(),
      _ => p.b.toInt(),
    };
  }

  final out = <int>[];
  for (var chn = 0; chn < 3; chn++) {
    final top = ch(x0, y0, chn) + (ch(x1, y0, chn) - ch(x0, y0, chn)) * fx;
    final bottom = ch(x0, y1, chn) + (ch(x1, y1, chn) - ch(x0, y1, chn)) * fx;
    out.add((top + (bottom - top) * fy).round().clamp(0, 255));
  }
  return out;
}

/// Ảnh xám thuần (mỗi pixel 1 byte) + kích thước — đầu vào của [detectGray].
final class GrayImage {
  const GrayImage(this.data, this.width, this.height);

  final Uint8List data;
  final int width;
  final int height;
}

/// Đổi PNG bất kỳ → ảnh xám thuần (công thức luminance trùng detector).
GrayImage _grayFromPng(Uint8List pngBytes) {
  final decoded = img.decodeImage(pngBytes)!;
  final width = decoded.width;
  final height = decoded.height;
  final bytes = decoded.getBytes();
  final channels = decoded.numChannels;
  final data = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final idx = (y * width + x) * channels;
      final r = bytes[idx];
      final hasRgb = channels >= 3 && idx + 2 < bytes.length;
      final g = hasRgb ? bytes[idx + 1] : r;
      final b = hasRgb ? bytes[idx + 2] : r;
      data[y * width + x] = (r * 299 + g * 587 + b * 114) ~/ 1000;
    }
  }
  return GrayImage(data, width, height);
}

/// Ảnh xám tổng hợp: nền trắng + các ô vuông đen (mốc) + các vòng đen rỗng
/// (nhiễu chữ/bong bóng — lọc theo tỉ lệ lấp đầy phải loại chúng).
Uint8List _syntheticGray({
  required int width,
  required int height,
  required int squareSide,
  required List<Offset> squares,
  required List<Offset> rings,
  int ringRadius = 22,
}) {
  final data = Uint8List(width * height);
  data.fillRange(0, data.length, 255);
  void fillRect(double cx, double cy, int side, int value) {
    final half = side ~/ 2;
    final x0 = (cx - half).floor().clamp(0, width - 1);
    final x1 = (cx + half).floor().clamp(0, width - 1);
    final y0 = (cy - half).floor().clamp(0, height - 1);
    final y1 = (cy + half).floor().clamp(0, height - 1);
    for (var y = y0; y <= y1; y++) {
      data.fillRange(y * width + x0, y * width + x1 + 1, value);
    }
  }

  for (final s in squares) {
    fillRect(s.dx, s.dy, squareSide, 20);
  }
  // Vòng: đậm ở vành, trắng ở ruột — không đủ "đặc" để lọt qua lọc.
  for (final r in rings) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final d = (x - r.dx) * (x - r.dx) + (y - r.dy) * (y - r.dy);
        if (d <= ringRadius * ringRadius &&
            d >= (ringRadius - 6) * (ringRadius - 6)) {
          data[y * width + x] = 30;
        }
      }
    }
  }
  return data;
}

extension _Shade on Uint8List {
  Uint8List _applyShade(bool darkBand) {
    if (!darkBand) return this;
    final image = img.decodePng(this)!;
    final w = image.width;
    final h = image.height;
    // Dải tối lớn phủ nửa phải dưới (mô phỏng bóng tay/đồ vật che).
    for (var y = (h * 0.35).round(); y < h; y++) {
      for (var x = (w * 0.45).round(); x < w; x++) {
        final p = image.getPixel(x, y);
        image.setPixelRgb(
          x,
          y,
          (p.r * 0.45).round().clamp(0, 255),
          (p.g * 0.45).round().clamp(0, 255),
          (p.b * 0.45).round().clamp(0, 255),
        );
      }
    }
    return Uint8List.fromList(img.encodePng(image, level: 3));
  }
}
