import 'dart:typed_data';

// 条件导入：web 走 dart:html 触发浏览器下载，桌面/移动走 file_picker.saveFile
// + dart:io。两端共用相同的 [saveQrImageBytes] 入口。
import 'qr_image_saver_io.dart'
    if (dart.library.html) 'qr_image_saver_web.dart';

/// 「保存到相册」结果：
/// - `ok = true` 表示保存成功，`path` 在桌面端是用户选择的路径，web 端为
///   下载文件名（仅展示用）。
/// - `ok = false` 且 `cancelled = true` 表示用户主动取消（如取消文件选择），
///   不应显示错误 toast。
/// - 其余情况 `error` 给出简短中文提示。
class QrSaveResult {
  const QrSaveResult({
    required this.ok,
    this.cancelled = false,
    this.path,
    this.error,
  });

  final bool ok;
  final bool cancelled;
  final String? path;
  final String? error;

  static const QrSaveResult cancelledByUser = QrSaveResult(
    ok: false,
    cancelled: true,
  );
}

/// 把 `bytes`（PNG / JPG 任一格式都可）保存到设备：
/// - web：触发浏览器下载，`suggestedName` 作为文件名（默认 `qrcode.png`）。
/// - 桌面：弹出系统保存对话框，用户选目录后写入 bytes。
/// - 移动：当前未接入相册保存包，返回错误，由调用方退化为 toast 提示。
Future<QrSaveResult> saveQrImageBytes({
  required Uint8List bytes,
  String suggestedName = 'qrcode.png',
}) {
  return saveQrImageBytesImpl(bytes: bytes, suggestedName: suggestedName);
}
