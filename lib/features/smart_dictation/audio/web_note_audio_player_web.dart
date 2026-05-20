import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'web_note_audio_player_base.dart';

WebNoteAudioPlayer createWebNoteAudioPlayer() => _WebNoteAudioPlayer();

class _WebNoteAudioPlayer implements WebNoteAudioPlayer {
  bool _ready = false;
  web.AudioContext? _audioContext;
  web.AnalyserNode? _analyser;
  final Map<String, web.AudioBuffer> _buffersByAsset =
      <String, web.AudioBuffer>{};
  final Set<_ActivePlayback> _activePlaybacks = <_ActivePlayback>{};
  final StreamController<List<double>> _frequencyController =
      StreamController<List<double>>.broadcast();
  Timer? _visualTicker;

  @override
  bool get isReady => _ready;

  @override
  Stream<List<double>> get frequencyBands => _frequencyController.stream;

  web.AudioContext _ensureContext() {
    final existing = _audioContext;
    if (existing != null) {
      return existing;
    }
    final context = web.AudioContext(
      web.AudioContextOptions(latencyHint: 'interactive'.toJS),
    );
    final analyser = context.createAnalyser()
      ..fftSize = 512
      ..smoothingTimeConstant = 0.76;
    analyser.connect(context.destination);
    _audioContext = context;
    _analyser = analyser;
    return context;
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
    final analyser = _analyser;
    if (analyser == null) {
      return;
    }

    source.connect(gain);
    gain.connect(analyser);
    source.start();

    final playback = _ActivePlayback(source: source, gain: gain);
    _activePlaybacks.add(playback);
    _startVisualTicker();

    playback.cleanupTimer = Timer(
      Duration(milliseconds: (buffer.duration * 1000).ceil() + 80),
      () => _cleanupPlayback(playback),
    );
  }

  @override
  Future<void> stopAll() async {
    for (final playback in List<_ActivePlayback>.from(_activePlaybacks)) {
      _cleanupPlayback(playback, stopSource: true);
    }
    _stopVisualTicker();
  }

  @override
  Future<void> dispose() async {
    await stopAll();
    _buffersByAsset.clear();
    _ready = false;
    await _frequencyController.close();

    final context = _audioContext;
    _audioContext = null;
    _analyser = null;
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
    if (_activePlaybacks.isEmpty) {
      _stopVisualTicker();
    }
  }

  void _startVisualTicker() {
    _visualTicker ??= Timer.periodic(const Duration(milliseconds: 66), (_) {
      final analyser = _analyser;
      if (analyser == null || _activePlaybacks.isEmpty) {
        _frequencyController.add(const <double>[]);
        return;
      }
      final data = Uint8List(analyser.frequencyBinCount);
      analyser.getByteFrequencyData(data.toJS);
      _frequencyController.add(_compressFrequencyData(data));
    });
  }

  void _stopVisualTicker() {
    _visualTicker?.cancel();
    _visualTicker = null;
    if (!_frequencyController.isClosed) {
      _frequencyController.add(const <double>[]);
    }
  }

  List<double> _compressFrequencyData(List<int> data) {
    const bands = 46;
    if (data.isEmpty) {
      return const <double>[];
    }
    final result = List<double>.filled(bands, 0);
    for (var i = 0; i < bands; i++) {
      final start = math.pow(i / bands, 1.55) * (data.length - 1);
      final end = math.pow((i + 1) / bands, 1.55) * (data.length - 1);
      final from = start.floor().clamp(0, data.length - 1);
      final to = math.max(from + 1, end.ceil().clamp(0, data.length));
      var sum = 0.0;
      for (var j = from; j < to; j++) {
        sum += data[j] / 255.0;
      }
      final average = sum / (to - from);
      result[i] = math.pow((average * 2.8).clamp(0.0, 1.0), 0.58) as double;
    }
    return result;
  }
}

class _ActivePlayback {
  _ActivePlayback({required this.source, required this.gain});

  final web.AudioBufferSourceNode source;
  final web.GainNode gain;
  Timer? cleanupTimer;
}
