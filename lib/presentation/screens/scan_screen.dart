// Màn chấm phiếu bằng camera (R1→R5): preview TRÀN TOÀN MÀN HÌNH (không
// AppBar) đúng như ảnh tham chiếu obs_006.png của TN Maker; 4 ô vuông
// TRẮNG ĐẶC là CỬA SỔ NHẬN DIỆN mốc: **toàn bộ diện tích từng ô phải đè
// BAO TRỌN ô đen in trên phiếu** — khi chụp, pipeline quét mọi pixel trong
// ô (quy đúng hệ khung qua cover mapping) để tìm tâm mốc thật (R5), KHÔNG
// dùng tâm ô kéo tay nữa. Đủ mốc → KHOÁ viền xanh. Nút chụp LUÔN bật —
// chấm thẳng trong isolate (processPhoto có lượt 2 nới lỏng): kết quả ngay
// (GradeResultScreen R4); đọc không được → snackbar chụp lại.
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
import '../../data/cv/marker_blob_scan.dart'
    show expandFractionRect, locateDarkBlobInRegion;
import '../../data/cv/preview_overlay.dart'
    show CoverMapping, MarkerOverlayCalibration;
import '../../data/cv/scan_flow.dart'
    show GradedScan, processPhoto;
import '../../data/cv/sheet_alignment.dart';
import '../../data/cv/sheet_render_io.dart' show saveScannedImages;
import '../../domain/entities/class_room.dart';
import '../../domain/entities/contest.dart';
import '../../domain/entities/graded_sheet.dart';
import '../../domain/services/sheet_layout.dart';
import '../state/providers.dart';
import 'grade_result_screen.dart';

/// Bề rộng mục tiêu khi lấy mẫu luồng Y (đồng bộ [SheetMarkerDetector]).
const int _previewTargetWidth = 640;

