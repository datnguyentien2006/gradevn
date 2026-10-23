// Màn chi tiết kỳ thi (R1): cấu hình phiếu + quản lý mã đề + chấm phiếu.
//
// R1:
// - "In phiếu mẫu" đã bỏ khỏi UI (renderer phiếu trống vẫn giữ nội bộ);
//   tính năng XLSX vẫn tồn tại nhưng bị ẩn sau cờ `showXlsxFeatures`.
// - Nhập mã đề chuyển sang KeyEditorScreen (2 tab: mã đề / trả lời);
//   mọi nút nhãn hiển thị đều tiếng Việt.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/data/import_export/xlsx_service.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

import '../state/providers.dart';
import 'key_editor_screen.dart';
import 'scan_screen.dart';

/// Màn chi tiết kỳ thi: cấu hình phiếu + quản lý mã đề (key) + chấm phiếu.
final class ContestDetailScreen extends ConsumerWidget {
  const ContestDetailScreen({super.key, required this.contest});

  final Contest contest;

  static final RegExp _invalidNameChars = RegExp(r'[\\/:*?"<>|]');

  /// R1: tạm ẩn luồng XLSX (xuất kết quả / nhập mã đề file) khỏi UI.
  /// Bật lại khi luồng file sắp xếp lại ở M4; code + test vẫn giữ nguyên.
  static const bool showXlsxFeatures = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
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
                  Text('Cấu hình phiếu',
                      style: Theme.of(context).textTheme.titleMedium),
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
                    child: Text('Chưa có mã đề nào. Nhấn "Thêm mã đề" để nhập.'),
                  )
                : Column(
                    children: [
                      for (final k in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.key_outlined),
                            title: Text('Mã đề: ${k.examCode}'),
                            subtitle:
                                Text('${k.answerCount} câu · ${k.answerSequence}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  ref.read(answerKeyRepositoryProvider).delete(k.id),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(l10n.contestDetailScanButton),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ScanScreen(contestId: contest.id),
            )),
          ),
          if (showXlsxFeatures) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.table_view),
              label: const Text('Xuất kết quả ra XLSX'),
              onPressed: () => _exportResults(context, ref),
            ),
          ],
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
            onPressed: () => _openKeyEditor(context),
          ),
          if (showXlsxFeatures)
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

  /// R1: nhập mã đề và đáp án bằng trình nhập 2 tab (thay dialog văn bản);
  /// thành công → editor pop trả về mã đề đã lưu, hiển thị thông báo.
  Future<void> _openKeyEditor(BuildContext context) async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
          builder: (_) => KeyEditorScreen(contest: contest)),
    );
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.keyEditorSavedMessage(saved))),
      );
    }
  }

  /// Luồng nhập file XLSX (ẩn sau [showXlsxFeatures] — code giữ cho M4).
  /// Người dùng huỷ chọn file → picker trả danh sách rỗng: thoát không lỗi.
  Future<void> _importKeys(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    // Huỷ hộp thoại chọn file: `picked` rỗng → thoát (không dùng .single —
    // ném StateError khi rỗng, crash M3 đã ghi nhận).
    if (picked.isEmpty) return;
    final path = picked.first.path;
    if (path == null) return;
    final keys = await ref.read(spreadsheetServiceProvider).readKeys(path);
    if (keys.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Không đọc được mã đề nào từ file.')));
      return;
    }
    await ref.read(answerKeyRepositoryProvider).insertMany(
          contest.id,
          [for (final k in keys) (k.examCode, k.answerSequence)],
        );
    messenger.showSnackBar(SnackBar(content: Text('Đã nhập ${keys.length} mã đề.')));
  }

  /// Luồng xuất kết quả XLSX (ẩn sau [showXlsxFeatures] — code giữ cho M4).
  Future<void> _exportResults(BuildContext context, WidgetRef ref) async {
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
