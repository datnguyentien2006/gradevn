// R5 — Kiểm thử quét mốc TRONG VÙNG GHIM (4 ô hình chữ nhật giáo viên căn).
//
// Nguyên tắc được kiểm tra: TOÀN BỘ DIỆN TÍCH từng ô là vùng nhận diện —
// pipeline quét mọi pixel trong ô, tâm blob đen tìm thấy chính là tâm mốc
// thật. Do đó:
//  * ô có thể LỆCH tâm khỏi mốc (miễn bao trọn mốc) vẫn quét được;
//  * ảnh xoay 90° (sensor ngang) vẫn chấm được khi ô ghim theo hệ bảng xoay;
//  * ô KHÔNG phủ mốc (không có blob đen đủ to) → trả null, KHÔNG chấm rác.
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/scan_service.dart';
import 'package:gradevn/domain/services/sheet_layout.dart';
import 'package:image/image.dart' as img;

import '../fixtures/fixture_builder.dart';

void main() {
  final fixture = standardFixture();
  final spec = fixture.spec;
  final page = SheetLayout.standardPage; // 1576×2205 dựng đứng
  final layout = fixture.layout;

  /// Cạnh ô mốc trên trang chuẩn (px) = markerSide (unit) × tỉ lệ trang.
  double markerSidePx() =>
      layout.template.markerSide * (page.width / layout.template.pageWidthUnits);

  test('4 ô lệch TÂM nhưng bao trọn mốc → vẫn chấm đúng (quét cả diện tích)',
      () {
    final bytes = renderFixture(fixture);
    // Ô = hình vuông 2.5 × cạnh mốc, tâm ô TỰ DỊCH 30% cạnh mốc ra hướng
    // gần biên phiếu — tâm ô KHÔNG trùng tâm mốc (sai số kéo tay của giáo
    // viên) nhưng mốc vẫn nằm gọn trong ô.
    final centers = layout.cornerMarkerCenters;
    final rects = <Rect>[];
    for (final c in centers) {
      final shift = c.dx < page.width / 2
          ? markerSidePx() * 0.3
          : -markerSidePx() * 0.3;
      final center = Offset(c.dx + shift, c.dy);
      final hw = markerSidePx() * 1.25;
      rects.add(Rect.fromLTRB(
        (center.dx - hw) / page.width,
        (center.dy - hw) / page.height,
        (center.dx + hw) / page.width,
        (center.dy + hw) / page.height,
      ));
    }
    final photoScan = const OmrScanService().scanPhoto(
      bytes,
      spec: spec,
      overlayRects: rects,
      frameSize: page,
    );
    expect(photoScan, isNotNull,
        reason: '4 ô bao trọn mốc (dù lệch tâm) phải quét được trong ô');
    expect(photoScan!.scan.examCode, '1');
    expect(photoScan.scan.studentCodeRaw, fixture.studentCodeRaw);
  });

  test('ảnh xoay 90° (sensor ngang) + ô ghim theo hệ bảng xoay → chấm được',
      () {
    final (bytes, frame) = rotatedFixturePage(fixture);
    final rects = <Rect>[];
    for (final c in layout.cornerMarkerCenters) {
      // Tâm mốc biến đổi cùng công thức xoay CW: (x, y) → (H − 1 − y, x)
      // với H = CHIỀU CAO bảng gốc = frame.width của bảng xoay.
      final rc = Offset(
        frame.width - 1 - c.dy,
        c.dx,
      );
      final hw = markerSidePx() * 1.25;
      rects.add(Rect.fromLTRB(
        (rc.dx - hw) / frame.width,
        (rc.dy - hw) / frame.height,
        (rc.dx + hw) / frame.width,
        (rc.dy + hw) / frame.height,
      ));
    }
    final photoScan = const OmrScanService().scanPhoto(
      bytes,
      spec: spec,
      overlayRects: rects,
      frameSize: frame,
    );
    expect(photoScan, isNotNull, reason: 'mốc nằm TRONG ô xoay phải quét được');
  });

  test('ô rác KHÔNG phủ mốc (detector cũng bó tay) → null, không chấm rác',
      () {
    final (bytes, frame) = rotatedFixturePage(fixture);
    // 4 ô nhỏ chồng nhau quanh TÂM trang (vùng nội dung, không chứa mốc) —
    // bên trong không có blob đen đủ to → quét trong ô bó tay, detector
    // toàn ảnh cũng bó tay (quad dẹt) → phải trả null.
    final cx = frame.width / 2;
    final cy = frame.height / 2;
    final garbage = <Rect>[];
    for (final d in const [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(1, 1),
      Offset(-1, 1),
    ]) {
      final hx = cx + d.dx * 60;
      final hy = cy + d.dy * 60;
      garbage.add(Rect.fromLTRB(
        (hx - 30) / frame.width,
        (hy - 30) / frame.height,
        (hx + 30) / frame.width,
        (hy + 30) / frame.height,
      ));
    }
    final photoScan = const OmrScanService().scanPhoto(
      bytes,
      spec: spec,
      overlayRects: garbage,
      frameSize: frame,
    );
    expect(photoScan, isNull, reason: 'ô không phủ mốc không được sinh quad rác');
  });
}

/// Ảnh fixture xoay 90° CW bằng tay + kích thước bảng xoay (~(h, w)).
(Uint8List, Size) rotatedFixturePage(FixtureDefinition fixture) {
  final decoded = img.decodePng(renderFixture(fixture))!;
  final w = decoded.width;
  final h = decoded.height;
  final rot = img.Image(width: h, height: w);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final px = decoded.getPixel(x, y);
      rot.setPixelRgb(h - 1 - y, x, px.r, px.g, px.b);
    }
  }
  return (Uint8List.fromList(img.encodePng(rot)), Size(h.toDouble(), w.toDouble()));
}
