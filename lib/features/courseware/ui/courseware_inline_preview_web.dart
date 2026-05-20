import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web 端通用内嵌预览：根据文件后缀选择最合适的 HTML 元素直接在页面内
/// 渲染，避免在新标签页打开。
///
/// 支持矩阵：
/// - **图片** (png/jpg/jpeg/webp/gif/bmp/svg)：`<img>` 居中、按比例缩放。
/// - **PDF**：`<iframe>` 直链，使用浏览器原生 PDF Viewer。
/// - **音频** (mp3/wav/m4a/aac/flac/ogg)：`<audio controls>` 居中。
/// - **视频** (mp4/webm/mov/m4v/ogv)：`<video controls>` 占满区域。
/// - **Office 文档** (doc/docx/xls/xlsx/ppt/pptx)：经
///   `https://view.officeapps.live.com/op/embed.aspx?src=...` 嵌入。
/// - **纯文本/标记** (txt/md/log/json/xml/csv/rtf)：`<iframe>` 直链，浏览器
///   通常会以纯文本形式渲染。
/// - **未知后缀**：兜底用 `<iframe>` 直链，由浏览器自行决定（通常会下载）。
class CoursewareInlinePreview extends StatefulWidget {
  const CoursewareInlinePreview({
    super.key,
    required this.url,
    this.placeholder,
    this.authToken = '',
  });

  final String url;

  /// 当 URL 为空时展示的占位 widget（一般传一个空状态）。Web 实现不会
  /// 在 URL 非空时使用它。
  final Widget? placeholder;

  /// 后端鉴权 token（`app-token` 头）。Web 端走浏览器同源 / iframe 直
  /// 链，文件 URL 通常本身就是公开静态资源，不需要附加 header；保留
  /// 这个字段只是为了与原生实现的签名保持一致。
  final String authToken;

  @override
  State<CoursewareInlinePreview> createState() =>
      _CoursewareInlinePreviewState();
}

class _CoursewareInlinePreviewState extends State<CoursewareInlinePreview> {
  static int _seq = 0;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant CoursewareInlinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(_registerView);
    }
  }

  void _registerView() {
    _viewType =
        'cw-inline-preview-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    final url = widget.url.trim();
    final kind = _kindForUrl(url);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      switch (kind) {
        case _PreviewKind.image:
          return _buildImage(url);
        case _PreviewKind.audio:
          return _buildAudio(url);
        case _PreviewKind.video:
          return _buildVideo(url);
        case _PreviewKind.office:
          return _buildIframe(_officeViewerUrl(url));
        case _PreviewKind.pdf:
        case _PreviewKind.text:
        case _PreviewKind.unknown:
          return _buildIframe(url);
      }
    });
  }

  web.HTMLElement _buildIframe(String src) {
    final iframe = web.HTMLIFrameElement()
      ..src = src
      ..allowFullscreen = true
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#FAFAFB';
    return iframe;
  }

  web.HTMLElement _buildImage(String src) {
    final wrapper = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.backgroundColor = '#FAFAFD'
      ..style.overflow = 'auto';
    final img = web.HTMLImageElement()
      ..src = src
      ..style.maxWidth = '100%'
      ..style.maxHeight = '100%'
      ..style.objectFit = 'contain';
    wrapper.appendChild(img);
    return wrapper;
  }

  web.HTMLElement _buildAudio(String src) {
    final wrapper = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.backgroundColor = '#FAFAFD'
      ..style.padding = '24px';
    final audio = web.HTMLAudioElement()
      ..src = src
      ..controls = true
      ..style.width = '80%';
    wrapper.appendChild(audio);
    return wrapper;
  }

  web.HTMLElement _buildVideo(String src) {
    final wrapper = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.backgroundColor = '#000000';
    final video = web.HTMLVideoElement()
      ..src = src
      ..controls = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';
    wrapper.appendChild(video);
    return wrapper;
  }

  String _officeViewerUrl(String src) {
    final encoded = Uri.encodeComponent(src);
    return 'https://view.officeapps.live.com/op/embed.aspx?src=$encoded';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return HtmlElementView(viewType: _viewType);
  }
}

enum _PreviewKind { image, pdf, audio, video, office, text, unknown }

_PreviewKind _kindForUrl(String url) {
  final lower = url.toLowerCase();
  final pathOnly = lower.split('?').first;
  bool hasExt(List<String> exts) {
    for (final e in exts) {
      if (pathOnly.endsWith('.$e')) return true;
    }
    return false;
  }

  if (hasExt(const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'])) {
    return _PreviewKind.image;
  }
  if (hasExt(const ['pdf'])) return _PreviewKind.pdf;
  if (hasExt(const ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'])) {
    return _PreviewKind.audio;
  }
  if (hasExt(const ['mp4', 'webm', 'mov', 'm4v', 'ogv'])) {
    return _PreviewKind.video;
  }
  if (hasExt(const ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'])) {
    return _PreviewKind.office;
  }
  if (hasExt(const ['txt', 'md', 'log', 'json', 'xml', 'csv', 'rtf'])) {
    return _PreviewKind.text;
  }
  return _PreviewKind.unknown;
}
