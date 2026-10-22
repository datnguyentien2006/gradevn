import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/app.dart';
import 'package:gradevn/data/db/app_database.dart';
import 'package:gradevn/presentation/state/providers.dart';

/// Smoke test M0/M1: app khởi động, tiêu đề tiếng Việt, 4 tab chuyển được.
void main() {
  testWidgets('app khởi động và hiển thị UI tiếng Việt', (tester) async {
    final db = inMemoryAppDatabase();
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const GradeVNApp(),
    ));
    await tester.pumpAndSettle();

    // Tiêu đề app
    expect(find.text('GradeVN — Chấm phiếu trắc nghiệm'), findsOneWidget);

    // 4 tab bottom navigation
    expect(find.text('Lớp học'), findsOneWidget);
    expect(find.text('Kỳ thi'), findsOneWidget);
    expect(find.text('Kết quả'), findsOneWidget);
    expect(find.text('Thống kê'), findsOneWidget);

    // Tab mặc định: lớp học trống
    expect(find.text('Chưa có lớp học nào. Thêm lớp để bắt đầu.'), findsOneWidget);

    await db.close();
  });

  testWidgets('chuyển tab Kỳ thi hiển thị nội dung trống tương ứng', (tester) async {
    final db = inMemoryAppDatabase();
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const GradeVNApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kỳ thi'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có kỳ thi nào. Tạo kỳ thi mới.'), findsOneWidget);

    await db.close();
  });

  testWidgets('thêm lớp qua dialog + hiển thị trong danh sách', (tester) async {
    final db = inMemoryAppDatabase();
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const GradeVNApp(),
    ));
    await tester.pumpAndSettle();

    // Mở dialog "Thêm lớp"
    final fabFinder = find.widgetWithText(FloatingActionButton, 'Thêm lớp');
    expect(fabFinder, findsOneWidget);
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    // Nhập tên + lưu
    expect(find.text('Tên lớp'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '10A1');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    // Dialog mô tả mở thứ hai
    await tester.enterText(find.byType(TextField), 'Lớp demo');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    // Lớp hiển thị
    expect(find.text('10A1'), findsWidgets);

    await db.close();
  });
}
