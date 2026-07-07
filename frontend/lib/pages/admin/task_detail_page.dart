import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../services/web_io.dart' if (dart.library.html) '../../services/web_io_web.dart';
import '../../theme/m3e_theme.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final int taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = ref.read(apiProvider);
    final taskJson = await api.getFormConfig(widget.taskId);
    final stats = await api.taskStats(widget.taskId);
    final students = await api.listStudents(widget.taskId);
    return {
      'task': Task.fromJson(taskJson['task'] as Map<String, dynamic>),
      'stats': stats,
      'studentCount': (students as List).length,
    };
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _toggleStatus(Task task) async {
    await ref.read(apiProvider).updateTask(
          widget.taskId,
          {'status': task.isOpen ? 'closed' : 'open'},
        );
    _refresh();
  }

  Future<void> _importStudents() async {
    final bytes = await pickFileBytes();
    if (bytes == null) return;
    try {
      await ref
          .read(apiProvider)
          .importStudentsWeb(widget.taskId, bytes, 'students.xlsx');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导入成功')));
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin')),
        title: const Text('任务详情'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('加载失败: ${snap.error}'));
          final task = snap.data!['task'] as Task;
          final stats = snap.data!['stats'] as Map<String, dynamic>;
          final studentCount = snap.data!['studentCount'] as int;

          return ListView(
            padding: EdgeInsets.all(m3e.spacing.md),
            children: [
              Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: m3e.shapes.extraLarge,
                child: Padding(
                  padding: EdgeInsets.all(m3e.spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(task.title,
                                style: m3e.typography.headlineSmall),
                          ),
                          Switch(
                            value: task.isOpen,
                            onChanged: (_) => _toggleStatus(task),
                          ),
                        ],
                      ),
                      if (task.description.isNotEmpty) ...[
                        SizedBox(height: m3e.spacing.xs),
                        Text(task.description,
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                      SizedBox(height: m3e.spacing.md),
                      Wrap(
                        spacing: m3e.spacing.sm,
                        children: [
                          _statChip(cs, '学生', studentCount.toString()),
                          _statChip(cs, '已提交',
                              stats['submitted']?.toString() ?? '0'),
                          _statChip(cs, '未提交',
                              stats['pending']?.toString() ?? '0'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: m3e.spacing.md),
              _ActionTile(
                icon: Icons.list_alt,
                title: '表单字段配置',
                subtitle: '设置题目显示名与导出表头（双轨制）',
                onTap: () => context.go('/admin/tasks/${widget.taskId}/fields'),
              ),
              _ActionTile(
                icon: Icons.upload_file,
                title: '导入学生名单',
                subtitle: 'Excel 表头需含「学号」「姓名」「密码」',
                onTap: () {
                  if (!kIsWeb) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请在网页端导入名单')));
                    return;
                  }
                  _importStudents();
                },
              ),
              _ActionTile(
                icon: Icons.people_outline,
                title: '查看填报情况',
                subtitle: '查看每位学生的提交明细',
                onTap: () => _showSubmissions(),
              ),
              _ActionTile(
                icon: Icons.download,
                title: '导出 Excel',
                subtitle: '按官方表头导出数据',
                onTap: () {
                  if (!kIsWeb) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请在网页端导出 Excel')));
                    return;
                  }
                  ApiService.instance.triggerExcelDownload(widget.taskId);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已开始下载 Excel')));
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statChip(ColorScheme cs, String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: cs.secondaryContainer,
    );
  }

  Future<void> _showSubmissions() async {
    final list = await ref.read(apiProvider).listSubmissions(widget.taskId);
    if (!mounted) return;
    final m3e = M3ETheme.of(context);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('填报情况'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (_, i) {
              final item = SubmissionItem.fromJson(list[i] as Map<String, dynamic>);
              return ListTile(
                leading: Icon(
                  item.submitted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: item.submitted
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text('${item.student.studentNo}  ${item.student.name}'),
                subtitle: Text(item.submitted ? '已提交' : '未提交'),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('关闭')),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: m3e.spacing.sm),
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: m3e.shapes.large,
        child: ListTile(
          leading: Icon(icon, color: cs.primary),
          title: Text(title),
          subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
