import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/sheet_spec.dart';
import '../../domain/services/omr_decoder.dart';
import '../../domain/services/sheet_layout.dart';
import 'marker_blob_scan.dart';
import 'omr_image_pipeline.dart';
import 'sheet_alignment.dart';

/// Kích thước trang chuẩn của hệ thống OMR = toàn trang giấy (khung mốc + lề)
/// × 0.5 so với ảnh scan tham chiếu (giữ đồng bộ [SheetLayout.standardPage]).
///
/// Mọi phiếu chụp thật đều được nắn phẳng về đúng kích thước này trước khi
/// đo mật độ, nhờ vậy toạ độ [SheetLayout] luôn khớp.
final Size omrPageSize = SheetLayout.standardPage;

/// Kết quả quét một phiếu (chưa chấm điểm, chưa lưu DB).
final class SheetScan {
  const SheetScan({
    required this.answers,
    required this.studentCodeRaw,
    required this.examCodeRaw,
    required this.answerBlocks,
    required this.studentCodeGrid,
    required this.examCodeGrid,
    required this.processingTime,
  });

  /// Đáp án giải mã theo từng câu ('A'..'J' hoặc null).
  final List<String?> answers;

  /// Chuỗi 6 chữ số đọc từ lưới số báo danh ('?' cho vị trí không đọc được).
  final String studentCodeRaw;

  /// Chuỗi 3 chữ số đọc từ lưới mã đề ('?' cho vị trí không đọc được).
  final String examCodeRaw;

  final List<DensityBlock> answerBlocks;
  final DensityBlock studentCodeGrid;
  final DensityBlock examCodeGrid;

  /// Thời gian xử lý (đo bằng Stopwatch) — dùng cho benchmark và log.
  final Duration processingTime;

  /// Số báo danh đã chuẩn hoá (bỏ số 0 vô nghĩa).
  String get studentCode => OmrDecoder.normalizeCode(studentCodeRaw);

  /// Mã đề đã chuẩn hoá.
  String get examCode => OmrDecoder.normalizeCode(examCodeRaw);

  /// R2: lưới mã đề TRỐNG (không đọc được chữ số nào) → bỏ chấm, NULL.
  bool get examCodeEmpty => OmrDecoder.isBlankCode(examCodeRaw);

  /// R2: lưới số báo danh TRỐNG → bỏ chấm, NULL.
  bool get studentCodeEmpty => OmrDecoder.isBlankCode(studentCodeRaw);
}

/// Kết quả quét 1 ảnh chụp thật: 4 góc khung đã phát hiện + ảnh nắn phẳng +
/// kết quả đo/giải mã trên ảnh nắn phẳng.
final class PhotoScan {
  const PhotoScan({
    required this.scan,
    required this.quad,
    required this.warpedBytes,
    this.detectedCandidates,
    this.verification,
  });

  final SheetScan scan;
  final AlignmentQuad quad;

  /// Ảnh đã nắn phẳng về [omrPageSize] (PNG) — dùng làm ảnh gốc khi lưu DB.
  final Uint8List warpedBytes;

  /// R3: ứng viên ô vuông (px ảnh gốc) từ lần phát hiện mốc — null khi quad
  /// không đến từ detector ([knownQuad]). Nguồn cho bằng chứng debug + thống kê.
  final List<Offset>? detectedCandidates;

  /// R3: kiểm chứng round-trip trên ảnh đã nắn (null khi [knownQuad] — người
  /// dùng đã ghim tay, bỏ kiểm để không lặp CropReview với mốc phai).
  final WarpedMarkerCheck? verification;
}

/// R3 — Ngưỡng kiểm chứng mốc sau nắn: px trang chuẩn (1576×2205).
const double markerVerificationTolerancePx = 6.0;

/// R3 — Kết quả kiểm chứng ROUND-TRIP (bằng chứng detector khoá đúng mốc):
/// nắn xong chạy lại detector trên ẢNH ĐÃ NẮN rồi đo khoảng cách từng tâm
/// mốc góc gần nhất tới vị trí chuẩn của [SheetLayout]. [passed] ✓ đòi
/// CẢ 4 góc ≤ [tolerance] — phiếu nắn lệch/nội dung rác không thể qua được.
final class WarpedMarkerCheck {
  const WarpedMarkerCheck({
    required this.offsets,
    this.tolerance = markerVerificationTolerancePx,
  });

  /// Sai lệch (px trang chuẩn) của 4 mốc góc theo thứ tự tl, tr, br, bl —
  /// khoảng cách từ vị trí chuẩn tới ứng viên TRÒN gần nhất trên ảnh nắn.
  final List<double> offsets;

  final double tolerance;

  double get maxOffset =>
      offsets.fold(0.0, (m, o) => o > m ? o : m);

  bool get passed =>
      offsets.length == 4 && offsets.every((o) => o <= tolerance);
}

/// Chạy kiểm chứng round-trip trên ẢNH ĐÃ NẮN (PNG trang chuẩn): decode →
/// detect ứng viên → khoảng cách 4 góc chuẩn. Ngược quá 1 góc → [passed]=false.
WarpedMarkerCheck verifyWarpedMarkers(
  Uint8List warpedPngBytes, {
  required SheetLayout layout,
  SheetMarkerDetector detector = const SheetMarkerDetector(),
}) {
  final detection = detector.detect(warpedPngBytes, template: layout.template);
  final offsets = <double>[];
  for (final expected in layout.cornerMarkerCenters) {
    var best = double.infinity;
    for (final c in detection.candidates) {
      final d = (c - expected).distance;
      if (d < best) best = d;
    }
    offsets.add(best);
  }
  return WarpedMarkerCheck(offsets: offsets);
}

