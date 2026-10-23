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
}
