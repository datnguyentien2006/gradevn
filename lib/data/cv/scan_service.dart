import 'dart:typed_data';
import 'dart:ui' show Size;

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
}

/// Kết quả quét 1 ảnh chụp thật: 4 góc khung đã phát hiện + ảnh nắn phẳng +
/// kết quả đo/giải mã trên ảnh nắn phẳng.
final class PhotoScan {
  const PhotoScan({
    required this.scan,
    required this.quad,
    required this.warpedBytes,
  });

  final SheetScan scan;
  final AlignmentQuad quad;

  /// Ảnh đã nắn phẳng về [omrPageSize] (PNG) — dùng làm ảnh gốc khi lưu DB.
  final Uint8List warpedBytes;
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
  PhotoScan? scanPhoto(
    Uint8List imageBytes, {
    required SheetSpec spec,
    OmrTuning tuning = const OmrTuning(),
  }) {
    final stopwatch = Stopwatch()..start();
    final detection = detector.detect(imageBytes);
    final quad = detection.quad;
    if (quad == null) return null;
    final layout = SheetLayout.forSpec(spec, page: omrPageSize);
    final targetQuad = AlignmentQuad(
      layout.cornerMarkerCenters[0],
      layout.cornerMarkerCenters[1],
      layout.cornerMarkerCenters[2],
      layout.cornerMarkerCenters[3],
    );
    final warped = warper.warpRectify(
      imageBytes,
      quad: quad,
      targetQuad: targetQuad,
      outputSize: layout.page,
    );
    final scanResult = scan(warped, layout: layout, spec: spec, tuning: tuning);
    stopwatch.stop();
    return PhotoScan(scan: scanResult, quad: quad, warpedBytes: warped);
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
