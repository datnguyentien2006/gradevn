import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/app.dart';

/// Smoke test M0: app khởi động, tiêu đề tiếng Việt, 4 tab chuyển được.
void main() {
  testWidgets('app khởi động và hiển thị UI tiếng Việt', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GradeVNApp()));

    // Tiêu đề app
    expect(find.text('GradeVN — Chấm phiếu trắc nghiệm'), findsOneWidget);

    // 4 tab bottom navigation
    expect(find.text('Lớp học'), findsOneWidget);
    expect(find.text('Kỳ thi'), findsOneWidget);
    expect(find.text('Kết quả'), findsOneWidget);
    expect(find.text('Thống kê'), findsOneWidget);

    // Tab mặc định: lớp học trống
    expect(find.text('Chưa có lớp học nào. Thêm lớp để bắt đầu.'), findsOneWidget);
  });

  testWidgets('chuyển tab Kỳ thi hiển thị nội dung trống tương ứng', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GradeVNApp()));

    await tester.tap(find.text('Kỳ thi'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có kỳ thi nào. Tạo kỳ thi mới.'), findsOneWidget);
  });
}
