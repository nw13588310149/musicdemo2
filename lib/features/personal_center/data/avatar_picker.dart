import 'dart:typed_data';

import 'avatar_picker_stub.dart'
    if (dart.library.html) 'avatar_picker_web.dart'
    if (dart.library.io) 'avatar_picker_io.dart';

/// 选择本地图片文件，返回字节流和文件名；用户取消或当前平台不支持时返回 null。
///
/// - [useCamera]：是否优先打开摄像头。
///   * web：将 `<input type="file">` 的 `capture` 属性置为 `environment`，
///     在移动浏览器上会拉起系统相机；桌面浏览器没有相机时退化成文件选择器。
///   * 桌面 / 移动 IO：当前未集成原生 `image_picker`，无论 [useCamera] 取何值，
///     都通过 `file_picker` 选择图片文件；调用方应自行兜底提示。
Future<({Uint8List bytes, String filename})?> pickAvatarFile({
  bool useCamera = false,
}) => pickAvatarFileImpl(useCamera: useCamera);
