import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import 'music_companion_audio_catalog.dart';
import 'music_companion_web_audio_player_base.dart';
import 'music_companion_web_audio_player_stub.dart'
    if (dart.library.html) 'music_companion_web_audio_player_web.dart';
import 'shared_soloud_piano_pool.dart';

/// 应用启动后后台预热钢琴池（不阻塞首屏）。
Future<void> warmupMusicCompanionPianoAudio() async {
  if (kIsWeb) return;
  try {
    await NativePlaybackAudioSession.ensurePlaybackActive();
    await SharedSoLoudPianoPool.instance.ensureLoaded();
  } catch (error, stack) {
    debugPrint('warmupMusicCompanionPianoAudio: $error\n$stack');
  }
}

class MusicCompanionAudioEngine {
  MusicCompanionAudioEngine({SoLoud? soLoud})
    : _soLoud = soLoud ?? SoLoud.instance;

  final SoLoud _soLoud;
  final SharedSoLoudPianoPool _pianoPool = SharedSoLoudPianoPool.instance;
  final MusicCompanionWebAudioPlayer _webPlayer =
      createMusicCompanionWebAudioPlayer();

  final Map<MusicCompanionMetronomeCue, AudioSource> _metronomeSourcesByCue =
      <MusicCompanionMetronomeCue, AudioSource>{};
  final List<SoundHandle> _activeHandles = <SoundHandle>[];

  Future<void>? _metronomeInitTask;

  /// 设置为 true 后，本引擎会拒绝任何后续的 `playNote` / `playMetronomeCue`。
  bool _disposed = false;

  bool get isReady => kIsWeb
      ? _webPlayer.isReady
      : _pianoPool.isLoaded || _metronomeSourcesByCue.isNotEmpty;

  bool get isPianoReady => kIsWeb ? _webPlayer.isReady : _pianoPool.isLoaded;

  /// 仅预热钢琴（进页 / 用户点琴键）。节拍器音源在首次播放时再加载。
  Future<void> ensurePianoInitialized() {
    if (kIsWeb) {
      return _webPlayer.prepare(kMusicCompanionPianoAssetByNote.values);
    }
    return _pianoPool.ensureLoaded();
  }

  Future<void> ensureMetronomeInitialized() {
    return _metronomeInitTask ??= () async {
      try {
        await _initializeMetronomeAssets();
      } catch (_) {
        _metronomeInitTask = null;
        rethrow;
      }
    }();
  }

  /// 兼容旧调用：等价于 [ensurePianoInitialized]。
  Future<void> ensureInitialized() => ensurePianoInitialized();

  Future<void> _initializeMetronomeAssets() async {
    final allAssets = <String>{...kMusicCompanionMetronomeAssetByCue.values};

    if (kIsWeb) {
      await _webPlayer.prepare(allAssets);
      return;
    }

    await NativePlaybackAudioSession.ensurePlaybackActive();

    if (!_soLoud.isInitialized) {
      await _soLoud.init(
        sampleRate: 44100,
        bufferSize: 2048,
        channels: Channels.stereo,
      );
    }
    _soLoud.setMaxActiveVoiceCount(256);

    for (final entry in kMusicCompanionMetronomeAssetByCue.entries) {
      final existing = _metronomeSourcesByCue[entry.key];
      if (existing != null) {
        continue;
      }
      final source = await _soLoud.loadAsset(
        entry.value,
        mode: LoadMode.memory,
      );
      _metronomeSourcesByCue[entry.key] = source;
    }
  }

  /// 在用户手势的同一调用栈内同步弹奏（iOS 关键路径）。
  bool tryPlayNoteFromUserGesture(String rawNote, {double volume = 1}) {
    if (_disposed || kIsWeb) {
      return false;
    }
    return _pianoPool.tryPlayNote(_normalizeNote(rawNote), volume: volume);
  }

  bool tryPlayMetronomeCueFromUserGesture(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) {
    if (_disposed || kIsWeb || !_soLoud.isInitialized) {
      return false;
    }
    final source = _metronomeSourcesByCue[cue];
    if (source == null) {
      return false;
    }
    try {
      _registerHandle(_soLoud.play(source, volume: volume));
      return true;
    } catch (error, stack) {
      debugPrint(
        'tryPlayMetronomeCueFromUserGesture($cue): $error\n$stack',
      );
      return false;
    }
  }

  Future<void> activateByUserGesture() async {
    await NativePlaybackAudioSession.ensurePlaybackActive();
    await ensurePianoInitialized();
    if (kIsWeb) {
      await _webPlayer.activateByUserGesture();
      return;
    }
    if (!_pianoPool.tryUnlockProbe()) {
      throw StateError('SoLoud playback probe failed');
    }
  }

  Future<void> playNote(String rawNote, {double volume = 1}) async {
    if (_disposed) return;
    await ensurePianoInitialized();
    if (_disposed) return;
    final note = _normalizeNote(rawNote);
    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) {
      return;
    }

    if (kIsWeb) {
      if (_disposed) return;
      await _webPlayer.playAsset(asset, volume: volume);
      return;
    }

    final source = _pianoPool.sourceForNote(note);
    if (source == null || _disposed) {
      return;
    }
    _registerHandle(_soLoud.play(source, volume: volume));
  }

  Future<void> playNotes(Iterable<String> notes, {double volume = 1}) async {
    if (_disposed) return;
    await ensurePianoInitialized();
    if (_disposed) return;
    await Future.wait(notes.map((note) => playNote(note, volume: volume)));
  }

  Future<void> playMetronomeCue(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) async {
    if (_disposed) return;
    await ensureMetronomeInitialized();
    if (_disposed) return;
    final asset = kMusicCompanionMetronomeAssetByCue[cue];
    if (asset == null) {
      return;
    }

    if (kIsWeb) {
      if (_disposed) return;
      await _webPlayer.playAsset(asset, volume: volume);
      return;
    }

    final source = _metronomeSourcesByCue[cue];
    if (source == null || _disposed) {
      return;
    }
    _registerHandle(_soLoud.play(source, volume: volume));
  }

  void _registerHandle(SoundHandle handle) {
    _activeHandles.add(handle);
    if (_activeHandles.length > 1024) {
      _activeHandles.removeRange(0, _activeHandles.length - 512);
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
  }

  void stopAllImmediately() {
    if (kIsWeb) {
      unawaited(_webPlayer.stopAll());
      return;
    }
    if (!_soLoud.isInitialized) {
      _activeHandles.clear();
      return;
    }
    for (final handle in List<SoundHandle>.from(_activeHandles)) {
      try {
        if (_soLoud.getIsValidVoiceHandle(handle)) {
          unawaited(_soLoud.stop(handle));
        }
      } catch (_) {}
    }
    _activeHandles.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopAll();

    if (kIsWeb) {
      await _webPlayer.dispose();
      _metronomeInitTask = null;
      return;
    }

    // 仅释放本引擎持有的节拍器音源；钢琴 wav 留在 [SharedSoLoudPianoPool]。
    for (final source in _metronomeSourcesByCue.values) {
      try {
        await _soLoud.disposeSource(source);
      } catch (_) {}
    }
    _metronomeSourcesByCue.clear();
    _activeHandles.clear();
    _metronomeInitTask = null;
  }

  String _normalizeNote(String rawNote) {
    return rawNote.trim().replaceAll('♯', '#').toUpperCase();
  }
}