/// R15: kiểm chứng round-trip trên mảng xám PLANAR đã nắn — dùng CÙNG lõi
/// [SheetMarkerDetector] (detectGray thay detect: bỏ decode PNG — phép quét
/// ngưỡng/components/hull không đổi — xem [verifyWarpedMarkers]) và cùng
/// logic tính độ lệch 4 mốc góc. Rớt quá 1 góc = fail như cũ.
WarpedMarkerCheck verifyWarpedGrayPlanar(
  Uint8List warpedGray, {
  required int width,
  required int height,
  required SheetLayout layout,
  SheetMarkerDetector detector = const SheetMarkerDetector(),
}) {
  final detection = detector.detectGray(
    warpedGray,
    width: width,
    height: height,
    template: layout.template,
  );
  final offsets = <double>[];
  for (final expected in layout.cornerMarkerCenters) {
    var best = double.infinity;
    for (final c in detection.candidates) {
      final d = (c - expected).distance;
      if (d < best) best = d;
    }
    offsets.add(best);
  }
  return WarpedMarkerCheck(offsets: offsets);
}

/// Ghép pipeline đo mật độ + bộ giải mã thành một bước "quét phiếu".
///
/// Interface/pipeline tách rời để M3 có thể thay bằng opencv_dart mà không đổi
/// tầng domain hay UI.
final class OmrScanService {
  const OmrScanService({
    this.pipeline = const DartOmrImagePipeline(),
    this.decoder = const OmrDecoder(),
    this.detector = const SheetMarkerDetector(),
    this.warper = const PerspectiveWarper(),
  });

  final OmrImagePipeline pipeline;
  final OmrDecoder decoder;
  final SheetMarkerDetector detector;
  final PerspectiveWarper warper;

