import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import '../audio/music_companion_audio_catalog.dart';
import '../audio/music_companion_audio_engine.dart';
import 'music_companion_state.dart';

final musicCompanionControllerProvider =
    StateNotifierProvider.autoDispose<
      MusicCompanionController,
      MusicCompanionState
    >((ref) {
      // 注意：StateNotifierProvider.autoDispose 会在 ref 被销毁时自动调用
      // controller.dispose()。如果再额外 `ref.onDispose(controller.dispose)`，
      // dispose 会被调用两次，第二次的 super.dispose() 会抛
      // "Tried to use ... after dispose"。所以这里不再手动注册 onDispose。
      return MusicCompanionController();
    });

class MusicCompanionController extends StateNotifier<MusicCompanionState> {
  MusicCompanionController({
    MusicCompanionAudioEngine? audioEngine,
    AudioRecorder? recorder,
  }) : _audioEngine = audioEngine ?? MusicCompanionAudioEngine(),
       _recorder = recorder ?? AudioRecorder(),
       _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 2048),
       super(MusicCompanionState.initial()) {
    unawaited(_prepareAudio());
  }

  final MusicCompanionAudioEngine _audioEngine;
  final AudioRecorder _recorder;
  final PitchDetector _pitchDetector;

  final Map<String, int> _pressedCounts = <String, int>{};
  final List<int> _tunerPcmBytes = <int>[];

  Timer? _metronomeTimer;
  Stopwatch? _metronomeStopwatch;
  int _metronomeGeneration = 0;
  int _metronomeTickCount = 0;
  double _metronomeLastTickMs = 0;

  StreamSubscription<Uint8List>? _tunerSubscription;

  Future<void> _prepareAudio() async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await NativePlaybackAudioSession.ensurePlaybackActive();
        await _audioEngine.ensurePianoInitialized();
        if (!mounted) return;
        state = state.copyWith(audioReady: true, errorMessage: null);
        return;
      } catch (error, stack) {
        debugPrint('MusicCompanion _prepareAudio($attempt): $error\n$stack');
        if (!mounted) return;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 320 * attempt));
          if (!mounted) return;
          continue;
        }
        state = state.copyWith(
          audioReady: false,
          errorMessage: '音乐伴侣音频初始化失败，请稍后重试。',
        );
      }
    }
  }

  Future<void> setTab(MusicCompanionTab tab) async {
    if (tab == state.activeTab) {
      return;
    }

    state = state.copyWith(activeTab: tab, errorMessage: null);

    if (tab != MusicCompanionTab.metronome) {
      _stopMetronome(resetBeat: true);
    }

    if (tab == MusicCompanionTab.tuner) {
      await NativePlaybackAudioSession.ensurePlayAndRecordActive();
      await startTuner();
    } else {
      await _stopTuner();
      if (tab != MusicCompanionTab.metronome) {
        unawaited(NativePlaybackAudioSession.ensurePlaybackActive());
      }
    }
  }

  Future<void> activateAudio() async {
    try {
      await NativePlaybackAudioSession.ensurePlaybackActive();
      if (!_audioEngine.isPianoReady) {
        await _audioEngine.ensurePianoInitialized();
      }
      if (!mounted) return;
      if (!_audioEngine.tryPlayNoteFromUserGesture('C4', volume: 0.02)) {
        await _audioEngine.activateByUserGesture();
      }
      if (!mounted) return;
      state = state.copyWith(audioReady: true, errorMessage: null);
    } catch (error, stack) {
      debugPrint('MusicCompanion activateAudio: $error\n$stack');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: state.audioReady
            ? '播放失败，请再试一次'
            : '音频尚未就绪，请稍候再试',
      );
    }
  }

  Future<void> pressPianoKey(String note) async {
    if (!mounted) return;
    _pressedCounts[note] = (_pressedCounts[note] ?? 0) + 1;
    state = state.copyWith(
      activePianoNotes: Set<String>.from(_pressedCounts.keys),
      errorMessage: null,
    );

    // iOS：必须在手势回调栈里同步 play，不能先 await 再 play。
    if (_audioEngine.tryPlayNoteFromUserGesture(note)) {
      if (!state.audioReady) {
        state = state.copyWith(audioReady: true);
      }
      return;
    }

    try {
      await NativePlaybackAudioSession.ensurePlaybackActive();
      if (!_audioEngine.isPianoReady) {
        await _audioEngine.ensurePianoInitialized();
      }
      if (!mounted) return;
      if (_audioEngine.tryPlayNoteFromUserGesture(note)) {
        state = state.copyWith(audioReady: true, errorMessage: null);
        return;
      }
      await _audioEngine.playNote(note, volume: 1);
      if (!mounted) return;
      state = state.copyWith(audioReady: true, errorMessage: null);
    } catch (error, stack) {
      debugPrint('MusicCompanion pressPianoKey($note): $error\n$stack');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: state.audioReady
            ? '播放失败，请再按一次琴键'
            : '音频加载中，请稍候再试',
      );
    }
  }

  void releasePianoKey(String note) {
    final currentCount = _pressedCounts[note];
    if (currentCount == null) {
      return;
    }

    if (currentCount <= 1) {
      _pressedCounts.remove(note);
    } else {
      _pressedCounts[note] = currentCount - 1;
    }

    state = state.copyWith(
      activePianoNotes: Set<String>.from(_pressedCounts.keys),
    );
  }

  void togglePianoLabels() {
    state = state.copyWith(pianoLabelsVisible: !state.pianoLabelsVisible);
  }

  void increasePianoHeight() {
    state = state.copyWith(
      pianoHeight: (state.pianoHeight + 12).clamp(196, 260),
    );
  }

  void decreasePianoHeight() {
    state = state.copyWith(
      pianoHeight: (state.pianoHeight - 12).clamp(196, 260),
    );
  }

  void setMetronomeTone(int index) {
    if (index == state.metronomeToneIndex) {
      return;
    }
    state = state.copyWith(metronomeToneIndex: index);
    _restartMetronomeIfNeeded();
  }

  void setMetronomeSignature(int index) {
    if (index == state.metronomeSignatureIndex) {
      return;
    }
    state = state.copyWith(
      metronomeSignatureIndex: index,
      metronomeActiveBeat: -1,
    );
    _restartMetronomeIfNeeded();
  }

  void setMetronomeBpm(double bpm) {
    final next = bpm.round().clamp(15, 300);
    if (next == state.metronomeBpm) {
      return;
    }
    state = state.copyWith(metronomeBpm: next);
    _restartMetronomeIfNeeded();
  }

  void nudgeMetronomeBpm(int delta) {
    setMetronomeBpm((state.metronomeBpm + delta).toDouble());
  }

  Future<void> toggleMetronome() async {
    if (state.metronomePlaying) {
      _stopMetronome(resetBeat: true);
      return;
    }
    await _startMetronome();
  }

  Future<void> _startMetronome() async {
    try {
      await NativePlaybackAudioSession.ensurePlaybackActive();
      await _audioEngine.ensureMetronomeInitialized();
      await activateAudio();
    } catch (error, stack) {
      debugPrint('MusicCompanion _startMetronome init: $error\n$stack');
      if (!mounted) return;
      state = state.copyWith(errorMessage: '节拍器音频加载失败，请稍后重试。');
      return;
    }
    if (!mounted) return;
    _stopMetronome(resetBeat: false);

    state = state.copyWith(
      metronomePlaying: true,
      metronomeActiveBeat: -1,
      errorMessage: null,
    );

    _metronomeGeneration += 1;
    _metronomeTickCount = 0;
    _metronomeLastTickMs = 0;
    _metronomeStopwatch = Stopwatch()..start();

    _scheduleMetronomeTick(_metronomeGeneration);
  }

  void _scheduleMetronomeTick(int generation) {
    if (!state.metronomePlaying || generation != _metronomeGeneration) {
      return;
    }

    final stopwatch = _metronomeStopwatch;
    if (stopwatch == null) {
      return;
    }

    final beatIntervalMs = 60000 / state.metronomeBpm;
    final elapsedMs = stopwatch.elapsedMicroseconds / 1000;
    final sinceLastTickMs = elapsedMs - _metronomeLastTickMs;

    if (sinceLastTickMs >= beatIntervalMs) {
      _metronomeLastTickMs = elapsedMs - (sinceLastTickMs % beatIntervalMs);
      final beatIndex = _metronomeTickCount % state.activeSignature.numerator;
      state = state.copyWith(metronomeActiveBeat: beatIndex);
      final cue = _resolveMetronomeCue(beatIndex);
      final vol = beatIndex == 0 ? 1.0 : 0.92;
      if (!_audioEngine.tryPlayMetronomeCueFromUserGesture(cue, volume: vol)) {
        unawaited(_audioEngine.playMetronomeCue(cue, volume: vol));
      }
      _metronomeTickCount += 1;
    }

    final nextElapsedMs = stopwatch.elapsedMicroseconds / 1000;
    final remainingMs =
        (beatIntervalMs - (nextElapsedMs - _metronomeLastTickMs)).clamp(
          1,
          beatIntervalMs,
        );

    _metronomeTimer = Timer(
      Duration(milliseconds: remainingMs.ceil()),
      () => _scheduleMetronomeTick(generation),
    );
  }

  MusicCompanionMetronomeCue _resolveMetronomeCue(int beatIndex) {
    switch (state.metronomeToneIndex) {
      case 0:
        return beatIndex == 0
            ? MusicCompanionMetronomeCue.tone1Accent
            : MusicCompanionMetronomeCue.tone1Regular;
      case 1:
        if (beatIndex == 0) {
          return MusicCompanionMetronomeCue.tone2Accent;
        }
        if ((state.metronomeSignatureIndex == 7 && beatIndex == 3) ||
            (state.metronomeSignatureIndex == 9 && beatIndex == 2)) {
          return MusicCompanionMetronomeCue.tone2Special;
        }
        return MusicCompanionMetronomeCue.tone2Regular;
      default:
        return switch (beatIndex) {
          0 => MusicCompanionMetronomeCue.tone3Beat1,
          1 => MusicCompanionMetronomeCue.tone3Beat2,
          2 => MusicCompanionMetronomeCue.tone3Beat3,
          3 => MusicCompanionMetronomeCue.tone3Beat4,
          4 => MusicCompanionMetronomeCue.tone3Beat5,
          5 => MusicCompanionMetronomeCue.tone3Beat6,
          6 => MusicCompanionMetronomeCue.tone3Beat7,
          7 => MusicCompanionMetronomeCue.tone3Beat8,
          8 => MusicCompanionMetronomeCue.tone3Beat9,
          9 => MusicCompanionMetronomeCue.tone3Beat10,
          10 => MusicCompanionMetronomeCue.tone3Beat11,
          _ => MusicCompanionMetronomeCue.tone3Beat12,
        };
    }
  }

  void _restartMetronomeIfNeeded() {
    if (!state.metronomePlaying) {
      return;
    }
    unawaited(_startMetronome());
  }

  void _stopMetronome({required bool resetBeat}) {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    _metronomeStopwatch?.stop();
    _metronomeStopwatch = null;
    _metronomeTickCount = 0;
    _metronomeLastTickMs = 0;
    _metronomeGeneration += 1;

    state = state.copyWith(
      metronomePlaying: false,
      metronomeActiveBeat: resetBeat ? -1 : state.metronomeActiveBeat,
    );
  }

  Future<void> startTuner() async {
    if (state.tunerListening) {
      return;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!mounted) return;
      if (!hasPermission) {
        state = state.copyWith(
          tunerPermissionGranted: false,
          tunerListening: false,
          errorMessage: '调音器需要麦克风权限，请先授权。',
        );
        return;
      }

      await _stopTuner();
      if (!mounted) return;
      _tunerPcmBytes.clear();

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
      );
      if (!mounted) {
        // 已经 dispose，立刻把刚启动的录音流关掉
        try {
          await _recorder.stop();
        } catch (_) {}
        return;
      }

      state = state.copyWith(
        tunerPermissionGranted: true,
        tunerListening: true,
        errorMessage: null,
      );

      _tunerSubscription = stream.listen(
        (chunk) {
          if (!mounted) return;
          unawaited(_handleTunerChunk(chunk));
        },
        onError: (_) {
          if (!mounted) return;
          state = state.copyWith(
            tunerListening: false,
            errorMessage: '调音器启动失败，请检查设备麦克风。',
          );
        },
        cancelOnError: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        tunerListening: false,
        tunerPermissionGranted: false,
        errorMessage: '当前设备暂不支持实时调音检测。',
      );
    }
  }

  Future<void> retryTunerPermission() => startTuner();

  void setTunerReferenceFrequency(int value) {
    final next = value.clamp(430, 450);
    if (next == state.tunerReferenceFrequency) {
      return;
    }
    state = state.copyWith(tunerReferenceFrequency: next);
  }

  void nudgeTunerReferenceFrequency(int delta) {
    setTunerReferenceFrequency(state.tunerReferenceFrequency + delta);
  }

  Future<void> _handleTunerChunk(Uint8List chunk) async {
    if (!mounted) return;
    const frameSize = 4096;
    _tunerPcmBytes.addAll(chunk);
    if (_tunerPcmBytes.length < frameSize) {
      return;
    }

    if (_tunerPcmBytes.length > frameSize * 3) {
      _tunerPcmBytes.removeRange(0, _tunerPcmBytes.length - frameSize * 2);
    }

    final frame = Uint8List.fromList(
      _tunerPcmBytes.sublist(_tunerPcmBytes.length - frameSize),
    );

    final result = await _pitchDetector.getPitchFromIntBuffer(frame);
    if (!mounted) return;
    final pitched =
        result.pitched && result.probability > 0.78 && result.pitch > 0;

    if (!pitched) {
      return;
    }

    final frequency = result.pitch;
    final noteData = _noteDataFromPitch(frequency);

    state = state.copyWith(
      tunerListening: true,
      tunerPermissionGranted: true,
      tunerDetectedFrequency: double.parse(frequency.toStringAsFixed(1)),
      tunerNote: noteData.$1,
      tunerCents: noteData.$2.clamp(-50, 50),
      errorMessage: null,
    );
  }

  (String, double) _noteDataFromPitch(double frequency) {
    final midiValue =
        69 +
        12 * (math.log(frequency / state.tunerReferenceFrequency) / math.ln2);
    final nearestMidi = midiValue.round();
    const noteNames = <String>[
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final noteName = noteNames[(nearestMidi % 12 + 12) % 12];
    final targetFrequency =
        state.tunerReferenceFrequency *
        math.pow(2, (nearestMidi - 69) / 12).toDouble();
    final cents = 1200 * (math.log(frequency / targetFrequency) / math.ln2);
    return (noteName, cents);
  }

  Future<void> _stopTuner() async {
    await _tunerSubscription?.cancel();
    _tunerSubscription = null;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {
      // 录音器可能已经被释放，吞掉异常即可
    }

    if (mounted && state.tunerListening) {
      state = state.copyWith(tunerListening: false);
    }
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(errorMessage: null);
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;

    // 1) 同步取消所有定时器与流订阅，避免后续回调再访问 state。
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    _metronomeStopwatch?.stop();
    _metronomeStopwatch = null;
    _metronomeGeneration += 1;

    final tunerSub = _tunerSubscription;
    _tunerSubscription = null;

    // 2) 先调用 super.dispose()，标记 mounted = false。
    super.dispose();

    // 3) 异步释放外部资源（音频引擎、录音器），整个过程不再读写 state。
    unawaited(() async {
      try {
        await tunerSub?.cancel();
      } catch (_) {}
      try {
        if (await _recorder.isRecording()) {
          await _recorder.stop();
        }
      } catch (_) {}
      try {
        await _audioEngine.stopAll();
      } catch (_) {}
      try {
        await _audioEngine.dispose();
      } catch (_) {}
      try {
        await _recorder.dispose();
      } catch (_) {}
    }());
  }
}
