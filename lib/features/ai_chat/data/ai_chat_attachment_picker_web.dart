// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<({Uint8List bytes, String filename, int size})?>
pickAiChatAttachmentFileImpl() async {
  final input = html.FileUploadInputElement()
    ..accept =
        'image/*,audio/*,video/*,.pdf,.txt,.doc,.docx,.ppt,.pptx,.xls,.xlsx'
    ..multiple = false;

  final completer =
      Completer<({Uint8List bytes, String filename, int size})?>();

  void cleanup() {
    input.remove();
  }

  input.onChange.first.then((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
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
      completer.complete(
        bytes == null
            ? null
            : (bytes: bytes, filename: file.name, size: file.size),
      );
    }
  });

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
