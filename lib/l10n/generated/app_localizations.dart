import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('vi')];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'GradeVN — Chấm phiếu trắc nghiệm'**
  String get appTitle;

  /// No description provided for @navClasses.
  ///
  /// In vi, this message translates to:
  /// **'Lớp học'**
  String get navClasses;

  /// No description provided for @navContests.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ thi'**
  String get navContests;

  /// No description provided for @navResults.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả'**
  String get navResults;

  /// No description provided for @navStats.
  ///
  /// In vi, this message translates to:
  /// **'Thống kê'**
  String get navStats;

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settingsTitle;

  /// No description provided for @keysTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đáp án / Mã đề'**
  String get keysTitle;

  /// No description provided for @scanTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chấm phiếu'**
  String get scanTitle;

  /// No description provided for @resultReviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem kết quả'**
  String get resultReviewTitle;

  /// No description provided for @chartTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thống kê'**
  String get chartTitle;

  /// No description provided for @emptyClasses.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lớp học nào. Thêm lớp để bắt đầu.'**
  String get emptyClasses;

  /// No description provided for @emptyContests.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có kỳ thi nào. Tạo kỳ thi mới.'**
  String get emptyContests;

  /// No description provided for @emptyResults.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài thi nào được chấm.'**
  String get emptyResults;

  /// No description provided for @comingSoon.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng đang được xây dựng — sẽ có ở milestone kế tiếp.'**
  String get comingSoon;

  /// No description provided for @ok.
  ///
  /// In vi, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy bỏ'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get save;

  /// No description provided for @back.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get back;

  /// No description provided for @scanLoadingData.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải dữ liệu kỳ thi…'**
  String get scanLoadingData;

  /// No description provided for @scanContestMissing.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy kỳ thi.'**
  String get scanContestMissing;

  /// No description provided for @scanCameraUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Camera không khả dụng trên thiết bị này.'**
  String get scanCameraUnavailable;

  /// No description provided for @scanPickSheetImage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh phiếu từ tệp…'**
  String get scanPickSheetImage;

  /// No description provided for @scanGuidance.
  ///
  /// In vi, this message translates to:
  /// **'Đặt phiếu trên nền sáng, chụp cách này một khoảng vừa phải — phiếu có thể nghiêng hoặc nằm lệch'**
  String get scanGuidance;

  /// No description provided for @scanCapture.
  ///
  /// In vi, this message translates to:
  /// **'Chụp phiếu'**
  String get scanCapture;

  /// No description provided for @scanProcessing.
  ///
  /// In vi, this message translates to:
  /// **'Đang chấm phiếu…'**
  String get scanProcessing;

  /// No description provided for @scanMarkerOverlayLocated.
  ///
  /// In vi, this message translates to:
  /// **'Đã đủ 4 mốc'**
  String get scanMarkerOverlayLocated;

  /// No description provided for @cropTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ghim mốc phiếu'**
  String get cropTitle;

  /// No description provided for @cropPickMarkers.
  ///
  /// In vi, this message translates to:
  /// **'Ghim 4 ô vuông đen theo thứ tự: trái-trên → phải-trên → phải-dưới → trái-dưới'**
  String get cropPickMarkers;

  /// No description provided for @cropPinsProgress.
  ///
  /// In vi, this message translates to:
  /// **'Nắn phẳng ({count}/{total})'**
  String cropPinsProgress(int count, int total);

  /// No description provided for @cropResetPins.
  ///
  /// In vi, this message translates to:
  /// **'Chọn lại'**
  String get cropResetPins;

  /// No description provided for @cropRetake.
  ///
  /// In vi, this message translates to:
  /// **'Chụp lại'**
  String get cropRetake;

  /// No description provided for @resultTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả phiếu'**
  String get resultTitle;

  /// No description provided for @resultScore.
  ///
  /// In vi, this message translates to:
  /// **'Điểm: {score}/{max}'**
  String resultScore(String score, String max);

  /// No description provided for @resultStats.
  ///
  /// In vi, this message translates to:
  /// **'{correct} câu đúng • {incorrect} sai • {blank} bỏ trống'**
  String resultStats(int correct, int incorrect, int blank);

  /// No description provided for @resultStudentCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số báo danh'**
  String get resultStudentCodeLabel;

  /// No description provided for @resultExamCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã đề'**
  String get resultExamCodeLabel;

  /// No description provided for @resultStudentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Học sinh'**
  String get resultStudentLabel;

  /// No description provided for @resultStudentNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy số báo danh'**
  String get resultStudentNotFound;

  /// No description provided for @resultBestGuessNote.
  ///
  /// In vi, this message translates to:
  /// **'Không đọc được mã đề — dùng mã đề có điểm khớp cao nhất để chấm.'**
  String get resultBestGuessNote;

  /// No description provided for @resultSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu kết quả'**
  String get resultSave;

  /// No description provided for @resultScanAnother.
  ///
  /// In vi, this message translates to:
  /// **'Chụp phiếu khác'**
  String get resultScanAnother;

  /// No description provided for @partScoreLine.
  ///
  /// In vi, this message translates to:
  /// **'Phần {part}: {score} điểm'**
  String partScoreLine(String part, String score);

  /// No description provided for @sheetSavedMessage.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu: {code} — {score} điểm'**
  String sheetSavedMessage(String code, String score);

  /// No description provided for @scanImagePickFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không chọn được ảnh.'**
  String get scanImagePickFailed;

  /// No description provided for @scanError.
  ///
  /// In vi, this message translates to:
  /// **'Đã xảy ra lỗi: {error}'**
  String scanError(String error);

  /// No description provided for @sheetListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phiếu đã chấm'**
  String get sheetListTitle;

  /// No description provided for @sheetTileNoCode.
  ///
  /// In vi, this message translates to:
  /// **'Không có số báo danh'**
  String get sheetTileNoCode;

  /// No description provided for @sheetTileScore.
  ///
  /// In vi, this message translates to:
  /// **'{score} điểm'**
  String sheetTileScore(String score);

  /// No description provided for @sheetListEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có phiếu nào được chấm cho kỳ thi này.'**
  String get sheetListEmpty;

  /// No description provided for @deleteSheetConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá kết quả này?'**
  String get deleteSheetConfirmTitle;

  /// No description provided for @sheetDetailTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phiếu {code}'**
  String sheetDetailTitle(String code);

  /// No description provided for @detailPartScoresTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điểm theo phần'**
  String get detailPartScoresTitle;

  /// No description provided for @answerLinesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từng câu trả lời'**
  String get answerLinesTitle;

  /// No description provided for @answerLine.
  ///
  /// In vi, this message translates to:
  /// **'Câu {index} — chọn {answer} — {status}'**
  String answerLine(int index, String answer, String status);

  /// No description provided for @answerCorrect.
  ///
  /// In vi, this message translates to:
  /// **'Đúng'**
  String get answerCorrect;

  /// No description provided for @answerIncorrect.
  ///
  /// In vi, this message translates to:
  /// **'Sai'**
  String get answerIncorrect;

  /// No description provided for @answerBlank.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ trống'**
  String get answerBlank;

  /// No description provided for @detailNoImage.
  ///
  /// In vi, this message translates to:
  /// **'Không có ảnh phiếu.'**
  String get detailNoImage;

  /// No description provided for @sheetDeletedMessage.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá kết quả phiếu.'**
  String get sheetDeletedMessage;

  /// No description provided for @resultsContestCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} phiếu'**
  String resultsContestCount(int count);

  /// No description provided for @contestDetailScanButton.
  ///
  /// In vi, this message translates to:
  /// **'Chấm phiếu bằng camera'**
  String get contestDetailScanButton;

  /// No description provided for @keyEditorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã đề'**
  String get keyEditorTitle;

  /// No description provided for @keyEditorTabCode.
  ///
  /// In vi, this message translates to:
  /// **'MÃ ĐỀ'**
  String get keyEditorTabCode;

  /// No description provided for @keyEditorTabAnswers.
  ///
  /// In vi, this message translates to:
  /// **'TRẢ LỜI'**
  String get keyEditorTabAnswers;

  /// No description provided for @keyEditorCodePreview.
  ///
  /// In vi, this message translates to:
  /// **'Mã đề ghép từ các ô đã chọn'**
  String get keyEditorCodePreview;

  /// No description provided for @keyEditorDigitSlot.
  ///
  /// In vi, this message translates to:
  /// **'Chữ số {index}'**
  String keyEditorDigitSlot(int index);

  /// No description provided for @keyEditorSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu mã đề'**
  String get keyEditorSave;

  /// No description provided for @keyEditorCodeIncomplete.
  ///
  /// In vi, this message translates to:
  /// **'Chưa chọn đủ {slots} chữ số của mã đề.'**
  String keyEditorCodeIncomplete(int slots);

  /// No description provided for @keyEditorUnansweredConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Còn {count} câu chưa tô đáp án trên phiếu. Vẫn lưu mã đề này?'**
  String keyEditorUnansweredConfirm(int count);

  /// No description provided for @keyEditorNoEOnPaper.
  ///
  /// In vi, this message translates to:
  /// **'Phiếu này không có ô E'**
  String get keyEditorNoEOnPaper;

  /// No description provided for @keyEditorSavedMessage.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu mã đề {code}.'**
  String keyEditorSavedMessage(String code);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
