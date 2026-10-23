// Màn danh sách phiếu đã chấm của một kỳ thi (M3):
// ListTile SBD + điểm, xoá bằng giữ-lâu, bấm vào để xem chi tiết phiếu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:gradevn/domain/entities/contest.dart';

import '../state/providers.dart';
import 'sheet_detail_screen.dart';

final class SheetListScreen extends ConsumerWidget {
  const SheetListScreen({super.key, required this.contest});

  final Contest contest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sheets = ref.watch(gradedSheetsByContestProvider(contest.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sheetListTitle)),
      body: sheets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.scanError(e.toString()))),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(l10n.sheetListEmpty,
                    style: Theme.of(context).textTheme.bodyLarge))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final sheet = list[i];
                  final id = sheet.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(sheet.studentCode.isEmpty
                          ? l10n.sheetTileNoCode
                          : sheet.studentCode),
                      // R2: phiếu bỏ chấm (mã đề '') → phụ đề "chưa có mã
                      // đề" thay cho điểm 0 gây hiểu lầm.
                      subtitle: Text(sheet.examCode.isEmpty
                          ? l10n.sheetTileUnresolved
                          : _scoreText(l10n, sheet.score)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: id == null
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SheetDetailScreen(sheetId: id),
                                ),
                              ),
                      onLongPress:
                          id == null ? null : () => _confirmDelete(context, ref, l10n, id),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _scoreText(AppLocalizations l10n, double score) =>
      l10n.sheetTileScore(_format(score));

  String _format(double score) =>
      score % 1 == 0 ? score.toStringAsFixed(0) : score.toString();

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, int sheetId) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(gradedSheetRepositoryProvider);
    final openedDialog = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteSheetConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (openedDialog != true) return;
    await repo.delete(sheetId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.sheetDeletedMessage)));
  }
}
