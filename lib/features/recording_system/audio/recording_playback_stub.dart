import 'recording_playback.dart';

RecordingPlayback createPlatformRecordingPlayback() => _UnsupportedPlayback();

class _UnsupportedPlayback implements RecordingPlayback {
  @override
  Stream<int> get positionMs => const Stream<int>.empty();

  @override
  Stream<int> get durationMs => const Stream<int>.empty();

  @override
  Stream<RecordingPlaybackStatus> get status =>
      const Stream<RecordingPlaybackStatus>.empty();

  @override
  bool get isPlaying => false;

  @override
  bool get isCompleted => false;

  @override
  int? get currentDurationMs => null;

  @override
  Future<int?> setSource(String source, {required bool isUrl}) async {
    throw UnsupportedError('Recording playback is not supported.');
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(int positionMs) async {}

  @override
  Future<void> dispose() async {}
}