  /// Quét ảnh CHỤP THẬT (xoay/chếch/không tràn khung): phát hiện 4 ô vuông
  /// mốc → nắn phẳng về trang chuẩn → đo + giải mã. Trả về null nếu không tìm
  /// đủ 4 mốc tin cậy (UI rơi về CropReviewScreen cho người dùng ghim tay).
  ///
  /// R2: khi giáo viên đã GHIM 4 ô vuông trên preview ([overlayQuad] theo
  /// hệ KhUNG HIỂN THỊ dọc + [frameSize] khung đó), pipeline dùng vị trí ghim
  /// làm lưới an toàn: detector ưu tiên trước; detector thất bại mới thử
  /// phân định hướng rồi warp theo vị trí ghim.
  ///
  /// \[skipVerification\] (R4) — bỏ kiểm chứng round-trip: dùng ở lượt THỬ
  /// THỨ khi lượt thường rớt (mốc phai/ánh sáng) — giáo viên ĐÃ canh 4 ô
  /// trên preview khớp mốc nên chấp nhận warp theo vị trí ghim, chấm thẳng
  /// luôn thay vì rơi màn ghim tay.
  ///
  /// \[overlayMinQuality\] (R4) — hạ ngưỡng chất lượng quad overlay ở lượt
  /// thử thứ (mặc định 0.55, nới xuống 0.35): mốc hơi mờ vẫn nhận.
  ///
  /// R5 — \[overlayRects\]: 4 HÌNH CHỮ NHẬT giáo viên căn trên preview (tỉ lệ
  /// của khung hiển thị, thứ tự tl,tr,br,bl). **Nguyên tắc: TOÀN BỘ DIỆN TÍCH
  /// TỪNG Ô là vùng nhận diện mốc** — pipeline quét mọi pixel trong ô, mốc
  /// IN nằm gọn trong ô thì tâm blob đen chính là tâm mốc \[overlayQuad\]
  /// ghim chỉ còn là dữ liệu dự phòng (test cũ).
  ///
  /// \[knownQuad\] là quad ở HỆ ẢNH CHỤP (pixel ảnh decode) — dùng khi đã biết
  /// chắc toạ độ (vd. ảnh đã nắn về trang chuẩn từ CropReviewScreen: quad =
  /// 4 tâm mốc góc trang chuẩn), không dò hướng, không chạy detector.
  PhotoScan? scanPhoto(
    Uint8List imageBytes, {
    required SheetSpec spec,
    OmrTuning tuning = const OmrTuning(),
    AlignmentQuad? overlayQuad,
    List<Rect>? overlayRects,
    Size frameSize = const Size(1, 1),
    AlignmentQuad? knownQuad,
    bool skipVerification = false,
    double overlayMinQuality = _overlayQuadMinQuality,
    // R17: ảnh ĐÃ DECODE trước bởi Skia (dart:ui) ở thread chính — decode
    // native ~5× nhanh hơn package `image` (log22: 715ms release). Bỏ hẳn
    // để decode khi có. null → decode lối cũ (dùng cho fallback / test).
    ({Uint8List rgba, int width, int height})? predecoded,
  }) {
    final stopwatch = Stopwatch()..start();
    final layout = SheetLayout.forSpec(spec, page: omrPageSize);
    final targetQuad = AlignmentQuad(
      layout.cornerMarkerCenters[0],
      layout.cornerMarkerCenters[1],
      layout.cornerMarkerCenters[2],
      layout.cornerMarkerCenters[3],
    );

    // R15 — DECODE NGUỒN ĐÚNG 1 LẦN. Trước đây CÙNG MỘT tấm ảnh bị
    // decode lại 3-4 lần (JPEG cho overlay-rects + warpRectify; PNG cho
    // verify + measure) + encode PNG giữa chừng — nguyên nhân "chấm
    // 10-15s quá lâu" (người dùng). Giờ mọi pha sau decode chạy trên
    // mảng xám planar trong RAM; encode PNG CHỈ 1 LẦN cho kết quả.
    // Ảnh hỏng: knownQuad (nắn tay) ném FormatException như warpRectify
    // cũ; đường quét tự do trả null như detector/overlay cũ.
    final swDecode = Stopwatch()..start();
    Uint8List srcBytes;
    int srcW;
    int srcH;
    int srcCh;
    if (predecoded != null) {
      // R17: dùng RGBA Skia đã decode — KÊNH 0 = R, cùng giá trị kênh đầu
      // với img.decodeImage(getBytes()) phía dưới → mọi phép đo ĐỐI XỨNG.
      srcBytes = predecoded.rgba;
      srcW = predecoded.width;
      srcH = predecoded.height;
      srcCh = 4;
    } else {
      final source = img.decodeImage(imageBytes);
      if (source == null) {
        if (knownQuad != null) {
          throw const FormatException('Không giải mã được ảnh để nắn phẳng.');
        }
        debugPrint('DBG scanPhoto: DECODE NULL → rớt lượt này');
        return null;
      }
      srcW = source.width;
      srcH = source.height;
      srcBytes = source.getBytes();
      srcCh = source.numChannels;
    }
    // Xám planar KÊNH 0 — R17: đo luôn cả vòng xám trong pha decode.
    swDecode.stop();
    // Giá trị kênh đầu giữ nguyên từng pixel (đối xứng với _sampleGray cũ
    // và với bước grayscale R=G=B ở đo đầu).
    final srcGray = Uint8List(srcW * srcH);
    for (var i = 0; i < srcGray.length; i++) {
      srcGray[i] = srcBytes[i * srcCh];
    }

    final swOverlay = Stopwatch()..start();
    AlignmentQuad? quad;
    List<Offset>? detectedCandidates;
    var quadFromDetector = false;
    if (knownQuad != null) {
      quad = knownQuad;
    } else if (overlayRects != null) {
      // R5 — ƯU TIÊN VÙNG GHIM CỦA GIÁO VIÊN: 4 ô đã canh khớp mốc là tín hiệu
      // mạnh nhất trên bề mặt ảnh → quét THẬT TRONG Ô trước; detector toàn ảnh
      // chỉ chạy khi quét trong ô bó tay.
      quad = _resolveOverlayRects(
        srcBytes,
        srcCh,
        imageWidth: srcW,
        imageHeight: srcH,
        overlayRects: overlayRects,
        frameSize: frameSize,
      );
      if (quad == null) {
        // TEMPDBG: bật dump chi tiết component/gate của detector cho lượt chụp.
        final detection = const SheetMarkerDetector(debug: true).detect(imageBytes);
        detectedCandidates = [
          for (final c in detection.candidates) Offset(c.dx, c.dy),
        ];
        quad = detection.quad;
        quadFromDetector = quad != null;
      }
    } else {
      // TEMPDBG: bật dump chi tiết component/gate của detector cho lượt chụp.
      final detection = const SheetMarkerDetector(debug: true).detect(imageBytes);
      detectedCandidates = [
        for (final c in detection.candidates) Offset(c.dx, c.dy),
      ];
      quad = detection.quad;
      quadFromDetector = quad != null;
      if (quad == null && overlayQuad != null) {
        // R2: quad ghim của giáo viên là lưới an toàn khi detector bó tay:
        // phân định hướng ảnh (thẳng / xoay) rồi dùng vị trí ghim.
        quad = _resolveOverlayQuad(
          imageBytes,
          overlayQuad: overlayQuad,
          frameSize: frameSize,
          layout: layout,
          targetQuad: targetQuad,
          minQuality: overlayMinQuality,
        );
      }
    }
    if (quad == null) {
      // TEMPDBG
      debugPrint('DBG scanPhoto: QUAD NULL (rects=${overlayRects == null ? "không có" : "có, ${overlayRects.length}"}, '
          'detectorQuad=$quadFromDetector) → rớt lượt này');
      return null;
    }
    swOverlay.stop();
    final swWarp = Stopwatch()..start();

    // NẮN PHẮNG trên mảng xám — KHÔNG decode/encode trong pipeline.
    ({Uint8List gray, int width, int height}) warpPage(AlignmentQuad q) =>
        warper.warpGrayPlanar(
          srcGray: srcGray,
          srcWidth: srcW,
          srcHeight: srcH,
          quad: q,
          targetQuad: targetQuad,
          outputSize: layout.page,
        );
    Uint8List warpedGray;
    var warpedW = 0;
    var warpedH = 0;
    WarpedMarkerCheck? verification;
    if (knownQuad != null) {
      // knownQuad (ảnh đã ghim tay từ CropReview): miễn kiểm — tránh vòng
      // lặp với mốc phai.
      final page = warpPage(quad);
      warpedGray = page.gray;
      warpedW = page.width;
      warpedH = page.height;
    } else {
      final page = warpPage(quad);
      warpedGray = page.gray;
      warpedW = page.width;
      warpedH = page.height;
      // R4: lượt thử THỨ (skipVerification) → chấm thẳng theo quad BEST
      // hiện có: detector quad hoặc overlay quad (đã đạt quality).
      // R17 (bài học log22): quad đến từ QUÉT TRONG Ô GHIM (overlayRects,
      // không qua detector) là TIN CẬY — bằng chứng mạnh hơn round-trip:
      // mỗi tâm blob phải nằm lại CHÍNH XẠC trong ô giáo viên canh trên
      // preview + độ đặc ≥ _rectMinFill + cỡ 4 mốc đồng nhất. log22 chụp
      // thật: quad tốt (fill 0.96) bị verify round-trip RỚT GIẢ → vứt lượt
      // đúng, chạy alt-loop (detector decode lại + warp thêm) hết 7.7s rồi
      // sụp về lượt 2 nới lỏng (tổng 11.3s). Tin pin của giáo viên: KHÔNG
      // verify, KHÔNG alt-loop — chấm thẳng.
      final quadTrusted = !quadFromDetector && overlayRects != null;
      if (skipVerification || quadTrusted) {
        verification = null;
      } else {
        // R3 — KIỂM CHỨNG ROUND-TRIP: ảnh đã nắn phải tái-detect được CẢ
        // 4 mốc góc trong ≤ 6 px trang chuẩn. Góc nào lệch ⇒ coi như phiếu
        // chưa căn đúng (warp rác/pin nhắm) → null → UI rơi
        // CropReviewScreen, KHÔNG chấm một phiếu có thể sai lattice.
        verification = verifyWarpedGrayPlanar(
          warpedGray,
          width: warpedW,
          height: warpedH,
          layout: layout,
        );
        // R3.1 (màn NGANG): detector gán nhãn tl/tr/br/bl theo TRỤC ẢNH
        // decode; ảnh chụp ngang khiến quad đúng VỊ TRÍ nhưng NHÃN lệch
        // 90° ⇒ warp sai chiều ⇒ kiểm chứng rớt. Khi có vị trí GHIM từ
        // preview, phân định hướng qua ĐIỂM TỐI của mốc thật rồi thử lại
        // — lượt đạt kiểm chứng mới được dùng.
        if (!verification.passed) {
          final alts = <AlignmentQuad>[];
          if (!quadFromDetector && overlayRects != null) {
            // R5: quad hiện có đến từ QUÉT TRONG Ô ghim — cho detector toàn
            // ảnh một cơ hội, VÀ cho biến thể hướng CÒN LẠI của quét trong
            // ô (thẳng↔180 / CW↔CCW): mốc 180° đối xứng khiến 2 biến thể
            // đều bắt được blob, chỉ kiểm chứng round-trip phân biệt được.
            final det = detector.detect(imageBytes);
            detectedCandidates = [
              for (final c in det.candidates) Offset(c.dx, c.dy),
            ];
            if (det.quad != null) alts.add(det.quad!);
            final altRects = _resolveOverlayRects(
              srcBytes,
              srcCh,
              imageWidth: srcW,
              imageHeight: srcH,
              overlayRects: overlayRects,
              frameSize: frameSize,
              exclude: quad,
            );
            if (altRects != null) alts.add(altRects);
          } else if (quadFromDetector) {
            final altRects = overlayRects != null
                ? _resolveOverlayRects(
                    srcBytes,
                    srcCh,
                    imageWidth: srcW,
                    imageHeight: srcH,
                    overlayRects: overlayRects,
                    frameSize: frameSize,
                    exclude: quad,
                  )
                : null;
            if (altRects != null) alts.add(altRects);
            if (overlayQuad != null) {
              alts.add(_resolveOverlayQuad(
                imageBytes,
                overlayQuad: overlayQuad,
                frameSize: frameSize,
                layout: layout,
                targetQuad: targetQuad,
                minQuality: overlayMinQuality,
              )!);
            }
          }
          for (final alt in alts) {
            if (alt == quad) continue;
            final altPage = warpPage(alt);
            final altVerification = verifyWarpedGrayPlanar(
              altPage.gray,
              width: altPage.width,
              height: altPage.height,
              layout: layout,
            );
            if (altVerification.passed) {
              quad = alt;
              warpedGray = altPage.gray;
              warpedW = altPage.width;
              warpedH = altPage.height;
              verification = altVerification;
              break;
            }
          }
        }
        final vAfterAlts = verification;
        if (vAfterAlts == null || !vAfterAlts.passed) return null;
      }
    }
    swWarp.stop();
    // Dart không promote biến đích (quad) qua phép gán trong vòng lặp alt
    // → chốt bằng biến cục bộ final trước return.
    final quadGood = quad;
    if (quadGood == null) return null;
    final swScan = Stopwatch()..start();
    final scanResult = scanGrayPlanar(
      warpedGray,
      width: warpedW,
      height: warpedH,
      layout: layout,
      spec: spec,
      tuning: tuning,
    );
    swScan.stop();
    // R15: encode PNG ĐÚNG 1 LẦN — chỉ cho màn kết quả / lưu ảnh. Mọi
    // pha trước đã chạy trên mảng xám planar (không quanh co encode).
    final swEncode = Stopwatch()..start();
    final warpedPng = _grayPlanarToPng(warpedGray, warpedW, warpedH);
    swEncode.stop();
    stopwatch.stop();
    // TEMPDBG R15: đo từng pha — đối chứng tốc độ trên máy thật (log20).
    debugPrint('DBG timing: tổng=${stopwatch.elapsedMilliseconds}ms '
        'decode=${swDecode.elapsedMilliseconds} '
        'overlay=${swOverlay.elapsedMilliseconds} '
        'warp+verify=${swWarp.elapsedMilliseconds} '
        'scan=${swScan.elapsedMilliseconds} '
        'encode=${swEncode.elapsedMilliseconds}');
    return PhotoScan(
      scan: scanResult,
      quad: quadGood,
      warpedBytes: warpedPng,
      detectedCandidates: detectedCandidates,
      verification: verification,
    );
  }

