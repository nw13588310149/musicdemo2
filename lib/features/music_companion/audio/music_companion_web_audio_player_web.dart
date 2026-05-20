import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'music_companion_web_audio_player_base.dart';

MusicCompanionWebAudioPlayer createMusicCompanionWebAudioPlayer() {
  return _MusicCompanionWebAudioPlayer();
}

class _MusicCompanionWebAudioPlayer implements MusicCompanionWebAudioPlayer {
  web.AudioContext? _audioContext;
  final Map<String, web.AudioBuffer> _buffersByAsset =
      <String, web.AudioBuffer>{};
  final Set<_ActivePlayback> _activePlaybacks = <_ActivePlayback>{};

  bool _ready = false;

  @override
  bool get isReady => _ready;

  web.AudioContext _ensureContext() {
    return _audioContext ??= web.AudioContext(
      web.AudioContextOptions(latencyHint: 'interactive'.toJS),
    );
  }

  @override
  Future<void> prepare(Iterable<String> assets) async {
    final uniqueAssets = assets.toSet().toList(growable: false);
    if (_ready && uniqueAssets.every(_buffersByAsset.containsKey)) {
      return;
    }

    final context = _ensureContext();
    await Future.wait(
      uniqueAssets.map((asset) async {
        if (_buffersByAsset.containsKey(asset)) {
          return;
        }

        final byteData = await rootBundle.load(asset);
        final bytes = Uint8List.fromList(Uint8List.sublistView(byteData));
        final buffer = await context.decodeAudioData(bytes.buffer.toJS).toDart;
        _buffersByAsset[asset] = buffer;
      }),
    );

    _ready = true;
  }

  @override
  Future<void> activateByUserGesture() async {
    final context = _ensureContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
  }

  @override
  Future<void> playAsset(String asset, {double volume = 1}) async {
    final buffer = _buffersByAsset[asset];
    if (buffer == null) {
      return;
    }

    final context = _ensureContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }

    final source = context.createBufferSource()..buffer = buffer;
    final gain = context.createGain()
      ..gain.value = volume.clamp(0.0, 1.0).toDouble();

    source.connect(gain);
    gain.connect(context.destination);
    source.start();

    final playback = _ActivePlayback(source: source, gain: gain);
    _activePlaybacks.add(playback);

    final cleanupDelay = Duration(
      milliseconds: (buffer.duration * 1000).ceil() + 48,
    );
    playback.cleanupTimer = Timer(cleanupDelay, () {
      _cleanupPlayback(playback);
    });
  }

  @override
  Future<void> stopAll() async {
    for (final playback in List<_ActivePlayback>.from(_activePlaybacks)) {
      _cleanupPlayback(playback, stopSource: true);
    }
  }

  @override
  Future<void> dispose() async {
    await stopAll();
    _buffersByAsset.clear();
    _ready = false;

    final context = _audioContext;
    _audioContext = null;
    if (context != null && context.state != 'closed') {
      await context.close().toDart;
    }
  }

  void _cleanupPlayback(_ActivePlayback playback, {bool stopSource = false}) {
    if (!_activePlaybacks.remove(playback)) {
      return;
    }

    playback.cleanupTimer?.cancel();
    playback.cleanupTimer = null;

    if (stopSource) {
      try {
        playback.source.stop();
      } catch (_) {}
    }

    try {
      playback.source.disconnect();
    } catch (_) {}
    try {
      playback.gain.disconnect();
    } catch (_) {}
  }
}

class _ActivePlayback {
  _ActivePlayback({required this.source, required this.gain});

  final web.AudioBufferSourceNode source;
  final web.GainNode gain;
  Timer? cleanupTimer;
}
