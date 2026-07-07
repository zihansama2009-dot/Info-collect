import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../theme/m3e_theme.dart';

class StudentTaskSelectPage extends ConsumerWidget {
  const StudentTaskSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    final tasksAsync = ref.watch(availableTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择任务'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e', style: TextStyle(color: cs.error))),
        data: (data) {
          final userTasks = (data['user_tasks'] as List?) ?? [];
          final groupTasks = (data['group_tasks'] as List?) ?? [];
          final allTasks = [...userTasks, ...groupTasks];

          if (allTasks.isEmpty) {
            return Center(
              child: Text('暂无可用任务', style: TextStyle(color: cs.onSurfaceVariant)),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(m3e.spacing.md),
            itemCount: allTasks.length,
            itemBuilder: (context, i) {
              final task = allTasks[i];
              final isOpen = task['status'] == 'open';
              return Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: m3e.shapes.large,
                margin: EdgeInsets.only(bottom: m3e.spacing.sm),
                child: ListTile(
                  title: Text(task['title'] ?? '未命名任务'),
                  subtitle: Text(isOpen ? '进行中' : '已关闭', style: TextStyle(color: isOpen ? cs.primary : cs.outline)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: isOpen ? () {
                    final taskId = task['id'] as int;
                    context.go('/student/fill/$taskId');
                  } : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