  /// R2 — Phân định hướng ảnh và trả về quad theo hệ PIXEL ẢNH.
  ///
  /// [overlayQuad] do giáo viên ghim theo hệ KHUNG HIỂN THỊ (đúng thứ
  /// tự tl→tr→br→bl theo hướng màn hiện hành — R3.1: có thể là màn NGANG).
  /// Ảnh decode có thể đang lệch trục với khung — chiến lược:
  ///   1. Đọc kích thước ảnh và kích thước khung → so TRỤC:
  ///      cùng trục (dọc↔dọc / ngang↔ngang) → biến thể (thẳng, xoay 180°);
  ///      khác trục → biến thể (xoay CW, xoay CCW).
  ///   2. Từng biến thể: warp BẢN THU NHỎ về trang chuẩn rồi đo ĐỘ TỐI
  ///      tại 12 mốc in sẵn — biến thể đúng → mốc tối rõ (giấy trắng).
  ///   3. Trả quad biến thể tối nhất; không biến thể nào đạt ngưỡng
  ///      → null (UI rơi về CropReviewScreen ghim tay).
  AlignmentQuad? _resolveOverlayQuad(
    Uint8List imageBytes, {
    required AlignmentQuad overlayQuad,
    required Size frameSize,
    required SheetLayout layout,
    required AlignmentQuad targetQuad,
    double minQuality = _overlayQuadMinQuality,
  }) {
    final size = probeImageSize(imageBytes);
    if (size == null) return null;
    final fw = frameSize.width;
    final fh = frameSize.height;
    if (fw <= 0 || fh <= 0) return null;

    // Tâm quad theo TỈ LỆ khung (0..1) — cùng hệ cho mọi biến thể.
    Offset fraction(Offset p) => Offset(p.dx / fw, p.dy / fh);
    final points = [
      fraction(overlayQuad.tl),
      fraction(overlayQuad.tr),
      fraction(overlayQuad.br),
      fraction(overlayQuad.bl),
    ];

    List<Offset> mapTo(Offset Function(Offset f) map) =>
        [for (final p in points) map(p)];

    final variants = <List<Offset>>[];
    // R3.1: QUYẾT TRỤC bằng cách so HƯỚNG ảnh ↔ HƯỚNG KHUNG ghim (không
    // mặc định màn dọc nữa): cùng trục → thẳng/180; khác trục → CW/CCW.
    final imagePortrait = size.height >= size.width;
    final framePortrait = fh >= fw;
    if (imagePortrait == framePortrait) {
      // Cùng trục: dò (thẳng) và (xoay 180°).
      variants.add(mapTo((f) => Offset(f.dx * size.width, f.dy * size.height)));
      variants.add(mapTo((f) => Offset(
            (1 - f.dx) * size.width,
            (1 - f.dy) * size.height,
          )));
    } else {
      // Ảnh HOÁN ĐỔI trục khung (khung dọc + ảnh ngang, hoặc khung ngang +
      // ảnh dọc): hiển thị = xoay ±90°:
      //  • hiển thị = xoay CW của ảnh: (a, b) → (u = b, v = 1 - a)
      //  • hiển thị = xoay CCW của ảnh: (a, b) → (u = 1 - b, v = a)
      //  với (a, b) là tỉ lệ khung, (u, v) là tỉ lệ ảnh.
      variants.add(mapTo((f) =>
          Offset(f.dy * size.width, (1 - f.dx) * size.height)));
      variants.add(mapTo((f) =>
          Offset((1 - f.dy) * size.width, f.dx * size.height)));
    }

    AlignmentQuad? best;
    var bestScore = -1.0;
    // targetQuad cho warp thu nhỏ phải theo TỈ LỆ output mini.
    final sf = 320.0 / layout.page.width;
    final shr = 450 / layout.page.height;
    Offset scalePoint(Offset p) => Offset(p.dx * sf, p.dy * shr);
    final targetMini = AlignmentQuad(
      scalePoint(targetQuad.tl),
      scalePoint(targetQuad.tr),
      scalePoint(targetQuad.br),
      scalePoint(targetQuad.bl),
    );
    for (final v in variants) {
      final quad = AlignmentQuad(v[0], v[1], v[2], v[3]);
      if (!_plausibleQuad(quad)) continue;
      // Warp bản thu nhỏ (tránh encode PNG lớn) rồi đo 12 mốc.
      final mini = const PerspectiveWarper().warpToImage(
        imageBytes,
        quad: quad,
        targetQuad: targetMini,
        outputSize: const Size(320, 450),
      );
      final score = _markerQuality(
        mini,
        layout,
        scale: mini.width / layout.page.width,
      );
      if (score > bestScore) {
        bestScore = score;
        best = quad;
      }
    }
    // Ngưỡng tin cậy: biến thể quad đúng cho LÕI 12 mốc TỐI (≥50% pixel
    // <110) VÀ vòng ngoài mép mốc TRẮNG (lề giấy ≥ 50% pixel >190) —
    // quad rác (đo giữa nội dung) không thể đạt đồng thời cả hai.
    // R4: ngưỡng nhận qua [minQuality] — lượt thử thứ nới lỏng 0.35.
    if (best == null || bestScore < minQuality) return null;
    return best;
  }

