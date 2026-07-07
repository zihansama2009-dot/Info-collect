import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

/// 全局 API provider
final apiProvider = Provider<ApiService>((ref) => ApiService.instance);

/// 认证状态
class AuthState {
  final String? token;
  final String role; // admin / student
  final String? displayName;
  final int? taskId;
  const AuthState({this.token, this.role = '', this.displayName, this.taskId});

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
  bool get isLoggedIn => token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token');
    final role = sp.getString('role') ?? '';
    final name = sp.getString('name');
    final tid = sp.getInt('task_id');
    if (token != null) {
      ApiService.instance.init(token: token);
      state = AuthState(token: token, role: role, displayName: name, taskId: tid);
    } else {
      ApiService.instance.init();
    }
  }

  Future<void> loginAdmin(String username, String password) async {
    final res = await ApiService.instance.adminLogin(username, password);
    final token = res['token'] as String;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', token);
    await sp.setString('role', 'admin');
    await sp.setString('name', res['username'] as String);
    ApiService.instance.setToken(token);
    state = AuthState(token: token, role: 'admin', displayName: res['username'] as String);
  }

  Future<void> loginStudent(int taskId, String studentNo, String password) async {
    final res = await ApiService.instance.studentLogin(taskId, studentNo, password);
    final token = res['token'] as String;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', token);
    await sp.setString('role', 'student');
    await sp.setString('name', res['name'] as String);
    await sp.setInt('task_id', (res['task_id'] as num).toInt());
    ApiService.instance.setToken(token);
    state = AuthState(
      token: token,
      role: 'student',
      displayName: res['name'] as String,
      taskId: (res['task_id'] as num).toInt(),
    );
  }

  Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
    ApiService.instance.init();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

/// 当前选中的任务 ID（管理端）
final selectedTaskIdProvider = StateProvider<int?>((ref) => null);

/// 应用版本号
final versionProvider = FutureProvider<String>((ref) async {
  final api = ref.watch(apiProvider);
  final res = await api.getVersion();
  return res['version'] as String;
});

/// 当前管理员信息
final adminInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getAdminInfo();
});
