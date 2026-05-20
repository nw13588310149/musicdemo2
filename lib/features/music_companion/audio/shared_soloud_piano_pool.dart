import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import 'music_companion_audio_catalog.dart';

/// 全应用唯一的 SoLoud 钢琴音源池（页面退出不销毁 wav）。
class SharedSoLoudPianoPool {
  SharedSoLoudPianoPool._();

  static final SharedSoLoudPianoPool instance = SharedSoLoudPianoPool._();

  final SoLoud _soLoud = SoLoud.instance;
  final Map<String, AudioSource> _sourcesByNote = <String, AudioSource>{};

  Future<void>? _loadTask;

  bool get isLoaded => _sourcesByNote.isNotEmpty;

  AudioSource? sourceForNote(String note) => _sourcesByNote[note];

  Future<void> ensureLoaded() {
    return _loadTask ??= _loadAllNotes();
  }

  Future<void> _loadAllNotes() async {
    try {
      await NativePlaybackAudioSession.ensurePlaybackActive();

      if (!_soLoud.isInitialized) {
        await _soLoud.init(
          sampleRate: 44100,
          bufferSize: 2048,
          channels: Channels.stereo,
        );
      }
      _soLoud.setMaxActiveVoiceCount(256);

      if (_sourcesByNote.isNotEmpty) {
        return;
      }

      for (final entry in kMusicCompanionPianoAssetByNote.entries) {
        final source = await _soLoud.loadAsset(
          entry.value,
          mode: LoadMode.memory,
        );
        _sourcesByNote[entry.key] = source;
      }
    } catch (error, stack) {
      _loadTask = null;
      debugPrint('SharedSoLoudPianoPool.ensureLoaded failed: $error\n$stack');
      rethrow;
    }
  }

  /// 在用户点击的**同一调用栈**内同步发声（iOS 必须，不能先 await 再 play）。
  bool tryPlayNote(String note, {double volume = 1}) {
    if (kIsWeb || !_soLoud.isInitialized) {
      return false;
    }
    final source = _sourcesByNote[note];
    if (source == null) {
      return false;
    }
    try {
      _soLoud.play(source, volume: volume);
      return true;
    } catch (error, stack) {
      debugPrint('SharedSoLoudPianoPool.tryPlayNote($note): $error\n$stack');
      return false;
    }
  }

  /// 手势链上的解锁：同步播放极轻音，不 await stop。
  bool tryUnlockProbe({String probeNote = 'C4'}) {
    return tryPlayNote(probeNote, volume: 0.02);
  }
}
