import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../theme/m3e_theme.dart';

class StudentChangePasswordPage extends ConsumerStatefulWidget {
  const StudentChangePasswordPage({super.key});

  @override
  ConsumerState<StudentChangePasswordPage> createState() => _StudentChangePasswordPageState();
}

class _StudentChangePasswordPageState extends ConsumerState<StudentChangePasswordPage> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final oldPwd = _oldCtrl.text.trim();
    final newPwd = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (newPwd.length < 6) {
      setState(() => _error = '新密码至少6位');
      return;
    }
    if (newPwd != confirm) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).changeStudentPassword(oldPwd, newPwd);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码修改成功，请登录')),
        );
        await ref.read(authProvider.notifier).logout();
        if (mounted) context.go('/');
      }
    } catch (e) {
      setState(() => _error = '修改失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('首次登录，请修改密码'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: m3e.shapes.extraLarge,
            child: Padding(
              padding: EdgeInsets.all(m3e.spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_reset, size: 56, color: cs.primary),
                  SizedBox(height: m3e.spacing.md),
                  Text('首次登录，请修改密码', style: m3e.typography.headlineSmall),
                  SizedBox(height: m3e.spacing.lg),
                  TextField(
                    controller: _oldCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '初始密码',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: m3e.spacing.md),
                  TextField(
                    controller: _newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '新密码',
                      prefixIcon: Icon(Icons.lock_open),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: m3e.spacing.md),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '确认新密码',
                      prefixIcon: Icon(Icons.lock_open),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: m3e.spacing.sm),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                  SizedBox(height: m3e.spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('修改密码'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
