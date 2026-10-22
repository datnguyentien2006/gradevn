import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/placeholder_screen.dart';
import 'presentation/theme.dart';

/// Router đơn giản bằng named routes (map rất nhỏ, không cần go_router ở M0).
final class GradeVNApp extends ConsumerWidget {
  const GradeVNApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: GradeVNTheme.light(),
      darkTheme: GradeVNTheme.dark(),
      // Ứng dụng 100% tiếng Việt, offline — cưỡng bức locale vi.
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routes: {
        '/': (_) => const HomeScreen(),
        '/keys': (_) => const PlaceholderScreen(title: 'Đáp án / Mã đề'),
        '/scan': (_) => const PlaceholderScreen(title: 'Chấm phiếu'),
      },
    );
  }
}