  /// R5 — QUÉT TRONG VÙNG GHIM: trả về quad PIXEL ẢNH bằng cách tìm tâm blob
  /// đen TRONG TỪNG ô hình chữ nhật giáo viên căn trên preview.
  ///
  /// Nguyên tắc (yêu cầu người dùng 2026-10-24): **TOÀN BỘ DIỆN TÍCH từng ô
  /// là vùng nhận diện mốc** — quét mọi pixel trong cửa sổ ô; tâm khối pixel
  /// TỐI chính là tâm mốc thật. Không dùng tâm ô do giáo viên kéo (sai số
  /// ngón tay) và không phụ thuộc ngưỡng chất lượng warp 0.55 của
  /// [_resolveOverlayQuad] — có 4 blob đen cỡ đồng nhất là đủ tin cậy.
  ///
  /// [overlayRects]: 4 ô theo TỈ LỆ khung hiển thị (0..1, thứ tự tl,tr,br,bl);
  /// [frameSize]: kích thước khung hiển thị (chỉ dùng để QUYẾT TRỤC ảnh ↔
  /// khung). Cửa sổ quét được PHÓNG quanh tâm ô (kẹp biên ảnh) để chịu sai số
  /// ánh xạ preview ↔ ảnh chụp (FOV ảnh có thể rộng hơn khung); tâm blob phải
  /// nằm lại TRONG ô gốc mới tính là tìm thấy.
  ///
  /// Chọn biến thể hướng (thẳng/180/CW/CCW) giống [_resolveOverlayQuad] nhưng
  /// điểm tin cậy = TỈ LỆ ĐEN (fill) trong ô — biến thể đúng cho 4 ô đều có
  /// blob đen; quad rác/không phủ mốc không thể đạt [_rectMinFill].
  /// [exclude]: quad đã bị kiểm chứng từ chối ở lượt trước — biến thể sinh
  /// quad TRÙNG (≤ 2 px/mốc) bị bỏ qua để lượt fallback nhận biến thể HƯỚNG
  /// còn lại (mốc 180°/90° đối xứng khiến 2 biến thể đều bắt được blob).
  AlignmentQuad? _resolveOverlayRects(
    Uint8List bytes,
    int channels, {
    required int imageWidth,
    required int imageHeight,
    required List<Rect> overlayRects,
    required Size frameSize,
    AlignmentQuad? exclude,
  }) {
    if (overlayRects.length < 4) return null;
    // R15/R16: quét trên dữ liệu ĐÃ DECODE 1 lần — img.Image/decodeImage
    // nằm ngay đằng sau (tốn ~1-2s) đã bỏ; `bytes` + kênh truyền xuống.
    final size = Size(imageWidth.toDouble(), imageHeight.toDouble());
    final fw = frameSize.width;
    final fh = frameSize.height;
    if (fw <= 0 || fh <= 0) return null;

    // Biến thể hướng áp lên ĐIỂM TỈ LỆ (a,b hệ khung → u,v hệ ảnh).
    // Mỗi biến thể kèm NGHỊCH ĐẢO để quy tâm blob tìm thấy trong ảnh về
    // hệ khung (kiểm "tâm nằm trong ô gốc") — ánh xạ ±90° không tự nghịch.
    final bool sameAxis = (size.height >= size.width) == (fh >= fw);
    final List<(Offset Function(Offset), Offset Function(Offset))> variants;
    if (sameAxis) {
      // Cùng trục: thẳng + xoay 180° (cả hai tự nghịch đảo).
      variants = [
        ((f) => f, (f) => f),
        ((f) => Offset(1 - f.dx, 1 - f.dy), (f) => Offset(1 - f.dx, 1 - f.dy)),
      ];
    } else {
      // Khác trục (khung dọc + ảnh ngang, hoặc ngược lại): hiển thị = xoay
      // ±90° của ảnh — cùng công thức của [_resolveOverlayQuad].
      variants = [
        (
          (f) => Offset(f.dy, 1 - f.dx), // hiển thị = CW của ảnh
          (f) => Offset(1 - f.dy, f.dx), // ảnh → khung: (u,v) → (a=1−v, b=u)
        ),
        (
          (f) => Offset(1 - f.dy, f.dx), // hiển thị = CCW của ảnh
          (f) => Offset(f.dy, 1 - f.dx), // ảnh → khung: (u,v) → (a=v, b=1−u)
        ),
      ];
    }

    AlignmentQuad? best;
    var bestScore = -1.0;

    // TEMPDBG
    var variantIdx = 0;
    for (final (fwd, inv) in variants) {
      final locates = <_MarkerLocate>[];
      var worstFill = double.infinity;
      var ok = true;
      var rectIdx = 0;
      for (final rect in overlayRects.take(4)) {
        // Cửa sổ quét = ô PHÓNG quanh tâm (chống lệch FOV), kẹp biên ảnh.
        final expanded = expandFractionRect(rect, _rectExpandFactor);
        final c0 = fwd(expanded.topLeft);
        final c1 = fwd(expanded.bottomRight);
        final region = Rect.fromLTRB(
          math.min(c0.dx, c1.dx) * size.width,
          math.min(c0.dy, c1.dy) * size.height,
          math.max(c0.dx, c1.dx) * size.width,
          math.max(c0.dy, c1.dy) * size.height,
        );
        final locate = _locateDarkBlobInRect(
          bytes,
          channels,
          imageWidth,
          imageHeight,
          region,
        );
        if (locate == null) {
          // TEMPDBG
          debugPrint('DBG rects-scan: ô #$rectIdx biến thể #$variantIdx → KHÔNG có khối tối đủ lớn (region=$region)');
          ok = false;
          break;
        }
        // Tâm blob phải nằm lại TRONG ô gốc (ảnh → khung qua nghịch đảo).
        final cFrac = inv(Offset(
          locate.centroid.dx / size.width,
          locate.centroid.dy / size.height,
        ));
        if (!rect.contains(cFrac)) {
          // TEMPDBG
          debugPrint('DBG rects-scan: ô #$rectIdx biến thể #$variantIdx → tâm blob $cFrac NGOÀI ô $rect');
          ok = false;
          break;
        }
        locates.add(locate);
        worstFill = math.min(worstFill, locate.fill);
        rectIdx++;
      }
      if (!ok || worstFill < _rectMinFill) continue;
      // Cỡ mốc phải ĐỒNG NHẤT giữa 4 góc (mốc in 1 cỡ — blob bong bóng ngoài
      // phiếu hoặc glyph nội dung không thể trùng cỡ khắp 4 góc).
      final sides = [for (final l in locates) l.side];
      final sMin = sides.reduce(math.min);
      final sMax = sides.reduce(math.max);
      if (sMin <= 0 || sMax / sMin > 2.4) {
        // TEMPDBG
        debugPrint('DBG rects-scan: biến thể #$variantIdx rớt cạnh $sides (sMax/sMin=${(sMax / sMin).toStringAsFixed(2)})');
        continue;
      }
      final quad = AlignmentQuad(
        locates[0].centroid,
        locates[1].centroid,
        locates[2].centroid,
        locates[3].centroid,
      );
      if (!_plausibleQuad(quad)) continue;
      if (exclude != null && _quadNearlyEqual(quad, exclude)) continue;
      // TEMPDBG
      debugPrint('DBG rects-scan: biến thể #$variantIdx NHẬN quad (worstFill=${worstFill.toStringAsFixed(3)}): $quad');
      if (worstFill > bestScore) {
        bestScore = worstFill;
        best = quad;
      }
      // TEMPDBG: chuyển sang biến thể kế.
      variantIdx++;
    }
    return best;
  }

