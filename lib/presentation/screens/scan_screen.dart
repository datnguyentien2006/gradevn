// Màn chấm phiếu bằng camera (R1→R3): preview TRÀN TOÀN MÀN HÌNH (không
// AppBar) đúng như ảnh tham chiếu obs_006.png của TN Maker; 4 ô vuông
// TRẮNG ĐẶC là PHÉP CHIẾU của 4 ô vuông đen góc phiếu theo khung phiếu ảo
// (aspect-fit trang chuẩn) — không phải trang trí ở góc màn; giáo viên kéo
// ô TRẮNG đè BAO TRỌN ô đen in trên phiếu (drag/snap R2), detector bám
// chắc thì ô KHOÁ viền xanh. Nút chụp LUÔN bật; chấm trong isolate; thiếu
// mốc → màn ghim 4 ô vuông đen (CropReviewScreen) rồi chạy lại pipeline
// trên ảnh đã nắn.
//
// Quy ước an toàn:
// - Camera chỉ khởi tạo trên Android/iOS (Platform check) và MỌI lệnh camera
//   phải bọc try/catch — lỗi camera không bao giờ làm crash app.
// - Khi không có camera (Windows/test/phiên bản thiếu quyền) → hiển thị hướng
//   dẫn + nút chọn ảnh từ tệp (file_picker): luồng chấm vẫn chạy được.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/cv/detection_proof.dart' show saveDetectionProof;
import '../../data/cv/preview_overlay.dart'
    show CoverMapping, MarkerOverlayCalibration, snapSquareCenters, squareLockStates;
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

