// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'GradeVN — Chấm phiếu trắc nghiệm';

  @override
  String get navClasses => 'Lớp học';

  @override
  String get navContests => 'Kỳ thi';

  @override
  String get navResults => 'Kết quả';

  @override
  String get navStats => 'Thống kê';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get keysTitle => 'Đáp án / Mã đề';

  @override
  String get scanTitle => 'Chấm phiếu';

  @override
  String get resultReviewTitle => 'Xem kết quả';

  @override
  String get chartTitle => 'Thống kê';

  @override
  String get emptyClasses => 'Chưa có lớp học nào. Thêm lớp để bắt đầu.';

  @override
  String get emptyContests => 'Chưa có kỳ thi nào. Tạo kỳ thi mới.';

  @override
  String get emptyResults => 'Chưa có bài thi nào được chấm.';

  @override
  String get comingSoon =>
      'Tính năng đang được xây dựng — sẽ có ở milestone kế tiếp.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Hủy bỏ';

  @override
  String get add => 'Thêm';

  @override
  String get edit => 'Sửa';

  @override
  String get delete => 'Xóa';

  @override
  String get save => 'Lưu';

  @override
  String get back => 'Quay lại';

  @override
  String get scanLoadingData => 'Đang tải dữ liệu kỳ thi…';

  @override
  String get scanContestMissing => 'Không tìm thấy kỳ thi.';

  @override
  String get scanCameraUnavailable =>
      'Camera không khả dụng trên thiết bị này.';

  @override
  String get scanPickSheetImage => 'Chọn ảnh phiếu từ tệp…';

  @override
  String get scanGuidance =>
      'Đặt phiếu trên nền sáng, chụp cách này một khoảng vừa phải — phiếu có thể nghiêng hoặc nằm lệch';

  @override
  String get scanCapture => 'Chụp phiếu';

  @override
  String get scanProcessing => 'Đang chấm phiếu…';

  @override
  String get scanMarkerOverlayLocated => 'Đã đủ 4 mốc';

  @override
  String get scanDragHint =>
      'Kéo 4 ô vuông cho phủ 4 ô vuông đen trên phiếu rồi chụp';

  @override
  String get scanManualFix => 'Chỉnh thủ công';

  @override
  String get cropTitle => 'Ghim mốc phiếu';

  @override
  String get cropPickMarkers =>
      'Ghim 4 ô vuông đen theo thứ tự: trái-trên → phải-trên → phải-dưới → trái-dưới';

  @override
  String cropPinsProgress(int count, int total) {
    return 'Nắn phẳng ($count/$total)';
  }

  @override
  String get cropResetPins => 'Chọn lại';

  @override
  String get cropRetake => 'Chụp lại';

  @override
  String get resultTitle => 'Kết quả phiếu';

  @override
  String resultScore(String score, String max) {
    return 'Điểm: $score/$max';
  }

  @override
  String resultStats(int correct, int incorrect, int blank) {
    return '$correct câu đúng • $incorrect sai • $blank bỏ trống';
  }

  @override
  String get resultStudentCodeLabel => 'Số báo danh';

  @override
  String get resultExamCodeLabel => 'Mã đề';

  @override
  String get resultStudentLabel => 'Học sinh';

  @override
  String get resultStudentNotFound => 'Không tìm thấy số báo danh';

  @override
  String get resultBestGuessNote =>
      'Không đọc được mã đề — dùng mã đề có điểm khớp cao nhất để chấm.';

  @override
  String get resultSave => 'Lưu kết quả';

  @override
  String get resultScanAnother => 'Chụp phiếu khác';

  @override
  String partScoreLine(String part, String score) {
    return 'Phần $part: $score điểm';
  }

  @override
  String sheetSavedMessage(String code, String score) {
    return 'Đã lưu: $code — $score điểm';
  }

  @override
  String get scanImagePickFailed => 'Không chọn được ảnh.';

  @override
  String scanError(String error) {
    return 'Đã xảy ra lỗi: $error';
  }

  @override
  String get sheetListTitle => 'Phiếu đã chấm';

  @override
  String get sheetTileNoCode => 'Không có số báo danh';

  @override
  String sheetTileScore(String score) {
    return '$score điểm';
  }

  @override
  String get sheetListEmpty => 'Chưa có phiếu nào được chấm cho kỳ thi này.';

  @override
  String get deleteSheetConfirmTitle => 'Xoá kết quả này?';

  @override
  String sheetDetailTitle(String code) {
    return 'Phiếu $code';
  }

  @override
  String get detailPartScoresTitle => 'Điểm theo phần';

  @override
  String get answerLinesTitle => 'Từng câu trả lời';

  @override
  String answerLine(int index, String answer, String status) {
    return 'Câu $index — chọn $answer — $status';
  }

  @override
  String get answerCorrect => 'Đúng';

  @override
  String get answerIncorrect => 'Sai';

  @override
  String get answerBlank => 'Bỏ trống';

  @override
  String get detailNoImage => 'Không có ảnh phiếu.';

  @override
  String get sheetDeletedMessage => 'Đã xoá kết quả phiếu.';

  @override
  String resultsContestCount(int count) {
    return '$count phiếu';
  }

  @override
  String get contestDetailScanButton => 'Chấm phiếu bằng camera';

  @override
  String get keyEditorTitle => 'Nhập mã đề';

  @override
  String get keyEditorTabCode => 'MÃ ĐỀ';

  @override
  String get keyEditorTabAnswers => 'TRẢ LỜI';

  @override
  String get keyEditorCodePreview => 'Mã đề ghép từ các ô đã chọn';

  @override
  String keyEditorDigitSlot(int index) {
    return 'Chữ số $index';
  }

  @override
  String get keyEditorSave => 'Lưu mã đề';

  @override
  String keyEditorCodeIncomplete(int slots) {
    return 'Chưa chọn đủ $slots chữ số của mã đề.';
  }

  @override
  String keyEditorUnansweredConfirm(int count) {
    return 'Còn $count câu chưa tô đáp án trên phiếu. Vẫn lưu mã đề này?';
  }

  @override
  String get keyEditorNoEOnPaper => 'Phiếu này không có ô E';

  @override
  String keyEditorSavedMessage(String code) {
    return 'Đã lưu mã đề $code.';
  }
}
