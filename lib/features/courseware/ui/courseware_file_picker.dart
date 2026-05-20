import 'dart:typed_data';

import 'courseware_file_picker_io.dart'
    if (dart.library.html) 'courseware_file_picker_web.dart';

/// 文件选择类型，用于在弹出系统选择器时按场景过滤：
/// - [any]   ：任意文件，默认行为；
/// - [image] ：图片资源 —— Web 走 `accept="image/*"`、IO 走
///   `FilePicker.FileType.image`，移动端通常会直接拉起系统相册；
/// - [audio] ：音频资源 —— Web `accept="audio/*"`、IO `FileType.audio`。
enum CoursewarePickType { any, image, audio }

/// Picked file data.
class CoursewarePickedFile {
  const CoursewarePickedFile({
    required this.name,
    this.bytes,
    this.path,
    this.size,
  });

  final String name;
  final Uint8List? bytes;
  final String? path;
  final int? size;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
  bool get hasPath => path != null && path!.isNotEmpty;
  bool get canUpload => hasBytes || hasPath;
}

/// Picks files and returns filename + either bytes (web) or a local path (native).
///
/// - [allowMultiple]：是否允许多选（仅在 web / 图片选择上有意义）。
/// - [type]：限定可选文件类型。默认 [CoursewarePickType.any] —— 等价
///   于历史行为；显式传 [CoursewarePickType.image] 时移动端会直接进相册。
Future<List<CoursewarePickedFile>> pickCoursewareFiles({
  required bool allowMultiple,
  CoursewarePickType type = CoursewarePickType.any,
}) {
  return pickCoursewareFilesImpl(allowMultiple: allowMultiple, type: type);
}
