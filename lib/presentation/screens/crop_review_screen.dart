// Màn "ghim mốc phiếu" (R1, thay cho màn cắt hộp cũ): ảnh chụp không tìm đủ
// 4 ô vuông mốc → giáo viên GHIM 4 Ô VUÔNG ĐEN theo thứ tự
// (trái-trên → phải-trên → phải-dưới → trái-dưới) → nắn phẳng theo 4 tâm ghim
// về trang chuẩn → pop trả về PNG đã nắn (chạy lại pipeline để chấm).
//
// Toạ độ ghim lưu theo pixel của ẢNH (không phải pixel màn hình) để bước warp
// luôn khớp; vẽ overlay thì quy đổi theo tỉ lệ hiển thị (letterbox).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:image/image.dart' as img;

import '../../data/cv/sheet_alignment.dart';
import '../../domain/services/sheet_layout.dart';

/// Số mốc cần ghim (4 góc khung).
const int _requiredPins = 4;

/// Màn ghim mốc: pop trả về `Uint8List` (PNG đã nắn phẳng) hoặc `null` = bỏ.
final class CropReviewScreen extends StatefulWidget {
  const CropReviewScreen({
    super.key,
    required this.imageBytes,
    required this.layout,
  });

  final Uint8List imageBytes;

  /// Layout của kỳ thi (trang chuẩn + tâm mốc) — đích của bước nắn phẳng.
  final SheetLayout layout;

  @override
  State<CropReviewScreen> createState() => _CropReviewScreenState();
}

final class _CropReviewScreenState extends State<CropReviewScreen> {
  final List<Offset> _pins = <Offset>[];

  /// Tỉ lệ hiển thị + dịch chuyển (letterbox) của ảnh trên canvas.
  double _scale = 1;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Decode thuần Dart chỉ để biết kích thước ảnh; giữ nguyên bytes gốc.
    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) return; // UI hiển thị trạng thái lỗi khi null.
    _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
  }

  Size? _imageSize;

  /// Chạm ảnh → ghim mốc kế tiếp theo thứ tự nối sẵn; đủ 4 mốc thì chạm
  /// thêm không ghi gì mới (dùng nút "Chọn lại" để ghim từ đầu).
  void _onTapDown(TapDownDetails details) {
    final size = _imageSize;
    if (size == null || _scale <= 0 || _pins.length >= _requiredPins) return;
    // Quy đổi màn hình → ảnh (kẹp vào biên ảnh cho an toàn).
    final x = ((details.localPosition.dx - _offset.dx) / _scale)
        .clamp(0.0, size.width)
        .toDouble();
    final y = ((details.localPosition.dy - _offset.dy) / _scale)
        .clamp(0.0, size.height)
        .toDouble();
    setState(() => _pins.add(Offset(x, y)));
  }

  /// Áp dụng: nắn phẳng theo 4 tâm ghim về trang chuẩn → PNG → pop trả về.
  void _apply() {
    final size = _imageSize;
    if (size == null || _pins.length != _requiredPins) return;
    final quad = AlignmentQuad(
      _pins[0], // trái-trên
      _pins[1], // phải-trên
      _pins[2], // phải-dưới
      _pins[3], // trái-dưới
    );
    final centers = widget.layout.cornerMarkerCenters;
    final targetQuad = AlignmentQuad(centers[0], centers[1], centers[2], centers[3]);
    final warped = const PerspectiveWarper().warpRectify(
      widget.imageBytes,
      quad: quad,
      targetQuad: targetQuad,
      outputSize: widget.layout.page,
    );
    Navigator.of(context).pop(warped);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = _imageSize;
    if (size == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.cropTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 56),
              const SizedBox(height: 12),
              Text(l10n.scanImagePickFailed, textAlign: TextAlign.center),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.back),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(l10n.cropTitle)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.cropPickMarkers,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Tính letterbox mỗi frame (kích thước canvas có thể đổi khi xoay).
                final s = math.min(
                  constraints.maxWidth / size.width,
                  constraints.maxHeight / size.height,
                );
                _scale = s;
                _offset = Offset(
                  (constraints.maxWidth - size.width * s) / 2,
                  (constraints.maxHeight - size.height * s) / 2,
                );
                final imageScreenRect = Rect.fromLTWH(
                  _offset.dx,
                  _offset.dy,
                  size.width * _scale,
                  size.height * _scale,
                );
                return GestureDetector(
                  onTapDown: _onTapDown,
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: imageScreenRect,
                        child: Image.memory(widget.imageBytes, fit: BoxFit.fill),
                      ),
                      Positioned.fromRect(
                        rect: imageScreenRect,
                        child: CustomPaint(
                          painter: _PinsOverlayPainter(
                            pins: _pins,
                            scale: _scale,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cropRetake),
              ),
              OutlinedButton(
                onPressed: _pins.isEmpty ? null : () => setState(_pins.clear),
                child: Text(l10n.cropResetPins),
              ),
              FilledButton(
                onPressed: _pins.length == _requiredPins ? _apply : null,
                child: Text(
                    l10n.cropPinsProgress(_pins.length, _requiredPins)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vẽ các ghim đã đặt: vòng cam + số thứ tự mốc (TL→TR→BR→BL).
/// Toạ độ drawn = pixel ảnh nhân scale; letterbox không cần vì painter
/// nhận toạ độ ảnh và canvas được đặt đúng đè lên ảnh.
final class _PinsOverlayPainter extends CustomPainter {
  const _PinsOverlayPainter({required this.pins, required this.scale});

  final List<Offset> pins;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.orange.shade700;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < pins.length; i++) {
      final p = pins[i] * scale;
      canvas.drawCircle(p, 14, fill);
      canvas.drawCircle(p, 14, ring);
      final number = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      number.paint(canvas, p - Offset(number.width / 2, number.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PinsOverlayPainter oldDelegate) =>
      oldDelegate.pins != pins || oldDelegate.scale != scale;
}