/// R4 — Luồng GHIM MỘC/ghim tay (CropReviewScreen + nút "Chỉnh thủ công")
/// ẨN TOÀN BỘ theo yêu cầu người dùng: nút chụp LUÔN chấm thẳng (lượt 2
/// nới lỏng trong `processPhoto`), đọc không được → snackbar chụp lại.

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

  /// R8 (2026-10-25 log9) — CỐ ĐỊNH 4 ô: giáo viên DI CHUYỂN CAMERA cho
  /// khớp 4 ô vuông đen (y chỗ TN Maker), KHÔNG kéo ô nữa. Tâm ô luôn lấy
  /// từ calibration ([MarkerOverlayCalibration.centerFractions]) — bản
  /// tính-tươi, không state. Yêu cầu nguyên trực tiếp từ người dùng.
  List<Offset> get _squareCenters =>
      MarkerOverlayCalibration.forArea(_previewArea).centerFractions;

  /// R8: đèn xanh TỪNG Ô từ phép quét LIVE dùng CHUNG thuật toán với đường
  /// chụp ([locateDarkBlobInRegion] trên khung preview): ô xanh = "chính
  /// phép quét khi chụp sẽ đọc được mốc trong ô này". Xanh cũ (detector
  /// thấy candidate gần ô) là SAI — trên phiếu qua màn hình candidate gồm
  /// cả glyph/chữ → xanh có thể trên chữ (người dùng đã hỏi ý nghĩa).
  /// null = chưa lần phân tích nào.
  List<bool>? _rectScanOk;

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
  /// (720×1560): ô **157×203** chuẩn TN (R6 bỏ inset +24 px: ô phình
  /// 181×227 chèn luôn chữ sát mốc — dò nhầm), 2 cột tâm x =
  /// 94.5 / 625.5 (R3.5 thu vào ±16 px), hàng trên tâm y = 165.5,
  /// hàng dưới tâm y = 1076.5.
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

  /// R8: bán kính "khoá" cũ (detector candidate trong 0.75×cạnh ô) BỎ —
  /// đèn xanh giờ tính bằng phép quét blob thật [_rectScanOk].

  /// Đang phân tích 1 khung preview (trong isolate) — chặn chồng khung.
  bool _analyzing = false;

  /// R10: TỰ ĐỘNG CHÁM — đủ 4 đèn xanh ổn định → tự chụp + chấm, người dùng
  /// không cần bấm. 
  /// - [_greenStreak]: số tick liên tiếp có đủ 4/4 (tick = 250ms) — đòi ổn
  ///   định để không nổ vì đèn chớp qua ranhnh giới.
  /// - [_autoArmed]: chống chụp LẶP. Nổ 1 lần rồi hạ; chỉ nạp lại khi đèn
  ///   rời khỏi "4/4" (kéo phiếu ra/vào) — nếu không phiếu đứng yên sau khung
  ///   kết quả khi "CHỤP LẠI" sẽ lặp chụp vô hạn.
  bool _autoArmed = true;
  int _greenStreak = 0;

  /// TEMPDBG: đếm khung stream đi vào callback.
  int _frameCount = 0;

  /// R6b — cỡ khung HIỂN THỊ của stream phân tích (dọc: khung sensor
  /// ngang xoay 90°). Được ghi lại từ khung phân tích ĐẦU TIÊN — phát hiện
  /// mốc chưa đạt cũng không chặn việc quy ô ghim về hệ khung lúc chụp
  /// (R6: chụp bắt buộc có markers live là SAI — chỉ cần kích thước khung).
  Size? _analysisFrameSize;

  /// R2: thời điểm bắt đầu lần phân tích trước (throttle ≤ ~4 lần/giây).
  DateTime? _lastAnalysisStart;

  /// R2: khoảng nghỉ tối thiểu giữa hai lần phân tích khung preview.
  /// R11: chia tần số phân tích 4 Hz → 12.5 Hz (80 ms) — đèn xanh phải cập
  /// NHANH theo yêu cầu người dùng ("chuyển xanh dường như ngay lập tức");
  /// tick tính quét 4 ô chỉ ~1-2 ms (bỏ detector toàn trang chiếm phần lớn
  /// thời gian — xem comment hàm top-level).
  static const Duration _analysisInterval = Duration(milliseconds: 80);

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
      // TEMPDBG
      debugPrint('DBG startImageStream: OK');
    } catch (e) {
      // TEMPDBG
      debugPrint('DBG startImageStream: LỖI $e — bỏ luồng phân tích');
      // Luồng preview không hỗ trợ: bỏ overlay, luồng chấm vẫn bình thường.
    }
  }

  void _onCameraImage(CameraImage image) {
    // TEMPDBG: đếm khung đi vào callback.
    _frameCount++;
    if (_frameCount % 30 == 1) {
      debugPrint('DBG frame-in: n=$_frameCount planes=${image.planes.length} '
          '${image.width}x${image.height} stride=${image.planes.first.bytesPerRow} '
          'len=${image.planes.first.bytes.length} busy=$_busy analyzing=$_analyzing');
    }
    if (_analyzing || _busy || !mounted) return;
    if (image.planes.isEmpty) return;
    final y = image.planes.first;
    final width = image.width;
    final height = image.height;
    final stride = y.bytesPerRow;
    if (stride * (height - 1) + width > y.bytes.length) {
      // TEMPDBG
      debugPrint('DBG frame-reject-cụt: stride*hm1+w=${stride * (height - 1) + width} > len=${y.bytes.length}');
      return;
    }
    // R6b: ghi cỡ khung HIỂN THỊ (màn luôn dọc trên màn chụp → khung sensor
    // ngang xoay 90°) — đủ để quy ô ghim lúc chụp, kể cả khi chưa thấy quad.
    _analysisFrameSize = Size(height.toDouble(), width.toDouble());

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
    // R6: lệnh Isolate.run phải nằm trong hàm TOP-LEVEL — closure tạo trong
    // méthode instance sẽ chụp context chứa `this` (State → CameraController
    // → _Future unsendable) và SendPort.send ném "object is unsendable"
    // CHO MỖI KHUNG, nuốt cả luồng phân tích. Hàm top-level chỉ chụp các
    // biến sendable (bytes/stride/width/height + rects).
    // R8: gửi kèm 4 ô GHIM theo TỈ LỆ khung ("_captureOverlayRects" — đúng
    // vùng nhận diện mà CHỰP sẽ dùng) để isolate quét live: xanh = đọc được.
    final rects = _captureOverlayRects()?.$1;
    // R9: chọn CHIỀU xoay theo sensorOrientation của camera (90 = CW —
    // hầu hết máy; 270 = CCW). Sai chiều → nội dung khung dọc lộn
    // 180°/đối xứng → đèn xanh sẽ sáng ở ô đối diện.
    final sensor = _controller?.value.description.sensorOrientation ?? 90;
    final rotateCw = sensor != 270;
    _analyzeMarkerFrameInIsolate(bytes, stride, width, height, rects,
            rotateCw: rotateCw)
        .then<void>((res) {
      if (_analyzing) {
        _analyzing = false;
      } else {
        return; // đã dispose/đổi trạng thái trong lúc isolate chạy.
      }
      if (!mounted || _busy) return;
      final rectOk = res;
      // TEMPDBG: chỉ in KHI trạng thái đèn đổi — tránh nổ log 12 lần/giây.
      final old = _rectScanOk;
      if (!_sameLights(old, rectOk)) {
        debugPrint('DBG rect-ok: '
            '${[for (final o in rectOk) o ? "1" : "0"].join("")} '
            '(trước: ${old == null ? "chưa" : [for (final o in old) o ? "1" : "0"].join("")})');
      }
      setState(() {
        _rectScanOk = rectOk;
      });
      // R11: tự động chụp khi đủ 4/4 đèn xanh — NGAY SAU 2 tick liên tiếp
      // (~160 ms, cắm chữ "độ trễ thấp" của người dùng); KHÔNG hiện thông
      /// báo "đã đủ 4 mốc" nữa — xanh đủ là chụp luôn. Nổ 1 lần/lượt
      // "rời 4/4 → đủ 4/4" kể từ lúc nạp [_autoArmed]; _busy thì đợi tick sau.
      final allGreen = rectOk.length >= 4 && rectOk.every((o) => o);
      if (!allGreen) {
        _greenStreak = 0;
        _autoArmed = true;
      } else if (_greenStreak < 2) {
        _greenStreak++;
      }
      if (allGreen && _autoArmed && _greenStreak >= 2 && !_busy) {
        _autoArmed = false; // hạ NGAY trước khi chụp — chống nổ lặp.
        debugPrint('DBG auto-capture: đủ 4/4 đèn xanh x2 tick → TỰ CHỤP');
        _capture();
      }
    }).catchError((Object e, StackTrace s) {
      // TEMPDBG
      debugPrint('DBG analyze-ERROR: $e');
      debugPrint('$s');
      _analyzing = false;
      // Khung lỗi (memory/rotation lạ): bỏ qua, khung sau tiếp tục phân tích.
    });
  }

  /// Hàm top-level cho isolate (R2): lấy mẫu kênh Y về bề rộng
  /// [_previewTargetWidth], rồi chạy detector trên CẢ HAI phương hướng
  /// (thẳng / xoay 90°) vì buffer sensor có thể không khớp hướng màn.
  /// R3.1: chọn hướng theo HƯỚNG MÀN — khung nội dung DỰNG ĐỨNG theo màn.
  ///
  /// R8 (2026-10-25): quét thêm 4 ô GHIM ([rects] — TỈ LỆ khung HIỂN THỊ,
  /// đúng vùng mà CHỤP sẽ quét) bằng CHÍNH thuật toán đường chụp
  /// ([locateDarkBlobInRegion]): ô "đọc được" khi blob đặc tìm thấy trong
  /// ô và tâm blob nằm lại TRONG ô. Kết quả trả về cột [rectOk] — đèn
  /// xanh từng ô (quem nghĩa mới: xanh = chuẩn bị chụp sẽ đạt ô đó).
  ///
  /// Trả về bản ghi (_LiveFrame?, rectOk). [_LiveFrame] null khi không
  /// phương hướng nào dựng nổi quad — rectOk vẫn tính (đèn xanh không phụ
  /// thuộc detector toàn trang).
  static List<bool> _analyzeMarkerFrame(
      Uint8List planeBytes, int stride, int width, int height,
      {bool landscapeDisplay = false,
      List<Rect>? rects,
      bool rotateCw = true}) {
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

    // R8: KHUNG HIỂN THỊ của hướng màn: portrait → xoay 90° (khung dh rộng
    // × dw cao); landscape → thẳng (dw×dh). Phép quét ô chạy trên khung
    // NÀY để khớp hoàn toàn phép quy ô màn↔khung lúc chụp.
    final displayStraight = landscapeDisplay;
    // R9-fix (log12, người dùng: "xanh khi chưa căn / ô trên-phải không
    // xanh") — phép xoay cũ `rotated[y*dh + (dw-1-x)]` SAI khi dw>dh
    // (sensor 1920×1080: cột ghi tới 639 trên buffer chỉ rộng 360 → TRÀN
    // sang hàng kề, "ảnh xoay" thành ghép rác → mọi quét live/detector
    // xoay đọc nội dung SAI VỊ TRÍ trên màn). Xoay 90° chuẩn:
    //   CW : src(x, y) → dst(dh-1-y, x)   (Android sensorOrientation=90
    //        — hầu hết máy; top mép sensor → mép phải khung dọc)
    //   CCW: src(x, y) → dst(y, dw-1-x)   (sensorOrientation=270)
    // [rotateCw] do UI chọn theo `sensorOrientation` của controller.
    final rotated = Uint8List(dw * dh);
    if (rotateCw) {
      for (var y = 0; y < dh; y++) {
        final x0 = dh - 1 - y;
        for (var x = 0; x < dw; x++) {
          rotated[x * dh + x0] = gray[y * dw + x];
        }
      }
    } else {
      for (var y = 0; y < dh; y++) {
        for (var x = 0; x < dw; x++) {
          rotated[(dw - 1 - x) * dh + y] = gray[y * dw + x];
        }
      }
    }
    final Uint8List displayGray = displayStraight ? gray : rotated;
    final int dfw = displayStraight ? dw : dh; // rộng khung hiển thị
    final int dfh = displayStraight ? dh : dw; // cao khung hiển thị

    // Đèn xanh từng ô — không phụ thuộc detector toàn trang.
    bool rectReads(Rect frac) {
      int grayAtG(int x, int y) =>
          displayGray[(y.clamp(0, dfh - 1)) * dfw + x.clamp(0, dfw - 1)];
      // R8b (log11): cửa sổ quét PHÓNG 1.5× Y HỆT đường chụp
      // (_rectExpandFactor). Chấp nhận: tâm blob nằm TRONG ô GỐC.
      final rawRect = Rect.fromLTRB(
        frac.left * dfw,
        frac.top * dfh,
        frac.right * dfw,
        frac.bottom * dfh,
      );
      final region = expandFractionRect(frac, 1.5);
      // R9 (người dùng: "xanh CHỈ khi đọc được ô square"): ngưỡng so với
      // Ô ĐEN IN kỳ vọng trên khung dọc — cạnh khối phải thuộc dải
      // [0.12 × cạnh ngắn ô; 0.95 × cạnh ngắn ô]: glyph chữ/too smalls
      // và dải bezel khổng lồ loại ở đây; fill 0.6 (ô in là khối đặc
      // thật), aspect 0.6..1.65 (cột chữ/dải ngang loại).
      final shortRect = math.min(rawRect.width, rawRect.height);
      final locate = locateDarkBlobInRegion(
        width: dfw,
        height: dfh,
        region: Rect.fromLTRB(
          region.left * dfw,
          region.top * dfh,
          region.right * dfw,
          region.bottom * dfh,
        ),
        grayAt: grayAtG,
        minFill: 0.6,
        aspectMin: 0.6,
        aspectMax: 1.65,
        minSidePx: math.max(4.0, shortRect * 0.12),
        maxSidePx: shortRect * 0.95,
      );
      if (locate == null) return false;
      final c = Offset(locate.centroid.dx / dfw, locate.centroid.dy / dfh);
      return frac.contains(c);
    }

    // R11: BỎ Detector toàn trang trong tick live (yêu cầu người dùng:
    // "rects phải chuyển xanh NGAY LẬP TỨC, chấm đỏ/quad xanh không hiển
    // thị trên camera"). Detector quét toàn khung 2 hướng chiếm ~15-30 ms —
    // nút cổ chai duy nhất của tick; đèn xanh KHÔNG phụ thuộc detector, và
    // auto-capture chụp ảnh FULL-RES rồi pipeline chấm tự dò mốc trong
    // isolate khác (không dùng quad live) → chạy detector live là phí CPU.
    // Có mốc nếu cần ở chẩn đoán: hàm render bug painter đã xoá; đường chụp
    // vẫn chạy detector riêng (detectGray trong scan_service).
    final rectOk = [
      for (final r in (rects ?? const <Rect>[]).toList().take(4))
        rectReads(r),
    ];
    return rectOk;
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

  /// Chụp ảnh → quét + chấm. Nút chụp LUÔN bật (R1): chấm thẳng trong
  /// isolate (processPhoto có lượt 2 nới lỏng) — R4 không còn rơi màn ghim.
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
      // R5: 4 ô hình chữ nhật giáo viên căn → VÙNG NHẬN DIỆN của pipeline:
      // quy ô (tâm + CỠ Ô thật) màn → khung qua cover mapping; pipeline
      // quét toàn diện tích từng ô để tìm mốc (không còn quad "tâm nhắm").
      final overlay = _captureOverlayRects();
      // TEMPDBG: chẩn đoán chụp không đọc được phiếu.
      debugPrint(
          'DBG capture: frameCache=${_analysisFrameSize?.toString() ?? "chưa có"} '
          'area=$_previewArea rects=${overlay?.$1} frame=${overlay?.$2} '
          'box=$_markerBoxSize centers=$_squareCenters '
          'đèn=${_rectScanOk == null ? "chưa" : [for (final o in _rectScanOk!) o ? "1" : "0"].join("")}');
      await _process(
        Uint8List.fromList(bytes),
        overlayRects: overlay?.$1,
        frameSize: overlay?.$2 ?? const Size(1, 1),
      );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.scanError(e.toString()))));
    }
  }

  /// R5: 4 ô HÌNH CHỮ NHẬT giáo viên căn trên preview, quy từ hệ MÀN HÌNH
  /// sang TỈ LỆ KHUNG CAM (qua [CoverMapping.toFrame] từng góc — sửa cũ R2
  /// nhân tỉ lệ màn × khung trực tiếp, sai vì màn là cover của khung), kèm
  /// kích thước khung để pipeline quyết trục. Trả null khi chưa có khung
  /// phân tích nào (chụp nhanh trước khi detector kịp chạy một frame).
  (List<Rect>, Size)? _captureOverlayRects() {
    // R6b: chỉ cần cỡ khung đã ghi từ luồng phân tích — không bắt buộc
    // markers live (quad chưa đạt không được phép ném ô ghim đi).
    final frame = _analysisFrameSize;
    final centers = _squareCenters;
    final area = _previewArea;
    if (frame == null || area.width <= 0 || area.height <= 0) {
      return null;
    }
    final mapping = CoverMapping(frame: frame, screen: area);
    final box = _markerBoxSize;
    final half = Offset(box.width / 2, box.height / 2);
    final rects = <Rect>[];
    for (var i = 0; i < 4; i++) {
      final center = Offset(centers[i].dx * area.width, centers[i].dy * area.height);
      final tl = mapping.toFrame(center - half);
      final br = mapping.toFrame(center + half);
      rects.add(Rect.fromLTRB(
        tl.dx / frame.width,
        tl.dy / frame.height,
        br.dx / frame.width,
        br.dy / frame.height,
      ));
    }
    return (rects, frame);
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

  /// Quét + chấm ảnh (isolate): đủ mốc (hoặc lượt 2 nới lỏng dựng nổi khung)
  /// → MÀN KẾT QUẢ R4; cả 2 lượt rớt → snackbar chụp lại (ở lại camera).
  ///
  /// R5: \[overlayRects\] = 4 ô hình chữ nhật theo TỈ LỆ khung — vùng nhận
  /// diện mốc của pipeline (quét toàn diện tích ô); \[frameSize\] khung đó.
  /// \[knownQuad\] = quad hệ ảnh chụp khi biết chắc (hiếm — đường nắn tay
  /// đã ẩn R4).
  Future<void> _process(
    Uint8List bytes, {
    List<Rect>? overlayRects,
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
        overlayRects: overlayRects,
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
    // TEMPDBG (R7, log9): chụp #2 dừng im lặng sau gradeScan — log rõ kết
    // cục để nhìn ra nằm ở chấm vs hiển thị.
    if (graded == null) {
      debugPrint('DBG process: graded=NULL');
    } else {
      debugPrint('DBG process: ${graded.graded ? "đã chấm" : "BỎ chấm (${graded.ungradedReason})"} '
          'điểm=${graded.result.score.toStringAsFixed(2)} '
          'đúng=${graded.result.correctCount}/${graded.result.correctFlags.length} '
          'SBD=${graded.photo.scan.studentCodeRaw} mã đề=${graded.usedExamCode} '
          'số đáp án=${graded.photo.scan.answers.length}');
    }
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
      // R4 — KHÔNG còn màn ghim mốc: cả 2 lượt nới lỏng đều không dựng nổi
      // khung → snackbar hướng dẫn chụp lại, ở lại camera.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.scanSheetUnreadable)),
      );
      return;
    }
    await _showResult(graded);
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

  /// R4: MÀN KẾT QUẢ giống TNMaker (GradeResultScreen — header "Mã đề" +
  /// điểm, ảnh phiếu nắn phủ vành màu, card "Warning!!!", CHỤP LẠI/GIỮ).
  /// Screen tự điều hướng: GIỮ → lưu xong pop cả 2 (về chi tiết kỳ thi);
  /// CHỤP LẠI/back → pop về camera.
  Future<void> _showResult(GradedScan graded) async {
    if (!mounted) return;
    debugPrint('DBG showResult: enter graded=${graded.graded}');
    final contest = _contest;
    if (contest == null) return;
    // R4: phiếu đã chấm TRƯỚC ĐÓ của kỳ thi — kiểm tra "Trùng SBD" card.
    // R10 (fix treo): KHÔNG await provider .future nữa — Riverpod 3 stream
    // provider với ref.read(.future) có thể KHÔNG NHỎ bao giờ phát giá trị
    // đầu → _showResult treo vô hạn, không hiện màn kết quả (log13/14:
    // "showResult: enter" rồi im lặng). Truy vấn THẲNG repository + timeout
    // 2s làm an toàn: không có gì được phép chặn màn kết quả — lỗi đồng nghĩa
    // "không trùng".
    List<GradedSheet> previousSheets = const [];
    try {
      previousSheets = await ref
          .read(gradedSheetRepositoryProvider)
          .watchByContest(contest.id)
          .first
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Không lấy được danh sách cũ → coi như không trùng (chỉ là cảnh báo).
    }    if (!mounted) {
      debugPrint('DBG showResult: !mounted sau khi đọc phiếu cũ → BỎ hiển thị');
      return;
    }
    debugPrint('DBG showResult: sheets cũ=${previousSheets.length} → push');
    final layout =
        SheetLayout.forSpec(contest.sheetSpec, page: SheetLayout.standardPage);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GradeResultScreen(
          graded: graded,
          contest: contest,
          layout: layout,
          previousSheets: previousSheets,
          onSave: () => _save(graded),
        ),
      ),
    );
    debugPrint('DBG showResult: hiển thị xong (pop)');
    // Quay về camera sau "CHỤP LẠI"/back: mở lại luồng phân tích preview.
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
          // R11: camera CHỈ hiển thị 4 ô rects — KHÔNG chấm đỏ/quạ xanh
          // (_DebugDetectionPainter đã xoá theo yêu cầu: chỉ rects xanh khi
          // khớp square).
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
          // R11: bỏ pill "Đã đủ 4 mốc" (yêu cầu: không hiện thông báo, đủ
          // 4 đèn xanh là tự chụp ngay).
          // R4: nút "Chỉnh thủ công" + toàn luồng GHIM MỐC ẨN theo yêu cầu
          // (CropReviewScreen giữ nguyên file, không còn được gọi).
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

  /// R8 (2026-10-25): 4 ô vuông mốc CỐ ĐỊNH theo calibration
  /// ([MarkerOverlayCalibration.forArea]) — giáo viên DI CHUYỂN CAMERA cho
  /// ô khớp ô đen trên phiếu (y hệt TN Maker), KHÔNG kéo ô (yêu cầu trực
  /// tiếp người dung trên). Viền XANH từng ô = [_rectScanOk]: phép quét
  /// CHÍNH XÁC như khi chụp đọc được mốc trong ô (وبác bỏ ý nghĩa cũ
  /// "detector thấy candidate gần ô" — trên phiếu qua màn hình candidate
  /// gồm cả glyph chi).
  List<Widget> _buildSquares() {
    final area = _previewArea;
    if (area == Size.zero) return const [];
    final centers = _squareCenters;
    final lights = _rectScanOk ?? const <bool>[false, false, false, false];
    final box = _markerBoxSize;
    final squares = <Widget>[];
    for (var i = 0; i < 4 && i < centers.length; i++) {
      final c = centers[i];
      final px =
          _previewOrigin + Offset(c.dx * area.width, c.dy * area.height);
      // obs_006 (TN Maker): nền TRẮNG MỜ phẳng, GÓC VUÔNG, KHÔNG SỐ — ô
      // chỉ là mục tiêu căn phiếu. R8: ô ĐỌC ĐƯỢC mốc → nền đục hơn +
      // VIỀN XANH (ý nghĩa: phép quét khi chụp sẽ đạt); chưa → trong suốt.
      final ok = i < lights.length ? lights[i] : false;
      final fillColor = ok
          ? Colors.white.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.32);
      final borderColor = ok ? const Color(0xFF2E7D32) : Colors.transparent;
      squares.add(Positioned(
        left: px.dx - box.width / 2,
        top: px.dy - box.height / 2,
        child: Container(
          width: box.width,
          height: box.height,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: borderColor, width: 3),
          ),
          // KHÔNG số 1..4 bên trong (y hệt TNMaker) — ô trống hoàn toàn
          // để không che khuất ô mốc đen đặt bên dưới khi căn phiếu.
        ),
      ));
    }
    return squares;
  }
}

