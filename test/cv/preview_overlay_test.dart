// R2 — Kiểm thử hình học overlay 4 ô vuông trên preview camera.
//
// Thuần Dart: CoverMapping (cover khung↔màn hình), snapSquareCenters
// (ghim ứng viên gần nhất, không chiếm trùng mốc), onConfidentMarkerCount.
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:gradevn/data/cv/preview_overlay.dart';

void main() {
  group('CoverMapping', () {
    const frame = Size(480, 640);
    const screen = Size(720, 1600);
    const mapping = CoverMapping(frame: frame, screen: screen);

    test('quy đổi khung → màn hình đúng cover (lấy tỉ lệ lớn, cắt đối xứng)',
        () {
      // scale = max(720/480, 1600/640) = 2.5; offset X = (720 − 1200)/2 = −240.
      expect(mapping.toScreen(const Offset(96, 20)), const Offset(0, 50));
      expect(mapping.toScreen(const Offset(480, 640)),
          const Offset(960, 1600)); // biên phải khung lấn ra ngoài màn hình
    });

    test('quy đổi màn hình → khung là nghịch đảo (trong vùng thấy được)', () {
      const p = Offset(200, 100);
      final back = mapping.toFrame(mapping.toScreen(p));
      expect((back - p).distance, lessThan(1e-9));
    });

    test('kẹp biên khung khi điểm màn hình ở vùng bị cắt', () {
      expect(mapping.toFrame(const Offset(-1000, 0)),
          const Offset(0, 0));
      expect(mapping.toFrame(const Offset(5000, 1600)),
          const Offset(480, 640));
    });

    test('framePointToPhoto: tỉ lệ trực tiếp khung → ảnh chụp', () {
      const m = CoverMapping(frame: Size(480, 640), screen: Size(720, 1600));
      expect(
        m.framePointToPhoto(const Offset(240, 320), const Size(4800, 6400)),
        const Offset(2400, 3200),
      );
    });
  });

  group('snapSquareCenters', () {
    test('ôn gần ứng viên → snap; không ứng viên trong bán kính → giữ nguyên',
        () {
      final snap = snapSquareCenters(
        [const Offset(100, 100), const Offset(500, 900)],
        [const Offset(110, 95)],
        30,
      );
      expect(snap[0], const Offset(110, 95));
      expect(snap[1], isNull);
    });

    test('mỗi mốc chỉ cho 1 ô chiếm: ô sau bỏ qua ứng viên đã chiếm', () {
      final snap = snapSquareCenters(
        [const Offset(100, 100), const Offset(115, 105)],
        [const Offset(105, 100)],
        30,
      );
      expect(snap[0], const Offset(105, 100)); // ô trước gần hơn → chiếm
      expect(snap[1], isNull);
    });

    test('chọn ứng viên gần nhất, không phải ứng viên đầu danh sách', () {
      final snap = snapSquareCenters(
        [const Offset(100, 100)],
        [const Offset(150, 100), const Offset(105, 100)],
        30,
      );
      expect(snap[0], const Offset(105, 100));
    });
  });

  group('onConfidentMarkerCount', () {
    test('đếm số ô nằm trên ứng viên trong bán kính', () {
      final count = onConfidentMarkerCount(
        [
          const Offset(100, 100),
          const Offset(300, 100),
          const Offset(500, 100),
          const Offset(700, 100),
        ],
        [
          const Offset(102, 99),
          const Offset(295, 104),
          const Offset(1200, 1200),
        ],
        15,
      );
      expect(count, 2);
    });

    test('không ứng viên → 0', () {
      expect(onConfidentMarkerCount(
        [const Offset(0, 0)],
        [const Offset(9999, 9999)],
        20,
      ), 0);
    });
  });

  group('squareLockStates (R3)', () {
    test('trạng thái khoá ĐÚNG TỪNG ô, độc lập với ô còn lại', () {
      final states = squareLockStates(
        [const Offset(100, 100), const Offset(300, 100)],
        [const Offset(102, 99), const Offset(900, 900)],
        15,
      );
      expect(states, <bool>[true, false]);
    });

    test('hiểm ứng viên nào → mọi ô mở', () {
      expect(
        squareLockStates(
          [const Offset(0, 0), const Offset(50, 0)],
          const <Offset>[],
          20,
        ),
        <bool>[false, false],
      );
    });
  });

  group('SheetProjection (R3) — phép chiếu phiếu ảo', () {
    const page = Size(1576, 2205);
    final markerCenters = <Offset>[
      const Offset(100, 125),
      const Offset(1476, 125),
      const Offset(1476, 2080),
      const Offset(100, 2080),
    ];

    test('outline aspect-fit giữ tỉ lệ trang, căn giữa, chừa lề mỗi phía', () {
      const area = Size(720, 1200);
      final p = SheetProjection(
        pageSize: page,
        markerCenters: markerCenters,
        markerSide: 87,
        area: area,
      );
      final rect = p.outlineRect;
      // Tỉ lệ phiếu chuẩn ≈ 0.7147 — chiều rộng giới hạn: 720×(1−0.16)=604.8.
      expect(rect.width, closeTo(604.8, 0.5));
      expect(rect.height, closeTo(604.8 / page.aspectRatio, 1.0));
      expect(rect.center, const Offset(360, 600));
    });

    test('4 tâm mốc chiếu đúng vị trí tương đối trên khung ảo', () {
      const area = Size(720, 1200);
      final p = SheetProjection(
        pageSize: page,
        markerCenters: markerCenters,
        markerSide: 87,
        area: area,
      );
      final rect = p.outlineRect;
      final projected = p.projectedMarkerCenters;
      expect(projected.length, 4);
      // Điểm trên-trái: lề 100/1576 chiều rộng, 125/2205 chiều cao.
      expect(projected[0].dx, closeTo(rect.left + 100 / 1576 * rect.width, 0.5));
      expect(projected[0].dy, closeTo(rect.top + 125 / 2205 * rect.height, 0.5));
      // Điểm dưới-phải đối xứng.
      expect(projected[2].dx,
          closeTo(rect.left + 1476 / 1576 * rect.width, 0.5));
      expect(projected[2].dy,
          closeTo(rect.top + 2080 / 2205 * rect.height, 0.5));
    });

    test('cạnh ô mốc chiếu tỉ lệ theo khung, không phải cỡ cố định', () {
      const area = Size(720, 1200);
      final p = SheetProjection(
        pageSize: page,
        markerCenters: markerCenters,
        markerSide: 87,
        area: area,
      );
      expect(p.projectedMarkerSide, closeTo(87 / 1576 * p.outlineRect.width, 0.5));

      // Camera đổi bao quát (vùng preview hẹp hơn) → tỉ lệ khung giảm → ô nhỏ hơn.
      final p2 = SheetProjection(
        pageSize: page,
        markerCenters: markerCenters,
        markerSide: 87,
        area: const Size(480, 1600),
      );
      expect(p2.projectedMarkerSide, lessThan(p.projectedMarkerSide));
    });
  });

  group('MarkerOverlayCalibration (y hệt TNMaker, toàn màn dọc 720×1560)', () {
    test('cỡ ô = 157/720 × width, 203/1560 × height (khung đo thực tế)', () {
      expect(MarkerOverlayCalibration.widthFraction, closeTo(157 / 720, 1e-6));
      expect(MarkerOverlayCalibration.heightFraction, closeTo(203 / 1560, 1e-6));
      // Tỉ lệ độc lập với đơn vị preview:
      // preview 720×1560 → ô đúng bằng px đo gốc.
      final w1 = MarkerOverlayCalibration.widthFraction * 720;
      final h1 = MarkerOverlayCalibration.heightFraction * 1560;
      expect(w1, closeTo(157, 1e-6));
      expect(h1, closeTo(203, 1e-6));
      // Preview khác kích thước → cùng tỉ lệ nhân lên.
      final w2 = MarkerOverlayCalibration.widthFraction * 360;
      final h2 = MarkerOverlayCalibration.heightFraction * 780;
      expect(w2, closeTo(78.5, 1e-6));
      expect(h2, closeTo(101.5, 1e-6));
    });

    test('4 tâm khớp 4 khung ô đã đo (tl, tr, br, bl), đối xứng', () {
      final centers = MarkerOverlayCalibration.centerFractions;
      expect(centers.length, 4);
      // Tâm include-bounds: tl [0..156]×[64..266] → (78.5, 165.5).
      expect(centers[0].dx, closeTo(78.5 / 720, 1e-6));
      expect(centers[0].dy, closeTo(165.5 / 1560, 1e-6));
      // tr [563..719]×[64..266] → (641.5, 165.5).
      expect(centers[1].dx, closeTo(641.5 / 720, 1e-6));
      expect(centers[1].dy, closeTo(165.5 / 1560, 1e-6));
      // br [563..719]×[974..1177] → (641.5, 1076.5).
      expect(centers[2].dx, closeTo(641.5 / 720, 1e-6));
      expect(centers[2].dy, closeTo(1076.5 / 1560, 1e-6));
      // bl [0..156]×[974..1177] → (78.5, 1076.5).
      expect(centers[3].dx, closeTo(78.5 / 720, 1e-6));
      expect(centers[3].dy, closeTo(1076.5 / 1560, 1e-6));
      // Cặp đối xứng trục dọc: tl/tr cùng dy, br/bl cùng dy; cặp ngang
      // cùng dx, tổng 2 tâm ngang = 1.0 (đối xứng biên).
      expect(centers[0].dy, centers[1].dy);
      expect(centers[2].dy, centers[3].dy);
      expect(centers[0].dx, centers[3].dx);
      expect(centers[1].dx, centers[2].dx);
      expect(centers[0].dx + centers[1].dx, closeTo(1.0, 1e-6));
    });

    test('lề trên 64 px & hàng dưới kết thúc 1177 (nhường dưới cho nút chụp)',
        () {
      final centers = MarkerOverlayCalibration.centerFractions;
      // Tâm hàng trên ×1560 − 101.5 = 64 (biên trên ô).
      expect(centers[0].dy * 1560 - 203 / 2, closeTo(64, 1e-6));
      // Tâm hàng dưới ×1560 + 101.5 = 1178 (biên dưới exclusive; 1177 là
      // biên.Include-bounds cuối cùng).
      expect(centers[2].dy * 1560 + 203 / 2, closeTo(1178, 1e-6));
      // Mép trái ô = 0 (sát mép màn), mép phải ô = 720.
      expect(centers[0].dx * 720 - 157 / 2, closeTo(0, 1e-6));
      expect(centers[1].dx * 720 + 157 / 2, closeTo(720, 1e-6));
    });

    test('trong khoảng [0,1] và ô không lọt lề ngoài không gian đo', () {
      final centers = MarkerOverlayCalibration.centerFractions;
      for (final c in centers) {
        expect(c.dx, inExclusiveRange(0.0, 1.0));
        expect(c.dy, inExclusiveRange(0.0, 1.0));
      }
      expect(MarkerOverlayCalibration.widthFraction, lessThan(0.25));
      expect(MarkerOverlayCalibration.heightFraction, lessThan(0.25));
    });
  },
  );
}
