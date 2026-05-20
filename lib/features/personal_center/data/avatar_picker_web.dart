// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<({Uint8List bytes, String filename})?> pickAvatarFileImpl({
  bool useCamera = false,
}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;
  // capture="environment" 在移动浏览器上会拉起系统相机（指向后置摄像头）；
  // 桌面浏览器若硬件不支持会自动退化为常规文件选择。
  if (useCamera) {
    input.setAttribute('capture', 'environment');
  }

  final completer = Completer<({Uint8List bytes, String filename})?>();

  void cleanup() {
    input.remove();
  }

  input.onChange.first.then((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    Uint8List? bytes;
    if (result is ByteBuffer) {
      bytes = Uint8List.view(result);
    } else if (result is List<int>) {
      bytes = Uint8List.fromList(result);
    }
    cleanup();
    if (!completer.isCompleted) {
      if (bytes == null) {
        completer.complete(null);
      } else {
        completer.complete((bytes: bytes, filename: file.name));
      }
    }
  });

  // 当窗口失焦后再次聚焦时，如果用户没有选择文件，主动结束等待，避免 Future 永不返回。
  late StreamSubscription<html.Event> focusSub;
  focusSub = html.window.onFocus.listen((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!completer.isCompleted) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        cleanup();
        completer.complete(null);
      }
    }
    await focusSub.cancel();
  });

  html.document.body?.append(input);
  input.click();

  return completer.future;
}
