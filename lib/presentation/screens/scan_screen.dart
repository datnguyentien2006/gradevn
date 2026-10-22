// Màn chấm phiếu bằng camera (M3): ngắm khung → chụp → quét + chấm trong
// isolate → xem kết quả → lưu DB + ảnh vào bộ nhớ ứng dụng.
//
// Quy ước an toàn:
// - Camera chỉ khởi tạo trên Android/iOS (Platform check) và MỌI lệnh camera
//   phải bọc try/catch — lỗi camera không bao giờ làm crash app.
// - Khi không có camera (Windows/test/phiên bản thiếu quyền) → hiển thị hướng
//   dẫn + nút chọn ảnh từ tệp (file_picker): luồng chấm vẫn chạy được.

import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/cv/scan_flow.dart' show GradedScan, processPhoto;
import '../../data/cv/sheet_painter.dart' show renderMarkedSheet;
import '../../domain/entities/graded_sheet.dart';
import '../../domain/entities/class_room.dart';
import '../../domain/entities/contest.dart';
import '../../domain/entities/sheet_spec.dart';
import '../../domain/services/sheet_layout.dart';
import '../state/providers.dart';
import 'crop_review_screen.dart';

final class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, required this.contestId});

  final int contestId;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

final class _ScanScreenState extends ConsumerState<ScanScreen> {
  Contest? _contest;
  List<AnswerKey> _keys = <AnswerKey>[];
  List<Student> _students = <Student>[];
  bool _loading = true;
  bool _busy = false;
  CameraController? _controller;
  bool _cameraFailed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initCamera();
  }

  /// Nạp contest + keys + học sinh của lớp (nếu contest gán lớp) TRƯỚC chụp.
  Future<void> _loadData() async {
    try {
      final contest =
          await ref.read(contestRepositoryProvider).byId(widget.contestId);
      final keys = <AnswerKey>[];
      final students = <Student>[];
      if (contest != null) {
        final keyStream =
            await ref.read(answerKeyRepositoryProvider).watchByContest(contest.id).first;
        keys.addAll(keyStream);
        final classId = contest.classRoomId;
        if (classId != null) {
          students.addAll(
              await ref.read(studentRepositoryProvider).watchByClass(classId).first);
        }
      }
      if (!mounted) return;
      setState(() {
        _contest = contest;
        _keys = keys;
        _students = students;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.scanError(e.toString()))));
      setState(() => _loading = false);
    }
  }

  /// Camera chỉ trên Android/iOS; lỗi nào cũng đưa về chế độ "chọn ảnh từ tệp".
  Future<void> _initCamera() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraFailed = true);
        return;
      }
      CameraDescription description = cameras.first;
      for (final c in cameras) {
        if (c.lensDirection == CameraLensDirection.back) {
          description = c;
          break;
        }
      }
      final controller = CameraController(
        description,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Chụp ảnh → quét + chấm.
  Future<void> _capture() async {
    if (_busy || _loading) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _process(bytes);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.scanError(e.toString()))));
    }
  }

  /// Chọn ảnh phiếu từ tệp (dự phòng khi không có camera).
  Future<void> _pickImage() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      if (picked.isEmpty) return;
      final bytes = await picked.first.readAsBytes();
      if (!mounted) return;
      await _process(Uint8List.fromList(bytes));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.scanError(e.toString()))));
    }
  }

  /// Quét + chấm ảnh (isolate) → dialog lỗi hoặc bottom sheet kết quả.
  Future<void> _process(Uint8List bytes) async {
    final contest = _contest;
    if (contest == null) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    GradedScan? graded;
    try {
      graded = await processPhoto(
        bytes,
        contest: contest,
        keys: _keys,
        candidateStudents: _students,
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.scanError(e.toString()))));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (graded == null) {
      await _showFrameNotFound(bytes);
    } else {
      await _showResult(graded);
    }
  }

  /// Khung phiếu không đọc được: chụp lại hoặc mở màn cắt ảnh rồi thử tiếp.
  Future<void> _showFrameNotFound(Uint8List bytes) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.scanFrameNotFound),
        content: Text(l10n.scanFrameNotFoundHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.scanRetake),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openCrop(bytes);
            },
            child: Text(l10n.scanTryCrop),
          ),
        ],
      ),
    );
  }

  Future<void> _openCrop(Uint8List bytes) async {
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CropReviewScreen(imageBytes: bytes)),
    );
    if (cropped != null) await _process(cropped);
  }

  Future<void> _showResult(GradedScan graded) async {
    if (!mounted) return;
    final contest = _contest;
    if (contest == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ResultSheet(
        graded: graded,
        contest: contest,
        onSave: () async {
          final saved = await _save(graded);
          if (saved && sheetContext.mounted) Navigator.pop(sheetContext);
        },
        onScanAnother: () => Navigator.pop(sheetContext),
      ),
    );
  }

  /// Lưu ảnh (gốc đã nắn phẳng + phiếu có gạch kết quả) vào thư mục tài liệu
  /// rồi insert hàng DB; thành công → snackbar + pop về màn trước.
  Future<bool> _save(GradedScan graded) async {
    final contest = _contest;
    if (contest == null) return false;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final scan = graded.photo.scan;
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
          p.join(docsDir.path, 'sheets', 'contest_${contest.id}'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final origPath = p.join(dir.path, 'orig_$ts.png');
      File(origPath).writeAsBytesSync(graded.photo.warpedBytes);
      final layout =
          SheetLayout.forSpec(contest.sheetSpec, page: SheetLayout.standardPage);
      final markedPath = p.join(dir.path, 'marked_$ts.png');
      File(markedPath).writeAsBytesSync(renderMarkedSheet(
        warpedGrayBytes: graded.photo.warpedBytes,
        layout: layout,
        correctFlags: graded.result.correctFlags,
        studentCodeRaw: scan.studentCodeRaw,
        examCodeRaw: scan.examCodeRaw,
      ));
      final sheet = GradedSheet(
        contestId: contest.id,
        examCode: graded.usedExamCode,
        studentCode: scan.studentCode,
        chosen: graded.photo.scan.answers,
        correctFlags: graded.result.correctFlags,
        score: graded.result.score,
        keyId: graded.usedKey?.id,
        studentId: graded.student?.id,
        partScores: graded.result.partScores,
        originalImagePath: origPath,
        markedImagePath: markedPath,
        gradedAt: DateTime.now(),
      );
      await ref.read(gradedSheetRepositoryProvider).insert(sheet);
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.sheetSavedMessage(
            scan.studentCode, _scoreText(graded.result.score))),
      ));
      navigator.pop(); // về màn trước (chi tiết kỳ thi)
      return true;
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.scanError(e.toString()))));
      return false;
    }
  }

  String _scoreText(double score) =>
      score % 1 == 0 ? score.toStringAsFixed(0) : score.toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.scanLoadingData),
          ],
        ),
      );
    }
    if (_contest == null) {
      return Center(child: Text(l10n.scanContestMissing));
    }
    if (_busy) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.scanProcessing),
          ],
        ),
      );
    }
    final camera = _controller;
    final cameraReady = camera != null && camera.value.isInitialized;
    if (!cameraReady || _cameraFailed) {
      return _FallbackPicker(l10n: l10n, onPick: _pickImage);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(camera),
        Positioned.fill(child: CustomPaint(painter: const _GuidancePainter())),
        Positioned(
          left: 12,
          right: 12,
          bottom: 108,
          child: Text(
            l10n.scanGuidance,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              backgroundColor: Colors.black38,
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: _PickIconButton(onPick: _pickImage, tooltip: l10n.scanPickSheetImage),
        ),
        Positioned(
          bottom: 24,
          right: (MediaQuery.of(context).size.width / 2) - 36,
          child: FloatingActionButton(
            backgroundColor: Colors.orange,
            tooltip: l10n.scanCapture,
            onPressed: _capture,
            child: const Icon(Icons.camera_alt),
          ),
        ),
      ],
    );
  }
}

