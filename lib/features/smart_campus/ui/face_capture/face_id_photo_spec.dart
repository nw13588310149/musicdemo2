import 'dart:ui';

/// 中国标准一寸证件照比例（25mm × 35mm → 295px × 413px @300dpi）。
abstract final class FaceIdPhotoSpec {
  static const double frameAspectWidth = 295;
  static const double frameAspectHeight = 413;

  static const int outputWidth = 590;
  static const int outputHeight = 826;

  static double get frameAspectRatio => frameAspectWidth / frameAspectHeight;

  /// 在预览区域内居中放置证件照取景框。
  static Rect frameRectInPreview(Size previewSize) {
    const aspect = frameAspectWidth / frameAspectHeight;
    final maxH = previewSize.height * 0.86;
    final maxW = previewSize.width * 0.52;
    var h = maxH;
    var w = h * aspect;
    if (w > maxW) {
      w = maxW;
      h = w / aspect;
    }
    return Rect.fromLTWH(
      (previewSize.width - w) / 2,
      (previewSize.height - h) / 2,
      w,
      h,
    );
  }
}
