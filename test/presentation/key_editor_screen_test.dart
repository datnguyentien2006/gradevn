// Widget test KeyEditorScreen (R1): 2 tab hoạt động, mã ghép xem trước được,
// thiếu mã đề → chặn lưu; đủ mã đề mà còn câu trống → hộp xác nhận; xác nhận
// → snackbar + pop + key được ghi qua repository (fake thuần Dart — tránh
// NativeDatabase trong zone testWidgets, cổng riêng có thể giữ test treo).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/domain/repositories/repositories.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:gradevn/presentation/screens/key_editor_screen.dart';
import 'package:gradevn/presentation/state/providers.dart';

/// Repository key "hồi cốp" thuần Dart: ghi nhớ hàng insert để khẳng định.
final class _FakeKeyRepository implements AnswerKeyRepository {
  final List<AnswerKey> inserted = <AnswerKey>[];

  @override
  Stream<List<AnswerKey>> watchByContest(int contestId) =>
      Stream.value(List.of(inserted));

  @override
  Future<AnswerKey?> byExamCode(int contestId, String examCode) async {
    for (final k in inserted) {
      if (k.contestId == contestId && k.examCode == examCode) return k;
    }
    return null;
  }

  @override
  Future<int> insert(AnswerKey key) async {
    final id = inserted.length + 1;
    inserted.add(AnswerKey(
      id: id,
      contestId: key.contestId,
      examCode: key.examCode,
      answerSequence: key.answerSequence,
    ));
    return id;
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> insertMany(
      int contestId, List<(String, String)> keys) async {
    for (final (code, seq) in keys) {
      await insert(AnswerKey(
        id: 0,
        contestId: contestId,
        examCode: code,
        answerSequence: seq,
      ));
    }
  }
}

Contest _contest() => Contest(
      id: 7,
      name: 'Kiểm tra 45 phút',
      examDate: DateTime(2026, 10, 23),
      questionCount: 40,
      answerChoices: 4,
    );

Future<void> _pumpEditor(WidgetTester tester, _FakeKeyRepository repo) async {
  final container = ProviderContainer(overrides: [
    answerKeyRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: KeyEditorScreen(contest: _contest()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Chọn đủ mã đề '0' '0' '1' trên tab MÃ ĐỀ (chip hiển thị trước mặt).
Future<void> _fillCode(WidgetTester tester) async {
  // Chip trong từng hàng vị trí: .first → slot 1, .at(1) → slot 2, .at(2)
  // → slot 3 (mỗi slot chứa đủ 10 chữ số nên cần chọn theo thứ tự hàng).
  await tester.tap(find.widgetWithText(ChoiceChip, '0').first);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, '0').at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, '1').at(2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mở editor: 2 tab, mã ghép ban đầu ???', (tester) async {
    final repo = _FakeKeyRepository();
    await _pumpEditor(tester, repo);

    expect(find.text('MÃ ĐỀ'), findsOneWidget);
    expect(find.text('TRẢ LỜI'), findsOneWidget);
    expect(find.text('???'), findsOneWidget); // bản xem trước mã ghép

    // Sang tab TRẢ LỜI: các hàng câu hiển thị.
    await tester.tap(find.text('TRẢ LỜI'));
    await tester.pumpAndSettle();
    expect(find.text('Câu 1'), findsOneWidget);
  });

  testWidgets('thiếu mã đề: chặn lưu + thông báo, KHÔNG pop, KHÔNG ghi DB',
      (tester) async {
    final repo = _FakeKeyRepository();
    await _pumpEditor(tester, repo);

    await tester.tap(find.widgetWithText(ChoiceChip, '0').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lưu mã đề'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa chọn đủ 3 chữ số của mã đề.'), findsOneWidget);
    expect(find.byType(KeyEditorScreen), findsOneWidget); // chưa pop
    expect(repo.inserted, isEmpty);
  });

  testWidgets('mã đề "001" + 1 câu trả lời, còn câu trống → xác nhận → lưu',
      (tester) async {
    final repo = _FakeKeyRepository();
    await _pumpEditor(tester, repo);

    await _fillCode(tester);
    expect(find.text('001'), findsOneWidget); // bản xem trước mã ghép

    // Tab TRẢ LỜI: trả lời Câu 1 = A.
    await tester.tap(find.text('TRẢ LỜI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').first); // vòng chữ A của hàng trên cùng
    await tester.pumpAndSettle();

    // Lưu: còn 39 câu trống → hộp xác nhận.
    await tester.tap(find.text('Lưu mã đề'));
    await tester.pumpAndSettle();
    expect(find.text('Còn 39 câu chưa tô đáp án trên phiếu. Vẫn lưu mã đề này?'),
        findsOneWidget);

    // Thử "Hủy bỏ": KHÔNG lưu.
    await tester.tap(find.text('Hủy bỏ'));
    await tester.pumpAndSettle();
    expect(find.byType(KeyEditorScreen), findsOneWidget);

    // Lưu lại và xác nhận.
    await tester.tap(find.text('Lưu mã đề'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Đã pop về màn trước...
    expect(find.byType(KeyEditorScreen), findsNothing);
    // ...và key đã ghi DB (saninator asserted song song, ưu tiên logic).
    expect(repo.inserted, hasLength(1));
    expect(repo.inserted.single.examCode, '001');
    expect(repo.inserted.single.answerSequence, 'A${'-' * 39}');
  });
}
