// 非 Web 平台的 stub 实现（学生端 APK 不需要文件操作）
// Web 平台编译时会被 web_io_web.dart 替代（通过条件导入）

void downloadFile(String url) {}

Future<List<int>?> pickFileBytes() async => null;
