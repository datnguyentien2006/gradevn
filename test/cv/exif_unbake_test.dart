// R18 — test hình học hoàn tác EXIF trên RGBA: mô hình 3×2 (a..f, mỗi pixel
// 4 byte — dùng byte đầu làm "tên"), đã chứng minh tay từng phép.
//
//   src (w=3, h=2):        tên pixel theo thứ tự lưới:
//     a b c
//     d e f
// Mỗi phép hoàn tác của bake EXIF phải RA ĐÚNG hình dạng như dưới.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:gradevn/data/cv/scan_flow.dart';

Uint8List _src() {
  // a..f — byte 0 = tên, byte 1..3 = đệm nhận diện (2,3 dành shim).
  const names = [0x61, 0x62, 0x63, 0x64, 0x65, 0x66]; // a b c d e f
  final out = Uint8List(6 * 4);
  for (var i = 0; i < 6; i++) {
    out[i * 4] = names[i];
    out[i * 4 + 1] = 0x02;
    out[i * 4 + 2] = 0x03;
    out[i * 4 + 3] = 0x04;
  }
  return out;
}

/// Đọc lưới TÊN (byte đầu mỗi pixel) của ảnh RGBA.
List<List<int>> _grid(Uint8List p, int w, int h) {
  return [
    for (var y = 0; y < h; y++) [for (var x = 0; x < w; x++) p[(y * w + x) * 4]],
  ];
}

void _expect(
  ({Uint8List rgba, int width, int height}) out,
  int w,
  int h,
  List<List<int>> grid,
) {
  expect(out.width, w, reason: 'w sai');
  expect(out.height, h, reason: 'h sai');
  expect(_grid(out.rgba, w, h), grid);
}

void main() {
  test('unbake EXIF 1 → nguyên bản', () {
    final out = unbakeExifRgbaForTest(_src(), 3, 2, 1);
    _expect(out, 3, 2, [
      [0x61, 0x62, 0x63],
      [0x64, 0x65, 0x66],
    ]);
  });

  test('unbake EXIF 2 (bake = mirrorH) → mirrorH', () {
    final out = unbakeExifRgbaForTest(_src(), 3, 2, 2);
    _expect(out, 3, 2, [
      [0x63, 0x62, 0x61],
      [0x66, 0x65, 0x64],
    ]);
  });

  test('unbake EXIF 3 (bake = rot180) → rot180', () {
    final out = unbakeExifRgbaForTest(_src(), 3, 2, 3);
    _expect(out, 3, 2, [
      [0x66, 0x65, 0x64],
      [0x63, 0x62, 0x61],
    ]);
  });

  test('unbake EXIF 4 (bake = mirrorV) → mirrorV', () {
    final out = unbakeExifRgbaForTest(_src(), 3, 2, 4);
    _expect(out, 3, 2, [
      [0x64, 0x65, 0x66],
      [0x61, 0x62, 0x63],
    ]);
  });

  test('unbake EXIF 5 (bake = transpose) → transpose', () {
    final out = unbakeExifRgbaForTest(_src(), 3, 2, 5);
    // transpose(w↔h): [a d / b e / c f]
    _expect(out, 2, 3, [
      [0x61, 0x64],
      [0x62, 0x65],
      [0x63, 0x66],
    ]);
  });

  test('unbake EXIF 6 (bake = rot90CW) → rot90CCW', () {
    final out = unbakeExifRgbaForTest(_src(), 3, 2, 6);
    // rot90CCW: [c f / b e / a d]
    _expect(out, 2, 3, [
      [0x63, 0x66],
      [0x62, 0x65],
      [0x61, 0x64],
    ]);
  });

  test('unbake EXIF 7 (bake = rot90CW(mirrorH)) → mirrorH(rot90CCW)', () {
    final out = unbakeExifRgbaForTest(_src(), 3, 2, 7);
    // rot90CCW(baked) = [c f / b e / a d]; mirrorH = [f c / e b / d a]
    _expect(out, 2, 3, [
      [0x66, 0x63],
      [0x65, 0x62],
      [0x64, 0x61],
    ]);
  });

  test('unbake EXIF 8 (bake = rot90CCW) → rot90CW', () {
    final out = unbakeExifRgbaForTest(_src(), 3, 2, 8);
    // rot90CW: [d a / e b / f c]
    _expect(out, 2, 3, [
      [0x64, 0x61],
      [0x65, 0x62],
      [0x66, 0x63],
    ]);
  });

  /// Chốt logic toàn diện: hoà cung ứng 2 lần lại cho thay một ảnh EXIF
  /// identity hoàn chỉnh (bake rồi hoàn tác = ảnh gốc).
  test('bake(rot6)+unbake(6) = ảnh gốc (hình chữ nhật 2×3)', () {
    // raw 2×3 (w=2,h=3): a b / c d / e f.
    // unbake 8 = rot90CW (raw đã "bake CCW") → rồi unbake 6 = rot90CCW về lại
    // raw — vòng idéal khép kín chứng minh phép quay 2 chiều khớp nhau.
    final raw = Uint8List(6 * 4);
    const names = [0x61, 0x62, 0x63, 0x64, 0x65, 0x66];
    for (var i = 0; i < 6; i++) {
      raw[i * 4] = names[i];
    }
    final baked = unbakeExifRgbaForTest(raw, 2, 3, 8);
    final restored = unbakeExifRgbaForTest(
      baked.rgba,
      baked.width,
      baked.height,
      6,
    );
    _expect(restored, 2, 3, [
      [0x61, 0x62],
      [0x63, 0x64],
      [0x65, 0x66],
    ]);
  });
}
