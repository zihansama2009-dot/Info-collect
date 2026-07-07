import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../theme/m3e_theme.dart';

class AdminTaskAssignPage extends ConsumerStatefulWidget {
  final int taskId;
  const AdminTaskAssignPage({super.key, required this.taskId});

  @override
  ConsumerState<AdminTaskAssignPage> createState() => _AdminTaskAssignPageState();
}

class _AdminTaskAssignPageState extends ConsumerState<AdminTaskAssignPage> {
  List<dynamic> _allStudents = [];
  List<dynamic> _allGroups = [];
  Set<int> _selectedUserIds = {};
  Set<int> _selectedGroupIds = {};
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    final assignments = await api.getTaskAssignments(widget.taskId);
    _allStudents = await api.listStudents();
    _allGroups = await api.listGroups();

    _selectedUserIds = {};
    for (final a in (assignments['users'] as List? ?? [])) {
      _selectedUserIds.add(a['student_user_id'] as int);
    }
    _selectedGroupIds = {};
    for (final a in (assignments['groups'] as List? ?? [])) {
      _selectedGroupIds.add(a['group_id'] as int);
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiProvider);
      await api.assignUsersToTask(widget.taskId, _selectedUserIds.toList());
      await api.assignGroupsToTask(widget.taskId, _selectedGroupIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分配成功')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分配失败: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m3e = M3ETheme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin/tasks/${widget.taskId}')),
        title: const Text('分配任务'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(m3e.spacing.md),
              children: [
                Text('用户', style: m3e.typography.titleMedium),
                SizedBox(height: m3e.spacing.sm),
                ..._allStudents.map((s) {
                  final id = s['id'] as int;
                  final checked = _selectedUserIds.contains(id);
                  return CheckboxListTile(
                    title: Text('${s['student_no']} ${s['name']}'),
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedUserIds.add(id);
                        } else {
                          _selectedUserIds.remove(id);
                        }
                      });
                    },
                  );
                }),
                SizedBox(height: m3e.spacing.lg),
                Text('组', style: m3e.typography.titleMedium),
                SizedBox(height: m3e.spacing.sm),
                ..._allGroups.map((g) {
                  final id = g['id'] as int;
                  final checked = _selectedGroupIds.contains(id);
                  return CheckboxListTile(
                    title: Text(g['name'] ?? ''),
                    subtitle: Text(g['description'] ?? ''),
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedGroupIds.add(id);
                        } else {
                          _selectedGroupIds.remove(id);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
    );
  }
}
