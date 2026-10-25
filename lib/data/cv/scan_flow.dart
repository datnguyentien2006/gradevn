// Keo dán "quét → chấm → gắn học sinh" (M3) — THUẦN Dart, không dart:io,
// không camera, không UI: nhận bytes ảnh vào, trả về entity giá trị ra.
//
// Nút bấm hai mức:
// - [gradeScan]: hàm thuần (unit-test trực tiếp, chạy trong Isolate được).
// - [processPhoto]: bọc [gradeScan] trong `Isolate.run` để pipeline đo mật độ
//   (tốn CPU) không treo thread UI khi chụp thật.

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'dart:ui' show Rect, Size, Image, ImageByteFormat, decodeImageFromList;

import '../../domain/entities/contest.dart';
import '../../domain/entities/class_room.dart';
import '../../domain/services/grader.dart';
import '../../domain/services/omr_decoder.dart';
import 'omr_image_pipeline.dart' show OmrTuning;
import 'sheet_alignment.dart' show AlignmentQuad;
import 'scan_service.dart';

/// R2 — Lý do phiếu bị bỏ chấm (luồng NULL): giáo viên quên tô một trong
/// hai lưới chỉ dẫn. Mã đề ưu tiên hơn khi cả hai trống.
enum UngradedReason { examCode, studentCode }

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
    this.graded = true,
    this.ungradedReason,
    this.multiAnswerCount = 0,
  });

  /// Kết quả chấm (cờ đúng/sai từng câu + điểm tổng + điểm từng phần).
  final GradingResult result;

  /// Mã đề thực dùng để chấm: mã đề nằm trên key đã chọn, hoặc mã đề đọc
  /// được (đã chuẩn hoá) khi không có key.
  ///
  /// R2: với phiếu BỎ CHấm vì lưới mã đề trống → '' (dấu hiệu "chưa có
  /// mã đề" khi lưu DB, giáo viên bổ sung sau).
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

  /// R2: false = phiếu bị BỎ CHẤM (luồng NULL) — [result] chỉ là giá trị
  /// rỗng (tất cả cờ null, điểm 0), BAN ĐẦU cố ý KHÔNG chạy bộ chấm.
  final bool graded;

  /// R2: lý do bỏ chấm ([UngradedReason]) — non null khi [graded] == false.
  final UngradedReason? ungradedReason;

  /// R4: số câu tô ≥2 ô thật sự (cảnh báo "Nhiều đáp án" màn kết quả —
  /// decode vẫn chọn ô đậm nhất, KHÔNG chặn chấm).
  final int multiAnswerCount;
}

