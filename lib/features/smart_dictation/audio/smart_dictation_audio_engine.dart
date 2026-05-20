import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import '../../music_companion/audio/shared_soloud_piano_pool.dart';
import 'web_note_audio_player_base.dart';
import 'web_note_audio_player_stub.dart'
    if (dart.library.html) 'web_note_audio_player_web.dart';

class SmartDictationAudioEngine {
  SmartDictationAudioEngine({SoLoud? soLoud})
    : _soLoud = soLoud ?? SoLoud.instance;

  final SoLoud _soLoud;
  final SharedSoLoudPianoPool _pianoPool = SharedSoLoudPianoPool.instance;
  final WebNoteAudioPlayer _webPlayer = createWebNoteAudioPlayer();
  final List<SoundHandle> _activeHandles = <SoundHandle>[];
  final StreamController<List<double>> _frequencyController =
      StreamController<List<double>>.broadcast();
  AudioData? _audioData;
  Timer? _visualTicker;
  Future<void>? _initTask;

  bool get isReady => kIsWeb ? _webPlayer.isReady : _pianoPool.isLoaded;

  Stream<List<double>> get frequencyBands =>
      kIsWeb ? _webPlayer.frequencyBands : _frequencyController.stream;

  Future<void> ensureInitialized() {
    return _initTask ??= _initializeAndPreload();
  }

  Future<void> _initializeAndPreload() async {
    if (kIsWeb) {
      await _webPlayer.prepare(_assetByCanonical.values);
      return;
    }
    await _pianoPool.ensureLoaded();
    if (!_soLoud.isInitialized) {
      return;
    }
    _soLoud.setVisualizationEnabled(true);
    _soLoud.setFftSmoothing(0.82);
    _audioData ??= AudioData(GetSamplesKind.linear);
    _soLoud.setMaxActiveVoiceCount(256);
  }

  Future<void> playToken(String token, {double volume = 1}) async {
    await ensureInitialized();
    final canonical = canonicalFromToken(token);
    if (canonical.isEmpty) {
      return;
    }
    if (kIsWeb) {
      final asset = _assetByCanonical[canonical];
      if (asset == null) {
        return;
      }
      await _webPlayer.playAsset(asset, volume: volume);
      return;
    }
    final source = _pianoPool.sourceForNote(canonical);
    if (source == null) {
      return;
    }
    final handle = _soLoud.play(source, volume: volume);
    _activeHandles.add(handle);
    _startVisualTicker();
  }

  /// Web compatibility: browsers require user-gesture-triggered audio unlock.
  /// Call this from a tap handler before the first real playback.
  Future<void> activateByUserGesture() async {
    await ensureInitialized();
    if (kIsWeb) {
      await _webPlayer.activateByUserGesture();
      return;
    }
    await NativePlaybackAudioSession.ensurePlaybackActive();
    _pianoPool.tryUnlockProbe();
  }

  Future<void> playTokensHarmonic(
    List<String> tokens, {
    double volume = 1,
  }) async {
    await ensureInitialized();
    for (final token in tokens) {
      final canonical = canonicalFromToken(token);
      if (canonical.isEmpty) {
        continue;
      }
      if (kIsWeb) {
        final asset = _assetByCanonical[canonical];
        if (asset != null) {
          await _webPlayer.playAsset(asset, volume: volume);
        }
        continue;
      }
      final source = _pianoPool.sourceForNote(canonical);
      if (source == null) {
        continue;
      }
      final handle = _soLoud.play(source, volume: volume);
      _activeHandles.add(handle);
      _startVisualTicker();
    }
  }

