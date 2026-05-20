import 'dart:async';

import 'package:record/record.dart';

import 'recording_capture.dart';

RecordingCapture createPlatformRecordingCapture() => _RecordPluginCapture();

class _RecordPluginCapture implements RecordingCapture {
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<double> _amplitudes =
      StreamController<double>.broadcast();

  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  Stream<double> get amplitudes => _amplitudes.stream;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start({required String path}) async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) => _amplitudes.add(amp.current), onError: (_) {});
  }

  @override
  Future<void> pause() async {
    await _recorder.pause();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }

  @override
  Future<void> resume() async {
    await _recorder.resume();
    _amplitudeSub ??= _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) => _amplitudes.add(amp.current), onError: (_) {});
  }

  @override
  Future<String?> stop() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    return _recorder.stop();
  }

  @override
  Future<void> cancel() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorder.cancel();
  }

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Future<bool> isPaused() => _recorder.isPaused();

  @override
  Future<void> dispose() async {
    await _amplitudeSub?.cancel();
    await _amplitudes.close();
    await _recorder.dispose();
  }
}
