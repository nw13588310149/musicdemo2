// 沿用项目其它 _web.dart 文件的 dart:html 用法（face_image_picker_web /
// courseware_file_picker_web 等），故抑制 `avoid_web_libraries_in_flutter`
// 与 `deprecated_member_use`（`dart:html` 已被官方标记 deprecated）。
//
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'qr_image_saver.dart';

/// Web 端走 [html.AnchorElement] + Blob URL 触发浏览器原生下载，下载文件名
/// 沿用 `suggestedName`。下载本身是异步触发，无法精确感知用户是否真的选了
/// 「保存」，所以只要 anchor 触发成功就视为 OK。
Future<QrSaveResult> saveQrImageBytesImpl({
  required Uint8List bytes,
  required String suggestedName,
}) async {
  try {
    final blob = html.Blob(<dynamic>[bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = suggestedName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    // 下一帧后回收 Blob URL，给浏览器触发下载留出时间窗。
    Timer(const Duration(seconds: 5), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });
    return QrSaveResult(ok: true, path: suggestedName);
  } catch (e) {
    return QrSaveResult(ok: false, error: '下载失败：$e');
  }
}
