// Màn "cắt lại vùng phiếu" (M3): ảnh chụp không tìm thấy khung → giáo viên kéo
// 4 góc chọn hộp bao phiếu → trả về PNG của vùng đã cắt để chạy lại pipeline.
//
// Toạ độ hộp cắt lưu theo pixel của ẢNH (không phải pixel màn hình) để bước
// crop với package:image luôn khớp; vẽ overlay thì quy đổi theo tỉ lệ hiển thị.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:image/image.dart' as img;

/// Góc của hộp cắt đang kéo.
enum _CropAnchor { topLeft, topRight, bottomRight, bottomLeft }

/// Kích thước tối thiểu của hộp cắt (pixel ảnh).
const double _minCropSize = 40;

/// Bán kính vẽ tay cầm góc (pixel màn hình).
const double _handleRadius = 22;

/// Màn cắt ảnh: pop trả về `Uint8List` (PNG vùng đã cắt) hoặc `null` = bỏ.
final class CropReviewScreen extends StatefulWidget {
  const CropReviewScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<CropReviewScreen> createState() => _CropReviewScreenState();
}

final class _CropReviewScreenState extends State<CropReviewScreen> {
  img.Image? _image;

  /// Hộp cắt hiện tại (toạ độ pixel ảnh).
  Rect _rect = Rect.zero;

  /// Tỉ lệ hiển thị + dịch chuyển (letterbox) của ảnh trên canvas.
  double _scale = 1;
  Offset _offset = Offset.zero;
  _CropAnchor? _draggedAnchor;

  @override
  void initState() {
    super.initState();
    // Decode thuần Dart (package:image) — cho kích thước ảnh + crop cuối cùng.
    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded != null) {
      final width = decoded.width.toDouble();
      final height = decoded.height.toDouble();
      // Hộp ban đầu: thụt vào 8% mỗi cạnh (gợi ý vùng phiếu).
      _rect = Rect.fromLTRB(width * 0.08, height * 0.08, width * 0.92, height * 0.92);
    }
    _image = decoded;
  }

  Offset _cornerOf(_CropAnchor anchor) => switch (anchor) {
        _CropAnchor.topLeft => _rect.topLeft,
        _CropAnchor.topRight => _rect.topRight,
        _CropAnchor.bottomRight => _rect.bottomRight,
        _CropAnchor.bottomLeft => _rect.bottomLeft,
      };

  /// Quy đổi vị trí góc ảnh → vị trí màn hình.
  Offset _screenPoint(Offset imagePoint) =>
      _offset + imagePoint * _scale;

  void _onHandlePan(DragUpdateDetails details, _CropAnchor anchor) {
    final image = _image;
    if (image == null || _scale <= 0) return;
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final dx = details.delta.dx / _scale;
    final dy = details.delta.dy / _scale;

    setState(() {
      switch (anchor) {
        case _CropAnchor.topLeft:
          final left = (_rect.left + dx).clamp(0.0, _rect.right - _minCropSize);
          final top = (_rect.top + dy).clamp(0.0, _rect.bottom - _minCropSize);
          _rect = Rect.fromLTRB(left, top, _rect.right, _rect.bottom);
        case _CropAnchor.topRight:
          final right = (_rect.right + dx).clamp(_rect.left + _minCropSize, w);
          final top = (_rect.top + dy).clamp(0.0, _rect.bottom - _minCropSize);
          _rect = Rect.fromLTRB(_rect.left, top, right, _rect.bottom);
        case _CropAnchor.bottomRight:
          final right = (_rect.right + dx).clamp(_rect.left + _minCropSize, w);
          final bottom = (_rect.bottom + dy).clamp(_rect.top + _minCropSize, h);
          _rect = Rect.fromLTRB(_rect.left, _rect.top, right, bottom);
        case _CropAnchor.bottomLeft:
          final left = (_rect.left + dx).clamp(0.0, _rect.right - _minCropSize);
          final bottom = (_rect.bottom + dy).clamp(_rect.top + _minCropSize, h);
          _rect = Rect.fromLTRB(left, _rect.top, _rect.right, bottom);
      }
    });
  }

  /// Áp dụng: crop vùng đã chọn (toạ độ ảnh) → PNG → pop trả về cho người gọi.
  void _apply() {
    final image = _image;
    if (image == null) return;
    final x = _rect.left.toInt().clamp(0, image.width - 1);
    final y = _rect.top.toInt().clamp(0, image.height - 1);
    final width = _rect.width.toInt().clamp(1, image.width - x);
    final height = _rect.height.toInt().clamp(1, image.height - y);
    final cropped = img.copyCrop(image, x: x, y: y, width: width, height: height);
    final png = img.encodePng(cropped, level: 6);
    Navigator.of(context).pop(png);
  }

  Widget _handleWidget(_CropAnchor anchor) {
    final point = _screenPoint(_cornerOf(anchor));
    return Positioned(
      left: point.dx - _handleRadius,
      top: point.dy - _handleRadius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _draggedAnchor = anchor),
        onPanUpdate: (details) => _onHandlePan(details, anchor),
        onPanEnd: (_) => setState(() => _draggedAnchor = null),
        onPanCancel: () => setState(() => _draggedAnchor = null),
        child: SizedBox(
          width: _handleRadius * 2,
          height: _handleRadius * 2,
          child: CustomPaint(
            painter: _HandlePainter(active: _draggedAnchor == anchor),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final image = _image;
    if (image == null) {
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Tính letterbox mỗi frame (kích thước canvas có thể đổi khi xoay).
          final s = math.min(
            constraints.maxWidth / image.width,
            constraints.maxHeight / image.height,
          );
          _scale = s;
          _offset = Offset(
            (constraints.maxWidth - image.width * s) / 2,
            (constraints.maxHeight - image.height * s) / 2,
          );
          final imageScreenRect = Rect.fromLTWH(
            _offset.dx,
            _offset.dy,
            image.width * _scale,
            image.height * _scale,
          );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: imageScreenRect,
                child: Image.memory(widget.imageBytes, fit: BoxFit.fill),
              ),
              Positioned.fromRect(
                rect: imageScreenRect,
                child: CustomPaint(
                  painter: _CropOverlayPainter(rect: _rect, scale: _scale),
                ),
              ),
              for (final anchor in _CropAnchor.values) _handleWidget(anchor),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cropRetake),
            ),
            FilledButton(
              onPressed: _apply,
              child: Text(l10n.cropApply),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vẽ vùng tối bao quanh hộp cắt + viền trắng (toạ độ bản vẽ = pixel ảnh).
final class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.rect, required this.scale});

  final Rect rect;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final window = Rect.fromLTWH(
      rect.left * scale,
      rect.top * scale,
      rect.width * scale,
      rect.height * scale,
    );
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, Paint()..color = Colors.black54);
    canvas.drawRect(window, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawRect(
      window,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final corner in [
      window.topLeft,
      window.topRight,
      window.bottomRight,
      window.bottomLeft,
    ]) {
      canvas.drawCircle(corner, 6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.scale != scale;
}

/// Tay cầm góc: vòng tròn trắng, đậm hơn khi đang kéo.
final class _HandlePainter extends CustomPainter {
  const _HandlePainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      active ? 7 : 5,
      Paint()..color = active ? Colors.orangeAccent : Colors.white,
    );
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) => oldDelegate.active != active;
}
