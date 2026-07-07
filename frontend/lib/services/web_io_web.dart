// Web 平台实现（dart:html），通过条件导入仅在 Web 编译时引入
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

void downloadFile(String url) {
  html.AnchorElement(href: url)
    ..setAttribute('download', '班级数据.xlsx')
    ..style.display = 'none'
    ..click();
}

Future<List<int>?> pickFileBytes() async {
  final upload = html.FileUploadInputElement()..accept = '.xlsx,.xls';
  upload.click();
  final completer = Completer<List<int>?>();
  upload.onChange.listen((_) {
    if (upload.files!.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = upload.files!.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      completer.complete(Uint8List.fromList(reader.result as List<int>));
    });
    reader.readAsArrayBuffer(file);
  });
  return completer.future;
}
