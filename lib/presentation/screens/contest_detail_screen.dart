import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/data/import_export/xlsx_service.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:pdf/pdf.dart' as pdf_format;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import '../state/providers.dart';
import 'scan_screen.dart';
import '../../data/cv/sheet_painter.dart' show renderBlankSheet;
import '../../domain/services/sheet_layout.dart';

/// Màn chi tiết kỳ thi: cấu hình phiếu + quản lý mã đề (key) + xuất kết quả.
final class ContestDetailScreen extends ConsumerWidget {
  const ContestDetailScreen({super.key, required this.contest});

  final Contest contest;

  static final RegExp _invalidNameChars = RegExp(r'[\\/:*?"<>|]');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(keysByContestProvider(contest.id));
    return Scaffold(
      appBar: AppBar(title: Text(contest.name)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cấu hình phiếu', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Số câu: ${contest.questionCount} · '
                      'Lựa chọn: ${contest.answerChoices} (A..${contest.lastChoiceLetter}) · '
                      'Điểm tối đa: ${contest.maxScore}'),
                  Text('Loại phiếu: ${contest.formType.name}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Mã đề / đáp án', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          keys.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi: $e')),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Chưa có mã đề nào. Thêm thủ công hoặc nhập file XLSX.'),
                  )
                : Column(
                    children: [
                      for (final k in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.key_outlined),
                            title: Text('Mã đề: ${k.examCode}'),
                            subtitle: Text('${k.answerCount} câu · ${k.answerSequence}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref.read(answerKeyRepositoryProvider).delete(k.id),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(AppLocalizations.of(context)!.contestDetailScanButton),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ScanScreen(contestId: contest.id),
            )),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined),
            label: Text(AppLocalizations.of(context)!.printBlankSheet),
            onPressed: () => _printBlankSheet(context),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.table_view),
            label: const Text('Xuất kết quả ra XLSX'),
            onPressed: () => _exportResults(context, ref),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          FloatingActionButton.extended(
            heroTag: 'addKey',
            icon: const Icon(Icons.add),
            label: const Text('Thêm mã đề'),
            onPressed: () => _addKeyManually(context, ref),
          ),
          FloatingActionButton.extended(
            heroTag: 'importKeys',
            icon: const Icon(Icons.upload_file),
            label: const Text('Nhập mã đề (XLSX)'),
            onPressed: () => _importKeys(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _addKeyManually(BuildContext context, WidgetRef ref) async {
    final seqController = TextEditingController();
    final examController = TextEditingController();    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm mã đề'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: examController,
              decoration: const InputDecoration(labelText: 'Mã đề (VD: A01, 123)'),
            ),
            TextField(
              controller: seqController,
              decoration: const InputDecoration(
                labelText: 'Dãy đáp án (VD: ABCD — mỗi ký tự 1 câu)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Hủy bỏ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (saved != true) return;
    final exam = examController.text.trim();
    final seq = seqController.text.toUpperCase().replaceAll(RegExp(r'[\s,;]'), '');
    if (exam.isEmpty || seq.isEmpty) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(answerKeyRepositoryProvider).insert(
      AnswerKey(id: 0, contestId: contest.id, examCode: exam, answerSequence: seq),
    );
    messenger.showSnackBar(SnackBar(content: Text('Đã thêm mã đề $exam.')));
  }

  Future<void> _importKeys(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    final path = picked.single.path;
    if (path == null) return;
    final keys = await ref.read(spreadsheetServiceProvider).readKeys(path);
    if (keys.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Không đọc được mã đề nào từ file.')));
      return;
    }
    await ref.read(answerKeyRepositoryProvider).insertMany(
      contest.id,
      [for (final k in keys) (k.examCode, k.answerSequence)],
    );
    messenger.showSnackBar(SnackBar(content: Text('Đã nhập ${keys.length} mã đề.')));
  }

  /// M3: in phiếu mẫu (phiếu trống) của kỳ thi — dựng PDF A4 dọc từ
  /// renderBlankSheet rồi chia sẻ qua Printing; luôn thất bại (desktop không
  /// có plugin) → fallback ghi file vào thư mục tài liệu và báo đường dẫn.
  Future<void> _printBlankSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final layout =
          SheetLayout.forSpec(contest.sheetSpec, page: SheetLayout.standardPage);
      final png = renderBlankSheet(layout);
      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: pdf_format.PdfPageFormat.a4,
        build: (context) => pw.Image(
          pw.MemoryImage(png),
          fit: pw.BoxFit.fill,
        ),
      ));
      final bytes = await doc.save();
      final safeName = contest.name.replaceAll(_invalidNameChars, '_');
      final ok = await Printing.sharePdf(
        bytes: bytes,
        filename: 'phieu_$safeName.pdf',
      );
      if (ok == false) {
        final docsDir = await getApplicationDocumentsDirectory();
        final fallbackPath =
            '${docsDir.path}${Platform.pathSeparator}phieu_$safeName.pdf';
        File(fallbackPath).writeAsBytesSync(bytes);
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.blankSheetSavedMessage(fallbackPath))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.scanError(l10n.blankSheetFailed)),
      ));
    }
  }

  Future<void> _exportResults(BuildContext context, WidgetRef ref) async {
    // M1: ghi vào thư mục tài liệu của ứng dụng (không phụ thuộc SAF).
    // M4 sẽ nâng cấp luồng lưu tùy chọn + PDF.
    final messenger = ScaffoldMessenger.of(context);
    final docsDir = await getApplicationDocumentsDirectory();
    final output = '${docsDir.path}${Platform.pathSeparator}'
        'ketqua_${contest.name.replaceAll(_invalidNameChars, '_')}.xlsx';
    final service = ref.read(spreadsheetServiceProvider);
    await service.writeResults(
      filePath: output,
      contestName: contest.name,
      rows: const <ResultRow>[],
    );
    messenger.showSnackBar(SnackBar(content: Text('Đã xuất file: $output')));
  }
}

extension ContestBriefX on Contest {
  /// Ký tự lựa chọn cuối cùng (A..J) giới hạn bởi answerChoices.
  String get lastChoiceLetter {
    const alpha = 'ABCDEFGHIJ';
    return alpha[(answerChoices - 1).clamp(0, alpha.length - 1)];
  }
}
