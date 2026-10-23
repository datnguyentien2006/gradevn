// Keo dán "quét → chấm → gắn học sinh" (M3) — THUẦN Dart, không dart:io,
// không camera, không UI: nhận bytes ảnh vào, trả về entity giá trị ra.
//
// Nút bấm hai mức:
// - [gradeScan]: hàm thuần (unit-test trực tiếp, chạy trong Isolate được).
// - [processPhoto]: bọc [gradeScan] trong `Isolate.run` để pipeline đo mật độ
//   (tốn CPU) không treo thread UI khi chụp thật.

import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Size;

import '../../domain/entities/contest.dart';
import '../../domain/entities/class_room.dart';
import '../../domain/services/grader.dart';
import '../../domain/services/omr_decoder.dart';
import 'omr_image_pipeline.dart' show OmrTuning;
import 'sheet_alignment.dart' show AlignmentQuad;
import 'scan_service.dart';

/// Kết quả chấm một phiếu đã quét: điểm + key đã dùng + học sinh đã gắn
/// + ảnh chụp gốc ([PhotoScan]) để lưu DB / vẽ phiếu có gạch đáp án.
final class GradedScan {
  const GradedScan({
    required this.result,
    required this.usedExamCode,
    required this.usedKey,
    required this.usedBestGuessKey,
    required this.student,
    required this.photo,
  });

  /// Kết quả chấm (cờ đúng/sai từng câu + điểm tổng + điểm từng phần).
  final GradingResult result;

  /// Mã đề thực dùng để chấm: mã đề nằm trên key đã chọn, hoặc mã đề đọc
  /// được (đã chuẩn hoá) khi không có key.
  final String usedExamCode;

  /// Key được chọn: khớp mã đề trước, fallback mã đề điểm cao nhất; null
  /// khi kỳ thi chưa có key nào.
  final AnswerKey? usedKey;

  /// true khi đọc không được mã đề và phải đoán key theo điểm khớp cao nhất.
  final bool usedBestGuessKey;

  /// Học sinh khớp SBD (tra cứu theo lưới số — nguồn sự thật duy nhất).
  /// null khi SBD không tra được / không có danh sách lớp.
  final Student? student;

  /// Kết quả quét ảnh gốc (khung + ảnh nắn phẳng PNG 1240×1754).
  final PhotoScan photo;
}

/// Chấm một phiếu từ dữ liệu đã giải mã (thuần, không IO).
///
/// - Chọn key: `Grader.selectKey` theo mã đề (chuẩn hoá, xoá số 0 vô nghĩa);
///   đọc không được mã đề → `Grader.bestScoringKey` đoán theo điểm khớp cao nhất.
/// - Không có key nào: kết quả toàn câu null (không trừ điểm, không ném lỗi).
/// - Gắn học sinh: chỉ tra cứu theo SBD đọc từ lưới số. OCR ([StudentInfoOcr])
///   KHÔNG tham gia quyết định — lưới số là nguồn tất định.
GradedScan gradeScan({
  required Contest contest,
  required List<AnswerKey> keys,
  required List<Student> candidateStudents,
  required List<String?> chosen,
  required String studentCodeRaw,
  required String examCodeRaw,
  required PhotoScan photo,
}) {
  final directKey = Grader.selectKey(keys, examCodeRaw);
  final key = directKey ?? Grader.bestScoringKey(keys: keys, chosen: chosen);

  // "Đoán key" chỉ chấp nhận khi mã đề không đọc được (rỗng hoặc có '?').
  final normalizedExam = OmrDecoder.normalizeCode(examCodeRaw);
  final usedBestGuessKey =
      directKey == null && key != null && (normalizedExam.isEmpty || normalizedExam.contains('?'));

  // Không key nào: gradeForContest with dãy đáp án rỗng → mọi cờ null, điểm 0.
  final result = const Grader().gradeForContest(
    contest: contest,
    keyAnswers: key?.answerSequence ?? '',
    chosen: chosen,
  );

  final normalizedStudent = OmrDecoder.normalizeCode(studentCodeRaw);
  Student? student;
  if (normalizedStudent.isNotEmpty) {
    for (final candidate in candidateStudents) {
      if (OmrDecoder.normalizeCode(candidate.code) == normalizedStudent) {
        student = candidate;
        break;
      }
    }
  }

  return GradedScan(
    result: result,
    usedExamCode: key?.examCode ?? normalizedExam,
    usedKey: key,
    usedBestGuessKey: usedBestGuessKey,
    student: student,
    photo: photo,
  );
}

/// Dữ liệu đầu vào của isolate (mọi trường đều plain-data: TypedData/const
/// entity — gửi qua port an toàn).
final class _ScanJob {
  const _ScanJob({
    required this.bytes,
    required this.contest,
    required this.keys,
    required this.candidateStudents,
    required this.tuning,
    this.overlayQuad,
    this.overlayFrameSize = const Size(1, 1),
    this.knownQuad,
  });

  final Uint8List bytes;
  final Contest contest;
  final List<AnswerKey> keys;
  final List<Student> candidateStudents;
  final OmrTuning tuning;

  /// R2: quad giáo viên ghim trên preview (hệ KHUNG HIỂN THỊ) + khung đó.
  final AlignmentQuad? overlayQuad;
  final Size overlayFrameSize;

  /// R2: quad hệ ẢNH CHỤP biết chắc (ảnh đã nắn về trang chuẩn).
  final AlignmentQuad? knownQuad;
}

/// Thân isolate: quét ảnh → chấm. Hàm top-level (isolate không gửi method).
GradedScan? _scanAndGrade(_ScanJob job) {
  final photo = const OmrScanService().scanPhoto(
    job.bytes,
    spec: job.contest.sheetSpec,
    tuning: job.tuning,
    overlayQuad: job.overlayQuad,
    frameSize: job.overlayFrameSize,
    knownQuad: job.knownQuad,
  );
  if (photo == null) return null; // khung căn chỉnh không tìm thấy
  return gradeScan(
    contest: job.contest,
    keys: job.keys,
    candidateStudents: job.candidateStudents,
    chosen: photo.scan.answers,
    studentCodeRaw: photo.scan.studentCodeRaw,
    examCodeRaw: photo.scan.examCodeRaw,
    photo: photo,
  );
}

/// Bọc isolate: quét + chấm một ảnh chụp thật ngoài thread UI.
///
/// Trả về null khi không tìm thấy khung phiếu trên ảnh (gợi ý chụp lại/cắt ảnh).
///
/// R2: khi FE báo trước quad ghim 4 ô vuông từ preview ([overlayQuad] +
/// [frameSize]) hoặc quad hệ ảnh chụp chắc chắn ([knownQuad]) → pipeline
/// đổi thứ tự dự phòng như mô tả ở [OmrScanService.scanPhoto].
Future<GradedScan?> processPhoto(
  Uint8List bytes, {
  required Contest contest,
  required List<AnswerKey> keys,
  required List<Student> candidateStudents,
  OmrTuning tuning = const OmrTuning(),
  AlignmentQuad? overlayQuad,
  Size frameSize = const Size(1, 1),
  AlignmentQuad? knownQuad,
}) {
  return Isolate.run(() {
    final job = _ScanJob(
      bytes: bytes,
      contest: contest,
      keys: keys,
      candidateStudents: candidateStudents,
      tuning: tuning,
      overlayQuad: overlayQuad,
      overlayFrameSize: frameSize,
      knownQuad: knownQuad,
    );
    return _scanAndGrade(job);
  });
}
