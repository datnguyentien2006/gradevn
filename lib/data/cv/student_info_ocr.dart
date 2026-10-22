import 'dart:typed_data';

/// Cổng trừu tượng OCR thông tin học sinh trên phiếu (tương lai của M3+).
///
/// Vai trò hiện tại: **không tham gia vào lưới chấm điểm**. Số báo danh (SBD)
/// đã được mã hoá sẵn trong lưới 6×10 ô chữ số trên phiếu và được đọc tất định
/// bằng `OmrDecoder.decodeDigits` (cùng nguồn sự thật với toạ độ [SheetLayout]),
/// nên kết quả luôn tái lập được. OCR chỉ là đường tương lai để đọc các phần
/// KHÔNG có lưới (ví dụ: họ tên viết tay), khi cần đối chiếu tra cứu.
///
/// Vì vậy [StudentInfoOcr] trả về `Future<String?>` — `null` nghĩa là "không
/// đọc được", luồng chấm không bao giờ phụ thuộc vào kết quả này: toàn bộ
/// luồng chấm vẫn chạy 100% offline với bản no-op dưới đây.
abstract interface class StudentInfoOcr {
  /// Đọc SBD/từ khoá tra cứu trên vùng thông tin (ảnh PNG đã cắt).
  ///
  /// Trả về `null` khi không đọc được — luồng chấm không thay đổi hành vi.
  Future<String?> readStudentCode(Uint8List infoZonePng);
}

/// Cài đặt no-op của [StudentInfoOcr]: luôn trả về `null`.
///
/// Giữ chấm phiếu chạy được hoàn toàn offline (không TFLite/network) và cho
/// phép test không mong đợi OCR. Khi thay bằng engine thật, luồng chấm không đổi.
final class NoOpStudentInfoOcr implements StudentInfoOcr {
  const NoOpStudentInfoOcr();

  @override
  Future<String?> readStudentCode(Uint8List infoZonePng) async => null;
}
