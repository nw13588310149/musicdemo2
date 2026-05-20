// 平台分发：Web 用 iframe（避开 CORS、与 1.0 一致），原生用 pdfrx。
//
// 关键：必须用 `dart.library.html` 判断而不是 `dart.library.js_interop`。
// dart:js_interop 在 Dart 3 上是核心库，native/web 都"满足"该条件，
// 会导致 web 编译时仍然选中 native 实现（这正是之前 web 全屏按钮
// 点击没反应的根因——`tryFullscreenWebPdf` 命中了 native 的 stub）。
// 项目内其他平台分发文件（qr_image_saver、avatar_picker 等）也都
// 一致使用 dart.library.html。
export 'theory_pdf_view_native.dart'
    if (dart.library.html) 'theory_pdf_view_web.dart';