/// Chấm một phiếu từ dữ liệu đã giải mã (thuần, không IO).
///
/// - R2 LUỒNG NULL: mã đề HOẶC số báo danh hoàn toàn trống (không đọc được
///   chữ số nào) → BỎ chấm ngay: trả [GradedScan.graded] = false, không
///   chọn key, không chạy bộ chấm; UI hiện điểm "NULL" + lý do.
/// - Chọn key: `Grader.selectKey` theo mã đề (chuẩn hoá, xoá số 0 vô nghĩa);
///   mã đề đọc không ra (một phần, còn chữ số) → `Grader.bestScoringKey`
///   đoán theo điểm khớp cao nhất (cảnh báo best-key giữ nguyên như M3).
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
  final totalQuestions = contest.sheetSpec.questionCount;

  // → R2: LUỒNG NULL — lưới mã đề HOẶC số báo danh hoàn toàn TRỐNG (không
  // đọc được CHỮ SỐ nào → học sinh quên tô): BỎ CHẤM ngay, không chọn key,
  // KHÔNG chạy bộ chấm. Điểm không tồn tại (hiển thị "NULL").
  if (OmrDecoder.isBlankCode(examCodeRaw) ||
      OmrDecoder.isBlankCode(studentCodeRaw)) {
    final emptyResult = GradingResult(
      correctFlags: List<bool?>.filled(totalQuestions, null),
      score: 0,
    );
    // Cả hai trống: ưu tiên lý do mã đề (bổ sung trước khi chấm lại).
    final reason = OmrDecoder.isBlankCode(examCodeRaw)
        ? UngradedReason.examCode
        : UngradedReason.studentCode;
    // SBD đọc được vẫn gắn học sinh (không phải "chấm" — chỉ tra dữ liệu).
    Student? student;
    final normalizedStudent = OmrDecoder.normalizeCode(studentCodeRaw);
    for (final candidate in candidateStudents) {
      if (OmrDecoder.normalizeCode(candidate.code) == normalizedStudent) {
        student = candidate;
        break;
      }
    }
    return GradedScan(
      result: emptyResult,
      // Mã đề trống lưu '' (chờ giáo viên bổ sung); SBD trống lưu mã đề
      // đã đọc (đúng ràng) hoặc ''.
      usedExamCode: reason == UngradedReason.examCode
          ? ''
          : OmrDecoder.normalizeCode(examCodeRaw),
      usedKey: null,
      usedBestGuessKey: false,
      student: student,
      photo: photo,
      graded: false,
      ungradedReason: reason,
    );
  }

  final directKey = Grader.selectKey(keys, examCodeRaw);
  final key = directKey ?? Grader.bestScoringKey(keys: keys, chosen: chosen);

  // "Đoán key" chỉ chấp nhận khi mã đề không đọc được (rỗng hoặc có '?').
  final normalizedExam = OmrDecoder.normalizeCode(examCodeRaw);
  final usedBestGuessKey =
      directKey == null && key != null && (normalizedExam.isEmpty || normalizedExam.contains('?'));

  // Không key nào: gradeForContest với dãy đáp án rỗng → mọi cờ null, điểm 0.
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
    // R4: cảnh báo "Nhiều đáp án" — đếm câu có ≥2 ô đậm (decode vẫn chọn
    // ô đậm nhất; không chặn chấm).
    multiAnswerCount: OmrDecoder.countMultiMarkAnswers(
      blocks: photo.scan.answerBlocks,
      totalQuestions: totalQuestions,
    ),
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
    this.overlayRects,
    this.overlayFrameSize = const Size(1, 1),
    this.overlayQuad,
    this.knownQuad,
    this.relaxed = false,
    this.predecoded,
  });

  final Uint8List bytes;
  final Contest contest;
  final List<AnswerKey> keys;
  final List<Student> candidateStudents;
  final OmrTuning tuning;

  /// R17: RGBA đã decode SẴN bằng Skia ở isolate chính (xem [_skiaPredecode])
  /// — bơm thẳng vào scanPhoto, bỏ 715ms decode Dart (log22).
  final ({Uint8List rgba, int width, int height})? predecoded;

  /// R5: 4 ô HÌNH CHỮ NHẬT giáo viên căn trên preview — TOÀN BỘ DIỆN TÍCH
  /// từng ô là vùng nhận diện mốc (tỉ lệ khung hiển thị 0..1). Ưu tiên cao
  /// nhất: quét blob đen trong ô trước khi chạy detector toàn ảnh.
  final List<Rect>? overlayRects;

  /// R2: quad giáo viên ghim trên preview (hệ KHUNG HIỂN THỊ) + khung đó.
  final AlignmentQuad? overlayQuad;
  final Size overlayFrameSize;

  /// R2: quad hệ ẢNH CHỤP biết chắc (ảnh đã nắn về trang chuẩn).
  final AlignmentQuad? knownQuad;

  /// R4: lượt THỬ THỨ nới lỏng (bỏ kiểm chứng round-trip + hạ ngưỡng
  /// overlay) — giáo viên đã canh 4 ô khớp mốc trên preview → chấm thẳng
  /// thay vì rơi CropReview.
  final bool relaxed;
}

