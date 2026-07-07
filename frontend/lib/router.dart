import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/providers.dart';
import 'pages/admin/admin_login_page.dart';
import 'pages/admin/admin_home_page.dart';
import 'pages/admin/admin_settings_page.dart';
import 'pages/admin/admin_student_list_page.dart';
import 'pages/admin/admin_group_list_page.dart';
import 'pages/admin/admin_task_assign_page.dart';
import 'pages/admin/task_detail_page.dart';
import 'pages/admin/form_field_edit_page.dart';
import 'pages/student/student_login_page.dart';
import 'pages/student/student_change_password_page.dart';
import 'pages/student/student_task_select_page.dart';
import 'pages/student/student_fill_page.dart';
import 'theme/m3e_theme.dart';

/// 全局 GoRouter Provider：只创建一次，避免每次 build 重建导致路由状态丢失。
/// redirect 内部实时 ref.read(authProvider)，确保登录状态变化后能正确放行。
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      // 实时读取最新认证状态，不使用构建期快照
      final auth = ref.read(authProvider);
      final loggedIn = auth.isLoggedIn;
      final isAdmin = auth.isAdmin;
      final path = state.uri.path;

      // 学生端入口固定路径，不做权限拦截
      if (path.startsWith('/s/')) return null;

      if (path == '/admin/login') {
        return (loggedIn && isAdmin) ? '/admin' : null;
      }
      if (path.startsWith('/admin') && !(loggedIn && isAdmin)) {
        return '/admin/login';
      }
      if (path == '/' && loggedIn) {
        return isAdmin ? '/admin' : '/student/tasks';
      }
      // 学生已登录但访问登录页，重定向到任务选择
      if (path == '/s/login' && loggedIn && !isAdmin) {
        return '/student/tasks';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const _EntryPage()),
      GoRoute(path: '/admin/login', builder: (c, s) => const AdminLoginPage()),
      GoRoute(path: '/admin', builder: (c, s) => const AdminHomePage()),
      GoRoute(path: '/admin/settings', builder: (c, s) => const AdminSettingsPage()),
      GoRoute(path: '/admin/students', builder: (c, s) => const AdminStudentListPage()),
      GoRoute(path: '/admin/groups', builder: (c, s) => const AdminGroupListPage()),
      GoRoute(path: '/admin/tasks/:id/assign', builder: (c, s) {
        final id = int.parse(s.pathParameters['id']!);
        return AdminTaskAssignPage(taskId: id);
      }),
      GoRoute(path: '/admin/tasks/:id', builder: (c, s) {
        final id = int.parse(s.pathParameters['id']!);
        return TaskDetailPage(taskId: id);
      }),
      GoRoute(path: '/admin/tasks/:id/fields', builder: (c, s) {
        final id = int.parse(s.pathParameters['id']!);
        return FormFieldEditPage(taskId: id);
      }),
      GoRoute(path: '/s/login', builder: (c, s) => const StudentLoginPage()),
      GoRoute(path: '/student/change-password', builder: (c, s) => const StudentChangePasswordPage()),
      GoRoute(path: '/student/tasks', builder: (c, s) => const StudentTaskSelectPage()),
      GoRoute(path: '/student/fill/:taskId', builder: (c, s) {
        final taskId = int.parse(s.pathParameters['taskId']!);
        return StudentFillPage(taskId: taskId);
      }),
    ],
  );
});

/// 监听 authProvider 变化，在登录/登出时触发 GoRouter 重新执行 redirect
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// 入口页：选择管理员入口或学生入口
class _EntryPage extends ConsumerWidget {
  const _EntryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: EdgeInsets.all(m3e.spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups, size: 72, color: cs.primary),
                SizedBox(height: m3e.spacing.md),
                Text('班级信息收集系统',
                    style: m3e.typography.headlineSmall),
                SizedBox(height: m3e.spacing.sm),
                Text('轻量级 · 免运维 · Material 3 Expressive',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                SizedBox(height: m3e.spacing.xl),
                FilledButton.icon(
                  onPressed: () => context.go('/admin/login'),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('管理员入口'),
                ),
                SizedBox(height: m3e.spacing.sm),
                OutlinedButton.icon(
                  onPressed: () => context.go('/s/login'),
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('学生填报入口'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