  /// Tỉ lệ đen tối thiểu trong cửa sổ quét coi là "có mốc": fill đo trên cửa
  /// sổ PHÓNG 1.5× nên bị pha loãng theo tỉ lệ 1/(hệ số phóng × ô/cạnh mốc)²:
  ///  * ô CHUẨN (mốc chiếm ~70% cạnh ô) → fill ≈ 0.22;
  ///  * ô kéo tay LỆCH nhẹ (ô ≈ 2.5× cạnh mốc) → fill ≈ 0.07 — vẫn phải đạt;
  ///  * ô rác (nội dung chữ/glyph) → fill ≈ ≤ 0.02.
  static const double _rectMinFill = 0.04;

  /// Hệ số PHÓNG cửa sổ quét quanh tâm ô (chống sai lệch FOV preview ↔ ảnh).
  static const double _rectExpandFactor = 1.5;

  /// [expandFractionRect] đã chuyển vào marker_blob_scan.dart (dùng chung
  /// với luồng live đèn xanh R8).

  /// Tìm blob tối trong 1 vùng ảnh (px nguyên) — trả về tâm khối tối + cỡ
  /// cạnh ước lượng + tỉ lệ đặc của khối (R6b).
  ///
  /// R6b — hai sửa so với R5:
  ///  1. Ngưỡng theo PHÂN VỊ 75 của cửa sổ ("mức trang giấy"), không còn
  ///     mean×0.62: chụp màn Phần BezEL đen cạnh trang kéo mean xuống →
  ///     mốc gray ~90 rớt ngưỡng cũ. Trang chiếm đa số cửa sổ nên phân vị
  ///     75 luôn rơi vào "trang" — mốc (gray thấp) và glyph đều tối so với
  ///     trang; nền đen phẳng bên ngoài trang không làm lệch ngưỡng.
  ///  2. Chọn THÀNH PHẦN LIÊN THÔNG đặc (fill ≥ 0.5, gần vuông), không còn
  ///     gộp MỌI pixel tối vào một tâm: chữ/bezel trong cửa sổ chỉ là
  ///     cột dẹt/glyph nhỏ bị lọc theo hình dạng — mốc ô vuông đen thắng
  ///     (khối đặc lớn nhất), tâm blob = tâm mốc thật.
  _MarkerLocate? _locateDarkBlobInRect(
    Uint8List bytes,
    int channels,
    int imageWidth,
    int imageHeight,
    Rect region,
  ) {
    final w = imageWidth;
    final h = imageHeight;
    final x0 = region.left.clamp(0.0, w - 1.0).toInt();
    final y0 = region.top.clamp(0.0, h - 1.0).toInt();
    final x1 = region.right.clamp(x0 + 8.0, w.toDouble()).toInt();
    final y1 = region.bottom.clamp(y0 + 8.0, h.toDouble()).toInt();
    final rw = x1 - x0;
    final rh = y1 - y0;
    if (rw < 8 || rh < 8) return null;

    // Thuật toán dùng CHUNG theo R7 (2026-10-25): cùng phép quét chạy LIVE
    // cho đèn xanh từng ô (marker_blob_scan.dart).
    // R16: đọc độ xám qua CHỈ SỐ mảng (luminance 299/587/114 — GIỮ NGUYÊN
    // công thức của đường getPixel cũ) thay getPixel từng pixel (tạo
    // object/một lần gọi mỗi pixel — chậm rõ trong build debug).
    int grayAtByte(int x, int y) {
      if (x < 0 || y < 0 || x >= w || y >= h) return 255;
      final idx = (y * w + x) * channels;
      if (idx >= bytes.length) return 255;
      final r = bytes[idx];
      if (channels < 3 || idx + 2 >= bytes.length) return r;
      final g = bytes[idx + 1];
      final b = bytes[idx + 2];
      return (r * 299 + g * 587 + b * 114) ~/ 1000;
    }

    return locateDarkBlobInRegion(
      width: w,
      height: h,
      region: region,
      grayAt: grayAtByte,
    );
  }

