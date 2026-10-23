// Màn chấm phiếu bằng camera (R1): preview TỰ DO (không còn ô ngắm chữ nhật),
// overlay đồng thời "Đã đủ 4 mốc" khi bộ phát hiện thấy đủ 4 ô vuông trong
// luồng preview; nút chụp LUÔN bật; chấm trong isolate; thiếu mốc → màn ghim
// 4 ô vuông đen (CropReviewScreen) rồi chạy lại pipeline trên ảnh đã nắn.
//
// Quy ước an toàn:
// - Camera chỉ khởi tạo trên Android/iOS (Platform check) và MỌI lệnh camera
//   phải bọc try/catch — lỗi camera không bao giờ làm crash app.
// - Khi không có camera (Windows/test/phiên bản thiếu quyền) → hiển thị hướng
//   dẫn + nút chọn ảnh từ tệp (file_picker): luồng chấm vẫn chạy được.

import 'dart:io';
import 'dart:isolate';
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
import '../../data/cv/sheet_alignment.dart';
import '../../data/cv/sheet_render_io.dart' show saveScannedImages;
import '../../domain/entities/class_room.dart';
import '../../domain/entities/contest.dart';
import '../../domain/entities/graded_sheet.dart';
import '../../domain/entities/sheet_spec.dart';
import '../../domain/services/sheet_layout.dart';
import '../state/providers.dart';
import 'crop_review_screen.dart';

