import 'dart:typed_data';

Future<Uint8List> readRecordedBytes(String source) async {
  throw UnsupportedError(
    'Recording bytes loader is not supported on this platform.',
  );
}

String createTemporaryRecordingPath() => 'recording.m4a';