  /// Ngưỡng chất lượng quad overlay — dưới ngưỡng coi như quad rác.
  static const double _overlayQuadMinQuality = 0.55;

  /// Quad còn "hình chữ nhật" (trải đủ 2 chiều) — chặn quad dẹt/rác.
  bool _plausibleQuad(AlignmentQuad quad) {
    final xs = <double>[quad.tl.dx, quad.tr.dx, quad.br.dx, quad.bl.dx];
    final ys = <double>[quad.tl.dy, quad.tr.dy, quad.br.dy, quad.bl.dy];
    final w = xs.reduce(math.max) - xs.reduce(math.min);
    final h = ys.reduce(math.max) - ys.reduce(math.min);
    return w > 1 && h > 1;
  }

  /// Hai quad trùng nhau khi chênh ≤ 2 px ở mỌI mốc (tâm blob lặp lại như
  /// nhau giữa 2 biến thể cùng quét 1 vùng).
  bool _quadNearlyEqual(AlignmentQuad a, AlignmentQuad b) {
    final ptsA = [a.tl, a.tr, a.br, a.bl];
    final ptsB = [b.tl, b.tr, b.br, b.bl];
    for (var i = 0; i < 4; i++) {
      if ((ptsA[i] - ptsB[i]).distance > 2.0) return false;
    }
    return true;
  }

