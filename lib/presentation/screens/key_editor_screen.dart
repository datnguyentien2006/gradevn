// Trình nhập mã đề & đáp án (R1): 2 tab — "MÃ ĐỀ" (chọn từng chữ số bằng
// chip 0–9, xem trước mã ghép trực tiếp) và "TRẢ LỜI" (mỗi câu một hàng vòng
// A–E, nhấn chọn / nhấn lần nữa để bỏ).
//
// Lưu: bắt buộc đủ mã đề; còn câu bỏ trống → hỏi xác nhận trước khi insert.
// Dẫn cấu hình từ kỳ thi (FormSpec): số chữ số = template.examSlots, bảng
// chữ luôn đủ A–E; phiếu không có ô E → ô E tô xám kèm ghi chú.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';

import '../../domain/entities/contest.dart';
import '../models/key_editor_model.dart';
import '../state/providers.dart';

/// Nhập một mã đề cho kỳ thi: tự insert DB rồi pop về màn trước.
final class KeyEditorScreen extends ConsumerStatefulWidget {
  const KeyEditorScreen({super.key, required this.contest});

  final Contest contest;

  @override
  ConsumerState<KeyEditorScreen> createState() => _KeyEditorScreenState();
}

final class _KeyEditorScreenState extends ConsumerState<KeyEditorScreen> {
  late final KeyEditorModel _model = KeyEditorModel.fromConfig(
    KeyEditorConfig.fromContest(widget.contest),
  );

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  /// Lưu: đủ mã đề mới cho qua; còn câu bỏ trống → xác nhận trước.
  /// Pop trả về mã đề đã lưu (ContestDetailScreen hiển thị thông báo).
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    if (!_model.isCodeComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.keyEditorCodeIncomplete(_model.examSlots))),
      );
      return;
    }
    if (_model.unansweredCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.keyEditorUnansweredConfirm(_model.unansweredCount)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final examCode = _model.examCode;
    await ref.read(answerKeyRepositoryProvider).insert(
          AnswerKey(
            id: 0,
            contestId: widget.contest.id,
            examCode: examCode,
            answerSequence: _model.answerSequence,
          ),
        );
    if (!mounted) return;
    navigator.pop(examCode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.keyEditorTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.keyEditorTabCode),
              Tab(text: l10n.keyEditorTabAnswers),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CodeTab(model: _model),
            _AnswersTab(model: _model),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.keyEditorSave),
              onPressed: _save,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab MÃ ĐỀ: bản xem trước mã ghép + một hàng chip 0–9 cho từng vị trí.
final class _CodeTab extends StatelessWidget {
  const _CodeTab({required this.model});

  final KeyEditorModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(l10n.keyEditorCodePreview,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    model.examCode,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var slot = 0; slot < model.examSlots; slot++) ...[
            Text(l10n.keyEditorDigitSlot(slot + 1),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var value = 0; value <= 9; value++)
                  ChoiceChip(
                    label: Text('$value'),
                    selected: model.isDigitSelected(slot, value),
                    onSelected: (_) => model.toggleDigit(slot, value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// Tab TRẢ LỜI: ghi chú ô E (nếu phiếu không có) + các hàng vòng lựa chọn.
final class _AnswersTab extends StatelessWidget {
  const _AnswersTab({required this.model});

  final KeyEditorModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) => Column(
        children: [
          if (!model.eOnPaper) _EditorNote(note: l10n.keyEditorNoEOnPaper),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: model.questionCount,
              itemBuilder: (context, index) => _AnswerRow(
                question: index,
                model: model,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một câu: nhãn "Câu N" + các vòng chữ A–E (nhấn chọn / nhấn lần nữa bỏ).
final class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.question, required this.model});

  final int question;
  final KeyEditorModel model;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text('Câu ${question + 1}'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                const Spacer(),
                for (var i = 0; i < model.letters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  _AnswerCircle(
                    letter: model.letters[i],
                    selected: model.isAnswerSelected(question, model.letters[i]),
                    onPaper: model.letters[i] != 'E' || model.eOnPaper,
                    onTap: () => model.toggleAnswer(question, model.letters[i]),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vòng lựa chọn chữ cái: tô đậm khi chọn; ô không có trên phiếu tô xám.
final class _AnswerCircle extends StatelessWidget {
  const _AnswerCircle({
    required this.letter,
    required this.selected,
    required this.onPaper,
    required this.onTap,
  });

  final String letter;
  final bool selected;
  final bool onPaper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dimmed = !onPaper && !selected;
    return Semantics(
      label: letter,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? colorScheme.primary
                : dimmed
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                    : null,
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : dimmed
                      ? colorScheme.outlineVariant
                      : colorScheme.outline,
            ),
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected
                  ? colorScheme.onPrimary
                  : dimmed
                      ? colorScheme.outline
                      : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner ghi chú nhỏ (phiếu không có ô E).
final class _EditorNote extends StatelessWidget {
  const _EditorNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(note)),
        ],
      ),
    );
  }
}
