import 'recording_playback_stub.dart'
    if (dart.library.html) 'recording_playback_web.dart'
    if (dart.library.io) 'recording_playback_io.dart';

class RecordingPlaybackStatus {
  const RecordingPlaybackStatus({
    required this.playing,
    required this.completed,
  });

  final bool playing;
  final bool completed;
}

abstract class RecordingPlayback {
  Stream<int> get positionMs;

  Stream<int> get durationMs;

  Stream<RecordingPlaybackStatus> get status;

  bool get isPlaying;

  bool get isCompleted;

  int? get currentDurationMs;

  Future<int?> setSource(String source, {required bool isUrl});

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(int positionMs);

  Future<void> dispose();
}

RecordingPlayback createRecordingPlayback() =>
    createPlatformRecordingPlayback();
