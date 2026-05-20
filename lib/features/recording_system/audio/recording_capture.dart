import 'recording_capture_stub.dart'
    if (dart.library.html) 'recording_capture_web.dart'
    if (dart.library.io) 'recording_capture_io.dart';

abstract class RecordingCapture {
  Stream<double> get amplitudes;

  Future<bool> hasPermission();

  Future<void> start({required String path});

  Future<void> pause();

  Future<void> resume();

  Future<String?> stop();

  Future<void> cancel();

  Future<bool> isRecording();

  Future<bool> isPaused();

  Future<void> dispose();
}

RecordingCapture createRecordingCapture() => createPlatformRecordingCapture();
