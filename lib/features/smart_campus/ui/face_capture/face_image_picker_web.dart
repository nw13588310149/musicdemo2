// Web 实现：上传照片走隐藏 <input type=file>，摄像头采集走 getUserMedia +
// HtmlElementView 包裹的 <video> 预览，配合 <canvas> 抓帧得到 JPEG 字节流。
//
// 这里沿用项目里已有的 dart:html + dart:ui_web 用法（参考
// `courseware/ui/courseware_file_picker_web.dart`、
// `courseware/ui/courseware_inline_preview_web.dart`），保证编译目标 / 行为
// 一致，不引入新依赖。
//
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import 'face_id_photo_flow.dart';
import 'face_image_picker.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

bool get isCameraCaptureSupportedImpl => true;

// ============================================================================
// 上传本地图片
// ============================================================================

Future<FaceCapturedPhoto?> pickFacePhotoFromFileImpl(BuildContext context) {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';
  // 部分浏览器要求 input 在 DOM 中才能稳定触发文件选择 / FileReader。
  html.document.body?.append(input);

  final completer = Completer<FaceCapturedPhoto?>();

  void cleanup() {
    try {
      input.remove();
    } catch (_) {}
  }

  void completeWith(FaceCapturedPhoto? f) {
    if (!completer.isCompleted) completer.complete(f);
    cleanup();
  }

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completeWith(null);
      return;
    }
    final file = files.first;
    final bytes = await _readBlobBytes(file);
    if (bytes == null || bytes.isEmpty) {
      completeWith(null);
      return;
    }
    if (!context.mounted) {
      completeWith(null);
      return;
    }
    final cropped = await openFaceIdPhotoCropFlow(
      context,
      sourceBytes: bytes,
      sourceName: file.name.isNotEmpty ? file.name : 'album.jpg',
    );
    completeWith(cropped);
  });

  // 取消按钮在大部分浏览器只触发 cancel，不会触发 onChange。
  input.addEventListener('cancel', (_) => completeWith(null));

  // 必须由用户手势同步触发，否则 Safari / Firefox 会拦截。
  input.click();

  return completer.future;
}

// ============================================================================
// 摄像头采集对话框
// ============================================================================

Future<FaceCapturedPhoto?> captureFacePhotoFromCameraImpl(
  BuildContext context,
) async {
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) {
    if (context.mounted) {
      AppToast.show(context, '当前浏览器不支持摄像头采集');
    }
    return null;
  }

  late html.MediaStream stream;
  try {
    stream = await mediaDevices.getUserMedia(<String, dynamic>{
      'video': <String, dynamic>{
        'facingMode': 'user',
        'width': <String, dynamic>{'ideal': 720},
        'height': <String, dynamic>{'ideal': 720},
      },
      'audio': false,
    });
  } catch (e) {
    if (context.mounted) {
      AppToast.show(context, '无法打开摄像头：${_friendlyError(e)}');
    }
    return null;
  }

  if (!context.mounted) {
    _stopStream(stream);
    return null;
  }

  final result = await showScaledDialog<FaceCapturedPhoto?>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (ctx) => _FaceCameraDialog(stream: stream),
  );

  _stopStream(stream);
  if (result == null || !context.mounted) return null;
  return openFaceIdPhotoCropFlow(
    context,
    sourceBytes: result.bytes,
    sourceName: result.name,
    title: '确认证件照',
    hint: '可拖动或缩放微调，将面部对准框内后确认',
  );
}

void _stopStream(html.MediaStream stream) {
  for (final t in stream.getTracks()) {
    try {
      t.stop();
    } catch (_) {}
  }
}

String _friendlyError(Object e) {
  final msg = e.toString();
  if (msg.contains('NotAllowedError') || msg.contains('PermissionDenied')) {
    return '已被浏览器拒绝授权';
  }
  if (msg.contains('NotFoundError') || msg.contains('DevicesNotFoundError')) {
    return '未检测到摄像头设备';
  }
  if (msg.contains('NotReadableError')) return '摄像头被其它程序占用';
  return msg;
}

