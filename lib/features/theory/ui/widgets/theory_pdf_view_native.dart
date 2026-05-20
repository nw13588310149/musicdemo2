import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class TheoryPdfView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final headers = <String, String>{
      if (authToken.isNotEmpty) 'app-token': authToken,
    };
    return PdfViewer.uri(
      Uri.parse(url),
      headers: headers.isEmpty ? null : headers,
      withCredentials: true,
      params: PdfViewerParams(
        backgroundColor: const Color(0xFFFAFAFB),
        margin: 12,
        // 去掉每一页四周默认的黑色 drop shadow（pdfrx 默认值是
        // BoxShadow(color: Colors.black54, blurRadius: 4, ...)），
        // 让 PDF 干净地贴在卡片背景上。
        pageDropShadow: null,
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
          final progress = (totalBytes != null && totalBytes > 0)
              ? bytesDownloaded / totalBytes
              : null;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress,
                    color: const Color(0xFF8741FF),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  progress == null
                      ? 'PDF 加载中…'
                      : 'PDF 加载中…${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF6D6B75),
                    fontSize: 12,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          );
        },
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Color(0xFFC9C6D8),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PDF 加载失败，请稍后重试',
                    style: TextStyle(
                      color: Color(0xFF6D6B75),
                      fontSize: 13,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    url,
                    style: const TextStyle(
                      color: Color(0xFF8741FF),
                      fontSize: 11,
                      fontFamily: 'Manrope',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    error.toString(),
                    style: const TextStyle(
                      color: Color(0xFFB6B5BB),
                      fontSize: 11,
                      fontFamily: 'Manrope',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 仅在 Web 端调用浏览器 Fullscreen API 把 iframe 撑满全屏；
/// Native 平台没有 iframe，永远返回 false，让上层走 [showGeneralDialog]
/// 的 Flutter 全屏对话框。
bool tryFullscreenWebPdf() => false;