/// Thân isolate: quét ảnh → chấm. Hàm top-level (isolate không gửi method).
GradedScan? _scanAndGrade(_ScanJob job) {
  // TEMPDBG
  debugPrint('DBG scanAndGrade: relaxed=${job.relaxed} '
      'rects=${job.overlayRects} frame=${job.overlayFrameSize} '
      'overlayQuad=${job.overlayQuad != null} knownQuad=${job.knownQuad != null}');
  final photo = const OmrScanService().scanPhoto(
    job.bytes,
    spec: job.contest.sheetSpec,
    tuning: job.tuning,
    overlayRects: job.overlayRects,
    overlayQuad: job.overlayQuad,
    frameSize: job.overlayFrameSize,
    knownQuad: job.knownQuad,
    skipVerification: job.relaxed,
    overlayMinQuality: job.relaxed ? 0.35 : _defaultOverlayMinQuality,
    predecoded: job.predecoded,
  );
  // TEMPDBG
  debugPrint('DBG scanAndGrade: photo=${photo == null ? "NULL" : "quad=${photo.quad}, verify=${photo.verification}"}');
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
///
/// R4 — LUỒN CHẤM THẲNG (yêu cầu người dùng): lượt 1 chấm như thường; nếu
/// rớt (mốc phai / kiểm chứng < 6px / quad overlay dưới 0.55) chạy LƯỢT 2
/// nới lỏng ngay trong cùng isolate (bỏ kiểm chứng round-trip + hạ ngưỡng
/// overlay 0.35) — KHÔNG còn rơi về màn ghim mốc thủ công nữa. Chỉ báo lỗi
/// ở UI mới là "đọc không được phiếu → chụp lại".
/// R5 — \[overlayRects\]: 4 ô hình chữ nhật giáo viên căn trên preview —
/// pipeline QUÉT TOÀN DIỆN TÍCH từng ô để tìm mốc (ưu tiên cao nhất), đúng
/// nguyên tắc "khung chữ nhật là vùng nhận diện ô vuông tô đen".
Future<GradedScan?> processPhoto(
  Uint8List bytes, {
  required Contest contest,
  required List<AnswerKey> keys,
  required List<Student> candidateStudents,
  OmrTuning tuning = const OmrTuning(),
  List<Rect>? overlayRects,
  AlignmentQuad? overlayQuad,
  Size frameSize = const Size(1, 1),
  AlignmentQuad? knownQuad,
}) async {
  // R17: decode bằng DECODER NATIVE của engine (Skia) TRƯỚC lúc cài isolate
  // — decodeImageFromList chỉ chạy isolate chính, đổi lại nhanh hơn hẳn
  // decode Dart của package `image` (log22: decode=715ms → đo lần này).
  final predecoded = await _skiaPredecode(bytes);
  return Isolate.run(() {
    final job = _ScanJob(
      bytes: bytes,
      contest: contest,
      keys: keys,
      candidateStudents: candidateStudents,
      tuning: tuning,
      overlayRects: overlayRects,
      overlayQuad: overlayQuad,
      overlayFrameSize: frameSize,
      knownQuad: knownQuad,
      predecoded: predecoded,
    );
    final normal = _scanAndGrade(job);
    if (normal != null) return normal;
    // R4: lượt 2 — nới lỏng mọi kiểm chứng, chấm best-effort.
    return _scanAndGrade(_ScanJob(
      bytes: bytes,
      contest: contest,
      keys: keys,
      candidateStudents: candidateStudents,
      tuning: tuning,
      overlayRects: overlayRects,
      overlayQuad: overlayQuad,
      overlayFrameSize: frameSize,
      knownQuad: knownQuad,
      relaxed: true,
      predecoded: predecoded,
    ));
  });
}

/// Ngưỡng overlay mặc định của [OmrScanService] (0.55) — giữ một hằng ở
/// tầng flow để lượt 1 KHÔNG truyền gì (dùng mặc định) và lượt 2 nới rõ.
const double _defaultOverlayMinQuality = 0.55;

/// R17 — EXIF Orientation của JPEG (góc 0–8) đọc CHỈ TỪ HEADER (không decode
/// pixel, vài micro-giây): quét marker APP1 → TIFF header → IFD0 tag 0x0112.
/// null khi không đọc nổi / không có EXIF.
///
/// Lý do phải có: decodeImageFromList (Skia) TỰ ĐỘNG quay ảnh theo EXIF,
/// còn package `image` KHÔNG — nếu EXIF ≠ 1 mà dùng lẫn, hệ toạ độ pixel
/// lệch 90°/lật so với đường cũ ⇒ sai khung. Khi lệch → trả null, pipeline
/// dùng đường decode Dart cũ (chậm hơn nhưng GIỮ nguyên hiện trạng).
int? _jpegExifOrientation(Uint8List b) {
  try {
    if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
    var i = 2;
    while (i + 4 <= b.length) {
      final m = b[i + 1];
      if (b[i] != 0xFF || m == 0xFF) return null; // không phải marker
      if (m == 0x01 || (m >= 0xD0 && m <= 0xD7) || m == 0xD8) {
        i += 2; // marker không mang độ dài (STANDALONE/RST)
        continue;
      }
      if (m == 0xD9 || m == 0xDA) {
        return null; // EOI/SOS — hết header, không có EXIF
      }
      final segLen = (b[i + 2] << 8) | b[i + 3];
      if (segLen < 2) return null;
      if (m == 0xE1 && i + 12 <= b.length) {
        // chữ ký "Exif\0\0" bắt đầu sau độ dài phân đoạn
        if (b[i + 4] == 0x45 &&
            b[i + 5] == 0x78 &&
            b[i + 6] == 0x69 &&
            b[i + 7] == 0x66 &&
            b[i + 8] == 0x00 &&
            b[i + 9] == 0x00) {
          final t = i + 10; // đầu TIFF header
          final le = b[t] == 0x49 && b[t + 1] == 0x49; // "II"
          final be = b[t] == 0x4D && b[t + 1] == 0x4D; // "MM"
          if (!le && !be) return null;
          int u16(int p) =>
              le ? (b[p] | (b[p + 1] << 8)) : ((b[p] << 8) | b[p + 1]);
          int u32(int p) => le
              ? (b[p] |
                  (b[p + 1] << 8) |
                  (b[p + 2] << 16) |
                  (b[p + 3] << 24))
              : ((b[p] << 24) |
                  (b[p + 1] << 16) |
                  (b[p + 2] << 8) |
                  b[p + 3]);
          final ifd = t + u32(t + 4);
          if (ifd + 2 > b.length) return null;
          final count = u16(ifd);
          for (var e = 0; e < count; e++) {
            final ent = ifd + 2 + e * 12;
            if (ent + 12 > b.length) return null;
            if (u16(ent) == 0x0112) {
              // SHORT, count=1 → giá trị nằm 2 byte đầu của phần value
              return u16(ent + 8);
            }
          }
          return null;
        }
      }
      i += 2 + segLen;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// R17/R18 — decode ảnh bằng decoder NATIVE (Skia/dart:ui) trên isolate
/// chính, rồi HOÀN TÁC bake-EXIF của Skia khi ảnh có EXIF ≠ 1 (xem
/// [_unbakeExifRgba]) — khi đó hệ toạ độ pixel GIỐNG HẲN đường decode
/// package `image` (không bake), toàn bộ pipeline phía sau không đổi.
/// Trả null → pipeline decode lối cũ (package `image` trong isolate chấm).
Future<({Uint8List rgba, int width, int height})?> _skiaPredecode(
  Uint8List bytes,
) async {
  final orientation = _jpegExifOrientation(bytes);
  try {
    final swNative = Stopwatch()..start();
    final done = Completer<Image>();
    decodeImageFromList(bytes, done.complete);
    final image = await done.future;
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    final w = image.width;
    final h = image.height;
    image.dispose();
    swNative.stop();
    if (data == null) return null;
    final baked =
        data.buffer.asUint8List(data.offsetInBytes, w * h * 4);
    // EXIF ∈ 2..8 → Skia đã QUAY/lật ảnh so với layout thô: hoàn tác lại
    // để khớp hệ toạ độ của đường decode Dart cũ.
    final swUnbake = Stopwatch()..start();
    final unbaked = _unbakeExifRgba(baked, w, h, orientation ?? 1);
    swUnbake.stop();
    debugPrint('DBG predecode: EXIF=$orientation '
        'native=${swNative.elapsedMilliseconds}ms '
        'unbake=${swUnbake.elapsedMilliseconds}ms '
        '→ dùng Skia (${unbaked.width}x${unbaked.height})');
    return unbaked;
  } catch (e) {
    debugPrint('DBG predecode: LỖI $e → decode lối cũ');
    return null;
  }
}

/// R18 — cửa test cho [_unbakeExifRgba] (công khai CHỈ để test hình học).
@visibleForTesting
({Uint8List rgba, int width, int height}) unbakeExifRgbaForTest(
  Uint8List src,
  int w,
  int h,
  int orientation,
) =>
    _unbakeExifRgba(src, w, h, orientation);

/// R18 — hoàn tác bake EXIF của Skia trên RGBA (đưa về layout thô), trả về
/// kèm KÍCH THƯỚC THÔ (vì quay 90° hoán đổi w↔h).
///
/// Ý nghĩa EXIF = phép biến đổi cần áp lên THÔ để hiển thị đúng (bake):
///   1 none | 2 mirrorH | 3 rot180 | 4 mirrorV | 5 transpose | 6 rot90CW |
///   7 mirrorH+rot90CW | 8 rot90CCW
/// Hoàn tác = biến đổi NGƯỢC trên ảnh đã bake. Mỗi phép là involution
/// (áp 2 lần = 1). Mỗi mapping đã chứng minh tay bằng ví dụ 3×2 (a..f).
({Uint8List rgba, int width, int height}) _unbakeExifRgba(
  Uint8List src,
  int w,
  int h,
  int orientation,
) {
  switch (orientation) {
    case 2:
      return _mirrorH(src, w, h);
    case 3:
      return _rot180(src, w, h);
    case 4:
      return _mirrorV(src, w, h);
    case 5:
      // bake = transpose(raw) → raw = transpose(baked)
      return _transpose(src, w, h);
    case 6:
      // bake = rot90CW(raw) → raw = rot90CCW(baked)
      return _rot90Ccw(src, w, h);
    case 7:
      // bake = rot90CW(mirrorH(raw))
      //   → mirrorH(raw) = rot90CCW(baked) → raw = mirrorH(rot90CCW(baked))
      final mid = _rot90Ccw(src, w, h);
      return _mirrorH(mid.rgba, mid.width, mid.height);
    case 8:
      // bake = rot90CCW(raw) → raw = rot90CW(baked)
      return _rot90Cw(src, w, h);
    default:
      // EXIF 1/0/không rõ: Skia không bake → trả nguyên bản.
      return (rgba: src, width: w, height: h);
  }
}

/// Bản RGBA 4 byte/pixel — dùng nội bộ cho các phép hoàn tác EXIF.
typedef _Rgba = ({Uint8List rgba, int width, int height});

/// mirrorH 3×2 ví dụ: [a b c / d e f] → [c b a / f e d]
_Rgba _mirrorH(Uint8List src, int w, int h) {
  final dst = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    final row = y * w * 4;
    for (var x = 0; x < w; x++) {
      final s = row + ((w - 1 - x) * 4);
      final d = row + (x * 4);
      dst[d] = src[s];
      dst[d + 1] = src[s + 1];
      dst[d + 2] = src[s + 2];
      dst[d + 3] = src[s + 3];
    }
  }
  return (rgba: dst, width: w, height: h);
}

/// mirrorV: [a b c / d e f] → [d e f / a b c]
_Rgba _mirrorV(Uint8List src, int w, int h) {
  final dst = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final s = ((h - 1 - y) * w + x) * 4;
      final d = (y * w + x) * 4;
      dst[d] = src[s];
      dst[d + 1] = src[s + 1];
      dst[d + 2] = src[s + 2];
      dst[d + 3] = src[s + 3];
    }
  }
  return (rgba: dst, width: w, height: h);
}

/// rot180: [a b c / d e f] → [f e d / c b a]
_Rgba _rot180(Uint8List src, int w, int h) {
  final dst = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final s = ((h - 1 - y) * w + (w - 1 - x)) * 4;
      final d = (y * w + x) * 4;
      dst[d] = src[s];
      dst[d + 1] = src[s + 1];
      dst[d + 2] = src[s + 2];
      dst[d + 3] = src[s + 3];
    }
  }
  return (rgba: dst, width: w, height: h);
}

