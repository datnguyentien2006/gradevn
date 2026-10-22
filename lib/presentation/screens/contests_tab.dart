import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/domain/entities/class_room.dart';
import 'package:gradevn/domain/entities/contest.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';

import '../state/providers.dart';
import 'contest_detail_screen.dart';

const _formTypeLabels = <SheetFormType, String>{
  SheetFormType.standard: 'Phiếu chuẩn',
  SheetFormType.fifty: 'Phiếu 50 câu',
  SheetFormType.hundred20: 'Phiếu 120 câu',
  SheetFormType.ministry: 'Phiếu bộ đề (nhiều phần)',
};

const _orientationLabels = <SheetOrientation, String>{
  SheetOrientation.portrait: 'Dọc',
  SheetOrientation.landscape: 'Ngang',
};

/// Tab "Kỳ thi": danh sách kỳ thi + tạo kỳ thi mới.
final class ContestsTab extends ConsumerWidget {
  const ContestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contests = ref.watch(contestsProvider);
    return Scaffold(
      body: contests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_outlined, size: 56,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(AppLocalizations.of(context)!.emptyContests,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.quiz_outlined),
                      title: Text(c.name),
                      subtitle: Text(
                          'Ngày: ${_date(c.examDate)} · ${c.questionCount} câu · max ${_score(c.maxScore)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref.read(contestRepositoryProvider).delete(c.id),
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ContestDetailScreen(contest: c),
                      )),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Tạo kỳ thi'),
        onPressed: () => _createContest(context, ref),
      ),
    );
  }

  String _date(DateTime d) => '${d.day.toStringAsFixed(0).padLeft(2, '0')}/'
      '${d.month.toStringAsFixed(0).padLeft(2, '0')}/${d.year}';

  String _score(double s) => s % 1 == 0 ? s.toStringAsFixed(0) : s.toString();

  Future<void> _createContest(BuildContext context, WidgetRef ref) async {
    final contest = await _contestFormDialog(context, ref);
    if (contest == null) return;
    await ref.read(contestRepositoryProvider).insert(contest);
  }
}

/// Form tạo kỳ thi (modal đầy màn hình cho gọn).
Future<Contest?> _contestFormDialog(BuildContext context, WidgetRef ref) {
  final controllers = {
    'name': TextEditingController(),
    'questions': TextEditingController(text: '40'),
    'choices': TextEditingController(text: '4'),
    'max': TextEditingController(text: '10'),
    'p1': TextEditingController(),
    'p2': TextEditingController(),
    'p3': TextEditingController(),
    'w1': TextEditingController(),
    'w2': TextEditingController(),
    'w3': TextEditingController(),
  };
  var formType = SheetFormType.standard;
  var orientation = SheetOrientation.portrait;
  var examDate = DateTime.now();
  ClassRoom? selectedClass;

  return showDialog<Contest>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Tạo kỳ thi mới'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controllers['name']!,
                    decoration: const InputDecoration(labelText: 'Tên kỳ thi')),
                TextField(controller: controllers['questions']!,
                    decoration: const InputDecoration(labelText: 'Số câu hỏi'),
                    keyboardType: TextInputType.number),
                TextField(controller: controllers['choices']!,
                    decoration: const InputDecoration(labelText: 'Số lựa chọn (4=A..D)'),
                    keyboardType: TextInputType.number),
                TextField(controller: controllers['max']!,
                    decoration: const InputDecoration(labelText: 'Điểm tối đa (10)'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                DropdownButtonFormField<SheetFormType>(
                  initialValue: formType,
                  decoration: const InputDecoration(labelText: 'Loại phiếu'),
                  items: [
                    for (final e in SheetFormType.values)
                      DropdownMenuItem(value: e, child: Text(_formTypeLabels[e]!)),
                  ],
                  onChanged: (v) => setState(() => formType = v ?? formType),
                ),
                if (formType == SheetFormType.ministry) ...[
                  TextField(controller: controllers['p1']!,
                      decoration: const InputDecoration(labelText: 'Số câu Phần I'),
                      keyboardType: TextInputType.number),
                  TextField(controller: controllers['w1']!,
                      decoration: const InputDecoration(labelText: 'Điểm Phần I'),
                      keyboardType: TextInputType.number),
                  TextField(controller: controllers['p2']!,
                      decoration: const InputDecoration(labelText: 'Số câu Phần II'),
                      keyboardType: TextInputType.number),
                  TextField(controller: controllers['w2']!,
                      decoration: const InputDecoration(labelText: 'Điểm Phần II'),
                      keyboardType: TextInputType.number),
                  TextField(controller: controllers['p3']!,
                      decoration: const InputDecoration(labelText: 'Số câu Phần III'),
                      keyboardType: TextInputType.number),
                  TextField(controller: controllers['w3']!,
                      decoration: const InputDecoration(labelText: 'Điểm Phần III'),
                      keyboardType: TextInputType.number),
                ],
                DropdownButtonFormField<SheetOrientation>(
                  initialValue: orientation,
                  decoration: const InputDecoration(labelText: 'Hướng phiếu'),
                  items: [
                    for (final e in SheetOrientation.values)
                      DropdownMenuItem(value: e, child: Text(_orientationLabels[e]!)),
                  ],
                  onChanged: (v) => setState(() => orientation = v ?? orientation),
                ),
                _ClassPicker(
                  selected: selectedClass,
                  onSelected: (c) => setState(() => selectedClass = c),
                ),
                Row(
                  children: [
                    Text('Ngày: ${examDate.day}/${examDate.month}/${examDate.year}'),
                    IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: examDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => examDate = d);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy bỏ')),
          FilledButton(
            onPressed: () {
              final name = controllers['name']!.text.trim();
              if (name.isEmpty) return;
              final contest = Contest(
                id: 0,
                name: name,
                examDate: examDate,
                classRoomId: selectedClass?.id,
                questionCount: int.tryParse(controllers['questions']!.text) ?? 40,
                answerChoices: int.tryParse(controllers['choices']!.text) ?? 4,
                maxScore: double.tryParse(controllers['max']!.text) ?? 10,
                formType: formType,
                orientation: orientation,
                partOneCount: int.tryParse(controllers['p1']!.text),
                partTwoCount: int.tryParse(controllers['p2']!.text),
                partThreeCount: int.tryParse(controllers['p3']!.text),
                partOneWeight: double.tryParse(controllers['w1']!.text),
                partTwoWeight: double.tryParse(controllers['w2']!.text),
                partThreeWeight: double.tryParse(controllers['w3']!.text),
              );
              Navigator.pop(dialogContext, contest);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
}

/// Chọn lớp (tùy chọn).
final class _ClassPicker extends ConsumerStatefulWidget {
  const _ClassPicker({required this.selected, required this.onSelected});

  final ClassRoom? selected;
  final ValueChanged<ClassRoom?> onSelected;

  @override
  ConsumerState<_ClassPicker> createState() => _ClassPickerState();
}

final class _ClassPickerState extends ConsumerState<_ClassPicker> {
  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider);
    return classes.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => const SizedBox.shrink(),
      data: (list) => DropdownButtonFormField<ClassRoom?>(
        initialValue: widget.selected,
        decoration: const InputDecoration(labelText: 'Lớp (tùy chọn)'),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Không gán lớp —')),
          for (final c in list) DropdownMenuItem(value: c, child: Text(c.name)),
        ],
        onChanged: widget.onSelected,
      ),
    );
  }
}