/// R6 wrapper FOR isolate: gọi từ instance method nhưng là hàm TOP-LEVEL —
/// closure của Isolate.run chỉ chụp các tham số sendable (Uint8List, int,
/// `List<Rect>` — Rect/Bool list sendable), không chụp `this`/`_controller`
/// (đối tượng chứa Future — unsendable, gây "object is unsendable" mỗi khung
/// và giết cả luồng phân tích live).
///
/// R8: trả về bản ghi (_LiveFrame?, rectOk — đèn xanh từng ô).
/// R11: chỉ trả `List<bool>` đèn xanh — detector toàn trang đã bỏ khỏi tick
/// live (đèn độc lập với detector; chụp vẫn dò mốc riêng trong isolate).
Future<List<bool>> _analyzeMarkerFrameInIsolate(
    Uint8List planeBytes, int stride, int width, int height,
    List<Rect>? rects,
    {bool rotateCw = true}) {
  return Isolate.run(() => _ScanScreenState._analyzeMarkerFrame(
      planeBytes, stride, width, height,
      rects: rects, rotateCw: rotateCw));
}

/// R8: đèn xanh đổi trạng thái? (chỉ in log khi ĐỔI — tránh nổ log 4 lần/s).
bool _sameLights(List<bool>? a, List<bool> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

