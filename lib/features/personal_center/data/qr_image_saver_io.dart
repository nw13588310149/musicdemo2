import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'qr_image_saver.dart';

/// 桌面（Windows / macOS / Linux）走 `FilePicker.platform.saveFile` 让用户挑
/// 一个保存路径，再用 dart:io 写入字节。移动端 `FilePicker.saveFile` 在多数
/// 平台未实现，返回 null 时退化为「未保存」错误，由调用方提示用户。
Future<QrSaveResult> saveQrImageBytesImpl({
  required Uint8List bytes,
  required String suggestedName,
}) async {
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '保存到相册',
      fileName: suggestedName,
      type: FileType.image,
    );
    if (path == null || path.isEmpty) {
      return QrSaveResult.cancelledByUser;
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return QrSaveResult(ok: true, path: path);
  } on UnimplementedError {
    return const QrSaveResult(
      ok: false,
      error: '当前平台暂不支持保存到相册，请截屏保存',
    );
  } catch (e) {
    return QrSaveResult(ok: false, error: '保存失败：$e');
  }
}
