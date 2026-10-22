import 'dart:typed_data';

import '../../domain/entities/sheet_spec.dart';
import '../../domain/services/omr_decoder.dart';
import '../../domain/services/sheet_layout.dart';
import 'omr_image_pipeline.dart';

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

  /// Chuỗi 6 chữ số đọc từ lưới mã đề.
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

/// Ghép pipeline đo mật độ + bộ giải mã thành một bước "quét phiếu".
///
/// Interface/pipeline tách rời để M3 có thể thay bằng opencv_dart mà không đổi
/// tầng domain hay UI.
final class OmrScanService {
  const OmrScanService({
    this.pipeline = const DartOmrImagePipeline(),
    this.decoder = const OmrDecoder(),
  });

  final OmrImagePipeline pipeline;
  final OmrDecoder decoder;

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
      spec: spec ?? layout.spec,
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