  /// Chất lượng warp tại 12 vị trí mốc trên trang chuẩn (0..1):
  /// ½·(tỉ lệ pixel TỐI <110 trong lõi mốc) + ½·(tỉ lệ TRẮNG >190 ở vòng
  /// lề ngay ngoài mép mốc). Quad đúng: mốc đen + lề trắng cùng lúc.
  double _markerQuality(
    img.Image warped,
    SheetLayout layout, {
    required double scale,
  }) {
    final template = layout.template;
    final centers = <Offset>[
      ...layout.cornerMarkerCenters,
      for (final m in template.extraMarkers) layout.toPage(m.x, m.y),
    ];
    final r = (template.markerSide * layout.scale * scale ~/ 2)
        .clamp(1, 12)
        .toDouble();
    final rOuter = r * 1.9;
    var coreDark = 0;
    var ringWhite = 0;
    var ringCount = 0;
    for (final c in centers) {
      final cx = (c.dx * scale).toInt();
      final cy = (c.dy * scale).toInt();
      for (var dy = -rOuter.toInt(); dy <= rOuter.toInt(); dy++) {
        for (var dx = -rOuter.toInt(); dx <= rOuter.toInt(); dx++) {
          final d = math.sqrt((dx * dx + dy * dy).toDouble());
          final x = (cx + dx).clamp(0, warped.width - 1);
          final y = (cy + dy).clamp(0, warped.height - 1);
          final v = warped.getPixel(x, y).r.toInt();
          if (d <= r && v < 110) coreDark++;
          if (d >= r && d <= rOuter) {
            if (v > 190) ringWhite++;
            ringCount++;
          }
        }
      }
    }
    if (ringCount == 0) return 0;
    final coreCount = centers.length *
        ((2 * r.toInt() + 1) * (2 * r.toInt() + 1));
    return 0.5 * (coreDark / coreCount) + 0.5 * (ringWhite / ringCount);
  }

  SheetScan scan(
    Uint8List imageBytes, {
    required SheetLayout layout,
    SheetSpec? spec,
    OmrTuning tuning = const OmrTuning(),
  }) {
    final stopwatch = Stopwatch()..start();
    final densities = pipeline.measure(imageBytes, layout: layout, tuning: tuning);
    final answers = decoder.decodeAnswers(
      blocks: densities.answerBlocks,
      spec: spec ?? layout.specOrDefault,
      totalQuestions: layout.totalQuestions,
      rowsPerAnswerBlock: layout.rowsPerAnswerBlock,
    );
    final studentCodeRaw = decoder.decodeDigits(densities.studentCodeGrid);
    final examCodeRaw = decoder.decodeDigits(densities.examCodeGrid);
    stopwatch.stop();
    return SheetScan(
      answers: List.unmodifiable(answers),
      studentCodeRaw: studentCodeRaw,
      examCodeRaw: examCodeRaw,
      answerBlocks: densities.answerBlocks,
      studentCodeGrid: densities.studentCodeGrid,
      examCodeGrid: densities.examCodeGrid,
      processingTime: stopwatch.elapsed,
    );
  }

  /// R15: quét trên mảng xám PLANAR đã nắn (đường nóng) — đo mật độ qua
  /// [DartOmrImagePipeline.measureGrayPlanar] thay [measure] (bỏ decode PNG
  /// + grayscale-copy), decode đáp án như [scan] cũ. Kết quả tương đương
  /// từng pixel.
  SheetScan scanGrayPlanar(
    Uint8List gray, {
    required int width,
    required int height,
    required SheetLayout layout,
    SheetSpec? spec,
    OmrTuning tuning = const OmrTuning(),
  }) {
    final stopwatch = Stopwatch()..start();
    final densities = pipeline is DartOmrImagePipeline
        ? (pipeline as DartOmrImagePipeline).measureGrayPlanar(
            gray,
            width: width,
            height: height,
            layout: layout,
            tuning: tuning,
          )
        : pipeline.measure(
            _grayPlanarToPng(gray, width, height),
            layout: layout,
            tuning: tuning,
          );
    final answers = decoder.decodeAnswers(
      blocks: densities.answerBlocks,
      spec: spec ?? layout.specOrDefault,
      totalQuestions: layout.totalQuestions,
      rowsPerAnswerBlock: layout.rowsPerAnswerBlock,
    );
    final studentCodeRaw = decoder.decodeDigits(densities.studentCodeGrid);
    final examCodeRaw = decoder.decodeDigits(densities.examCodeGrid);
    stopwatch.stop();
    return SheetScan(
      answers: List.unmodifiable(answers),
      studentCodeRaw: studentCodeRaw,
      examCodeRaw: examCodeRaw,
      answerBlocks: densities.answerBlocks,
      studentCodeGrid: densities.studentCodeGrid,
      examCodeGrid: densities.examCodeGrid,
      processingTime: stopwatch.elapsed,
    );
  }
}

/// R15: rơi dự phòng khi pipeline KHÔNG phải DartOmrImagePipeline
/// (không có nhánh measureGrayPlanar) — gói mảng xám thành PNG cho đường
/// cũ. Chỉ dùng đúng 1 lần cho lượt chuẩn (chi phí không áp ảnh thật).
Uint8List _grayPlanarToPng(Uint8List gray, int width, int height) {
  // R17 (log22: encode=578ms release): chỉ dùng cho LƯU DB + hiển thị —
  // nửa độ phân giải (788×1102) vẫn đủ đọc phiếu, 4× ít pixel ⇒ encode
  // rẻ ~4×. Đo mật độ/chấm KHÔNG dùng hàm này (chạy trên mảng xám).
  var w = width;
  var h = height;
  var src = gray;
  if (w >= 8 && h >= 8) {
    final ow = w ~/ 2;
    final oh = h ~/ 2;
    final half = Uint8List(ow * oh);
    for (var y = 0; y < oh; y++) {
      final srcRow = (2 * y) * width;
      final dstRow = y * ow;
      for (var x = 0; x < ow; x++) {
        half[dstRow + x] = gray[srcRow + 2 * x];
      }
    }
    w = ow;
    h = oh;
    src = half;
  }
  // R16: Image.fromBytes — cùng biểu diễn pixel, bỏ vòng setPixelRgb.
  final page = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: src.buffer,
    format: img.Format.uint8,
    numChannels: 1,
  );
  return img.encodePng(page, level: 1);
}

/// R5 — Kết quả tìm blob tối trong 1 ô ghim (hệ PIXEL ẢNH).
/// R7: thuật toán đã tách vào marker_blob_scan.dart — đây chỉ BÍ DANH
/// (typedef) giữ tương thích các chỗ gọi nội bộ.
typedef _MarkerLocate = MarkerLocate;
