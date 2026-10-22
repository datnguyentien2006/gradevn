import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/domain/entities/class_room.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';

import '../state/providers.dart';

/// Tab "Lớp học": danh sách lớp + thêm lớp.
final class ClassesTab extends ConsumerWidget {
  const ClassesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);
    return Scaffold(
      body: classes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) => list.isEmpty
            ? _ClassesEmpty()
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0])),
                      title: Text(c.name),
                      subtitle: c.description == null ? null : Text(c.description!),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await ref.read(classRoomRepositoryProvider).delete(c.id);
                          messenger.showSnackBar(
                              SnackBar(content: Text('Đã xóa lớp ${c.name}.')));
                        },
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ClassDetailScreen(classRoom: c),
                      )),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Thêm lớp'),
        onPressed: () => _addClassDialog(context, ref),
      ),
    );
  }

  Future<void> _addClassDialog(BuildContext context, WidgetRef ref) async {
    final name = await _textDialog(context, 'Tên lớp', 'VD: 10A1');
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    final desc = await _textDialog(context, 'Mô tả (bỏ trống được)', 'VD: Lớp chuyên tin');
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(classRoomRepositoryProvider).insert(
          ClassRoom(
            id: 0,
            name: name.trim(),
            description: desc?.trim().isEmpty == true ? null : desc!.trim(),
          ),
        );
    messenger.showSnackBar(SnackBar(content: Text('Đã thêm lớp ${name.trim()}.')));
  }
}

final class _ClassesEmpty extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(l10n.emptyClasses, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Màn chi tiết lớp: danh sách học sinh + thêm học sinh + nhập file XLSX.
final class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsByClassProvider(classRoom.id));
    return Scaffold(
      appBar: AppBar(title: Text('Học sinh — ${classRoom.name}')),
      body: students.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text('Chưa có học sinh nào.'),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final s = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(s.code)),
                      title: Text(s.fullName),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteStudent(context, ref, s),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          FloatingActionButton.extended(
            heroTag: 'addStudent',
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Thêm học sinh'),
            onPressed: () => _addStudentDialog(context, ref),
          ),
          FloatingActionButton.extended(
            heroTag: 'importStudents',
            icon: const Icon(Icons.upload_file),
            label: const Text('Nhập file XLSX'),
            onPressed: () => _importStudents(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(BuildContext context, WidgetRef ref, Student s) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(studentRepositoryProvider).delete(s.id);
    messenger.showSnackBar(SnackBar(content: Text('Đã xóa học sinh ${s.fullName}.')));
  }

  Future<void> _addStudentDialog(BuildContext context, WidgetRef ref) async {
    final code = await _textDialog(context, 'Mã số học sinh (số báo danh)', 'VD: 0123');
    if (code == null || code.trim().isEmpty) return;
    if (!context.mounted) return;
    final name = await _textDialog(context, 'Họ và tên', 'VD: Nguyễn Văn A');
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(studentRepositoryProvider).insert(
          Student(
            id: 0,
            classId: classRoom.id,
            code: code.trim(),
            fullName: name.trim(),
          ),
        );
    messenger.showSnackBar(SnackBar(content: Text('Đã thêm học sinh ${name.trim()}.')));
  }

  Future<void> _importStudents(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    final path = picked.single.path;
    if (path == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Không chọn được file.')));
      return;
    }
    final students = await ref.read(spreadsheetServiceProvider).readStudents(path);
    if (students.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Không đọc được học sinh nào từ file.')));
      return;
    }
    await ref.read(studentRepositoryProvider).insertMany([
      for (final s in students) Student(id: 0, classId: classRoom.id, code: s.code, fullName: s.fullName),
    ]);
    messenger.showSnackBar(SnackBar(content: Text('Đã nhập ${students.length} học sinh.')));
  }
}

/// Dialog nhập chuỗi dùng chung.
Future<String?> _textDialog(BuildContext context, String title, String hint) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy bỏ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  return controller.text;
}