/// R3 — Feature flag "Chỉnh thủ công": ĐANG TẮT. Nút + luồng ghim tay
/// (CropReview) vẫn được giữ nguyên implementation (biên dịch + test xanh)
/// dành cho phiếu MỐC PHAI về sau — bật `true` là nút hiện lại ngay.
const bool showManualAlignment = false;

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
  /// R3: vị trí mặc định bám PHÉP CHIẾU mốc góc; kéo tay (R2) vẫn giữ làm
  /// dự phòng mốc phai — ô đã kéo tắt snap, chụp thiếu mốc → CropReview.
  List<Offset>? _squareCenters;

  /// R2: ô còn được snap tự động? Kéo tay xong sẽ tắt snap cho ô đó.
  final List<bool> _autoSnap = <bool>[true, true, true, true];

  /// R2: ô đang bị kéo (không snap trong khi cầm tay).
  int? _draggingIndex;

  /// R2: kích thước vùng preview (đo lần build gần nhất) — cần cho quy đổi
  /// khung ↔ màn hình và tính khoảng cách snap.
  /// R3.3: TRONG MÀN HÌNH (preview tràn toàn màn y hệt TNMaker — đo từ ảnh
  /// tham chiếu: camera phủ kín màn, KHÔNG letterbox).
  Size _previewArea = Size.zero;

  /// R3.2: offset vùng preview trong canvas (R3.3: preview tràn màn → 0).
  /// Giữ làm tham số dự phòng cho painter.
  final Offset _previewOrigin = Offset.zero;

  /// R3.4: vị trí + cỡ ô overlay = CALIBRATION THỰC ĐỊA do người dùng đo
  /// từ ảnh tham chiếu TNMaker — màn chụp DỌC nên `forArea` chọn bản DỌC
  /// (720×1560): ô **181×227** (bảng đo 157×203 + inset **24 px**, R3.4
  /// lượt 2 "tăng thêm nữa"; tâm KHÔNG đổi — ô phình quanh tâm cũ, phần
  /// dư tràn nhẹ ra mép như kiểu TNMaker ô sát mép), 2 cột tâm x =
  /// 78.5 / 641.5, hàng trên tâm y = 165.5, hàng dưới tâm y = 1076.5.
  /// Preview tràn màn bóp nhẹ (như ảnh tham chiếu, preset 16:9 để bóp ít
  /// nhất ~1.22×) nhưng bảng đo lấy TRÊN CÙNG kiểu render đó.

  /// R3.4: kích thước khung ô theo calibration HƯỚNG-THỨC
  /// ([MarkerOverlayCalibration.forArea]) — ô 181×227 trên màn dọc.
  Size get _markerBoxSize {
    final area = _previewArea;
    if (area.width <= 0 || area.height <= 0) {
      return const Size(60, 78);
    }
    final cal = MarkerOverlayCalibration.forArea(area);
    return Size(
      cal.widthFraction * area.width,
      cal.heightFraction * area.height,
    );
  }

  /// R3: cỡ ô "tương đương" = cạnh dài khung ô calibrated (dùng cho bán kính
  /// khoá và cỡ chữ): ô 163×209 không đều hai cạnh nên lấy cạnh lớn.
  double get _markerVisualSide => math.max(
        _markerBoxSize.width,
        _markerBoxSize.height,
      );

  /// R3: bán kính "khoá" — tâm ô cách một ứng viên mốc ≤ 0.75 × cạnh dài khung
  /// (nửa đường chéo khung ≈ 0.62 × cạnh dài; 0.75 đủ lỏng cho ngón tay/contact
  /// giữa ô overlay và mốc detect được trong khung).
  double get _lockRadius => _markerVisualSide * 0.75;

  /// Đang phân tích 1 khung preview (trong isolate) — chặn chồng khung.
  bool _analyzing = false;

  /// R2: thời điểm bắt đầu lần phân tích trước (throttle ≤ ~4 lần/giây).
  DateTime? _lastAnalysisStart;

  /// R2: khoảng nghỉ tối thiểu giữa hai lần phân tích khung preview.
  static const Duration _analysisInterval = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    // R3.4: màn chụp quay về HƯỚNG DỌC (yêu cầu người dùng 2026-10-24).
    // Preview tràn màn trên màn dọc dài có bóp nhẹ nhưng bảng đo 4 ô đã
    // được đo TRÊN CÙNG kiểu render dọc (720×1560) nên khớp 1-1 ảnh tham
    // chiếu TNMaker (bản dọc). Lock dọc để không xoay khung giữa chừng
    // làm lệch overlay.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
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
        // R3.4: veryHigh = 1920×1080 + chiến lược 16:9. Màn dọc dài
        // (19.5:9..20:9 ≈ 0.46) phủ buffer 16:9 (0.56) BÓP CHỈ ~1.22×;
        // nếu buffer 4:3 (0.75) sẽ bóp ~1.63× — nhiều hơn hẳn. Ảnh chụp
        // 1080p vẫn đủ nét cho pipeline chấm (warp về trang chuẩn).
        ResolutionPreset.veryHigh,
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
    // R3.4: màn chụp KHÓA DỌC (initState) → khung xoay 90° khớp màn dọc.
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

  /// R2: snap các ô CÒN BẬT snap tự động vào ứng viên gần nhất (đơn vị px
  /// màn hình) — bỏ qua ô đang kéo và ô đã bị phủ toạ độ tay. R3: mặc định
  /// mọi ô bật snap (bám phép chiếu); kéo tay tắt snap đúng ô đó.
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
  /// (thẳng / xoay 90°) vì buffer sensor có thể không khớp hướng màn.
  /// R3.1: chọn phương hướng theo HƯỚNG MÀN — màn [landscapeDisplay]:
  /// khung thẳng khớp màn ngang (sensor ∥ màn); màn dọc: khung xoay 90°
  /// (sensor ngang + màn dọc là phổ biến). Chọn phương hướng mà QUAD nội
  /// dung DỰNG ĐỨNG theo hướng màn để overlay khớp màn hình.
  ///
  /// Trả về `_LiveFrame` với ứng viên mốc theo TỈ LỆ khung đã chọn;
  /// không phương hướng nào đạt → null (UI không snap, chụp dùng detector).
  static _LiveFrame? _analyzeMarkerFrame(
      Uint8List planeBytes, int stride, int width, int height,
      {bool landscapeDisplay = false}) {
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
      if (!_uprightBox(det.quad!, landscapeDisplay)) {
        return null; // nội dung không dựng đứng theo hướng màn
      }
      Offset frac(Offset p) => Offset(
            (p.dx / fw).clamp(0.0, 1.0).toDouble(),
            (p.dy / fh).clamp(0.0, 1.0).toDouble(),
          );
      final fq = det.quad!;
      return _LiveFrame(
        ready: true,
        candidates: [
          for (final c in det.candidates)
            Offset(
              (c.dx / fw).clamp(0.0, 1.0).toDouble(),
              (c.dy / fh).clamp(0.0, 1.0).toDouble(),
            ),
        ],
        // R3 (chỉ DEBUG dùng): quad theo tỉ lệ khung — painter pdbg.
        quad: AlignmentQuad(frac(fq.tl), frac(fq.tr), frac(fq.br), frac(fq.bl)),
        frameWidth: fw,
        frameHeight: fh,
      );
    }

    // Ưu tiên khung khớp HƯỚNG MÀN (R3.1): màn ngang → thẳng trước (buffer
    // ngang ∥ màn ngang); màn dọc → xoay trước (sensor ngang + màn dọc).
    if (landscapeDisplay) {
      return build(straight, dw, dh) ?? build(rot, dh, dw);
    }
    return build(rot, dh, dw) ?? build(straight, dw, dh);
  }

  /// Bbox của quad có khớp HƯỚNG MÀN để nội dung "dựng đứng" trên preview:
  /// màn dọc → phiếu dựng đứng ⇒ bbox CAO > RỘNG; màn ngang → phiếu nằm
  /// NGANG theo khung màn (cùng tư thế đọc phiếu của TNMaker) ⇒ bbox
  /// RỘNG > CAO.
  static bool _uprightBox(AlignmentQuad quad, bool landscapeDisplay) {
    final xs = <double>[quad.tl.dx, quad.tr.dx, quad.br.dx, quad.bl.dx];
    final ys = <double>[quad.tl.dy, quad.tr.dy, quad.br.dy, quad.bl.dy];
    final w = xs.reduce(math.max) - xs.reduce(math.min);
    final h = ys.reduce(math.max) - ys.reduce(math.min);
    return landscapeDisplay ? w > h : h > w;
  }

  @override
  void dispose() {
    // R3.4: màn chụp dùng DỌC (lock portraitUp trong initState) — rời màn
    // vẫn trả dọc (app toàn bộ chạy dọc).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
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
  /// R3: ẨN sau feature flag [showManualAlignment] (giữ implementation,
  /// sẽ bật lại cho phiếu mốc phai — KHÔNG xoá).
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
  /// khung có sẵn _liveMarkers) + kích thước khung — pipeline dùng làm lưới dự phòng.
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

  /// Quét + chấm ảnh (isolate): đủ mốc → màn kết quả tức thời; thiếu mốc →
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
    // R3 (chỉ DEBUG): lưu bằng chứng annotate qua isolate — KHÔNG chặn luồng
    // (fire-and-forget); bản release không hề chạy nhánh này.
    if (kDebugMode) {
      unawaited(_saveDebugProof(
        bytes,
        graded?.photo.detectedCandidates,
        graded?.photo.quad,
      ));
    }
    if (graded == null) {
      await _openCrop(bytes);
    } else {
      await _showResult(graded, captureBytes: bytes);
    }
  }

  /// R3 (chỉ DEBUG): annotate ảnh chụp + ghi vào thư mục proof của app
  /// (adb-pull về → docs/evidence/). Lỗi nào cũng im lặng (proof không KHÔNG
  /// được làm hỏng luồng chấm).
  Future<void> _saveDebugProof(
    Uint8List photoBytes,
    List<Offset>? candidates,
    AlignmentQuad? quad,
  ) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final proofDir = p.join(docsDir.path, 'sheets', 'proof');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = await saveDetectionProof(
        photoBytes: photoBytes,
        directoryPath: proofDir,
        timestamp: ts,
        candidates: candidates,
        quad: quad,
      );
      if (path != null) debugPrint('[R3] detection proof: $path');
    } catch (e) {
      debugPrint('[R3] proof failed: $e');
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

  /// R3: thẻ kết quả XUẤT HIỆN NGAY sau chụp (không dialog phụ): đẩy màn
  /// toàn màn hình _ResultCardScreen; nền = ảnh chụp gốc làm mờ.
  Future<void> _showResult(GradedScan graded, {Uint8List? captureBytes}) async {
    if (!mounted) return;
    final contest = _contest;
    if (contest == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ResultCardScreen(
          graded: graded,
          contest: contest,
          backgroundImageBytes: captureBytes,
          onSave: () async {
            // R3: _save KHÔNG tự pop nữa — điều hướng do màn card đảm nhiệm:
            // lưu xong pop thẻ kết quả → pop màn chấm (về chi tiết kỳ thi).
            final ok = await _save(graded);
            if (ok && mounted) {
              Navigator.of(context).pop(); // pop thẻ kết quả
              Navigator.of(context).pop(); // pop màn chấm → chi tiết kỳ thi
            }
          },
          onScanAnother: () async {
            Navigator.of(context).pop(); // pop thẻ → về camera
          },
        ),
      ),
    );
    // Quay về camera sau "Chụp phiếu khác": mở lại luồng phân tích preview.
    if (mounted && !_busy) {
      _startMarkerOverlay();
    }
  }

  /// Lưu ảnh (gốc đã nắn phẳng + phiếu có gạch kết quả) vào thư mục tài liệu
  /// trong isolate (R2) rồi insert hàng DB; thành công → snackbar + pop.
  Future<bool> _save(GradedScan graded) async {
    final contest = _contest;
    if (contest == null) return false;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
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
      // R3: KHÔNG pop ở đây — màn thẻ kết quả điều hướng (pop thẻ → pop chấm).
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
    // obs_006 (TN Maker): preview camera TRÀN TOÀN MÀN HÌNH — KHÔNG AppBar;
    // quay lại bằng nút mờ góc trái trên (dưới đây) hoặc cử chỉ hệ thống.
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    // Nền đen fullscreen (obs_006) → chữ trạng thái màu trắng cho đọc được.
    const whiteText = TextStyle(color: Colors.white);
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 12),
            Text(l10n.scanLoadingData, style: whiteText),
          ],
        ),
      );
    }
    if (_contest == null) {
      return Center(
          child: Text(l10n.scanContestMissing, style: whiteText));
    }
    if (_busy) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 12),
            Text(l10n.scanProcessing, style: whiteText),
          ],
        ),
      );
    }
    final camera = _controller;
    final cameraReady = camera != null && camera.value.isInitialized;
    if (!cameraReady || _cameraFailed) {
      return _FallbackPicker(l10n: l10n, onPick: _pickImage);
    }
    // obs_006: nút điều khiển phải nổi TRÊN thanh nav Android (extendBody
    // để preview tràn xuống sau nav bar → cộng thêm padding hệ thống).
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final safeTop = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(builder: (context, constraints) {
      // R3.3: TRẢ VỀ PREVIEW TRÀN TOÀN MÀN (y hệt ảnh tham chiếu TNMaker:
      // camera phủ kín màn, KHÔNG letterbox). Không dùng widget
      // `CameraPreview` của plugin vì nó suy HƯỚNG từ CẢM BIẾN — màn khoá
      // NGANG + cầm máy dọc → nó áp 1/ratio (hộp dọc) → texture ngang bị ép
      // ngược chiều (nguyên nhân "bóp/gầy" đã báo). `buildPreview()` Texture
      // phóng phủ kín hộp — cùng kiểu render với ảnh tham chiếu nên bảng
      // đo calibration khớp 1-1.
      _previewArea = constraints.biggest;
      return Stack(
        fit: StackFit.expand,
        children: [
          // Nền đen dưới texture.
          const ColoredBox(color: Colors.black),
          // Preview TRÀN MÀN — cùng kiểu render TNMaker.
          Positioned.fill(child: camera.buildPreview()),
          // R3 (chỉ DEBUG): bằng chứng TRỰC QUAN trên preview — ứng viên
          // ứng viên (chấm đỏ + nhãn) + quad (xanh lá) từ luồng phân tích khung.
          if (kDebugMode && _liveMarkers != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DebugDetectionPainter(
                    live: _liveMarkers!,
                    area: _previewArea,
                    origin: _previewOrigin,
                  ),
                ),
              ),
            ),
          // obs_006: KHÔNG vẽ outline nét đứt — TN Maker chỉ hiển thị 4 ô
          // vuông trắng trên preview. R3.3: vị trí ô = calibration thực địa
          // (bản ngang, y hệt ảnh tham chiếu); kéo + snap + khoá giữ nguyên.
          ..._buildSquares(),
          // Nút quay lại mờ góc trái trên (obs_006 không thấy AppBar — nút
          // này tối giản để không phá cảnh quay).
          Positioned(
            left: 8,
            top: safeTop + 8,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black38,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          // Chỉ báo: pill xanh khi đủ 4 ô nằm trên mốc; ngược lại gợi ý canh.
          Positioned(
            left: 12,
            right: 12,
            bottom: 116 + safeBottom,
            child: Center(
              child: _StatePill(green: _allSquaresOnMarkers, label: _allSquaresOnMarkers
                  ? l10n.scanMarkerOverlayLocated
                  : l10n.scanDragHint),
            ),
          ),
          // R3: "Chỉnh thủ công" ẨN sau feature flag (prompt R3 #4: không xoá —
          // giữ nút + luồng ghim tay cho phiếu mốc phai, bật lại sau).
          if (showManualAlignment)
            Positioned(
              left: 12,
              bottom: 160 + safeBottom,
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
            bottom: 160 + safeBottom,
            child: _PickIconButton(onPick: _pickImage, tooltip: l10n.scanPickSheetImage),
          ),
          // obs_006/mockup camera_format.png: nút chụp = đĩa trắng tròn
          // giữa-dưới, nổi trên thanh nav Android.
          Positioned(
            bottom: 20 + safeBottom,
            left: (MediaQuery.sizeOf(context).width - 76) / 2,
            child: _ShutterButton(
              tooltip: l10n.scanCapture,
              onPressed: _capture,
            ),
          ),
        ],
      );
    });
  }

  /// R3: 4 ô vuông mốc — vị trí mặc định theo CALIBRATION THỰC ĐỊA
  /// ([MarkerOverlayCalibration.forArea], chuyển sang bản NGANG trên màn
  /// ngang: ô 203×157 sát mép, y hệt ảnh tham chiếu); kéo tự do (R2), snap
  /// khi detector tự tìm được, khoá → viền xanh. Danh sách THAY ĐỔI ĐƯỢC
  /// (không `const`) — R2-fix: _moveSquare gán phần tử (bug demo
  /// 2026-10-23: `const <Offset>[...]` làm ô đứng im vì UnsupportedError
  /// bị nuốt trong setState).
  List<Widget> _buildSquares() {
    final area = _previewArea;
    if (_squareCenters == null && area.width > 0) {
      _squareCenters = <Offset>[
        ...MarkerOverlayCalibration.forArea(area).centerFractions,
      ];
    }
    final centers = _squareCenters;
    if (centers == null) return const [];
    final locks = _lockStates() ?? const <bool>[false, false, false, false];
    final box = _markerBoxSize;
    final squares = <Widget>[];
    for (var i = 0; i < 4 && i < centers.length; i++) {
      final c = centers[i];
      final px =
          _previewOrigin + Offset(c.dx * area.width, c.dy * area.height);
      // obs_006 (TN Maker): ô TRẮNG ĐẶC, KHÔNG viền, KHÔNG bóng đổ — giáo
      // viên kéo ô trắng đè bao trọn ô đen in trên phiếu. Ô KHÓA (detector
      // bám chắc mốc): viền xanh + nền bớt đục để thấy mốc đã khớp bên dưới.
      // R3 (y hệt TNMaker): nền TRẮNG MỜ phẳng (~32% trên nền camera đen →
      // hiện xám nhạt như ảnh tham chiếu), GÓC VUÔNG, KHÔNG SỐ bên trong —
      // ô chỉ là mục tiêu căn phiếu, không phải nút nhãn.
      final locked = i < locks.length ? locks[i] : false;
      final fillColor = locked
          ? Colors.white.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.32);
      final borderColor =
          locked ? const Color(0xFF2E7D32) : Colors.transparent;
      // Trục hit phải rộng hơn trục vẽ (pad 12 mỗi phía) để ngón tay kéo
      // được cả ô mốc nhỏ khi camera gần phiếu.
      const hitPad = 12.0;
      squares.add(Positioned(
        key: ObjectKey(i),
        left: px.dx - box.width / 2 - hitPad,
        top: px.dy - box.height / 2 - hitPad,
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
          child: Padding(
            padding: const EdgeInsets.all(hitPad),
            child: Container(
              width: box.width,
              height: box.height,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: borderColor, width: locked ? 3 : 0),
              ),
              // R3: KHÔNG số 1..4 bên trong (y hệt TNMaker) — ô trống hoàn
              // toàn để không che khuất ô mốc đen đặt bên dưới khi căn phiếu.
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

  /// R2: đủ 4 mốc? — cả 4 ô tâm nằm trong bán kính khoá của ứng viên mốc màn hình.
  bool get _allSquaresOnMarkers {
    final states = _lockStates();
    if (states == null) return false;
    return states.every((locked) => locked);
  }

  /// R3: trạng thái khoá từng ô (null khi chưa đủ dữ liệu preview).
  List<bool>? _lockStates() {
    final centers = _squareCenters;
    final lm = _liveMarkers;
    final area = _previewArea;
    if (centers == null || lm == null || area == Size.zero) return null;
    final frame = lm.frameSize;
    final mapping = CoverMapping(frame: frame, screen: area);
    final candidates = <Offset>[
      for (final c in lm.candidates)
        mapping.toScreen(Offset(c.dx * frame.width, c.dy * frame.height)),
    ];
    return squareLockStates(
      [
        for (final c in centers)
          Offset(c.dx * area.width, c.dy * area.height),
      ],
      candidates,
      _lockRadius,
    );
  }
}

/// R3 (chỉ DEBUG): vẽ KẾT QUẢ phân tích khung mới nhất lên preview —
/// ứng viên mốc (chấm đỏ + nhãn cN) và quad 4 góc (xanh lá). Mục tiêu:
/// chứng minh bằng mắt trên thiết bị là detector khoá đúng 4 ô vuông đen
/// in trên phiếu, KHÔNG phải bong bóng/vật thể lân cận.
final class _DebugDetectionPainter extends CustomPainter {
  const _DebugDetectionPainter({
    required this.live,
    required this.area,
    required this.origin,
  });

  final _LiveFrame live;
  final Size area;

  /// R3.2: góc vùng preview trong canvas — điểm quy đổi từ khung camera
  /// là toạ độ TRONG vùng preview; vẽ lên canvas toàn màn cần cộng gốc.
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (area == Size.zero) return;
    final mapping = CoverMapping(frame: live.frameSize, screen: area);

    void text(Offset p, String label, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p + origin);
    }

    // Quad xanh lá.
    final quad = live.quad;
    if (quad != null) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x9920C05A);
      final pts = <Offset>[
        origin +
            mapping.toScreen(Offset(
              quad.tl.dx * live.frameSize.width,
              quad.tl.dy * live.frameSize.height,
            )),
        origin +
            mapping.toScreen(Offset(
              quad.tr.dx * live.frameSize.width,
              quad.tr.dy * live.frameSize.height,
            )),
        origin +
            mapping.toScreen(Offset(
              quad.br.dx * live.frameSize.width,
              quad.br.dy * live.frameSize.height,
            )),
        mapping.toScreen(Offset(
          quad.bl.dx * live.frameSize.width,
          quad.bl.dy * live.frameSize.height,
        )),
      ];
      for (var i = 0; i < pts.length; i++) {
        canvas.drawCircle(pts[i], 7, Paint()..color = const Color(0xDD1E9E44));
        text(pts[i] + const Offset(10, 2), '${i + 1}', Colors.white);
        final next = pts[(i + 1) % pts.length];
        canvas.drawLine(pts[i], next, paint);
      }
    }
    // Ứng viên đỏ + nhãn.
    final dot = Paint()..color = const Color(0xDDEB4A4A);
    for (var i = 0; i < live.candidates.length; i++) {
      final c = live.candidates[i];
      final p = mapping.toScreen(
          Offset(c.dx * live.frameSize.width, c.dy * live.frameSize.height));
      canvas.drawCircle(p, 5, dot);
      text(p + const Offset(6, -14), 'c$i', dot.color);
    }
  }

  @override
  bool shouldRepaint(_DebugDetectionPainter oldDelegate) =>
      oldDelegate.live != live || oldDelegate.area != area;
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
          // R2-fix: chữ dài (hint kéo ô) tràn phải khi một dòng — cho phép
          // xuống tối đa 2 dòng rồi mới cắt bớt (ellipsis).
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
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
    this.quad,
  });

  /// Detector tìm đủ 4 mốc góc theo phương hướng này.
  final bool ready;

  /// Ứng viên (TỈ LỆ 0..1 của khung đã chọn).
  final List<Offset> candidates;

  /// R3 (debug): quad 4 mốc góc theo TỈ LỆ khung đã chọn (null khi không có).
  final AlignmentQuad? quad;

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