class _FaceCameraDialog extends StatefulWidget {
  const _FaceCameraDialog({required this.stream});
  final html.MediaStream stream;

  @override
  State<_FaceCameraDialog> createState() => _FaceCameraDialogState();
}

class _FaceCameraDialogState extends State<_FaceCameraDialog> {
  late final String _viewType;
  late final html.VideoElement _video;
  Uint8List? _shotBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'face-camera-${DateTime.now().microsecondsSinceEpoch}';
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      // 自拍习惯：预览镜像，截图时也镜像绘制保持一致。
      ..style.transform = 'scaleX(-1)'
      ..srcObject = widget.stream;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _video,
    );
  }

  @override
  void dispose() {
    try {
      _video.srcObject = null;
      _video.pause();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final w = _video.videoWidth;
      final h = _video.videoHeight;
      if (w == 0 || h == 0) {
        AppToast.show(context, '摄像头画面尚未就绪，请稍候再试');
        if (mounted) setState(() => _busy = false);
        return;
      }
      final canvas = html.CanvasElement(width: w, height: h);
      final ctx2d = canvas.context2D
        ..translate(w.toDouble(), 0)
        ..scale(-1, 1)
        ..drawImage(_video, 0, 0);
      // 强行触发一次 setTransform 重置（稳健起见，部分浏览器实现细节）。
      ctx2d.setTransform(1, 0, 0, 1, 0, 0);
      final blob = await canvas.toBlob('image/jpeg', 0.92);
      final bytes = await _readBlobBytes(blob);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        AppToast.show(context, '拍摄失败，请重试');
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _shotBytes = bytes;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, '拍摄失败：$e');
      setState(() => _busy = false);
    }
  }

  void _retake() {
    setState(() => _shotBytes = null);
  }

  void _confirm() {
    final bytes = _shotBytes;
    if (bytes == null) return;
    final name = 'camera-${DateTime.now().millisecondsSinceEpoch}.jpg';
    Navigator.of(context).pop(
      FaceCapturedPhoto(bytes: bytes, name: name, mimeType: 'image/jpeg'),
    );
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasShot = _shotBytes != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: ui(32), vertical: ui(24)),
      child: Container(
        width: ui(540),
        padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '摄像头采集',
              style: TextStyle(
                fontSize: ui(18),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              '请正对摄像头，保持光线均匀，露出额头与双耳后点击「拍摄」。',
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF6D6B75),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.5,
              ),
            ),
            SizedBox(height: ui(16)),
            ClipRRect(
              borderRadius: BorderRadius.circular(ui(12)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  color: Colors.black,
                  child: hasShot
                      ? Image.memory(_shotBytes!, fit: BoxFit.cover)
                      : HtmlElementView(viewType: _viewType),
                ),
              ),
            ),
            SizedBox(height: ui(16)),
            if (!hasShot)
              AppDialogActionBar(
                cancelLabel: '取消',
                confirmLabel: _busy ? '拍摄中…' : '拍摄',
                confirmEnabled: !_busy,
                onCancel: _cancel,
                onConfirm: _capture,
              )
            else
              AppDialogActionBar(
                cancelLabel: '重拍',
                confirmLabel: '使用此照片',
                onCancel: _retake,
                onConfirm: _confirm,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FileReader 工具
// ============================================================================

Future<Uint8List?> _readBlobBytes(html.Blob? blob) {
  final completer = Completer<Uint8List?>();
  if (blob == null) {
    completer.complete(null);
    return completer.future;
  }
  final reader = html.FileReader();

  reader.onLoadEnd.first.then((_) {
    final data = reader.result;
    if (data == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
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

  reader.readAsArrayBuffer(blob);
  return completer.future;
}
