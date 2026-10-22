import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

import '../../domain/services/omr_decoder.dart';
import '../../domain/services/sheet_layout.dart';

/// Tham số hiệu chỉnh cho bộ đo mật độ mực.
///
/// Đây là bộ tham số **khởi điểm của GradeVN** (được hiệu chuẩn lại bằng
/// fixture ở M2 và bằng phiếu in thật ở M3).
final class OmrTuning {
  const OmrTuning({
    this.inkDelta = 45,
    this.insetRatio = 0.28,
    this.borderRatio = 0.08,
    this.sampleStep = 1,
  });

  /// Độ tương phản tối thiểu (thang 0..255) so với nền cục bộ để coi là mực.
  final double inkDelta;

  /// Tỉ lệ rìa mỗi ô bỏ qua khi đo lõi (tránh viền bong bóng).
  final double insetRatio;

  /// Độ dày dải viền dùng ước lượng nền cục bộ.
  final double borderRatio;

  /// Bước lấy mẫu pixel (1 = mọi pixel).
  final int sampleStep;
}

/// Kết quả đo mật độ mực của toàn phiếu (chưa giải mã).
final class SheetDensities {
  const SheetDensities({
    required this.answerBlocks,
    required this.studentCodeGrid,
    required this.examCodeGrid,
  });

  final List<DensityBlock> answerBlocks;
  final DensityBlock studentCodeGrid;
  final DensityBlock examCodeGrid;
}

/// Cổng trừu tượng cho pipeline xử lý ảnh.
///
/// M2 dùng bản thuần Dart ([DartOmrImagePipeline]); nếu benchmark vượt ~2 s/phiếu
/// sẽ thay bằng opencv_dart phía sau đúng interface này (không đổi domain).
abstract interface class OmrImagePipeline {
  SheetDensities measure(
    Uint8List imageBytes, {
    required SheetLayout layout,
    OmrTuning tuning = const OmrTuning(),
  });
}

/// Pipeline thuần Dart: ảnh xám → nền cục bộ từng ô → tỉ lệ pixel mực ở lõi ô.
///
/// Vì sao dùng nền cục bộ thay vì ngưỡng toàn ảnh: ảnh chụp điện thoại luôn có
/// gradient sáng/tối và bóng đổ; đo nền ngay trên viền từng ô giúp ngưỡng bám
/// theo điều kiện sáng tại chỗ mà vẫn rất nhẹ (chỉ đọc pixel trong ô).
final class DartOmrImagePipeline implements OmrImagePipeline {
  const DartOmrImagePipeline();

  @override
  SheetDensities measure(
    Uint8List imageBytes, {
    required SheetLayout layout,
    OmrTuning tuning = const OmrTuning(),
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Không giải mã được ảnh phiếu (định dạng lạ).');
    }
    final gray = img.grayscale(decoded);
    final width = gray.width;
    final height = gray.height;
    final channels = gray.numChannels;
    final bytes = gray.getBytes();

    final scaleX = width / layout.page.width;
    final scaleY = height / layout.page.height;
    Rect scaleRect(Rect r) => Rect.fromLTRB(
          r.left * scaleX,
          r.top * scaleY,
          r.right * scaleX,
          r.bottom * scaleY,
        );

    double measureRect(Rect rect) => _cellInkDensity(
          bytes: bytes,
          channels: channels,
          imageWidth: width,
          imageHeight: height,
          cell: scaleRect(rect),
          tuning: tuning,
        );

    final blocks = <DensityBlock>[];
    for (final block in layout.answerBlocks) {
      final values = List.generate(
        block.rows,
        (row) => List.generate(
          block.columns,
          (col) => measureRect(block.cellRect(row, col)),
        ),
      );
      blocks.add(DensityBlock(values));
    }

    DensityBlock digitGrid(DigitGridGeometry grid) {
      // DensityBlock cho lưới chữ số: [slot (cột chữ số)][value (0..9)] —
      // đúng thứ tự OmrDecoder.decodeDigits mong đợi (row = lưới, col = giá trị).
      final values = List.generate(
        grid.slots,
        (slot) => List.generate(
          grid.rows,
          (value) => measureRect(grid.cellRect(slot, value)),
        ),
      );
      return DensityBlock(values);
    }

    return SheetDensities(
      answerBlocks: List.unmodifiable(blocks),
      studentCodeGrid: digitGrid(layout.studentCodeGrid),
      examCodeGrid: digitGrid(layout.examCodeGrid),
    );
  }

  /// Tỉ lệ pixel "có mực" trong lõi ô, so với nền ước lượng từ viền ô.
  double _cellInkDensity({
    required Uint8List bytes,
    required int channels,
    required int imageWidth,
    required int imageHeight,
    required Rect cell,
    required OmrTuning tuning,
  }) {
    final x1 = cell.left.floor().clamp(0, imageWidth - 1);
    final y1 = cell.top.floor().clamp(0, imageHeight - 1);
    final x2 = cell.right.ceil().clamp(x1 + 1, imageWidth);
    final y2 = cell.bottom.ceil().clamp(y1 + 1, imageHeight);
    final cw = x2 - x1;
    final ch = y2 - y1;
    if (cw < 4 || ch < 4) return 0;

    final border = math.max(1, (math.min(cw, ch) * tuning.borderRatio).round());

    // Nền cục bộ: trung bình độ sáng trên 4 dải viền.
    var sum = 0;
    var count = 0;
    final step = tuning.sampleStep;
    for (var y = y1; y < y2; y += step) {
      for (var dx = 0; dx < border; dx += step) {
        final xa = x1 + dx;
        final xb = x2 - 1 - dx;
        sum += _grayAt(bytes, channels, imageWidth, xa, y);
        sum += _grayAt(bytes, channels, imageWidth, xb, y);
        count += 2;
      }
    }
    for (var x = x1; x < x2; x += step) {
      for (var dy = 0; dy < border; dy += step) {
        final ya = y1 + dy;
        final yb = y2 - 1 - dy;
        sum += _grayAt(bytes, channels, imageWidth, x, ya);
        sum += _grayAt(bytes, channels, imageWidth, x, yb);
        count += 2;
      }
    }
    if (count == 0) return 0;
    final background = sum / count;
    final darkBelow = background - tuning.inkDelta;

    // Lõi ô: bỏ rìa [insetRatio] mỗi phía để không dính viền bong bóng.
    final inset = (math.min(cw, ch) * tuning.insetRatio).round();
    final ix1 = x1 + inset;
    final ix2 = x2 - inset;
    final iy1 = y1 + inset;
    final iy2 = y2 - inset;
    if (ix2 <= ix1 || iy2 <= iy1) return 0;

    var dark = 0;
    var total = 0;
    for (var y = iy1; y < iy2; y += step) {
      for (var x = ix1; x < ix2; x += step) {
        final g = _grayAt(bytes, channels, imageWidth, x, y);
        if (g < darkBelow) dark++;
        total++;
      }
    }
    if (total == 0) return 0;
    return dark / total;
  }

  int _grayAt(Uint8List bytes, int channels, int imageWidth, int x, int y) {
    final idx = (y * imageWidth + x) * channels;
    return idx < bytes.length ? bytes[idx] : 255;
  }
}
