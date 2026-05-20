import 'recording_capture.dart';

RecordingCapture createPlatformRecordingCapture() => _UnsupportedRecordingCapture();

class _UnsupportedRecordingCapture implements RecordingCapture {
  @override
  Stream<double> get amplitudes => const Stream<double>.empty();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> start({required String path}) async {
    throw UnsupportedError('Recording is not supported on this platform.');
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<bool> isPaused() async => false;

  @override
  Future<void> dispose() async {}
}
