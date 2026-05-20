import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'face_id_photo_spec.dart';

/// 将 [InteractiveViewer] 中的原图按取景框裁切并缩放到标准证件照尺寸。
Uint8List? cropFaceIdPhotoFromViewport({
  required Uint8List sourceBytes,
  required Rect frameInViewport,
  required Matrix4 imageToViewport,
}) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;

  final oriented = img.bakeOrientation(decoded);
  final inverse = Matrix4.inverted(imageToViewport);

  final topLeft = MatrixUtils.transformPoint(inverse, frameInViewport.topLeft);
  final bottomRight =
      MatrixUtils.transformPoint(inverse, frameInViewport.bottomRight);

  var x = topLeft.dx.round();
  var y = topLeft.dy.round();
  var w = (bottomRight.dx - topLeft.dx).round();
  var h = (bottomRight.dy - topLeft.dy).round();

  x = x.clamp(0, oriented.width - 1);
  y = y.clamp(0, oriented.height - 1);
  w = w.clamp(1, oriented.width - x);
  h = h.clamp(1, oriented.height - y);

  return _encodeStandardIdPhoto(
    img.copyCrop(oriented, x: x, y: y, width: w, height: h),
  );
}

/// 将相机原图按预览 [BoxFit.cover] 规则映射后，裁切取景框区域并缩放到标准证件照尺寸。
Uint8List? cropFaceIdPhoto({
  required Uint8List sourceBytes,
  required Rect frameInPreview,
  required Size previewSize,
}) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;

  final oriented = img.bakeOrientation(decoded);
  final iw = oriented.width.toDouble();
  final ih = oriented.height.toDouble();
  final W = previewSize.width;
  final H = previewSize.height;

  final scale = math.max(W / iw, H / ih);
  final offsetX = (W - iw * scale) / 2;
  final offsetY = (H - ih * scale) / 2;

  var x = ((frameInPreview.left - offsetX) / scale).round();
  var y = ((frameInPreview.top - offsetY) / scale).round();
  var w = (frameInPreview.width / scale).round();
  var h = (frameInPreview.height / scale).round();

  x = x.clamp(0, oriented.width - 1);
  y = y.clamp(0, oriented.height - 1);
  w = w.clamp(1, oriented.width - x);
  h = h.clamp(1, oriented.height - y);

  return _encodeStandardIdPhoto(
    img.copyCrop(oriented, x: x, y: y, width: w, height: h),
  );
}

Uint8List? _encodeStandardIdPhoto(img.Image cropped) {
  final resized = img.copyResize(
    cropped,
    width: FaceIdPhotoSpec.outputWidth,
    height: FaceIdPhotoSpec.outputHeight,
    interpolation: img.Interpolation.cubic,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
}

/// 初始变换：原图像素坐标 → 视口坐标，[BoxFit.cover] 居中铺满。
Matrix4 faceIdPhotoCoverTransform({
  required Size imageSize,
  required Size viewportSize,
}) {
  final scale = faceIdPhotoCoverScale(
    imageSize: imageSize,
    viewportSize: viewportSize,
  );
  return faceIdPhotoTransformFromGesture(
    imageSize: imageSize,
    viewportSize: viewportSize,
    scale: scale,
    offset: Offset.zero,
  );
}

double faceIdPhotoCoverScale({
  required Size imageSize,
  required Size viewportSize,
}) {
  return math.max(
    viewportSize.width / imageSize.width,
    viewportSize.height / imageSize.height,
  );
}

/// 平移 + 缩放：图片像素坐标 → 裁切视口坐标（与裁切页手势一致）。
Matrix4 faceIdPhotoTransformFromGesture({
  required Size imageSize,
  required Size viewportSize,
  required double scale,
  required Offset offset,
}) {
  final cx = viewportSize.width / 2 + offset.dx;
  final cy = viewportSize.height / 2 + offset.dy;
  final ix = imageSize.width / 2;
  final iy = imageSize.height / 2;
  return Matrix4.identity()
    ..translateByDouble(cx, cy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-ix, -iy, 0, 1);
}
