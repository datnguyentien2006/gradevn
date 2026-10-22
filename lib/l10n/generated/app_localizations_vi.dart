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
}
