import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../services/web_io.dart' if (dart.library.html) '../../services/web_io_web.dart';
import '../../theme/m3e_theme.dart';

class AdminStudentListPage extends ConsumerStatefulWidget {
  const AdminStudentListPage({super.key});

  @override
  ConsumerState<AdminStudentListPage> createState() => _AdminStudentListPageState();
}

class _AdminStudentListPageState extends ConsumerState<AdminStudentListPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    return await ref.read(apiProvider).listStudents();
  }

  Future<void> _createStudent() async {
    final noCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('新建学生账号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: noCtrl, decoration: const InputDecoration(labelText: '学号', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: pwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirmed != true) return;
    final no = noCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final pwd = pwdCtrl.text.trim();
    if (no.isEmpty || name.isEmpty || pwd.isEmpty) return;

    try {
      await ref.read(apiProvider).createStudent(no, name, pwd);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建成功')));
        setState(() => _future = _load());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  Future<void> _resetPassword(int userId, String name) async {
    final pwdCtrl = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('重置密码: $name'),
        content: TextField(
          controller: pwdCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新密码', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, pwdCtrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (confirmed == null || confirmed.isEmpty) return;
    try {
      await ref.read(apiProvider).resetStudentPassword(userId, confirmed);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码已重置')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重置失败: $e')));
    }
  }

  Future<void> _deleteStudent(int userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除学生账号'),
        content: Text('确定删除「$name」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiProvider).deleteStudent(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
        setState(() => _future = _load());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _importStudents() async {
    final bytes = await pickFileBytes();
    if (bytes == null || bytes.isEmpty) return;

    final pwdCtrl = TextEditingController(text: '123456');
    final defaultPwd = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('批量导入学生'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('表格格式：第一行为表头（跳过），A=学号, B=姓名, C=密码(可选)'),
            const SizedBox(height: 16),
            TextField(
              controller: pwdCtrl,
              decoration: const InputDecoration(
                labelText: '默认密码（密码列为空时使用）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, pwdCtrl.text.trim()), child: const Text('导入')),
        ],
      ),
    );
    if (defaultPwd == null || defaultPwd.isEmpty) return;

    try {
      final result = await ref.read(apiProvider).importStudents(bytes, defaultPassword: defaultPwd);
      if (!mounted) return;
      _showImportResult(result);
      setState(() => _future = _load());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  void _showImportResult(Map<String, dynamic> result) {
    final created = result['created'] ?? 0;
    final skipped = result['skipped'] ?? 0;
    final failed = result['failed'] ?? 0;
    final total = result['total'] ?? 0;
    final errors = (result['errors'] as List?) ?? [];
    final skippedRows = (result['skipped_rows'] as List?) ?? [];

    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('导入结果'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('总行数: $total'),
              Text('成功: $created', style: TextStyle(color: Colors.green)),
              Text('跳过(已存在): $skipped', style: TextStyle(color: Colors.orange)),
              Text('失败: $failed', style: TextStyle(color: Colors.red)),
              if (errors.isNotEmpty || skippedRows.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                if (errors.isNotEmpty) ...[
                  const Text('错误详情:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: errors.length,
                      itemBuilder: (context, i) {
                        final e = errors[i] as Map<String, dynamic>;
                        return Text('第${e['row']}行 ${e['student_no'] ?? ''}: ${e['reason']}',
                            style: const TextStyle(fontSize: 12, color: Colors.red));
                      },
                    ),
                  ),
                ],
                if (skippedRows.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('跳过详情:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: skippedRows.length,
                      itemBuilder: (context, i) {
                        final e = skippedRows[i] as Map<String, dynamic>;
                        return Text('第${e['row']}行 ${e['student_no'] ?? ''}: ${e['reason']}',
                            style: const TextStyle(fontSize: 12, color: Colors.orange));
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('确定')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin')),
        title: const Text('学生管理'),
        actions: [
          IconButton(onPressed: _importStudents, tooltip: '批量导入', icon: const Icon(Icons.upload_file)),
          IconButton(onPressed: _createStudent, icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('加载失败: ${snap.error}', style: TextStyle(color: cs.error)));
          final students = snap.data!;
          if (students.isEmpty) {
            return Center(child: Text('暂无学生账号', style: TextStyle(color: cs.onSurfaceVariant)));
          }
          return ListView.separated(
            padding: EdgeInsets.all(m3e.spacing.md),
            itemCount: students.length,
            separatorBuilder: (_, __) => SizedBox(height: m3e.spacing.sm),
            itemBuilder: (context, i) {
              final s = students[i];
              return Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: m3e.shapes.large,
                child: ListTile(
                  title: Text(s['student_no'] ?? ''),
                  subtitle: Text(s['name'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '重置密码',
                        onPressed: () => _resetPassword(s['id'], s['name']),
                        icon: Icon(Icons.lock_reset, color: cs.primary),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _deleteStudent(s['id'], s['name']),
                        icon: Icon(Icons.delete_outline, color: cs.error),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
