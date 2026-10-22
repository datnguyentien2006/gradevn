import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/placeholder_screen.dart';
import 'presentation/theme.dart';

/// Router đơn giản (named routes + onGenerateRoute cho đường có param).
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
      // Không màn hình nào gọi mạng: offline cưỡng bức (ràng buộc dự án).
      routes: {
        '/': (_) => const HomeScreen(),
        '/scan': (_) => const PlaceholderScreen(title: 'Chấm phiếu'),
      },
      onGenerateRoute: (settings) {
        final uri = settings.name ?? '';
        if (uri.startsWith('/contest/') && uri.endsWith('/scan')) {
          return MaterialPageRoute<void>(
            builder: (_) => const PlaceholderScreen(title: 'Chấm phiếu'),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
