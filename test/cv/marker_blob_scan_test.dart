// R7 (2026-10-25): kiểm thử module quét mốc dùng chung (chụp + LIVE xanh).
// Mô phỏng ảnh xám "trang giấy" (nền sáng) với khối đặc — đảm bảo:
//  1. Tìm đúng khối đặc gần tâm ô (torng tâm khối);
//  2. Lọc cột chữ dẹt / dải bezel (nhặt đúng ô vuông gần tâm hơn);
//  3. Trả null khi chỉ có nền (không có mốc).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/marker_blob_scan.dart';

/// Ảnh xám đơn giản: nền [bg], vẽ khối chữ nhật tối [ink].
class _GrayPage {
  _GrayPage(this.width, this.height, this.bg)
      : data = List<int>.filled(width * height, bg);

  final int width;
  final int height;
  final int bg;
  final List<int> data;

  void fillRect(int x0, int y0, int w, int h, int ink) {
    for (var y = y0; y < y0 + h; y++) {
      for (var x = x0; x < x0 + w; x++) {
        if (x >= 0 && x < width && y >= 0 && y < height) {
          data[y * width + x] = ink;
        }
      }
    }
  }

  int at(int x, int y) => data[(y.clamp(0, height - 1)) * width + x];
}

void main() {
  test('khối đặc ở giữa cửa sổ → tìm thấy, tâm chuẩn, fill cao', () {
    final page = _GrayPage(160, 160, 180);
    page.fillRect(70, 70, 16, 16, 40); // mốc 16×16 đặc (tâm = 78,78)
    final locate = locateDarkBlobInRegion(
      width: 160,
      height: 160,
      region: const Rect.fromLTRB(56, 56, 104, 104),
      grayAt: page.at,
    );
    expect(locate, isNotNull);
    expect(locate!.centroid.dx, inInclusiveRange(76, 81));
    expect(locate.centroid.dy, inInclusiveRange(76, 81));
    expect(locate.fill, greaterThanOrEqualTo(0.5));
    expect(locate.side, inInclusiveRange(12.0, 22.0));
  });

  test('cột chữ dẹt + mốc: chọn mốc gần tâm, bỏ cột dẹt', () {
    final page = _GrayPage(200, 200, 190);
    page.fillRect(30, 60, 4, 80, 30); // cột chữ dẹt bên trái cửa sổ
    page.fillRect(90, 90, 18, 18, 30); // mốc gần tâm cửa sổ
    final locate = locateDarkBlobInRegion(
      width: 200,
      height: 200,
      region: const Rect.fromLTRB(0, 40, 200, 200),
      grayAt: page.at,
    );
    expect(locate, isNotNull);
    expect(locate!.centroid.dx, greaterThan(60)); // nhặt mốc nội dung
  });

  test('chỉ nền trống → null (không nhặt "mốc" tưởng tượng)', () {
    final page = _GrayPage(120, 120, 200);
    final locate = locateDarkBlobInRegion(
      width: 120,
      height: 120,
      region: const Rect.fromLTRB(20, 20, 100, 100),
      grayAt: page.at,
    );
    expect(locate, isNull);
  });

  test('R9: khối nhỏ hơn minSidePx → bị loại (chữ đậm nhỏ)', () {
    final page = _GrayPage(160, 160, 180);
    page.fillRect(74, 74, 6, 6, 30); // khối nhỏ 6×6
    final locate = locateDarkBlobInRegion(
      width: 160,
      height: 160,
      region: const Rect.fromLTRB(56, 56, 104, 104),
      grayAt: page.at,
      minFill: 0.5,
      minSidePx: 10,
    );
    expect(locate, isNull);
  });

  test('R9: khối LỚN hơn maxSidePx (bezel/dải to) → bị loại', () {
    final page = _GrayPage(200, 200, 180);
    page.fillRect(80, 80, 80, 80, 30); // khối 80×80
    final locate = locateDarkBlobInRegion(
      width: 200,
      height: 200,
      region: const Rect.fromLTRB(56, 56, 184, 184),
      grayAt: page.at,
      minFill: 0.5,
      maxSidePx: 40,
    );
    expect(locate, isNull);
  });

  test('R9: khối có LỖ (fill 0.6 mặc định rớt) → bị loại', () {
    final page = _GrayPage(160, 160, 180);
    page.fillRect(70, 70, 16, 16, 30);
    page.fillRect(76, 76, 4, 4, 180); // lỗ giữa 4×4 → fill ≈ 0.84 ≥ 0.6
    final ok = locateDarkBlobInRegion(
      width: 160,
      height: 160,
      region: const Rect.fromLTRB(56, 56, 104, 104),
      grayAt: page.at,
      minFill: 0.6,
    );
    expect(ok, isNotNull);
    page.fillRect(73, 73, 10, 10, 180); // lỗ to 10×10 → fill ≈ 0.61 < 0.75
    final strict = locateDarkBlobInRegion(
      width: 160,
      height: 160,
      region: const Rect.fromLTRB(56, 56, 104, 104),
      grayAt: page.at,
      minFill: 0.75,
    );
    expect(strict, isNull);
  });
}
