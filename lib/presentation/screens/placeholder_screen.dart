import 'package:flutter/material.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';

/// Placeholder route — nội dung thật sẽ có ở các milestone kế.
final class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 48),
              const SizedBox(height: 12),
              Text(l10n.comingSoon, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