/// Bề rộng mục tiêu khi lấy mẫu luồng Y (đồng bộ [SheetMarkerDetector]).
const int _previewTargetWidth = 640;

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

  /// Overlay mốc: null = chưa biết; true = đã thấy đủ 4 mốc trong luồng.
  bool? _markersReady;

  /// Đang phân tích 1 khung preview (trong isolate) — chặn chồng khung.
  bool _analyzing = false;

  /// R2: thời điểm bắt đầu lần phân tích trước (throttle ≤ ~4 lần/giây).
  DateTime? _lastAnalysisStart;

  /// R2: khoảng nghỉ tối thiểu giữa hai lần phân tích khung preview.
  static const Duration _analysisInterval = Duration(milliseconds: 250);

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
        final keyStream = await ref
            .read(answerKeyRepositoryProvider)
            .watchByContest(contest.id)
            .first;
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
        // YUV420 để đọc kênh Y trên luồng preview (băng "đã đủ 4 mốc").
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _startMarkerOverlay();
    } catch (_) {
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  /// Overlay "đã đủ 4 mốc": lấy mẫu kênh Y của khung preview, gửi isolate chạy
  /// [SheetMarkerDetector.detectGray]; khung nằm ngang (sensor quay 90°) thì
  /// thử thêm chiều xoay. Lỗi nào → tắt overlay, không lan lỗi lên UI.
  void _startMarkerOverlay() {
    final controller = _controller;
    if (controller == null) return;
    try {
      controller.startImageStream(_onCameraImage);
    } catch (_) {
      // Luồng preview không hỗ trợ: bỏ overlay, luồng chấm vẫn bình thường.
    }
  }

  void _onCameraImage(CameraImage image) {
    if (_analyzing || _busy || !mounted) return;
    if (image.planes.isEmpty) return;
    final y = image.planes.first;
    final width = image.width;
    final height = image.height;
    final stride = y.bytesPerRow;
    if (stride * (height - 1) + width > y.bytes.length) return; // khung cụt

    // R2: giới hạn tần suất phân tích (≤ ~4 lần/giây) — phát hiện mốc không
    // cần 30 fps; phần khung thừa chỉ tốn pin/CPU và gây giật preview.
    final now = DateTime.now();
    final last = _lastAnalysisStart;
    if (last != null &&
        now.difference(last) < _analysisInterval) {
      return;
    }
    _lastAnalysisStart = now;

    _analyzing = true;
    // R2: toàn bộ việc lấy mẫu kênh Y chạy TRONG isolate — thread UI không
    // quét pixel nữa, chỉ gửi nguyên khung bytes (~<1 MB) đi.
    final bytes = Uint8List.sublistView(y.bytes);
    Isolate.run(() => _analyzeMarkerFrame(bytes, stride, width, height))
        .then((ready) {
      _analyzing = false;
      if (!mounted || _busy) return;
      if (ready != _markersReady) {
        setState(() => _markersReady = ready);
      }
    }).catchError((Object _) {
      _analyzing = false;
      // Khung lỗi (memory/rotation lạ): bỏ qua, khung sau tiếp tục phân tích.
    });
  }

  /// Hàm top-level cho isolate (R2): lấy mẫu kênh Y về bề rộng
  /// [_previewTargetWidth], rồi chạy detector trên ảnh thu nhỏ — chưa đủ
  /// mốc thì thử xoay 90° (sensor preview có thể nằm ngang → không tin cậy).
  static bool _analyzeMarkerFrame(
      Uint8List planeBytes, int stride, int width, int height) {
    final f = (width ~/ _previewTargetWidth).clamp(1, width);
    final dw = width ~/ f;
    final dh = height ~/ f;
    final gray = Uint8List(dw * dh);
    for (var dy = 0; dy < dh; dy++) {
      final srcRow = stride * (dy * f);
      for (var dx = 0; dx < dw; dx++) {
        gray[dy * dw + dx] = planeBytes[srcRow + dx * f];
      }
    }
    return _detectWithRotations(gray, dw, dh);
  }

  /// Thử ảnh thu nhỏ, chưa đủ thì thử xoay 90°
  /// (sensor preview có thể nằm ngang → tỉ lệ khung bị lệch, không tin cậy).
  static bool _detectWithRotations(Uint8List gray, int w, int h) {
    const detector = SheetMarkerDetector();
    if (detector.detectGray(gray, width: w, height: h).hasAllMarkers) {
      return true;
    }
    // Xoay 90°: điểm ảnh (x, y) → (y, w - 1 - x) trên ảnh mới (bề rộng h).
    final rotated = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        rotated[y * h + (w - 1 - x)] = gray[y * w + x];
      }
    }
    return detector.detectGray(rotated, width: h, height: w).hasAllMarkers;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Chụp ảnh → quét + chấm. Nút chụp LUÔN bật (R1): chụp khi chưa đủ mốc
  /// vẫn ổn — thiếu mốc sẽ rơi vào màn ghim mốc.
  Future<void> _capture() async {
    if (_busy || _loading) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      try {
        await controller.stopImageStream(); // ngừng luồng preview cho nhẹ.
      } catch (_) {
        // ngừng tốt nhất có thể; chụp vẫn tiếp tục.
      }
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _process(Uint8List.fromList(bytes));
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

  /// Quét + chấm ảnh (isolate): đủ mốc → bottom sheet kết quả; thiếu mốc →
  /// màn ghim 4 ô vuông đen, ghim xong nắn phẳng → chạy lại pipeline.
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
      await _openCrop(bytes);
    } else {
      await _showResult(graded);
    }
  }

  Future<void> _openCrop(Uint8List bytes) async {
    if (!mounted) return;
    final contest = _contest;
    if (contest == null) return;
    final layout =
        SheetLayout.forSpec(contest.sheetSpec, page: SheetLayout.standardPage);
    final rectified = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => CropReviewScreen(imageBytes: bytes, layout: layout),
      ),
    );
    if (rectified != null) await _process(rectified);
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
  /// trong isolate (R2) rồi insert hàng DB; thành công → snackbar + pop.
  Future<bool> _save(GradedScan graded) async {
    final contest = _contest;
    if (contest == null) return false;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final scan = graded.photo.scan;
      final docsDir = await getApplicationDocumentsDirectory();
      final layout =
          SheetLayout.forSpec(contest.sheetSpec, page: SheetLayout.standardPage);
      final ts = DateTime.now().millisecondsSinceEpoch;
      // R2: decode + renderMarkedSheet + ghi 2 tệp PNG chạy TRONG isolate —
      // thread UI không bị treo ~1s+ khi bấm "Lưu kết quả".
      final saved = await saveScannedImages(
        warpedBytes: graded.photo.warpedBytes,
        directoryPath: p.join(docsDir.path, 'sheets', 'contest_${contest.id}'),
        timestamp: ts,
        layout: layout,
        correctFlags: graded.result.correctFlags,
        studentCodeRaw: scan.studentCodeRaw,
        examCodeRaw: scan.examCodeRaw,
      );
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
        originalImagePath: saved.originalPath,
        markedImagePath: saved.markedPath,
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
        // R1: không còn ô ngắm — chụp tự do; chỉ báo khi đủ 4 mốc mới hiện.
        if (_markersReady == true)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: _MarkerBanner(label: l10n.scanMarkerOverlayLocated),
            ),
          ),
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
          bottom: 148,
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

/// Băng thông báo "Đã đủ 4 mốc" trên preview.
final class _MarkerBanner extends StatelessWidget {
  const _MarkerBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
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
