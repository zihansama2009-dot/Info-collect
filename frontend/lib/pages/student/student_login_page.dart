import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../theme/m3e_theme.dart';

class StudentLoginPage extends ConsumerStatefulWidget {
  const StudentLoginPage({super.key});

  @override
  ConsumerState<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends ConsumerState<StudentLoginPage> {
  final _noCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).loginStudent(
            _noCtrl.text.trim(),
            _passCtrl.text,
          );
      if (mounted) {
        final mustChange = await ref.read(mustChangePasswordProvider.future);
        if (mustChange) {
          context.go('/student/change-password');
        } else {
          context.go('/student/tasks');
        }
      }
    } catch (_) {
      setState(() => _error = '学号或密码错误');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    return Scaffold(
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
                  Icon(Icons.how_to_reg, size: 56, color: cs.primary),
                  SizedBox(height: m3e.spacing.sm),
                  Text('学生填报登录', style: m3e.typography.headlineSmall),
                  SizedBox(height: m3e.spacing.lg),
                  TextField(
                    controller: _noCtrl,
                    decoration: const InputDecoration(
                      labelText: '学号',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: m3e.spacing.md),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: m3e.spacing.sm),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                  SizedBox(height: m3e.spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('登录并填报'),
                    ),
                  ),
                  SizedBox(height: m3e.spacing.sm),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('返回首页'),
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
