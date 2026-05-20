import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import 'face_id_photo_crop_page.dart';
import 'face_image_picker.dart';

/// 打开证件照裁切页，返回标准尺寸 JPEG。
Future<FaceCapturedPhoto?> openFaceIdPhotoCropFlow(
  BuildContext context, {
  required Uint8List sourceBytes,
  required String sourceName,
  String title = '调整证件照',
  String hint = '拖动或双指缩放图片，将面部对准框内后点击确认',
}) {
  final scale = DashboardScaleScope.of(context);
  return Navigator.of(context).push<FaceCapturedPhoto>(
    MaterialPageRoute<FaceCapturedPhoto>(
      fullscreenDialog: true,
      builder: (ctx) => DashboardScaleScope(
        data: scale,
        child: FaceIdPhotoCropPage(
          sourceBytes: sourceBytes,
          sourceName: sourceName,
          title: title,
          hint: hint,
        ),
      ),
    ),
  );
}
