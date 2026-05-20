import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web-side reader for the source returned by `AudioRecorder.stop()`.
///
/// On Flutter Web `record` writes the recording to an in-memory `Blob`
/// (via the browser's MediaRecorder API) and surfaces it back as a
/// `blob:http://…` URL. We read those bytes synchronously via
/// `window.fetch(url).arrayBuffer()` and hand back a regular [Uint8List]
/// so the upload + preview pipeline can stay platform-agnostic.
///
/// Supports three URL shapes for resilience:
///   * `blob:…`   – freshly-recorded clip (the common path on Web).
///   * `data:…`   – base64-encoded fallbacks some hosts substitute.
///   * absolute   – previously-uploaded clips that we round-trip back
///     through the same code path (rare; preview already routes through
///     `just_audio`'s `setUrl`, but we keep this for completeness).
Future<Uint8List> readRecordedBytes(String source) async {
  if (source.isEmpty) {
    throw ArgumentError.value(source, 'source', 'empty recording URL');
  }

  final response = await web.window.fetch(source.toJS).toDart;
  if (!response.ok) {
    throw StateError(
      'failed to read recorded bytes: HTTP ${response.status} for $source',
    );
  }
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

/// Web has no real filesystem, and `AudioRecorder.start()` ignores the
/// path argument here – the browser allocates a `Blob` internally. We
/// still need to pass *something*, and an empty string is what the
/// `record` package documents for Web. The extension is irrelevant on
/// this side; the upload step picks the right one based on platform.
String createTemporaryRecordingPath() => '';
