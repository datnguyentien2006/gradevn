// Tab "Kết quả" (M3): danh sách kỳ thi → liệt kê phiếu đã chấm của kỳ thi đó.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';

import '../state/providers.dart';
import 'sheet_list_screen.dart';

final class ResultsTab extends ConsumerWidget {
  const ResultsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final contests = ref.watch(contestsProvider);
    return Scaffold(
      body: contests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(l10n.scanError(e.toString()))),
        data: (list) => list.isEmpty
            ? _emptyState(context, l10n)
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final contest = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(contest.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SheetListScreen(contest: contest),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, AppLocalizations l10n) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_outlined,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(l10n.emptyResults, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
}
