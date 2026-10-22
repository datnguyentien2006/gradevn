// Chi tiết một phiếu đã chấm (M3): điểm tổng, thống kê đúng/sai/bỏ trống,
// điểm theo phần (phiếu bộ đề), ảnh phiếu đã gạch kết quả + danh sách từng câu.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/domain/entities/graded_sheet.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';

import '../state/providers.dart';

final class SheetDetailScreen extends ConsumerWidget {
  const SheetDetailScreen({super.key, required this.sheetId});

  final int sheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sheetAsync = ref.watch(gradedSheetByIdProvider(sheetId));
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (sheetAsync.value?.studentCode) {
          final code? when code.isNotEmpty => l10n.sheetDetailTitle(code),
          _ => l10n.resultReviewTitle,
        }),
      ),
      body: sheetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.scanError(e.toString()))),
        data: (sheet) {
          if (sheet == null) {
            return Center(child: Text(l10n.sheetListEmpty));
          }
          final contestAsync = ref.watch(contestByIdProvider(sheet.contestId));
          return _SheetDetailBody(sheet: sheet, contest: contestAsync.value);
        },
      ),
    );
  }
}

final class _SheetDetailBody extends ConsumerWidget {
  const _SheetDetailBody({required this.sheet, required this.contest});

  final GradedSheet sheet;
  final Contest? contest;

  String _format(double score) =>
      score % 1 == 0 ? score.toStringAsFixed(0) : score.toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final formType = contest?.formType;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          _format(sheet.score),
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        Text(
          l10n.resultStats(sheet.correctCount, sheet.incorrectCount,
              sheet.unansweredCount),
          textAlign: TextAlign.center,
        ),
        if (formType == SheetFormType.ministry &&
            sheet.partScores.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.detailPartScoresTitle,
              style: Theme.of(context).textTheme.titleMedium),
          for (final entry in sheet.partScores.entries)
            Text(l10n.partScoreLine(entry.key, _format(entry.value))),
        ],
        const SizedBox(height: 16),
        _SheetImage(sheet: sheet, l10n: l10n),
        const SizedBox(height: 16),
        Text(l10n.answerLinesTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        for (var i = 0; i < sheet.chosen.length; i++) _AnswerTile(index: i, sheet: sheet),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.delete),
          onPressed: () async {
            final id = sheet.id;
            if (id == null) return;
            final confirmed = await showDialog<bool>(
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
            if (confirmed != true) return;
            await ref.read(gradedSheetRepositoryProvider).delete(id);
            messenger.showSnackBar(
                SnackBar(content: Text(l10n.sheetDeletedMessage)));
            navigator.pop();
          },
        ),
      ],
    );
  }
}

/// Ảnh phiếu: ưu tiên ảnh đã gạch kết quả, dự phòng ảnh gốc; thiếu → nhãn trống.
final class _SheetImage extends StatelessWidget {
  const _SheetImage({required this.sheet, required this.l10n});

  final GradedSheet sheet;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final path = sheet.markedImagePath ?? sheet.originalImagePath;
    if (path == null) {
      return SizedBox(
        height: 120,
        child: Center(child: Text(l10n.detailNoImage)),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SizedBox(
          height: 120,
          child: Center(child: Text(l10n.detailNoImage)),
        ),
      ),
    );
  }
}

/// Dòng từng câu: "Câu N — chọn <A> — Đúng/Sai/Bỏ trống".
final class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.index, required this.sheet});

  final int index;
  final GradedSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chosen = index < sheet.chosen.length ? sheet.chosen[index] : null;
    final flag = index < sheet.correctFlags.length ? sheet.correctFlags[index] : null;
    final status = flag == null
        ? l10n.answerBlank
        : flag
            ? l10n.answerCorrect
            : l10n.answerIncorrect;
    final color = flag == null
        ? Colors.grey
        : flag
            ? Colors.green
            : Colors.red;
    return ListTile(
      dense: true,
      leading: Icon(
        flag == null
            ? Icons.circle_outlined
            : flag
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
        color: color,
      ),
      title: Text(l10n.answerLine(index + 1, chosen ?? '—', status)),
    );
  }
}
