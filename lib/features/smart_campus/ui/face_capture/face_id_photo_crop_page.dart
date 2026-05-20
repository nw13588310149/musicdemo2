import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import 'face_id_frame_overlay.dart';
import 'face_id_photo_crop.dart';
import 'face_id_photo_spec.dart';
import 'face_image_picker.dart';

/// 证件照裁切页：相册选图 / 相机原图均经此页调整并输出标准尺寸。
class FaceIdPhotoCropPage extends StatefulWidget {
  const FaceIdPhotoCropPage({
    required this.sourceBytes,
    required this.sourceName,
    this.title = '调整证件照',
    this.hint = '拖动或双指缩放图片，将面部对准框内后点击确认',
    super.key,
  });

  final Uint8List sourceBytes;
  final String sourceName;
  final String title;
  final String hint;

  @override
  State<FaceIdPhotoCropPage> createState() => _FaceIdPhotoCropPageState();
}

class _FaceIdPhotoCropPageState extends State<FaceIdPhotoCropPage> {
  late final Uint8List _displayBytes;
  late final Size _imageSize;
  late final bool _decodeFailed;

  Size _viewportSize = Size.zero;
  Rect _frameRect = Rect.zero;
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _minScale = 0.2;
  double _maxScale = 8;

  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;

  bool _busy = false;
  bool _layoutReady = false;

  @override
  void initState() {
    super.initState();
    final decoded = img.decodeImage(widget.sourceBytes);
    if (decoded == null) {
      _decodeFailed = true;
      _displayBytes = widget.sourceBytes;
      _imageSize = Size.zero;
      return;
    }
    _decodeFailed = false;
    final oriented = img.bakeOrientation(decoded);
    _displayBytes = Uint8List.fromList(img.encodeJpg(oriented, quality: 92));
    _imageSize = Size(oriented.width.toDouble(), oriented.height.toDouble());
  }

  void _applyInitialTransform(Size viewport) {
    final cover = faceIdPhotoCoverScale(
      imageSize: _imageSize,
      viewportSize: viewport,
    );
    _scale = cover;
    _offset = Offset.zero;
    _minScale = cover * 0.35;
    _maxScale = cover * 6;
    _layoutReady = true;
  }

  void _onViewportSizeChanged(Size size) {
    if (_decodeFailed || size == _viewportSize) return;
    _viewportSize = size;
    _frameRect = FaceIdPhotoSpec.frameRectInPreview(size);
    if (!_layoutReady) {
      _applyInitialTransform(size);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_viewportSize == Size.zero) return;
    setState(() {
      _scale = (_gestureStartScale * details.scale).clamp(_minScale, _maxScale);
      _offset = _gestureStartOffset + details.focalPointDelta;
    });
  }

  Matrix4 get _imageToViewport => faceIdPhotoTransformFromGesture(
        imageSize: _imageSize,
        viewportSize: _viewportSize,
        scale: _scale,
        offset: _offset,
      );

  Future<void> _confirm() async {
    if (_busy || _frameRect == Rect.zero || _viewportSize == Size.zero) return;
    setState(() => _busy = true);
    try {
      final cropped = cropFaceIdPhotoFromViewport(
        sourceBytes: _displayBytes,
        frameInViewport: _frameRect,
        imageToViewport: _imageToViewport,
      );
      if (!mounted) return;
      if (cropped == null || cropped.isEmpty) {
        AppToast.show(context, '裁切失败，请重试');
        setState(() => _busy = false);
        return;
      }
      final ext = _outputExtension(widget.sourceName);
      final name = 'face-${DateTime.now().millisecondsSinceEpoch}$ext';
      Navigator.of(context).pop(
        FaceCapturedPhoto(bytes: cropped, name: name, mimeType: 'image/jpeg'),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, '裁切失败：$e');
      setState(() => _busy = false);
    }
  }

  static String _outputExtension(String sourceName) {
    final dot = sourceName.lastIndexOf('.');
    if (dot >= 0) return sourceName.substring(dot);
    return '.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: ui(24)),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(17),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(48)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(24)),
              child: Text(
                widget.hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(13),
                  color: Colors.white70,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui(12)),
                  child: _decodeFailed
                      ? const Center(
                          child: Text(
                            '无法读取图片，请换一张重试',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            if (size != _viewportSize) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() => _onViewportSizeChanged(size));
                              });
                            }
                            return _FaceIdCropViewport(
                              displayBytes: _displayBytes,
                              imageSize: _imageSize,
                              viewportSize: size.isEmpty ? Size.zero : size,
                              frameRect: _frameRect,
                              scale: _scale,
                              offset: _offset,
                              onScaleStart: _onScaleStart,
                              onScaleUpdate: _onScaleUpdate,
                            );
                          },
                        ),
                ),
              ),
            ),
            SizedBox(height: ui(16)),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(24), 0, ui(24), ui(20)),
              child: AppDialogActionBar(
                cancelLabel: '取消',
                confirmLabel: _busy ? '处理中…' : '确认裁切',
                confirmEnabled: !_busy && !_decodeFailed && _layoutReady,
                onCancel: _busy ? () {} : () => Navigator.of(context).pop(),
                onConfirm: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 裁切视口：居中缩放平移 + 证件照框（替代 InteractiveViewer，避免 iPad 大图错位）。
class _FaceIdCropViewport extends StatelessWidget {
  const _FaceIdCropViewport({
    required this.displayBytes,
    required this.imageSize,
    required this.viewportSize,
    required this.frameRect,
    required this.scale,
    required this.offset,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final Uint8List displayBytes;
  final Size imageSize;
  final Size viewportSize;
  final Rect frameRect;
  final double scale;
  final Offset offset;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    if (viewportSize == Size.zero || imageSize == Size.zero) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final drawW = imageSize.width * scale;
    final drawH = imageSize.height * scale;
    final left = viewportSize.width / 2 + offset.dx - drawW / 2;
    final top = viewportSize.height / 2 + offset.dy - drawH / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: onScaleStart,
      onScaleUpdate: onScaleUpdate,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: left,
            top: top,
            width: drawW,
            height: drawH,
            child: Image.memory(
              displayBytes,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: FaceIdFramePainter(
                frameRect: frameRect,
                previewSize: viewportSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
