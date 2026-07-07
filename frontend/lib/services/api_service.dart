import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_io.dart' if (dart.library.html) 'web_io_web.dart';

class ApiService {
  static late final ApiService instance = ApiService._();
  ApiService._();

  // 非 final：init() 可能被多次调用（如登出后重新初始化）
  late Dio dio;

  /// Web 端同源部署留空；APK 通过 dart-define 注入后端地址
  String baseUrl = const String.fromEnvironment('BACKEND_URL', defaultValue: kIsWeb ? '' : 'https://info.mczihan.link:1443');

  void init({String? token}) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
    dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
  }

  void setToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ===== 认证 =====
  Future<Map<String, dynamic>> adminLogin(String username, String password) =>
      _post('/api/admin/login', {
        'username': username,
        'password': password,
      });

  Future<Map<String, dynamic>> studentLogin(String studentNo, String password) =>
      _post('/api/student/login', {
        'student_no': studentNo,
        'password': password,
      });

  Future<Map<String, dynamic>> getAdminInfo() => _get('/api/admin/me');

  Future<Map<String, dynamic>> changeAdminUsername(String newUsername) =>
      _put('/api/admin/username', {'new_username': newUsername});

  Future<Map<String, dynamic>> changeAdminPassword(String oldPassword, String newPassword) =>
      _put('/api/admin/password', {'old_password': oldPassword, 'new_password': newPassword});

  Future<Map<String, dynamic>> getVersion() => _get('/api/admin/version');

  // ===== 任务 =====
  Future<List<dynamic>> listTasks() async => (await dio.get('/api/admin/tasks')).data;

  Future<Map<String, dynamic>> createTask(String title, String desc) =>
      _post('/api/admin/tasks', {'title': title, 'description': desc});

  Future<Map<String, dynamic>> updateTask(int id, Map<String, dynamic> body) =>
      _put('/api/admin/tasks/$id', body);

  Future<void> deleteTask(int id) async => dio.delete('/api/admin/tasks/$id');

  Future<Map<String, dynamic>> taskStats(int id) async =>
      (await dio.get('/api/admin/tasks/$id/stats')).data;

  // ===== 表单字段 =====
  Future<List<dynamic>> listFields(int taskId) async =>
      (await dio.get('/api/admin/tasks/$taskId/fields')).data;

  Future<List<dynamic>> saveFields(int taskId, List<Map<String, dynamic>> fields) async =>
      (await dio.put('/api/admin/tasks/$taskId/fields', data: fields)).data;

  Future<Map<String, dynamic>> getFormConfig(int taskId) async =>
      (await dio.get('/api/student/tasks/$taskId/config')).data;

  // ===== 学生管理（管理员）=====
  Future<List<dynamic>> listStudents() async => (await dio.get('/api/admin/students')).data;

  Future<Map<String, dynamic>> createStudent(String studentNo, String name, String password) =>
      _post('/api/admin/students', {'student_no': studentNo, 'name': name, 'password': password});

  Future<void> resetStudentPassword(int userId, String password) async =>
      dio.put('/api/admin/students/$userId/password', data: {'password': password});

  Future<void> deleteStudent(int userId) async =>
      dio.delete('/api/admin/students/$userId');

  Future<Map<String, dynamic>> importStudents(List<int> bytes, {String defaultPassword = ''}) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: 'students.xlsx'),
    });
    final path = defaultPassword.isEmpty
        ? '/api/admin/students/import'
        : '/api/admin/students/import?default_password=${Uri.encodeQueryComponent(defaultPassword)}';
    return Map<String, dynamic>.from((await dio.post(path, data: form)).data);
  }

  // ===== 组管理（管理员）=====
  Future<List<dynamic>> listGroups() async => (await dio.get('/api/admin/groups')).data;

  Future<Map<String, dynamic>> createGroup(String name, String description) =>
      _post('/api/admin/groups', {'name': name, 'description': description});

  Future<Map<String, dynamic>> updateGroup(int groupId, String name, String description) =>
      _put('/api/admin/groups/$groupId', {'name': name, 'description': description});

  Future<void> deleteGroup(int groupId) async =>
      dio.delete('/api/admin/groups/$groupId');

  Future<void> addGroupMember(int groupId, int userId) async =>
      dio.post('/api/admin/groups/$groupId/members', data: {'student_user_id': userId});

  Future<void> removeGroupMember(int groupId, int userId) async =>
      dio.delete('/api/admin/groups/$groupId/members/$userId');

  Future<List<dynamic>> listGroupMembers(int groupId) async =>
      (await dio.get('/api/admin/groups/$groupId/members')).data;

  // ===== 任务分配（管理员）=====
  Future<void> assignUsersToTask(int taskId, List<int> userIds) async =>
      dio.post('/api/admin/tasks/$taskId/assign/users', data: {'user_ids': userIds});

  Future<void> assignGroupsToTask(int taskId, List<int> groupIds) async =>
      dio.post('/api/admin/tasks/$taskId/assign/groups', data: {'group_ids': groupIds});

  Future<Map<String, dynamic>> getTaskAssignments(int taskId) async =>
      _get('/api/admin/tasks/$taskId/assignments');

  Future<Map<String, dynamic>> getAvailableTasks() async =>
      _get('/api/student/tasks/available');

  // ===== 学生密码修改=====
  Future<void> changeStudentPassword(String oldPassword, String newPassword) =>
      _put('/api/student/password', {'old_password': oldPassword, 'new_password': newPassword});

  // ===== 提交 =====
  Future<List<dynamic>> listSubmissions(int taskId) async =>
      (await dio.get('/api/admin/tasks/$taskId/submissions')).data;

  Future<Map<String, dynamic>> getMySubmission() async =>
      (await dio.get('/api/student/submission')).data;

  Future<void> submitForm(Map<String, dynamic> data) async =>
      dio.post('/api/student/submit', data: data);

  // ===== 导出（Web 端触发浏览器下载，APK 端为空操作）=====
  void triggerExcelDownload(int taskId) {
    final token = dio.options.headers['Authorization']?.toString().replaceFirst('Bearer ', '') ?? '';
    downloadFile('$baseUrl/api/admin/tasks/$taskId/export?token=$token');
  }

  // ===== 内部方法 =====
  Future<Map<String, dynamic>> _get(String path) async =>
      Map<String, dynamic>.from((await dio.get(path)).data);

  Future<Map<String, dynamic>> _post(String path, dynamic data) async =>
      Map<String, dynamic>.from((await dio.post(path, data: data)).data);

  Future<Map<String, dynamic>> _put(String path, dynamic data) async =>
      Map<String, dynamic>.from((await dio.put(path, data: data)).data);
}
