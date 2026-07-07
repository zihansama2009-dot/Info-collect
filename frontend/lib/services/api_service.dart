import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_io.dart' if (dart.library.html) 'web_io_web.dart';

class ApiService {
  static late final ApiService instance = ApiService._();
  ApiService._();

  // 非 final：init() 可能被多次调用（如登出后重新初始化）
  late Dio dio;

  /// Web 端同源部署留空；APK 指向远端 API
  String baseUrl = kIsWeb ? '' : 'https://info.mczihan.link:1443';

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

  Future<Map<String, dynamic>> studentLogin(
          int taskId, String studentNo, String password) =>
      _post('/api/student/login', {
        'task_id': taskId,
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

  // ===== 学生名单 =====
  Future<List<dynamic>> listStudents(int taskId) async =>
      (await dio.get('/api/admin/tasks/$taskId/students')).data;

  Future<void> importStudentsWeb(int taskId, List<int> bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await dio.post('/api/admin/tasks/$taskId/students/import', data: form);
  }

  Future<void> resetStudentPassword(int sid, String pwd) async =>
      dio.put('/api/admin/students/$sid/password', data: {'password': pwd});

  Future<void> deleteStudent(int sid) async =>
      dio.delete('/api/admin/students/$sid');

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
