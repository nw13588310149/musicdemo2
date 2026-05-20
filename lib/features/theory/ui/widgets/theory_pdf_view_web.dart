import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// 当前在 DOM 中"活跃"（最近一次 factory 创建出来）的 iframe。
/// 用作 [tryFullscreenWebPdf] 的目标——仅维护一份"最近一次"，
/// 多个 [TheoryPdfView] 同时存活时也优先全屏最近一个。
web.HTMLIFrameElement? _activeTheoryPdfIframe;

/// Web 端 PDF 显示：用 iframe 直接交给浏览器原生 PDF Viewer 渲染。
/// 这样可以避开浏览器对跨域 fetch 的 CORS 限制（PDF 静态 CDN 通常不会
/// 给前端 origin 配置 Access-Control-Allow-Origin），与 1.0 行为一致。
class TheoryPdfView extends StatefulWidget {
  const TheoryPdfView({
    super.key,
    required this.url,
    required this.authToken,
    this.interactive = true,
  });

  final String url;
  final String authToken;
  final bool interactive;

  @override
  State<TheoryPdfView> createState() => _TheoryPdfViewState();
}

class _TheoryPdfViewState extends State<TheoryPdfView> {
  static int _seq = 0;
  late String _viewType;
  web.HTMLIFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant TheoryPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // url 变化时重新注册一个新的 viewType，避免浏览器复用旧 iframe。
    if (oldWidget.url != widget.url) {
      setState(_registerView);
      return;
    }
    if (oldWidget.interactive != widget.interactive) {
      _applyInteractivity();
    }
  }

  void _registerView() {
    _viewType =
        'theory-pdf-iframe-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = widget.url
        ..allowFullscreen = true
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#FAFAFB';
      _iframe = iframe;
      _activeTheoryPdfIframe = iframe;
      _applyInteractivity();
      return iframe;
    });
  }

  @override
  void dispose() {
    if (identical(_activeTheoryPdfIframe, _iframe)) {
      _activeTheoryPdfIframe = null;
    }
    super.dispose();
  }

  void _applyInteractivity() {
    _iframe?.style.pointerEvents = widget.interactive ? 'auto' : 'none';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

/// 触发浏览器 Fullscreen API 把当前活跃的 PDF iframe 撑满整屏。
///
/// - 必须在用户手势事件链路（点击/按键）里同步调用，否则浏览器会拒绝；
/// - 退出全屏由用户按 Esc 或浏览器右上角的"退出全屏"按钮完成；
/// - 调用成功返回 true，让上层 page 跳过 Flutter 全屏对话框路径。
bool tryFullscreenWebPdf() {
  final iframe = _activeTheoryPdfIframe;
  if (iframe == null) {
    return false;
  }
  try {
    // requestFullscreen 返回 Promise，这里不需要 await，触发就行。
    iframe.requestFullscreen();
    return true;
  } catch (_) {
    return false;
  }
}
