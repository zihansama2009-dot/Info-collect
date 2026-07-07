import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../theme/m3e_theme.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  bool _loading = true;
  String? _username;
  String? _version;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await ref.read(apiProvider).getAdminInfo();
      setState(() {
        _username = info['username'] as String?;
        _version = info['version'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _changeUsername() async {
    final controller = TextEditingController(text: _username ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('修改用户名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新用户名',
            hintText: '3-64 位字母或数字',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == _username) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).changeAdminUsername(newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户名修改成功')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '原密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final oldPwd = oldCtrl.text.trim();
    final newPwd = newCtrl.text.trim();
    if (oldPwd.isEmpty || newPwd.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).changeAdminPassword(oldPwd, newPwd);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码修改成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
          onPressed: () => context.go('/admin'),
        ),
        title: const Text('账号设置'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
              : ListView(
                  padding: EdgeInsets.all(m3e.spacing.md),
                  children: [
                    Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: m3e.shapes.large,
                      child: Padding(
                        padding: EdgeInsets.all(m3e.spacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: cs.primary),
                                SizedBox(width: m3e.spacing.sm),
                                Text('管理员信息', style: m3e.typography.titleMedium),
                              ],
                            ),
                            SizedBox(height: m3e.spacing.md),
                            _infoRow('用户名', _username ?? '-', m3e),
                            SizedBox(height: m3e.spacing.sm),
                            _infoRow('版本', _version ?? '-', m3e),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: m3e.spacing.md),
                    Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: m3e.shapes.large,
                      child: Padding(
                        padding: EdgeInsets.all(m3e.spacing.md),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.person_outline, color: cs.primary),
                              title: const Text('修改用户名'),
                              subtitle: const Text('更改管理员登录用户名'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _saving ? null : _changeUsername,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.lock_outline, color: cs.primary),
                              title: const Text('修改密码'),
                              subtitle: const Text('更改管理员登录密码'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _saving ? null : _changePassword,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _infoRow(String label, String value, M3EThemeData m3e) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: m3e.typography.labelMedium.copyWith(color: cs.onSurfaceVariant)),
        ),
        Expanded(child: Text(value, style: m3e.typography.bodyMedium)),
      ],
    );
  }
}
