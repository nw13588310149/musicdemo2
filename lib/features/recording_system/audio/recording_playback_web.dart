import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'recording_playback.dart';

RecordingPlayback createPlatformRecordingPlayback() => _HtmlAudioPlayback();

class _HtmlAudioPlayback implements RecordingPlayback {
  _HtmlAudioPlayback() {
    _audio.preload = 'metadata';

    _audio.addEventListener(
      'timeupdate',
      ((web.Event _) => _emitPosition()).toJS,
    );
    _audio.addEventListener(
      'durationchange',
      ((web.Event _) => _emitDuration()).toJS,
    );
    _audio.addEventListener(
      'loadedmetadata',
      ((web.Event _) {
        _emitDuration();
        _completePendingLoad(null);
      }).toJS,
    );
    _audio.addEventListener(
      'canplay',
      ((web.Event _) {
        _emitDuration();
        _completePendingLoad(null);
      }).toJS,
    );
    _audio.addEventListener('play', ((web.Event _) => _emitStatus()).toJS);
    _audio.addEventListener('pause', ((web.Event _) => _emitStatus()).toJS);
    _audio.addEventListener(
      'ended',
      ((web.Event _) {
        _completed = true;
        _emitStatus();
      }).toJS,
    );
    _audio.addEventListener(
      'error',
      ((web.Event _) {
        final code = _audio.error?.code;
        _completePendingLoad(StateError('HTMLAudioElement load error: $code'));
      }).toJS,
    );
  }

  final web.HTMLAudioElement _audio = web.HTMLAudioElement();
  final StreamController<int> _positionController =
      StreamController<int>.broadcast();
  final StreamController<int> _durationController =
      StreamController<int>.broadcast();
  final StreamController<RecordingPlaybackStatus> _statusController =
      StreamController<RecordingPlaybackStatus>.broadcast();

  Completer<int?>? _loadCompleter;
  Timer? _positionTimer;
  bool _completed = false;

  @override
  Stream<int> get positionMs => _positionController.stream;

  @override
  Stream<int> get durationMs => _durationController.stream;

  @override
  Stream<RecordingPlaybackStatus> get status => _statusController.stream;

  @override
  bool get isPlaying => !_audio.paused;

  @override
  bool get isCompleted => _completed;

  @override
  int? get currentDurationMs => _durationToMs(_audio.duration);

  @override
  Future<int?> setSource(String source, {required bool isUrl}) async {
    await stop();
    _completed = false;
    _loadCompleter = Completer<int?>();
    _audio.src = source;
    _audio.load();

    return _loadCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _loadCompleter = null;
        return null;
      },
    );
  }

  @override
  Future<void> play() async {
    _completed = false;
    await _audio.play().toDart;
    _startPositionTimer();
    _emitStatus();
  }

  @override
  Future<void> pause() async {
    _audio.pause();
    _stopPositionTimer();
    _emitStatus();
  }

  @override
  Future<void> stop() async {
    _audio.pause();
    _stopPositionTimer();
    try {
      _audio.currentTime = 0;
    } catch (_) {}
    _audio.removeAttribute('src');
    _audio.load();
    _completed = false;
    _emitPosition();
    _emitStatus();
  }

  @override
  Future<void> seek(int positionMs) async {
    _completed = false;
    _audio.currentTime = math.max(positionMs, 0) / 1000.0;
    _emitPosition();
  }

  @override
  Future<void> dispose() async {
    await stop();
    _completePendingLoad(StateError('disposed'));
    await _positionController.close();
    await _durationController.close();
    await _statusController.close();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _emitPosition(),
    );
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _emitPosition() {
    if (!_positionController.isClosed) {
      _positionController.add((_audio.currentTime * 1000).round());
    }
  }

  void _emitDuration() {
    final ms = _durationToMs(_audio.duration);
    if (ms != null && !_durationController.isClosed) {
      _durationController.add(ms);
    }
  }

  void _emitStatus() {
    if (_statusController.isClosed) return;
    _statusController.add(
      RecordingPlaybackStatus(
        playing: !_audio.paused && !_completed,
        completed: _completed,
      ),
    );
  }

  int? _durationToMs(double value) {
    if (!value.isFinite || value <= 0) return null;
    return (value * 1000).round();
  }

  void _completePendingLoad(Object? error) {
    final completer = _loadCompleter;
    if (completer == null || completer.isCompleted) return;
    _loadCompleter = null;
    if (error != null) {
      completer.completeError(error);
      return;
    }
    completer.complete(_durationToMs(_audio.duration));
  }
}
