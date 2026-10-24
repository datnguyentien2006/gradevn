import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as img;

import '../../domain/entities/sheet_spec.dart';
import '../../domain/services/omr_decoder.dart';
import '../../domain/services/sheet_layout.dart';
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
  /// \[knownQuad\] là quad ở HỆ ẢNH CHỤP (pixel ảnh decode) — dùng khi đã biết
  /// chắc toạ độ (vd. ảnh đã nắn về trang chuẩn từ CropReviewScreen: quad =
  /// 4 tâm mốc góc trang chuẩn), không dò hướng, không chạy detector.
  PhotoScan? scanPhoto(
    Uint8List imageBytes, {
    required SheetSpec spec,
    OmrTuning tuning = const OmrTuning(),
    AlignmentQuad? overlayQuad,
    Size frameSize = const Size(1, 1),
    AlignmentQuad? knownQuad,
  }) {
    final stopwatch = Stopwatch()..start();
    final layout = SheetLayout.forSpec(spec, page: omrPageSize);
    final targetQuad = AlignmentQuad(
      layout.cornerMarkerCenters[0],
      layout.cornerMarkerCenters[1],
      layout.cornerMarkerCenters[2],
      layout.cornerMarkerCenters[3],
    );

    AlignmentQuad? quad;
    List<Offset>? detectedCandidates;
    if (knownQuad != null) {
      quad = knownQuad;
    } else {
      final detection = detector.detect(imageBytes);
      detectedCandidates = [
        for (final c in detection.candidates) Offset(c.dx, c.dy),
      ];
      quad = detection.quad;
      if (quad == null && overlayQuad != null) {
        // R2: quad ghim của giáo viên là lưới an toàn khi detector bó tay:
        // phân định hướng ảnh (thẳng / xoay) rồi dùng vị trí ghim.
        quad = _resolveOverlayQuad(
          imageBytes,
          overlayQuad: overlayQuad,
          frameSize: frameSize,
          layout: layout,
          targetQuad: targetQuad,
        );
      }
    }
    if (quad == null) return null;
    Uint8List warped;
    WarpedMarkerCheck? verification;
    if (knownQuad != null) {
      // knownQuad (ảnh đã ghim tay từ CropReview): miễn kiểm — tránh vòng
      // lặp với mốc phai.
      warped = warper.warpRectify(
        imageBytes,
        quad: quad,
        targetQuad: targetQuad,
        outputSize: layout.page,
      );
    } else {
      warped = warper.warpRectify(
        imageBytes,
        quad: quad,
        targetQuad: targetQuad,
        outputSize: layout.page,
      );
      // R3 — KIỂM CHỨNG ROUND-TRIP: ảnh đã nắn phải tái-detect được CẢ 4 mốc
      // góc trong ≤ 6 px trang chuẩn. Góc nào lệch ⇒ coi như phiếu chưa căn
      // đúng (warp rác/pin nhắm) → null → UI rơi CropReviewScreen, KHÔNG chấm
      // một phiếu có thể sai lattice.
      verification = verifyWarpedMarkers(warped, layout: layout);
      // R3.1 (màn NGANG): detector gán nhãn tl/tr/br/bl theo TRỤC ẢNH decode;
      // ảnh chụp ngang khiến quad đúng VỊ TRÍ nhưng NHÃN lệch 90° ⇒ warp sai
      // chiều ⇒ kiểm chứng rớt. Khi có vị trí GHIM từ preview, phân định
      // hướng qua ĐIỂM TỐI của mốc thật rồi thử lại — lượt đạt kiểm chứng
      // mới được dùng.
      if (!verification.passed && overlayQuad != null) {
        final alt = _resolveOverlayQuad(
          imageBytes,
          overlayQuad: overlayQuad,
          frameSize: frameSize,
          layout: layout,
          targetQuad: targetQuad,
        );
        if (alt != null) {
          final altWarped = warper.warpRectify(
            imageBytes,
            quad: alt,
            targetQuad: targetQuad,
            outputSize: layout.page,
          );
          final altVerification =
              verifyWarpedMarkers(altWarped, layout: layout);
          if (altVerification.passed) {
            quad = alt;
            warped = altWarped;
            verification = altVerification;
          }
        }
      }
      if (!verification.passed) return null;
    }
    final scanResult = scan(warped, layout: layout, spec: spec, tuning: tuning);
    stopwatch.stop();
    return PhotoScan(
      scan: scanResult,
      quad: quad,
      warpedBytes: warped,
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
    if (best == null || bestScore < _overlayQuadMinQuality) return null;
    return best;
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
}
