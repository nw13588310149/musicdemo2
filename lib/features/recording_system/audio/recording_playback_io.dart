import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'recording_playback.dart';

RecordingPlayback createPlatformRecordingPlayback() => _JustAudioPlayback();

class _JustAudioPlayback implements RecordingPlayback {
  _JustAudioPlayback() {
    _positionSub = _player.positionStream.listen((duration) {
      _positionController.add(duration.inMilliseconds);
    }, onError: (_) {});
    _durationSub = _player.durationStream.listen((duration) {
      final ms = duration?.inMilliseconds ?? 0;
      if (ms > 0) _durationController.add(ms);
    }, onError: (_) {});
    _stateSub = _player.playerStateStream.listen((state) {
      _statusController.add(
        RecordingPlaybackStatus(
          playing:
              state.playing &&
              state.processingState != ProcessingState.completed,
          completed: state.processingState == ProcessingState.completed,
        ),
      );
    }, onError: (_) {});
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<int> _positionController =
      StreamController<int>.broadcast();
  final StreamController<int> _durationController =
      StreamController<int>.broadcast();
  final StreamController<RecordingPlaybackStatus> _statusController =
      StreamController<RecordingPlaybackStatus>.broadcast();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  Stream<int> get positionMs => _positionController.stream;

  @override
  Stream<int> get durationMs => _durationController.stream;

  @override
  Stream<RecordingPlaybackStatus> get status => _statusController.stream;

  @override
  bool get isPlaying => _player.playing;

  @override
  bool get isCompleted => _player.processingState == ProcessingState.completed;

  @override
  int? get currentDurationMs => _player.duration?.inMilliseconds;

  @override
  Future<int?> setSource(String source, {required bool isUrl}) async {
    final duration = isUrl
        ? await _player.setUrl(source)
        : await _player.setFilePath(source);
    return duration?.inMilliseconds;
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(int positionMs) {
    return _player.seek(Duration(milliseconds: positionMs));
  }

  @override
  Future<void> dispose() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _stateSub?.cancel();
    await _positionController.close();
    await _durationController.close();
    await _statusController.close();
    await _player.dispose();
  }
}
