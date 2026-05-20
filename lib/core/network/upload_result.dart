/// Parsed result of an upload-style backend response.
///
/// Modern endpoints return both a relative `path` (suitable for saving on
/// the server) and an absolute `url` (suitable for direct display). Older
/// endpoints may return just one or neither — the helpers below tolerate
/// every observed shape.
class UploadResult {
  const UploadResult({required this.path, required this.url});

  final String path;
  final String url;

  bool get isEmpty => path.isEmpty && url.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Best value to send to a save endpoint: prefers `path`, falls back to
  /// `url` if the backend only returned an absolute URL.
  String get savable => path.isNotEmpty ? path : url;

  /// Best value to use for display: prefers `url`, falls back to `path`.
  String get displayable => url.isNotEmpty ? url : path;
}

/// Parses an upload-endpoint response body into a normalized [UploadResult].
///
/// Accepts the modern shape:
/// ```json
/// { "path": "app/upload/.../foo.png", "url": "https://cdn/.../foo.png" }
/// ```
/// as well as legacy shapes (single string body, `fileUrl`/`filePath`/`src`,
/// or an envelope `{ "data": <inner> }` that needs another unwrap pass).
UploadResult parseUploadResult(dynamic data) {
  if (data == null) return const UploadResult(path: '', url: '');

  if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isEmpty || trimmed == 'null') {
      return const UploadResult(path: '', url: '');
    }
    final isUrl =
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('//');
    return UploadResult(path: isUrl ? '' : trimmed, url: isUrl ? trimmed : '');
  }

  if (data is num) {
    return UploadResult(path: '', url: data.toString());
  }

  if (data is Map) {
    final path = _firstNonEmpty(<dynamic>[data['path'], data['filePath']]);
    final url = _firstNonEmpty(<dynamic>[
      data['url'],
      data['fileUrl'],
      data['src'],
    ]);

    if (path.isNotEmpty || url.isNotEmpty) {
      return UploadResult(path: path, url: url);
    }

    // Some legacy responses wrap the payload one extra level under "data".
    final inner = data['data'];
    if (inner != null && inner != data) {
      return parseUploadResult(inner);
    }
  }

  return const UploadResult(path: '', url: '');
}

String _firstNonEmpty(List<dynamic> values) {
  for (final v in values) {
    final s = v?.toString().trim() ?? '';
    if (s.isNotEmpty && s != 'null') {
      return s;
    }
  }
  return '';
}