/// Nút chụp — đĩa TRẮNG tròn giữa-dưới (mockup camera_format.png, phong cách
/// obs_006): vòng ngoài trắng mờ, đĩa trong trắng đặc + icon tối. GestureDetector
/// thay FAB để kiểm soát trọn vẹn hình dạng không phụ thuộc theme.
final class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      tooltip: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 3),
            color: Colors.black26,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.camera_alt, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

/// Màn dự phòng khi camera không khả dụng: hướng dẫn + chọn ảnh từ tệp.
/// Nền màn giờ là ĐEN fullscreen (obs_006) → icon/chữ màu sáng cho đọc được.
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
            const Icon(Icons.videocam_off_outlined,
                size: 56, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              l10n.scanCameraUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
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

/// R3 — THẺ KẾT QUẢ tức thời (màn nguyên màn hình, mô phỏng khung kết quả
/// của app tham khảo — phong cách original Dart): nền = ẢNH CHỤP GỐC làm
/// mờ tối; card trắng góc bo với tiêu đề "Kết quả phiếu", điểm TO
/// "Điểm: x/10", dòng "N câu đúng • M sai • K bỏ trống", phần thông tin
/// SBD/Mã đề/Học sinh; 2 nút "Lưu kết quả" (primary) và "Chụp phiếu khác"
/// (secondary). QUY TẮC R2 giữ nguyên: card nổi HOÀN TOÀN trên thanh nav
/// Android (SafeArea + viewPadding), NULL "NULL (Không có mã đề)" /
/// "(Không có số báo danh)" bỏ chấm và hiển thị lý do.
final class _ResultCardScreen extends StatefulWidget {
  const _ResultCardScreen({
    required this.graded,
    required this.contest,
    required this.onSave,
    required this.onScanAnother,
    this.backgroundImageBytes,
  });

  final GradedScan graded;
  final Contest contest;
  final VoidCallback onSave; // R3: callback caller điều hướng sau khi lưu.
  final VoidCallback onScanAnother;
  final Uint8List? backgroundImageBytes;

  @override
  State<_ResultCardScreen> createState() => _ResultCardScreenState();
}

final class _ResultCardScreenState extends State<_ResultCardScreen> {
  bool _saving = false;

  String _scoreText(double score) =>
      score % 1 == 0 ? score.toStringAsFixed(0) : score.toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final graded = widget.graded;
    final contest = widget.contest;
    final result = graded.result;
    final scan = graded.photo.scan;
    final studentName = graded.student?.fullName ?? l10n.resultStudentNotFound;
    final bgBytes = widget.backgroundImageBytes;
    // R2: giữ nguyên quy tắc — card phải nổi trên cả viewPadding (nav bar).
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Nền: ảnh chụp gốc làm mờ (mất nét nhẹ + phủ tối 55%) — nếu không
          // có bytes (luồng hiếm) nền xám than trơn.
          if (bgBytes != null)
            Opacity(
              opacity: 0.45,
              child: Image.memory(
                bgBytes,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            )
          else
            ColoredBox(color: const Color(0xFF26262B)),
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(blurRadius: 24, color: Colors.black54),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.resultTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // R2: phiếu BỎ chấm (lưới mã đề/SBD trống) → điểm "NULL"
                    // + lý do, KHÔNG có dòng thống kê đúng/sai (chưa hề chấm).
                    if (!graded.graded) ...[
                      Text(
                        l10n.resultNullScore,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.resultStats(result.correctCount,
                            result.incorrectCount, result.unansweredCount),
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
                        Text(l10n.partScoreLine(
                            entry.key, _scoreText(entry.value))),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(l10n.resultSave),
                      onPressed: _saving ? null : () {
                        setState(() => _saving = true);
                        widget.onSave();
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(l10n.resultScanAnother),
                      onPressed: _saving ? null : widget.onScanAnother,
                    ),
                  ],
                ),
              ),
            ),
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
