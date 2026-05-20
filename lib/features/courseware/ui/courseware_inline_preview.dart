// 通用文件内嵌预览组件入口。
//
// Web 端会根据后缀自动选择 `<img>` / `<iframe>` / `<audio>` / `<video>` /
// Office Online 嵌入等方式直接在页面内渲染；非 web 平台返回占位提示。
export 'courseware_inline_preview_io.dart'
    if (dart.library.html) 'courseware_inline_preview_web.dart';