/// Nút chọn ảnh từ tệp (trên preview và trong màn dự phòng).
final class _PickIconButton extends StatelessWidget {
  const _PickIconButton({required this.onPick, required this.tooltip});

  final VoidCallback onPick;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      icon: const Icon(Icons.photo_outlined),
      onPressed: () => onPick(),
    );
  }
}

/// Màn dự phòng khi camera không khả dụng: hướng dẫn + chọn ảnh từ tệp.
final class _FallbackPicker extends StatelessWidget {
  const _FallbackPicker({required this.l10n, required this.onPick});

  final AppLocalizations l10n;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(l10n.scanCameraUnavailable, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.photo_outlined),
              label: Text(l10n.scanPickSheetImage),
              onPressed: onPick,
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlay ngắm: chữ nhật trong suốt tối với "cửa sổ" trong suốt giữa —
/// khớp tỉ lệ trang A4 của phiếu.
final class _GuidancePainter extends CustomPainter {
  const _GuidancePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const pageRatio = 1240 / 1754; // SheetLayout.standardPage
    var windowW = size.width * 0.86;
    var windowH = windowW / pageRatio;
    if (windowH > size.height * 0.66) {
      windowH = size.height * 0.66;
      windowW = windowH * pageRatio;
    }
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: windowW,
      height: windowH,
    );
    final full = Offset.zero & size;
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
  }

  @override
  bool shouldRepaint(_GuidancePainter oldDelegate) => false;
}

/// Bottom sheet kết quả: điểm + thống kê + SBD/mã đề/học sinh + điểm phần.
final class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.graded,
    required this.contest,
    required this.onSave,
    required this.onScanAnother,
  });

  final GradedScan graded;
  final Contest contest;
  final VoidCallback onSave;
  final VoidCallback onScanAnother;

  String _scoreText(double score) =>
      score % 1 == 0 ? score.toStringAsFixed(0) : score.toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = graded.result;
    final scan = graded.photo.scan;
    final studentName = graded.student?.fullName ?? l10n.resultStudentNotFound;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.resultTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.resultScore(
                _scoreText(result.score), _scoreText(contest.maxScore)),
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.resultStats(result.correctCount, result.incorrectCount,
                result.unansweredCount),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ResultRow(l10n.resultStudentCodeLabel, scan.studentCodeRaw),
          _ResultRow(l10n.resultExamCodeLabel, graded.usedExamCode),
          _ResultRow(l10n.resultStudentLabel, studentName),
          if (graded.usedBestGuessKey) ...[
            const SizedBox(height: 8),
            Text(l10n.resultBestGuessNote,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (contest.formType == SheetFormType.ministry &&
              result.partScores.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l10n.detailPartScoresTitle,
                style: Theme.of(context).textTheme.titleMedium),
            for (final entry in result.partScores.entries)
              Text(l10n.partScoreLine(entry.key, _scoreText(entry.value))),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.resultSave),
            onPressed: onSave,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(l10n.resultScanAnother),
            onPressed: onScanAnother,
          ),
        ],
      ),
    );
  }
}

/// Dòng nhãn — giá trị trong sheet kết quả.
final class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: '),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}