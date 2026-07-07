import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/m3e_theme.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  late Future<List<Task>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Task>> _load() async {
    final list = await ref.read(apiProvider).listTasks();
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<void> _createTask() async {
    final title = await _showInputDialog('新建任务', '任务标题');
    if (title == null || title.trim().isEmpty) return;
    await ref.read(apiProvider).createTask(title.trim(), '');
    _refresh();
  }

  Future<String?> _showInputDialog(String title, String label) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Task task) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: m3e.shapes.extraLarge,
        backgroundColor: cs.surfaceContainerLow,
        icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 32),
        title: Text('永久删除任务？', style: Theme.of(context).textTheme.headlineSmall),
        content: Text(
          '您确定要删除任务「${task.title}」吗？\n\n这将永久清除该任务下的所有表单配置和全班同学的填报数据，且无法恢复！',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () async {
              Navigator.of(c).pop();
              try {
                await ref.read(apiProvider).deleteTask(task.id);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('任务已删除')));
                  _refresh();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('删除失败: $e')));
                }
              }
            },
            child: const Text('确认删除'),
          ),
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
        title: const Text('任务管理'),
        actions: [
          IconButton(
            tooltip: '账号设置',
            onPressed: () => context.go('/admin/settings'),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '退出登录',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTask,
        icon: const Icon(Icons.add),
        label: const Text('新建任务'),
      ),
      body: FutureBuilder<List<Task>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('加载失败: ${snap.error}'));
          }
          final tasks = snap.data!;
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox, size: 64, color: cs.outline),
                  const SizedBox(height: 12),
                  Text('暂无任务，点击右下角创建', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(m3e.spacing.md),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => SizedBox(height: m3e.spacing.sm),
            itemBuilder: (context, i) {
              final t = tasks[i];
              return Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: m3e.shapes.large,
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: m3e.spacing.md, vertical: m3e.spacing.xs),
                  title: Text(t.title, style: m3e.typography.titleMedium),
                  subtitle: Text(
                    t.isOpen ? '进行中 · 点击查看详情' : '已关闭',
                    style: TextStyle(color: t.isOpen ? cs.primary : cs.outline),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(t.isOpen ? '开放' : '关闭'),
                        backgroundColor:
                            t.isOpen ? cs.primaryContainer : cs.surfaceContainerHighest,
                      ),
                      IconButton(
                        tooltip: '删除任务',
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () => _showDeleteConfirmation(t),
                      ),
                    ],
                  ),
                  onTap: () => context.go('/admin/tasks/${t.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