/// transpose: [a b c / d e f] → [a d / b e / c f] (dst là w×h → h×w)
_Rgba _transpose(Uint8List src, int w, int h) {
  final dst = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final s = (y * w + x) * 4;
      final d = (x * h + y) * 4;
      dst[d] = src[s];
      dst[d + 1] = src[s + 1];
      dst[d + 2] = src[s + 2];
      dst[d + 3] = src[s + 3];
    }
  }
  return (rgba: dst, width: h, height: w);
}

/// rot90CW: dst(w×h) ← src[h×w], dst(dx,dy) ← src(w-1-dy, dx)
/// 3×2 ví dụ: [a b c / d e f] → [d a / e b / f c] (3 dòng, 2 cột)
_Rgba _rot90Cw(Uint8List src, int w, int h) {
  final dstW = h;
  final dstH = w;
  final dst = Uint8List(w * h * 4);
  for (var dy = 0; dy < dstH; dy++) {
    for (var dx = 0; dx < dstW; dx++) {
      final s = ((h - 1 - dx) * w + dy) * 4;
      final d = (dy * dstW + dx) * 4;
      dst[d] = src[s];
      dst[d + 1] = src[s + 1];
      dst[d + 2] = src[s + 2];
      dst[d + 3] = src[s + 3];
    }
  }
  return (rgba: dst, width: dstW, height: dstH);
}

/// rot90CCW: dst(h×w) ← src[w×h], dst(dx,dy) ← src(dy, h-1-dx)
/// 3×2 ví dụ: [a b c / d e f] → [c f / b e / a d] (3 dòng, 2 cột)
_Rgba _rot90Ccw(Uint8List src, int w, int h) {
  final dstW = h;
  final dstH = w;
  final dst = Uint8List(w * h * 4);
  for (var dy = 0; dy < dstH; dy++) {
    for (var dx = 0; dx < dstW; dx++) {
      final s = (dy * w + (h - 1 - dx)) * 4;
      final d = (dy * dstW + dx) * 4;
      dst[d] = src[s];
      dst[d + 1] = src[s + 1];
      dst[d + 2] = src[s + 2];
      dst[d + 3] = src[s + 3];
    }
  }
  return (rgba: dst, width: dstW, height: dstH);
}
