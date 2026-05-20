import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 桌面 / 移动 IO 端的头像选择实现：通过 `file_picker` 让用户从本地文件系统
/// 中挑选一张图片。
///
/// - [useCamera]：本实现暂未集成原生 `image_picker`，桌面端没有"相机"概念，
///   该参数当前被忽略；调用方在 IO 平台不支持相机时应自行做兜底提示。
Future<({Uint8List bytes, String filename})?> pickAvatarFileImpl({
  bool useCamera = false,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) {
    return null;
  }
  return (bytes: bytes, filename: file.name);
}
