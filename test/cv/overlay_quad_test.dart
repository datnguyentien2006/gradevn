// R2 — Kiểm thử quad overlay (phân định hướng) và quad chắc chắn (hệ ảnh).
//
// Mục tiêu R2 #2: pipeline dùng vị trí 4 ô vuông giáo viên ghim làm LƯỚI
// DỰ PHÒNG khi detector bó tay, và dùng quad hệ ảnh chụp biết chắc để khôi
// phục ảnh trả từ CropReviewScreen (mốc in phai/mất vẫn chấm được).
//
// Ghi chú R2: 12 mốc đối xứng 180° → khi ảnh decode nằm ngang (pixel xoay),
// dò CW/CCW không phân biệt được hướng (test không dò vào trường hợp này);
// trên thiết bị thực ảnh takePicture gần như luôn đúng hướng hiển thị →
// biến thể "thẳng" chọn chắc chắn.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/scan_service.dart';
import 'package:gradevn/data/cv/sheet_alignment.dart' show AlignmentQuad;
import 'package:gradevn/domain/services/sheet_layout.dart';
import 'package:image/image.dart' as img;

import '../fixtures/fixture_builder.dart';

void main() {
  final fixture = standardFixture();
  final spec = fixture.spec;
  final layout = fixture.layout;

  Uint8List rotatedImage() {
    final decoded = img.decodePng(renderFixture(fixture))!;
    // copyRotate 90°: nội dung dựng đứng → nằm ngang trong ảnh decode.
    return Uint8List.fromList(img.encodePng(img.copyRotate(decoded, angle: 90)));
  }

  test('quad ghim (khung dọc) + ảnh pixel dọc đúng hướng → chọn biến thẳng',
      () {
    final bytes = renderFixture(fixture);
    // Ghim đúng vị trí mốc trên trang chuẩn; khung = chính trang chuẩn.
    final photoScan = const OmrScanService().scanPhoto(
      bytes,
      spec: spec,
      overlayQuad: _pageCornerQuad(layout),
      frameSize: SheetLayout.standardPage,
    );
    expect(photoScan, isNotNull, reason: 'quad ghim đúng mốc phải đạt');
    // Mã đề chuẩn hoá: '001' → '1' (bỏ số 0 vô nghĩa đầu).
    expect(photoScan!.scan.examCode, '1');
    expect(photoScan.scan.studentCodeRaw, fixture.studentCodeRaw);
  });

  test('quad ghim rác (không phủ mốc) trên ảnh detector bó tay → null', () {
    // Ảnh xoay: nội dung nằm ngang → detector từ chối (quad dẹt) → pipeline
    // rơi về nhánh overlay; ô ghim rác của giáo viên phải bị chất lượng
    // từ chối (không warp rác).
    final bytes = rotatedImage();
    final frame = SheetLayout.standardPage;
    final cx = frame.width / 2;
    final cy = frame.height / 2;
    final r = 60.0;
    final photoScan = const OmrScanService().scanPhoto(
      bytes,
      spec: spec,
      overlayQuad: AlignmentQuad(
        Offset(cx - r, cy - r),
        Offset(cx + r, cy - r),
        Offset(cx + r, cy + r),
        Offset(cx - r, cy + r),
      ),
      frameSize: frame,
    );
    expect(photoScan, isNull);
  });

  test('ảnh xoay + quad ghim trùng mốc → nhánh overlay trả quad hợp lệ', () {
    // Lưu ý R2: 12 mốc đối xứng 180° nên dò CW/CCW không phân biệt được
    // hướng — test giữ hợp đồng "không crash + luôn trả quad đạt ngưỡng";
    // hướng thật quyết bởi thứ tự ghim 1-4 của giáo viên trên preview.
    final bytes = rotatedImage();
    final photoScan = const OmrScanService().scanPhoto(
      bytes,
      spec: spec,
      overlayQuad: _pageCornerQuad(layout),
      frameSize: SheetLayout.standardPage,
    );
    expect(photoScan, isNotNull);
  });

  test('knownQuad hệ ảnh (ảnh xoay 90°, quad xoay theo) → warp + chấm đúng',
      () {
    // Xoay ảnh 90° CW bằng tay (công thức rõ ràng, không phụ thuộc thư viện):
    // (x, y) → (H - 1 - y, x); ảnh mới W' = H, H' = W.
    final page = img.decodePng(renderFixture(fixture))!;
    final w = page.width;
    final h = page.height;
    final rotImg = img.Image(width: h, height: w);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        // setPixel ghi nguyên pixel xám (a=r=g=b).
        final p = page.getPixel(x, y);
        rotImg.setPixelRgb(h - 1 - y, x, p.r, p.g, p.b);
      }
    }
    final bytes = Uint8List.fromList(img.encodePng(rotImg));

    // Quad hệ ảnh xoay = 4 tâm mốc góc biến đổi theo cùng công thức.
    Offset rotPoint(Offset p) => Offset(h - 1 - p.dy, p.dx);
    final rotPts = <Offset>[
      for (final p in layout.cornerMarkerCenters) rotPoint(p)
    ];
    final photoScan = const OmrScanService().scanPhoto(
      bytes,
      spec: spec,
      knownQuad: AlignmentQuad(
        rotPts[0],
        rotPts[1],
        rotPts[2],
        rotPts[3],
      ),
    );
    expect(photoScan, isNotNull);
    expect(photoScan!.scan.examCode, '1');
    expect(photoScan.scan.studentCodeRaw, fixture.studentCodeRaw);
  });
}

AlignmentQuad _pageCornerQuad(SheetLayout layout) {
  final c = layout.cornerMarkerCenters;
  return AlignmentQuad(
    Offset(c[0].dx, c[0].dy),
    Offset(c[1].dx, c[1].dy),
    Offset(c[2].dx, c[2].dy),
    Offset(c[3].dx, c[3].dy),
  );
}
