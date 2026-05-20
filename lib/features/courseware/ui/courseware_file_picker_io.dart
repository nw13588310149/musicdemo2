import 'package:file_picker/file_picker.dart';

import 'courseware_file_picker.dart';

Future<List<CoursewarePickedFile>> pickCoursewareFilesImpl({
  required bool allowMultiple,
  CoursewarePickType type = CoursewarePickType.any,
}) async {
  // FilePicker 的 FileType.image / audio 在 iOS / Android 上会直接走系统的
  // 相册 / 音频选择器；在桌面（Win / macOS / Linux）上则只是过滤可选
  // 扩展名 —— 两端语义都更贴近"上传图片/音频"的真实意图。
  final platformType = switch (type) {
    CoursewarePickType.image => FileType.image,
    CoursewarePickType.audio => FileType.audio,
    CoursewarePickType.any => FileType.any,
  };
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    type: platformType,
    withData: false,
  );
  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) {
    return const <CoursewarePickedFile>[];
  }
  return files
      .where((f) => f.path != null && f.path!.isNotEmpty)
      .map(
        (f) => CoursewarePickedFile(name: f.name, path: f.path, size: f.size),
      )
      .toList();
}
