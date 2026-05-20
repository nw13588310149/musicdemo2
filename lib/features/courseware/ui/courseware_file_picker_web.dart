// Web-only implementation (dart:html).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'courseware_file_picker.dart';

/// Web 端文件读取硬上限（1GB）。
///
/// 浏览器 `FileReader.readAsArrayBuffer` 必须把整文件一次性读入内存，
/// 体积过大会让 iPad / iPhone 上的 Safari Tab 进程被系统直接杀掉，
/// 用户感知就是「APP 闪退」。这里在源头拒绝过大文件，并由调用方
/// （`_UploadDialog._pick` / `_pickScoreAudio`）的体积校验逻辑
/// 兜住相同的语义。
///
/// 与上传对话框 `_kMaxFileBytes` 保持一致 —— 课件 / 音频允许到 1GB；
/// 真正撑爆浏览器内存的极端大文件仍然会被拦下来，避免标签页被
/// 系统 SIGKILL。
const int _kWebMaxBytes = 1024 * 1024 * 1024;

Future<List<CoursewarePickedFile>> pickCoursewareFilesImpl({
  required bool allowMultiple,
  CoursewarePickType type = CoursewarePickType.any,
}) {
  // accept 用于约束系统选择器只显示对应类型，并在移动浏览器上让
  // image/audio 直接拉起相册 / 录音器，避免再走"文件管理"。
  final accept = switch (type) {
    CoursewarePickType.image => 'image/*',
    CoursewarePickType.audio => 'audio/*',
    CoursewarePickType.any => '*/*',
  };
  final input = html.FileUploadInputElement()
    ..multiple = allowMultiple
    ..accept = accept
    ..style.display = 'none';

  // 部分浏览器要求 input 在 DOM 中才能触发文件选择 / FileReader 才能稳定工作。
  html.document.body?.append(input);

  final completer = Completer<List<CoursewarePickedFile>>();

  void cleanup() {
    try {
      input.remove();
    } catch (_) {}
  }

  void completeWith(List<CoursewarePickedFile> files) {
    if (!completer.isCompleted) {
      completer.complete(files);
    }
    cleanup();
  }

  input.onChange.listen((_) async {
    final fileList = input.files;
    if (fileList == null || fileList.isEmpty) {
      completeWith(const <CoursewarePickedFile>[]);
      return;
    }

    final result = <CoursewarePickedFile>[];
    for (final file in fileList) {
      // 体积过大的文件直接以 size-only 形式返回（bytes 留空）。
      // 调用方 `_UploadDialog` 会基于 size 弹出"超出上限"提示并跳过。
      // 不在这里读字节是关键：100MB+ 文件再走 readAsArrayBuffer
      // 直接会让 Safari 标签页被 OS kill 掉。
      if (file.size > _kWebMaxBytes) {
        result.add(CoursewarePickedFile(name: file.name, size: file.size));
        continue;
      }
      Uint8List? bytes;
      try {
        bytes = await _readFileBytes(file);
      } catch (_) {
        bytes = null;
      }
      if (bytes == null || bytes.isEmpty) {
        // 也保留一个 size-only 条目，方便上层提示「读取失败」。
        result.add(CoursewarePickedFile(name: file.name, size: file.size));
        continue;
      }
      result.add(
        CoursewarePickedFile(name: file.name, bytes: bytes, size: file.size),
      );
    }
    completeWith(result);
  });

  // 取消选择时（点击 cancel）大部分浏览器只触发 'cancel' 事件，
  // 不会触发 onChange — 这里也兜底一下。
  input.addEventListener('cancel', (_) {
    completeWith(const <CoursewarePickedFile>[]);
  });

  // 必须由用户手势同步触发。
  input.click();

  return completer.future;
}

Future<Uint8List?> _readFileBytes(html.File file) {
  final completer = Completer<Uint8List?>();
  final reader = html.FileReader();

  reader.onLoadEnd.first.then((_) {
    final data = reader.result;
    if (data == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    // dart:html 在不同浏览器里 result 的具体类型可能是 ByteBuffer / TypedData / List<int>。
    // 全部尝试一遍，最大限度拿到 Uint8List。
    if (data is ByteBuffer) {
      if (!completer.isCompleted) completer.complete(data.asUint8List());
      return;
    }
    if (data is TypedData) {
      if (!completer.isCompleted) {
        completer.complete(
          Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes),
        );
      }
      return;
    }
    if (data is List<int>) {
      if (!completer.isCompleted) completer.complete(Uint8List.fromList(data));
      return;
    }
    if (!completer.isCompleted) completer.complete(null);
  });

  reader.onError.first.then((_) {
    if (!completer.isCompleted) completer.complete(null);
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}
