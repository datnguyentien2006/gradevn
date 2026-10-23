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
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/cv/preview_overlay.dart'
    show CoverMapping, onConfidentMarkerCount, snapSquareCenters;
import '../../data/cv/scan_flow.dart'
    show GradedScan, UngradedReason, processPhoto;
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

  /// R2: kết quả phân tích khung preview mới nhất — ứng viên mốc theo TỈ LỆ
  /// khung HIỂN THỊ + kích thước khung; null = chưa lần phân tích nào khớp
  /// (không snap, chụp dùng detector như cũ).
  _LiveFrame? _liveMarkers;

  /// R2: tâm 4 ô vuông (TỈ LỆ của vùng preview). Thứ tự 1..4 =
  /// trái-trên → phải-trên → phải-dưới → trái-dưới (như ghim CropReview).
  List<Offset>? _squareCenters;

  /// R2: ô còn được snap tự động? Kéo tay xong sẽ tắt snap cho ô đó.
  final List<bool> _autoSnap = <bool>[true, true, true, true];

  /// R2: ô đang bị kéo (không snap trong khi cầm tay).
  int? _draggingIndex;

  /// R2: kích thước vùng preview (đo lần build gần nhất) — cần cho quy đổi
  /// khung ↔ màn hình và tính khoảng cách snap.
  Size _previewArea = Size.zero;

  /// R2: cỡ ô vuông trên màn hình (px lợi).
  static const double _squareSize = 76;

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
        .then((frame) {
      if (_analyzing) {
        _analyzing = false;
      } else {
        return; // đã dispose/đổi trạng thái trong lúc isolate chạy.
      }
      if (!mounted || _busy) return;
      if (frame == null) {
        // Không xác định được phương hướng hiển thị: bỏ snap, giữ vị trí ô.
        _liveMarkers = null;
        return;
      }
      setState(() {
        _liveMarkers = frame;
        _snapSquares();
      });
    }).catchError((Object _) {
      _analyzing = false;
      // Khung lỗi (memory/rotation lạ): bỏ qua, khung sau tiếp tục phân tích.
    });
  }

  /// R2: snap các ô còn bật snap tự động vào ứng viên gần nhất (đơn vị px
  /// màn hình) — bỏ qua ô đang kéo và ô đã bị phủ toạ độ tay.
  void _snapSquares() {
    final centers = _squareCenters;
    final area = _previewArea;
    final lm = _liveMarkers;
    if (centers == null || area == Size.zero || lm == null) return;
    final frame = lm.frameSize;
    final mapping = CoverMapping(frame: frame, screen: area);
    final candidates = <Offset>[
      for (final c in lm.candidates)
        mapping.toScreen(Offset(c.dx * frame.width, c.dy * frame.height)),
    ];
    final snap = snapSquareCenters(
      [for (final c in centers) Offset(c.dx * area.width, c.dy * area.height)],
      candidates,
      area.shortestSide * 0.25,
    );
    var changed = false;
    final next = List<Offset>.from(centers);
    for (var i = 0; i < next.length && i < snap.length; i++) {
      if (!_autoSnap[i] || _draggingIndex == i) continue;
      final target = snap[i];
      if (target == null) continue;
      next[i] = Offset(target.dx / area.width, target.dy / area.height);
      changed = true;
    }
    if (changed) _squareCenters = next;
  }

  /// Hàm top-level cho isolate (R2): lấy mẫu kênh Y về bề rộng
  /// [_previewTargetWidth], rồi chạy detector trên CẢ HAI phương hướng
  /// (thẳng / xoay 90°) vì buffer sensor có thể nằm ngang. Chọn phương
  /// hướng mà QUAD nội dung DỰNG ĐỨNG (bbox cao > rộng — phiếu dựng đứng
  /// trên preview dọc) để overlay khớp màn hình.
  ///
  /// Trả về `_LiveFrame` với ứng viên mốc theo TỈ LỆ khung đã chọn;
  /// không phương hướng nào đạt → null (UI không snap, chụp dùng detector).
  static _LiveFrame? _analyzeMarkerFrame(
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

    const detector = SheetMarkerDetector();
    // Chiều thẳng: khung dw×dh.
    final straight = detector.detectGray(gray, width: dw, height: dh);
    // Xoay 90°: (x, y) → (y, w - 1 - x), khung dh×dw.
    final rotated = Uint8List(dw * dh);
    for (var y = 0; y < dh; y++) {
      for (var x = 0; x < dw; x++) {
        rotated[y * dh + (dw - 1 - x)] = gray[y * dw + x];
      }
    }
    final rot = detector.detectGray(rotated, width: dh, height: dw);

    // Quy đổi ứng viên theo TỈ LỆ khung đã chọn (độc lập với f lấy mẫu).
    _LiveFrame? build(MarkerDetection det, int fw, int fh) {
      if (det.quad == null) return null;
      if (!_portraitBox(det.quad!)) return null; // nội dung không dựng đứng
      return _LiveFrame(
        ready: true,
        candidates: [
          for (final c in det.candidates)
            Offset(
              (c.dx / fw).clamp(0.0, 1.0).toDouble(),
              (c.dy / fh).clamp(0.0, 1.0).toDouble(),
            ),
        ],
        frameWidth: fw,
        frameHeight: fh,
      );
    }

    // Ưu tiên hướng XOAY (sensor ngang + màn dọc là phổ biến), rồi hướng thấp.
    return build(rot, dh, dw) ?? build(straight, dw, dh);
  }

  /// Bbox của quad có thảo (cao > rộng) — nội dung dựng đứng theo trục ảnh.
  static bool _portraitBox(AlignmentQuad quad) {
    final xs = <double>[quad.tl.dx, quad.tr.dx, quad.br.dx, quad.bl.dx];
    final ys = <double>[quad.tl.dy, quad.tr.dy, quad.br.dy, quad.bl.dy];
    final w = xs.reduce(math.max) - xs.reduce(math.min);
    final h = ys.reduce(math.max) - ys.reduce(math.min);
    return h > w;
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
      // R2: khi có khung + 4 ô vuông → truyền quad ghim làm lưới phòng hờ:
      // detector ưu tiên; detector bó tay mới warp theo vị trí ô vuông.
      final overlay = _captureOverlayQuad();
      await _process(
        Uint8List.fromList(bytes),
        overlayQuad: overlay?.$1,
        frameSize: overlay?.$2 ?? const Size(1, 1),
      );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.scanError(e.toString()))));
    }
  }

  /// R2: "Chỉnh thủ công" — chụp ảnh rồi mở màn GHIM MỐC (bỏ phát hiện):
  /// đường dự phòng cho phiếu mốc phai/nhiều lỗi in.
  Future<void> _captureManual() async {
    if (_busy || _loading) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      try {
        await controller.stopImageStream();
      } catch (_) {
        // ngừng tốt nhất có thể.
      }
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _openCrop(Uint8List.fromList(bytes));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.scanError(e.toString()))));
    }
  }

  /// R2: quad ghim theo hệ KHUNG HIỂN THỊ (nghịch của TỈ LỆ ô vuông xa tâm
  /// khung có sẵn _liveMarkers) + tamaño khung — pipeline dùng làm lưng dự phòng.
  (AlignmentQuad, Size)? _captureOverlayQuad() {
    final lm = _liveMarkers;
    final centers = _squareCenters;
    if (lm == null || centers == null || centers.length < 4) return null;
    Offset toFrame(Offset c) =>
        Offset(c.dx * lm.frameWidth, c.dy * lm.frameHeight);
    final quad = AlignmentQuad(
      toFrame(centers[0]), // trái-trên
      toFrame(centers[1]), // phải-trên
      toFrame(centers[2]), // phải-dưới
      toFrame(centers[3]), // trái-dưới
    );
    return (quad, lm.frameSize);
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
  ///
  /// R2: \[overlayQuad\] + \[frameSize\] = quad ghim ở hệ khung hiển thị
  /// (dự phòng khi detector bó tay); \[knownQuad\] = quad hệ ảnh chụp khi
  /// biết chắc (ảnh đã nắn từ CropReviewScreen).
  Future<void> _process(
    Uint8List bytes, {
    AlignmentQuad? overlayQuad,
    Size frameSize = const Size(1, 1),
    AlignmentQuad? knownQuad,
  }) async {
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
        overlayQuad: overlayQuad,
        frameSize: frameSize,
        knownQuad: knownQuad,
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
    if (rectified != null) {
      // R2: ảnh đã nắn về TRANG CHUẨN → 4 mốc góc nằm đúng vị trí chuẩn của
      // trang; truyền quad trực tiếp để pipeline KHÔNG phát hiện lại (mốc
      // phai/mất 1 góc vẫn chấm được) — sửa lỗi lặp CropReview ở M3.
      final c = layout.cornerMarkerCenters;
      await _process(
        rectified,
        knownQuad: AlignmentQuad(c[0], c[1], c[2], c[3]),
      );
    }
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
      // R2: phiếu bỏ chấm (NULL) → lưu mã đề '' (khi trống) / SBD ''
      // (khi SBD trống) — dấu hiệu "chờ bổ sung"; score 0 + cờ all null.
      final studentCode = !graded.graded && scan.studentCodeEmpty
          ? ''
          : scan.studentCode;
      final sheet = GradedSheet(
        contestId: contest.id,
        examCode: graded.usedExamCode,
        studentCode: studentCode,
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
        content: Text(
          !graded.graded
              ? l10n.sheetSavedUnresolved
              : l10n.sheetSavedMessage(
                  scan.studentCode, _scoreText(graded.result.score)),
        ),
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
    return LayoutBuilder(builder: (context, constraints) {
      // R2: kích thước vùng preview — dùng cho quy đổi khung ↔ màn hình.
      _previewArea = constraints.biggest;
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(camera),
          // R2: 4 ô vuông đánh số (1..4) — KÉO được; snap tự động về ứng
          // viên mốc khi detector tự nhìn thấy. Vị trí ban đầu: 4 góc.
          ..._buildSquares(),
          // Chỉ báo: pill xanh khi đủ 4 ô nằm trên mốc; ngược lại gợi ý kéo.
          Positioned(
            left: 12,
            right: 12,
            bottom: 116,
            child: Center(
              child: _StatePill(green: _allSquaresOnMarkers, label: _allSquaresOnMarkers
                  ? l10n.scanMarkerOverlayLocated
                  : l10n.scanDragHint),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 148,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.center_focus_weak, size: 18),
              onPressed: _captureManual,
              label: Text(l10n.scanManualFix),
            ),
          ),
          Positioned(
            right: 12,
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
    });
  }

  /// R2: 4 ô vuông mốc — vị trí mặc định ở 4 góc, kéo tự do, snap khi
  /// detector tự tìm được. Trả về danh sách widget `Positioned`.
  List<Widget> _buildSquares() {
    // Khởi tạo vị trí mặc định tôi lần đầu build (theo tỉ lệ vùng preview).
    _squareCenters ??= const <Offset>[
      Offset(0.15, 0.30), // 1 — trái-trên
      Offset(0.85, 0.30), // 2 — phải-trên
      Offset(0.85, 0.70), // 3 — phải-dưới
      Offset(0.15, 0.70), // 4 — trái-dưới
    ];
    final area = _previewArea;
    final ready = _allSquaresOnMarkers;
    final squares = <Widget>[];
    for (var i = 0; i < 4; i++) {
      final c = _squareCenters![i];
      final px = Offset(c.dx * area.width, c.dy * area.height);
      final color = ready
          ? Colors.white.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.28);
      squares.add(Positioned(
        key: ObjectKey(i),
        left: px.dx - _squareSize / 2,
        top: px.dy - _squareSize / 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _draggingIndex = i,
          onPanUpdate: (d) => _moveSquare(i, d.delta),
          onPanEnd: (_) {
            _draggingIndex = null;
            // Kéo tay xong: tắt snap cho ô này — giữ đúng vị trí giáo viên.
            if (_autoSnap[i]) setState(() => _autoSnap[i] = false);
          },
          onPanCancel: () => _draggingIndex = null,
          child: Container(
            width: _squareSize,
            height: _squareSize,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ready ? Colors.white : Colors.white.withValues(alpha: 0.85),
                width: 2,
              ),
              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(1, 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return squares;
  }

  /// R2: kéo ô vuông — cập nhật TỈ LỆ, kẹp biên (cách mép ít nhất 4%).
  void _moveSquare(int index, Offset delta) {
    final area = _previewArea;
    if (area.width <= 0 || area.height <= 0) return;
    setState(() {
      final c = _squareCenters![index];
      final next = Offset(
        c.dx + delta.dx / area.width,
        c.dy + delta.dy / area.height,
      );
      _squareCenters![index] = Offset(
        next.dx.clamp(0.04, 0.96).toDouble(),
        next.dy.clamp(0.04, 0.96).toDouble(),
      );
    });
  }

  /// R2: đủ 4 mốc? — cả 4 ô tâm nằm < 60% cỡ ô trên ứng viên mốc màn hình.
  bool get _allSquaresOnMarkers {
    final centers = _squareCenters;
    final lm = _liveMarkers;
    final area = _previewArea;
    if (centers == null || lm == null || area == Size.zero) return false;
    final frame = lm.frameSize;
    final mapping = CoverMapping(frame: frame, screen: area);
    final candidates = <Offset>[
      for (final c in lm.candidates)
        mapping.toScreen(Offset(c.dx * frame.width, c.dy * frame.height)),
    ];
    return onConfidentMarkerCount(
          [
            for (final c in centers)
              Offset(c.dx * area.width, c.dy * area.height),
          ],
          candidates,
          _squareSize * 0.6,
        ) >=
        4;
  }
}

/// R2: pill trạng thái overlay — xanh khi đủ 4 ô nằm trên mốc, nhạt khi
/// đang để giáo viên kéo/thiếu mốc.
final class _StatePill extends StatelessWidget {
  const _StatePill({required this.green, required this.label});

  final bool green;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: green ? Colors.green.shade700 : Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            green ? Icons.check_circle_outline : Icons.crop_square_outlined,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

/// R2: kết quả phân tích 1 khung preview (plain-data, gửi isolate được):
/// ứng viên mốc theo TỈ LỆ khung hiển thị + kích thước khung đã chọn.
final class _LiveFrame {
  const _LiveFrame({
    required this.ready,
    required this.candidates,
    required this.frameWidth,
    required this.frameHeight,
  });

  /// Detector tìm đủ 4 mốc góc theo phương hướng này.
  final bool ready;

  /// Ứng viên (TỈ LỆ 0..1 của khung đã chọn).
  final List<Offset> candidates;
  final int frameWidth;
  final int frameHeight;

  Size get frameSize =>
      Size(frameWidth.toDouble(), frameHeight.toDouble());
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
    // R2: cộng VIEW PADDING đáy (thanh điều hướng Android) vào đệm đáy —
    // hai nút "Lưu kết quả"/"Chụp phiếu khác" phải nổi trên thanh navigation.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
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
          // R2: phiếu BỎ chấm (lưới mã đề/SBD trống) → điểm "NULL" + lý do,
          // KHÔNG có dòng thống kê đúng/sai (không hề chấm).
          if (!graded.graded) ...[
            Text(
              l10n.resultNullScore,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              graded.ungradedReason == UngradedReason.examCode
                  ? l10n.resultNoExamCode
                  : l10n.resultNoStudentCode,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else ...[
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
          ],
          const SizedBox(height: 16),
          _ResultRow(
              l10n.resultStudentCodeLabel,
              scan.studentCodeEmpty ? '—' : scan.studentCodeRaw),
          _ResultRow(l10n.resultExamCodeLabel,
              graded.usedExamCode.isEmpty ? '—' : graded.usedExamCode),
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
