/// Câu trả lời của một câu trong phiếu đã quét.
enum AnswerMark { unanswered, correct, incorrect }

/// Kết quả đã chấm của một phiếu học sinh.
///
/// Tương ứng `MyAnswer`/`MyScore` trong tài liệu tham khảo
/// (docs/reference-analysis.md §5): điểm tổng, điểm từng phần,
/// thông tin học sinh + đường dẫn ảnh (original/result/info).
final class GradedSheet {
  const GradedSheet({
    required this.contestId,
    required this.examCode,
    required this.studentCode,
    required this.chosen,
    required this.correctFlags,
    required this.score,
    this.id,
    this.keyId,
    this.studentId,
    this.partScores = const <String, double>{},
    this.originalImagePath,
    this.markedImagePath,
    this.infoImagePath,
    this.gradedAt,
  });

  /// Id của hàng DB (tự sinh khi insert; null với phiếu chưa lưu).
  /// Màn xem lại/chi tiết phiếu cần id để đọc + xoá theo hàng.
  final int? id;

  /// Kỳ thi phiếu thuộc về.
  final int contestId;

  /// Mã đề đọc được từ phiếu.
  final String examCode;

  /// Số báo danh đọc được ("số báo danh " ô trống → chuỗi rỗng).
  final String studentCode;

  /// Lựa chọn đã decode: chỉ số câu → ký tự ('A'..'Z') hoặc null nếu trống.
  final List<String?> chosen;

  /// Theo từng câu: đúng = true, sai = false, null = câu trống.
  final List<bool?> correctFlags;

  final double score;

  final int? keyId;
  final int? studentId;

  /// Điểm từng phần (phần I/II/III của phiếu nhiều phần).
  final Map<String, double> partScores;

  final String? originalImagePath;
  final String? markedImagePath;
  final String? infoImagePath;
  final DateTime? gradedAt;

  int get correctCount =>
      correctFlags.where((f) => f == true).length;

  int get incorrectCount =>
      correctFlags.where((f) => f == false).length;

  int get unansweredCount =>
      correctFlags.where((f) => f == null).length;
}