  Future<void> playTokensMelodic(
    List<String> tokens, {
    Duration gap = const Duration(milliseconds: 320),
    double volume = 1,
  }) async {
    await ensureInitialized();
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final canonical = canonicalFromToken(token);
      if (canonical.isNotEmpty) {
        if (kIsWeb) {
          final asset = _assetByCanonical[canonical];
          if (asset != null) {
            await _webPlayer.playAsset(asset, volume: volume);
          }
        } else {
          final source = _pianoPool.sourceForNote(canonical);
          if (source != null) {
            final handle = _soLoud.play(source, volume: volume);
            _activeHandles.add(handle);
            _startVisualTicker();
          }
        }
      }
      if (i < tokens.length - 1) {
        await Future<void>.delayed(gap);
      }
    }
  }

  Future<void> stopAll() async {
    if (kIsWeb) {
      await _webPlayer.stopAll();
      return;
    }
    if (!_soLoud.isInitialized) {
      return;
    }
    for (final handle in List<SoundHandle>.from(_activeHandles)) {
      try {
        await _soLoud.stop(handle);
      } catch (_) {}
    }
    _activeHandles.clear();
    _stopVisualTicker();
  }

  Future<void> dispose() async {
    if (kIsWeb) {
      await _webPlayer.dispose();
      _initTask = null;
      return;
    }
    _activeHandles.clear();
    _stopVisualTicker();
    _audioData?.dispose();
    _audioData = null;
    await _frequencyController.close();
    _initTask = null;
  }

  void _startVisualTicker() {
    if (kIsWeb || _visualTicker != null) {
      return;
    }
    _visualTicker = Timer.periodic(const Duration(milliseconds: 66), (_) {
      if (!_soLoud.isInitialized) {
        _stopVisualTicker();
        return;
      }
      _activeHandles.removeWhere((handle) {
        try {
          return !_soLoud.getIsValidVoiceHandle(handle);
        } catch (_) {
          return true;
        }
      });
      if (_activeHandles.isEmpty) {
        _stopVisualTicker();
        return;
      }
      _frequencyController.add(_readFrequencyBands());
    });
  }

  void _stopVisualTicker() {
    _visualTicker?.cancel();
    _visualTicker = null;
    if (!_frequencyController.isClosed) {
      _frequencyController.add(const <double>[]);
    }
  }

  List<double> _readFrequencyBands() {
    final audioData = _audioData;
    if (audioData == null) {
      return const <double>[];
    }
    try {
      audioData.updateSamples();
      final samples = audioData.getAudioData(alwaysReturnData: false);
      if (samples.length < 256) {
        return const <double>[];
      }
      return _compressFft(samples.sublist(0, 256));
    } catch (_) {
      return const <double>[];
    }
  }

  List<double> _compressFft(Float32List fft) {
    const bands = 46;
    final result = List<double>.filled(bands, 0);
    for (var i = 0; i < bands; i++) {
      final start = math.pow(i / bands, 1.55) * (fft.length - 1);
      final end = math.pow((i + 1) / bands, 1.55) * (fft.length - 1);
      final from = start.floor().clamp(0, fft.length - 1);
      final to = math.max(from + 1, end.ceil().clamp(0, fft.length));
      var sum = 0.0;
      for (var j = from; j < to; j++) {
        sum += fft[j].abs();
      }
      final average = sum / (to - from);
      result[i] = math.pow((average * 7.5).clamp(0.0, 1.0), 0.55) as double;
    }
    return result;
  }

  static List<String> splitTokenGroup(String raw) {
    final cleaned = raw.replaceAll('，', ',').replaceAll('、', ',').trim();
    if (cleaned.isEmpty) {
      return const <String>[];
    }
    return cleaned
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static String canonicalFromToken(String rawToken) {
    if (rawToken.isEmpty) {
      return '';
    }
    final normalized = _normalizeToken(rawToken);
    if (normalized.isEmpty) {
      return '';
    }

    final direct = _tokenToCanonical[normalized];
    if (direct != null) {
      return direct;
    }

    final upper = normalized.toUpperCase();
    if (_assetByCanonical.containsKey(upper)) {
      return upper;
    }
    return '';
  }

  static String _normalizeToken(String raw) {
    return raw
        .trim()
        .replaceAll('<sup>#</sup>', '#')
        .replaceAll('<sup>b</sup>', 'b')
        .replaceAll('<sup>', '')
        .replaceAll('</sup>', '')
        .replaceAll('♯', '#')
        .replaceAll('＃', '#')
        .replaceAll('♭', 'b')
        .replaceAll('Ｂ', 'b')
        .replaceAll('，', ',')
        .replaceAll('。', '')
        .replaceAll('鹿', '1')
        .replaceAll('虏', '2')
        .replaceAll(' ', '')
        .replaceAll(RegExp('[^a-zA-Z0-9#,]'), '')
        .toLowerCase();
  }

  static const Map<String, String> _assetByCanonical = <String, String>{
    'F3': 'assets/audio/smart_dictation/piano/a81.wav',
    'F#3': 'assets/audio/smart_dictation/piano/b81.wav',
    'G3': 'assets/audio/smart_dictation/piano/a87.wav',
    'G#3': 'assets/audio/smart_dictation/piano/b87.wav',
    'A3': 'assets/audio/smart_dictation/piano/a69.wav',
    'A#3': 'assets/audio/smart_dictation/piano/b69.wav',
    'B3': 'assets/audio/smart_dictation/piano/a82.wav',
    'C4': 'assets/audio/smart_dictation/piano/a84.wav',
    'C#4': 'assets/audio/smart_dictation/piano/b84.wav',
    'D4': 'assets/audio/smart_dictation/piano/a89.wav',
    'D#4': 'assets/audio/smart_dictation/piano/b89.wav',
    'E4': 'assets/audio/smart_dictation/piano/a85.wav',
    'F4': 'assets/audio/smart_dictation/piano/a73.wav',
    'F#4': 'assets/audio/smart_dictation/piano/b73.wav',
    'G4': 'assets/audio/smart_dictation/piano/a79.wav',
    'G#4': 'assets/audio/smart_dictation/piano/b79.wav',
    'A4': 'assets/audio/smart_dictation/piano/a80.wav',
    'A#4': 'assets/audio/smart_dictation/piano/b80.wav',
    'B4': 'assets/audio/smart_dictation/piano/a65.wav',
    'C5': 'assets/audio/smart_dictation/piano/a83.wav',
    'C#5': 'assets/audio/smart_dictation/piano/b83.wav',
    'D5': 'assets/audio/smart_dictation/piano/a68.wav',
    'D#5': 'assets/audio/smart_dictation/piano/b68.wav',
    'E5': 'assets/audio/smart_dictation/piano/a70.wav',
    'F5': 'assets/audio/smart_dictation/piano/a71.wav',
    'F#5': 'assets/audio/smart_dictation/piano/b71.wav',
    'G5': 'assets/audio/smart_dictation/piano/a72.wav',
    'G#5': 'assets/audio/smart_dictation/piano/b72.wav',
    'A5': 'assets/audio/smart_dictation/piano/a74.wav',
    'A#5': 'assets/audio/smart_dictation/piano/b74.wav',
  };

  static const Map<String, String> _tokenToCanonical = <String, String>{
    'f': 'F3',
    '#f': 'F#3',
    'g': 'G3',
    '#g': 'G#3',
    'a': 'A3',
    'bb': 'A#3',
    'a#': 'A#3',
    'b': 'B3',
    'c': 'C4',
    'c1': 'C4',
    '#c1': 'C#4',
    'd1': 'D4',
    'be1': 'D#4',
    'd#1': 'D#4',
    'e1': 'E4',
    'f1': 'F4',
    '#f1': 'F#4',
    'g1': 'G4',
    '#g1': 'G#4',
    'a1': 'A4',
    'bb1': 'A#4',
    'a#1': 'A#4',
    'b1': 'B4',
    'c2': 'C5',
    '#c2': 'C#5',
    'd2': 'D5',
    'be2': 'D#5',
    'd#2': 'D#5',
    'e2': 'E5',
    'f2': 'F5',
    '#f2': 'F#5',
    'g2': 'G5',
    '#g2': 'G#5',
    'a2': 'A5',
    'bb2': 'A#5',
    'a#2': 'A#5',
    'f3': 'F3',
    'f#3': 'F#3',
    'g3': 'G3',
    'g#3': 'G#3',
    'a3': 'A3',
    'a#3': 'A#3',
    'b3': 'B3',
    'c4': 'C4',
    'c#4': 'C#4',
    'd4': 'D4',
    'd#4': 'D#4',
    'e4': 'E4',
    'f4': 'F4',
    'f#4': 'F#4',
    'g4': 'G4',
    'g#4': 'G#4',
    'a4': 'A4',
    'a#4': 'A#4',
    'b4': 'B4',
    'c5': 'C5',
    'c#5': 'C#5',
    'd5': 'D5',
    'd#5': 'D#5',
    'e5': 'E5',
    'f5': 'F5',
    'f#5': 'F#5',
    'g5': 'G5',
    'g#5': 'G#5',
    'a5': 'A5',
    'a#5': 'A#5',
  };
}
