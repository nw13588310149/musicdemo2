import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../music_companion/audio/music_companion_audio_engine.dart';
import '../data/music_play_repository.dart';
import 'music_play_state.dart';

final musicPlayControllerProvider = StateNotifierProvider.autoDispose
    .family<MusicPlayController, MusicPlayState, MusicPlayPageArgs>((
      ref,
      args,
    ) {
      final repository = ref.watch(musicPlayRepositoryProvider);
      final controller = MusicPlayController(
        repository: repository,
        args: args,
      );
      return controller;
    });

class MusicPlayController extends StateNotifier<MusicPlayState> {
  MusicPlayController({
    required this.repository,
    required MusicPlayPageArgs args,
  }) : _pianoEngine = MusicCompanionAudioEngine(),
       super(MusicPlayState.initial(args)) {
    unawaited(_initialize());
  }

  final MusicPlayRepository repository;
  final MusicCompanionAudioEngine _pianoEngine;

  /// 主音频播放器：使用 `media_kit` 在 native（iOS/Android/Desktop）
  /// 与 Web 上提供"倍速 + 升降调"双独立旋钮：
  /// - [Player.setRate] —— 变速保音高（mpv 默认开启 audio-pitch-correction）；
  /// - [Player.setPitch] —— 独立的半音变调（speed 不动）。
  /// 钢琴弹奏仍然走 [MusicCompanionAudioEngine]（基于 SoLoud），与此处互不影响。
  Player? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  bool _recordSaved = false;

  /// 已经 dispose 的标志位。
  ///
  /// `dispose()` 中第一时间置位，让任何还在 await 的异步链（[togglePlay]、
  /// [pressPianoKey]、[_openActiveTrack] 等）都能在拿到 `player.open(...)`
  /// 之前 short-circuit 退出，避免页面消失之后还冒出一声 "ding"。
  bool _disposed = false;

  /// `_openActiveTrack` 并发自增票据。
  ///
  /// iPad 上动作较快时，用户连点 1 次播放或快速翻页，会让两次
  /// `_openActiveTrack` 并发：两次都各自调 `player.open(...)`，
  /// 出现"两个音频同时在响"。这里用最经典的 ticket 方案：每次进入
  /// 自增 1，await 之后比对，落后的那次直接放弃。
  int _openTicket = 0;

  // ── 进度条 seek 合并 ────────────────────────────────────────────────
  // iPad 上拖进度条时，60–120Hz 的 onHorizontalDragUpdate 会让每个手势
  // 帧都触发一次 native `player.seek()`。mpv 的 seek 是 platform 往返
  // 调用（50–150ms / 次），不做合并就会出现"队列堆积 → 松手后还在追
  // 历史目标"的体验。下面三个字段实现：
  //   1. 同时只允许一次 native seek 在飞 (`_seekInFlight`)；
  //   2. 中间帧的目标只记到 `_pendingSeek`，最新的会覆盖旧的 —— 松手
  //      时一定收敛到最新手指位置；
  //   3. seek 发起后 ~350ms 内，`player.stream.position` 还可能吐 mpv
  //      "尚未跳到"前的旧位置，用 `_seekFilterUntil` + `_lastSeekTarget`
  //      把这些远离目标 (>500ms) 的事件丢弃，避免 thumb 看到"先回弹
  //      再前进"的鬼影。
  bool _seekInFlight = false;
  Duration? _pendingSeek;
  Duration? _lastSeekTarget;
  DateTime? _seekFilterUntil;
  static const Duration _kSeekStaleWindow = Duration(milliseconds: 350);
  static const int _kSeekStaleDiffMs = 500;

  /// 把半音数转为 [Player.setPitch] 接受的频率倍率（2^(n/12)）。
  static double _pitchRatio(int semitones) =>
      math.pow(2, semitones / 12.0).toDouble();

  /// "随机循环" 用的随机源。整个 controller 生命周期共用一个实例，避免每次
  /// 抽下一首都重新 seed → 在系统时钟低分辨率的设备（部分 Android）上连出
  /// 同一个数字的尴尬。
  final math.Random _shuffleRandom = math.Random();

  /// 在 [total] 个 track 中给"随机循环"挑一个**不等于** [currentIdx] 的下标。
  ///
  /// 经典 "skip-current" 写法：从 `total - 1` 个候选里 [Random.nextInt]，
  /// 拿到的下标若 `>= currentIdx` 再 +1，等价于把当前 track 从候选集里抽掉。
  /// 这样保证：
  ///   - 不会立即重复同一首（用户对 "随机" 的最低期待）；
  ///   - 仍然每首都有 `1/(N-1)` 的概率被抽到，分布均匀。
  int _shuffleNextIndex(int currentIdx, int total) {
    if (total <= 1) {
      return 0;
    }
    final n = _shuffleRandom.nextInt(total - 1);
    return n >= currentIdx ? n + 1 : n;
  }

  Future<void> _initialize() async {
    unawaited(_warmUpPiano());
    try {
      await loadDetail(state.args.id, preserveShowAnswer: false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: '页面初始化失败，请稍后重试');
    }
  }

  Future<void> _warmUpPiano() async {
    try {
      await _pianoEngine.ensurePianoInitialized();
      if (!mounted) {
        return;
      }
      state = state.copyWith(ready: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(ready: false);
    }
  }

  Future<void> loadDetail(int id, {required bool preserveShowAnswer}) async {
    if (id <= 0) {
      state = state.copyWith(loading: false, errorMessage: '教材参数无效，无法打开播放页');
      return;
    }

    state = state.copyWith(
      loading: true,
      errorMessage: '',
      position: Duration.zero,
      duration: Duration.zero,
      isPlaying: false,
      frequencyBands: const <double>[],
    );

    final responses = await Future.wait<ApiResponse>(<Future<ApiResponse>>[
      repository.getDetail(id),
      repository.getMyInfo(),
    ]);
    if (!mounted) {
      return;
    }

    final detailResponse = responses[0];
    final infoResponse = responses[1];
    if (!detailResponse.isSuccess ||
        detailResponse.data is! Map<String, dynamic>) {
      state = state.copyWith(
        loading: false,
        errorMessage: detailResponse.msg.isEmpty
            ? '加载教材详情失败'
            : detailResponse.msg,
      );
      return;
    }

    final detailMap = detailResponse.data as Map<String, dynamic>;
    final detail = _parseDetail(detailMap);
    if (detail.vipOnly && !_hasVipAccess(infoResponse.data)) {
      state = state.copyWith(
        loading: false,
        errorMessage: '当前内容需要会员权限，请先开通或续费会员',
      );
      return;
    }

    final nextShowAnswer = preserveShowAnswer
        ? state.showAnswer
        : _defaultShowAnswer(state.args.type, detail);

    final nextPitch = detail.hidePitchShift ? 0 : state.pitchSemitones;

    state = state.copyWith(
      loading: false,
      detail: detail,
      showAnswer: nextShowAnswer,
      activeImageIndex: 0,
      activeTrackIndex: 0,
      pitchSemitones: nextPitch,
      clearErrorMessage: true,
    );

    _recordSaved = false;
    await _openActiveTrack(play: false);
  }

  Future<void> togglePlay() async {
    if (_disposed) return;
    final track = state.activeTrack;
    if (track == null) {
      return;
    }

    final player = _player;
    if (player == null || state.duration == Duration.zero) {
      await _openActiveTrack(play: true);
      return;
    }
    // 应用户反馈：iPad 上点暂停 / 播放、拖进度条时会出现"呲/咔哒"杂音，
    // 上课接音响尤其明显。原因是 mpv 在 pause/play/seek 切点会让音频
    // 输出环里的 PCM 出现不连续——任何一次振幅过 0 的硬切都会被喇叭
    // 当成 step function 还原成 click。下面统一改成"音量渐变窗"：把
    // 切点包在一段 fade-out → op → fade-in 里，让不连续落在静音区间。
    if (state.isPlaying) {
      await _withFadedAudio(player, () => player.pause());
    } else {
      // 播放分支：当前是 paused 状态本来就无声，不需要 fade out（否则
      // 白白延迟 ~80ms 才出声，按键体感发木）。直接把音量压到 0、
      // 立刻 play、再 fade in，按键灵敏 + 无 click。
      try {
        await player.setVolume(0);
      } catch (_) {}
      try {
        await player.play();
      } catch (_) {}
      if (!_disposed) {
        await Future.delayed(const Duration(milliseconds: 25));
      }
      if (!_disposed) {
        await _fadeVolume(player, 0, 100, durationMs: 90);
      }
    }
  }

  /// 在 mpv 上做一次"音量渐变"：分 [steps] 步、在 [durationMs] 内
  /// 用 smoothstep 曲线从 [from] 平滑过渡到 [to]。
  ///
  /// 为什么不能直接 `setVolume(0)` 硬切：
  ///   1. mpv 的 setVolume 通过 IPC 异步送到 native 音频线程，await
  ///      返回 ≠ 实际生效，中间还有 5–30ms 抖动；
  ///   2. native 输出环里通常已经塞了 ~100ms 旧 PCM，硬切到 0 时这
  ///      一段还是会被推到喇叭，pop 仍然听得到；
  ///   3. 硬切自身就是 step function，振幅过 0 那一帧本身就是 click。
  ///
  /// 多步小幅 setVolume + smoothstep 把 step 拆成连续小台阶，听感上
  /// 就是平滑的"音量淡进淡出"，pop 被洗掉。
  Future<void> _fadeVolume(
    Player player,
    double from,
    double to, {
    int durationMs = 80,
    int steps = 8,
  }) async {
    if (_disposed) return;
    if (steps <= 1 || (from - to).abs() < 0.5) {
      try {
        await player.setVolume(to.clamp(0, 100).toDouble());
      } catch (_) {}
      return;
    }
    final stepDelay = math.max(1, durationMs ~/ steps);
    for (var i = 1; i <= steps; i++) {
      if (_disposed) return;
      final t = i / steps;
      final eased = t * t * (3 - 2 * t);
      final v = from + (to - from) * eased;
      try {
        await player.setVolume(v.clamp(0, 100).toDouble());
      } catch (_) {}
      if (i < steps) {
        await Future.delayed(Duration(milliseconds: stepDelay));
      }
    }
  }

  /// 把任何会产生 pop 的切点（pause/play/seek 等）包进
  /// 「fade-out → 等 mpv 输出环 drain → op → 等新帧 push 进来 → fade-in」
  /// 这一整段静音窗里。替代原先硬切 mute 的做法，是 iPad 上消除"呲"声
  /// 的关键。
  ///
  /// - [fadeOutMs] 渐隐时长，覆盖 mpv 当前帧到 0 振幅；
  /// - [holdBeforeMs] 渐隐到底后再多压一会儿，让 native audio 输出环
  ///   把"还在路上的"旧 PCM 全部推完；
  /// - [op] 真正的切点操作（pause / play / seek...）；
  /// - [holdAfterMs] op 后再静音一会儿，让 mpv 把目标位置的新 PCM 推
  ///   到输出环；如果立刻 fade in 会先听到旧位置/静默残响，反而显眼；
  /// - [fadeInMs] 渐升时长，让目标位置的音频从 0 平滑变响。
  Future<void> _withFadedAudio(
    Player player,
    Future<void> Function() op, {
    int fadeOutMs = 60,
    int holdBeforeMs = 25,
    int holdAfterMs = 70,
    int fadeInMs = 90,
  }) async {
    await _fadeVolume(player, 100, 0, durationMs: fadeOutMs);
    if (holdBeforeMs > 0 && !_disposed) {
      await Future.delayed(Duration(milliseconds: holdBeforeMs));
    }
    try {
      await op();
    } finally {
      if (!_disposed) {
        if (holdAfterMs > 0) {
          await Future.delayed(Duration(milliseconds: holdAfterMs));
        }
        if (!_disposed) {
          await _fadeVolume(player, 0, 100, durationMs: fadeInMs);
        }
      }
    }
  }

  Future<void> previous() async {
    if (_disposed) return;
    if (state.args.allLessonIds.isNotEmpty) {
      await _switchLesson(-1);
      return;
    }
    final detail = state.detail;
    if (detail == null || detail.tracks.length <= 1) {
      await seek(Duration.zero);
      return;
    }
    // "随机循环"模式下，"上一首"也走随机抽取：用户既然选了随机，下一/上一
    // 都按随机来更符合直觉（避免出现"上一首明明刚听过"的体验割裂）。
    final previousIndex = state.playMode == MusicPlayMode.shuffle
        ? _shuffleNextIndex(state.activeTrackIndex, detail.tracks.length)
        : (state.activeTrackIndex <= 0
            ? detail.tracks.length - 1
            : state.activeTrackIndex - 1);
    state = state.copyWith(
      activeTrackIndex: previousIndex,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  Future<void> next() async {
    if (_disposed) return;
    if (state.args.allLessonIds.isNotEmpty) {
      await _switchLesson(1);
      return;
    }
    final detail = state.detail;
    if (detail == null || detail.tracks.length <= 1) {
      await seek(Duration.zero);
      return;
    }
    // 随机循环：next 等价于"再随机抽一首"；其它模式按顺序推进 + 末尾回环。
    final nextIndex = state.playMode == MusicPlayMode.shuffle
        ? _shuffleNextIndex(state.activeTrackIndex, detail.tracks.length)
        : (state.activeTrackIndex >= detail.tracks.length - 1
            ? 0
            : state.activeTrackIndex + 1);
    state = state.copyWith(
      activeTrackIndex: nextIndex,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final nextSpeed = speed.clamp(0.5, 2.0);
    final player = _player;
    if (player != null) {
      try {
        // mpv 默认 audio-pitch-correction=yes：变速不变调。
        // Web 端 HTML5 audio 的浏览器默认也保留音高。
        await player.setRate(nextSpeed);
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    state = state.copyWith(speed: nextSpeed);
  }

  /// 独立的"升降调"控制（半音）。与 [setPlaybackSpeed] 完全解耦：
  /// 内部走 [Player.setPitch]，半音 N → 频率倍率 2^(N/12)。
  Future<void> setPitchSemitones(int semitones) async {
    if (state.detail?.hidePitchShift == true) {
      return;
    }
    final next = semitones.clamp(-12, 12);
    final player = _player;
    if (player != null) {
      try {
        await player.setPitch(_pitchRatio(next));
      } catch (_) {
        // Web/部分平台对 setPitch 不一定支持，静默吞掉，
        // UI 层依旧按照所选半音数显示。
      }
    }
    if (!mounted) {
      return;
    }
    state = state.copyWith(pitchSemitones: next);
  }

  /// 切换"循环模式"：顺序 → 单曲循环 → 随机循环 → 顺序。
  /// 仅在多曲目场景下有意义，单曲目时也允许调用但不会影响实际行为。
  void togglePlayMode() {
    final next = switch (state.playMode) {
      MusicPlayMode.sequence => MusicPlayMode.single,
      MusicPlayMode.single => MusicPlayMode.shuffle,
      MusicPlayMode.shuffle => MusicPlayMode.sequence,
    };
    state = state.copyWith(playMode: next);
  }

  /// 直接跳到曲目列表中的指定索引并播放。
  /// 用户在"播放列表"菜单中点击某一项时调用；与 [previous] / [next] 共享
  /// 同一套 ticket 化的 `_openActiveTrack`，避免连点产生双声。
  Future<void> selectTrack(int index) async {
    if (_disposed) return;
    final detail = state.detail;
    if (detail == null || detail.tracks.isEmpty) {
      return;
    }
    final safe = index.clamp(0, detail.tracks.length - 1);
    if (safe == state.activeTrackIndex) {
      // 同一首：从头重播（同时承担"单曲循环"自动续播的语义）。
      await seek(Duration.zero);
      final player = _player;
      if (player != null) {
        try {
          await player.play();
        } catch (_) {}
      }
      return;
    }
    state = state.copyWith(
      activeTrackIndex: safe,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  Future<void> seek(Duration position) async {
    final max = state.duration;
    final safe = max == Duration.zero
        ? position
        : Duration(
            milliseconds: position.inMilliseconds.clamp(0, max.inMilliseconds),
          );

    // 1) 已有 seek 在飞 → 只更新 pending 目标 + 乐观刷 UI 后立刻返回，
    //    让正在跑的 seek 循环跑完当前帧后接到最新目标。这样无论拖多快，
    //    native 端始终只有一条 seek 在排队。
    if (_seekInFlight) {
      _pendingSeek = safe;
      _lastSeekTarget = safe;
      _seekFilterUntil = DateTime.now().add(_kSeekStaleWindow);
      if (mounted) {
        state = state.copyWith(position: safe);
      }
      return;
    }

    // 2) 空闲：拿到飞行权 → 进入 seek 循环。每轮跑完后看 `_pendingSeek`，
    //    若有更新过的目标就继续跑下一轮；否则退出。
    _seekInFlight = true;
    Duration target = safe;
    _lastSeekTarget = target;
    _seekFilterUntil = DateTime.now().add(_kSeekStaleWindow);
    if (mounted) {
      state = state.copyWith(position: target);
    }

    // iPad 上拖进度条会持续产生 pop——把整段 seek 循环包在一段
    // fade-out → 反复 seek → 等输出环吐出目标位置 PCM → fade-in 的
    // 静音窗里。比原先"硬切 setVolume(0)"更彻底：硬切对 mpv 的 IPC
    // setVolume 来说不是即时生效（参见 [_fadeVolume] 的注释），输出
    // 环里的旧帧仍会被推到喇叭；多步渐隐才能真正盖掉切点的 click。
    Player? mutedPlayer;
    try {
      mutedPlayer = _player;
      if (mutedPlayer != null) {
        await _fadeVolume(mutedPlayer, 100, 0, durationMs: 60);
      }
      while (true) {
        final player = _player;
        if (player == null) {
          break;
        }
        try {
          await player.seek(target);
        } catch (_) {}

        final pending = _pendingSeek;
        if (pending != null && pending != target) {
          target = pending;
          _pendingSeek = null;
          _lastSeekTarget = target;
          _seekFilterUntil = DateTime.now().add(_kSeekStaleWindow);
          if (mounted) {
            state = state.copyWith(position: target);
          }
          continue;
        }
        _pendingSeek = null;
        break;
      }
    } finally {
      _seekInFlight = false;
      // 用户松手后，再多压 ~120ms 让 mpv 把目标位置的新 PCM 推到输出
      // 环；否则会先听到一段"啊—"或杂音再切到目标音乐，比原来的 pop
      // 更刺耳。然后用 fade-in 平滑恢复，避免恢复瞬间又出 click。
      final p = mutedPlayer;
      if (p != null && !_disposed) {
        try {
          await Future.delayed(const Duration(milliseconds: 120));
          if (!_disposed) {
            await _fadeVolume(p, 0, 100, durationMs: 90);
          }
        } catch (_) {}
      }
    }
  }

  Future<void> toggleFavorite() async {
    final detail = state.detail;
    if (detail == null) {
      return;
    }
    final nextFavorite = !detail.favorite;
    final response = await repository.setFavorite(
      targetId: detail.id,
      type: detail.type,
      favorite: nextFavorite,
    );
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        errorMessage: response.msg.isEmpty ? '收藏状态更新失败' : response.msg,
      );
      return;
    }
    state = state.copyWith(
      detail: MusicPlayDetail(
        id: detail.id,
        type: detail.type,
        title: detail.title,
        subtitle: detail.subtitle,
        shortText1: detail.shortText1,
        shortText2: detail.shortText2,
        coverUrl: detail.coverUrl,
        favorite: nextFavorite,
        vipOnly: detail.vipOnly,
        questionImages: detail.questionImages,
        answerImages: detail.answerImages,
        tracks: detail.tracks,
        longTextHtml: detail.longTextHtml,
        firstMenu: detail.firstMenu,
      ),
    );
  }

  void setShowAnswer(bool value) {
    if (value == state.showAnswer) {
      return;
    }
    state = state.copyWith(showAnswer: value, activeImageIndex: 0);
  }

  void setImageIndex(int index) {
    final images = state.visibleImages;
    if (images.isEmpty) {
      return;
    }
    final safe = index.clamp(0, images.length - 1);
    state = state.copyWith(activeImageIndex: safe);
  }

  Future<void> pressPianoKey(String note) async {
    if (_disposed) return;
    final active = Set<String>.from(state.activePianoNotes)..add(note);
    state = state.copyWith(activePianoNotes: active);
    await _pianoEngine.ensurePianoInitialized();
    if (!mounted || _disposed) {
      return;
    }
    await _pianoEngine.activateByUserGesture();
    if (!mounted || _disposed) {
      return;
    }
    if (!state.ready) {
      state = state.copyWith(ready: true);
    }
    await _pianoEngine.playNote(note);
  }

  void releasePianoKey(String note) {
    final active = Set<String>.from(state.activePianoNotes)..remove(note);
    state = state.copyWith(activePianoNotes: active);
  }

  void clearError() {
    if (state.errorMessage.isEmpty) {
      return;
    }
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<void> openShareDialog() async {
    state = state.copyWith(
      shareDialogVisible: true,
      classLoading: state.classList.isEmpty,
      clearErrorMessage: true,
    );
    final response = await repository.getClassList();
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        classLoading: false,
        errorMessage: response.msg.isEmpty ? '获取班级群失败' : response.msg,
      );
      return;
    }
    final raw = response.data;
    final list = <MusicPlayShareClass>[];
    if (raw is List) {
      for (final node in raw) {
        if (node is Map) {
          list.add(MusicPlayShareClass.fromJson(node));
        }
      }
    }
    state = state.copyWith(classList: list, classLoading: false);
  }

  void closeShareDialog() {
    state = state.copyWith(shareDialogVisible: false);
  }

  void toggleClass(String classId) {
    state = state.copyWith(
      classList: <MusicPlayShareClass>[
        for (final cls in state.classList)
          if (cls.id == classId) cls.copyWith(checked: !cls.checked) else cls,
      ],
    );
  }

  Future<bool> sendShare() async {
    final detail = state.detail;
    if (detail == null) {
      return false;
    }
    final selected = state.classList
        .where((cls) => cls.checked && cls.id.isNotEmpty)
        .toList();
    if (selected.isEmpty) {
      final hasChecked = state.classList.any((cls) => cls.checked);
      state = state.copyWith(
        errorMessage: hasChecked ? '所选班级数据异常，请刷新后重试' : '请先选择要分享的班级群',
      );
      return false;
    }

    state = state.copyWith(sending: true, clearErrorMessage: true);
    final content = jsonEncode(<String, dynamic>{
      'id': detail.id,
      'title': detail.title,
      'type': detail.type,
      'shortText3': detail.coverUrl,
      'subtitle': detail.subtitle,
    });

    for (final cls in selected) {
      final response = await repository.sendMsg(
        classId: cls.id,
        content: content,
      );
      if (!mounted) {
        return false;
      }
      if (!response.isSuccess) {
        state = state.copyWith(
          sending: false,
          errorMessage: response.msg.isEmpty ? '发送失败' : response.msg,
        );
        return false;
      }
    }

    state = state.copyWith(
      sending: false,
      shareDialogVisible: false,
      errorMessage: '消息已成功发送',
    );
    return true;
  }

  Future<void> _switchLesson(int delta) async {
    final ids = state.args.allLessonIds;
    if (ids.isEmpty) {
      return;
    }
    final currentIndex = ids.indexOf(state.args.id);
    if (currentIndex == -1) {
      return;
    }
    final nextIndex = (currentIndex + delta) % ids.length;
    final safeIndex = nextIndex < 0 ? ids.length - 1 : nextIndex;
    final nextId = ids[safeIndex];
    final nextArgs = MusicPlayPageArgs(
      id: nextId,
      type: state.args.type,
      allLessonIds: ids,
      // 切到下一节时保留入口侧的 autoPlayNext / closedByDefault 语义，否则
      // 节奏 / 旋律 自动跳到下一节后会因为 args 重置而失去自动续播能力。
      autoPlayNext: state.args.autoPlayNext,
      closedByDefault: state.args.closedByDefault,
    );
    state = state.copyWith(args: nextArgs);
    await loadDetail(nextId, preserveShowAnswer: false);
  }

  Future<void> _openActiveTrack({required bool play}) async {
    final track = state.activeTrack;
    if (track == null || track.url.isEmpty) {
      return;
    }

    // 每次进入即抢占 ticket；之后任何一个 await 之后都比一下当前 ticket，
    // 不一致就当成"自己已被新一次 open 取代"处理。
    final ticket = ++_openTicket;
    bool isStale() => _disposed || ticket != _openTicket;

    try {
      if (isStale()) return;
      final player = _ensurePlayer();
      debugPrint('MusicPlay audio open: ${track.url}');
      // 切歌前可能 seek/pause 的 fade 流程被 ticket 抢占或 dispose
      // 中断，留下 setVolume 还停在 0 的状态。这里在新 track 打开前
      // 显式回到 100，避免"切下一首没声音"的玄学 bug。
      try {
        await player.setVolume(100);
      } catch (_) {}
      await player.open(Media(track.url), play: play);
      if (isStale()) return;
      try {
        await player.setRate(state.speed);
      } catch (_) {}
      try {
        final semitones = state.detail?.hidePitchShift == true
            ? 0
            : state.pitchSemitones;
        await player.setPitch(_pitchRatio(semitones));
      } catch (_) {}
    } catch (error) {
      if (isStale()) return;
      debugPrint('MusicPlay audio load failed: $error');
      if (mounted) {
        state = state.copyWith(errorMessage: '音频加载失败，请稍后重试');
      }
    }
  }

  Player _ensurePlayer() {
    final current = _player;
    if (current != null) {
      return current;
    }
    // 关键：必须把 PlayerConfiguration.pitch 打开，
    // 否则 [Player.setPitch] 会抛 `ArgumentError('PlayerConfiguration.pitch is false')`，
    // 导致升降调在 native 端无效（UI 变了但声音不变）。
    // 该选项会让 mpv 关闭 audio-pitch-correction 并改用 scaletempo 滤镜，
    // 实现"独立倍速 + 独立音高"。Web 端 setPitch 仍然不支持，会被 try/catch 吞掉。
    final player = Player(
      configuration: const PlayerConfiguration(pitch: true),
    );
    _player = player;
    _bindPlayerStreams(player);
    return player;
  }

  void _bindPlayerStreams(Player player) {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();

    _positionSub = player.stream.position.listen((position) {
      if (!mounted) {
        return;
      }
      // seek 触发后短暂窗口（350ms）内，mpv 仍可能把"还没跳到目标"前的
      // 旧位置流回来。如果直接 copy 进 state，UI thumb 会看到"先回弹
      // 再前进"。这里把距离目标超过 500ms 的事件丢弃；一旦看到接近
      // 目标的位置就立刻解除过滤，避免误伤后续真实的播放进度。
      final filterUntil = _seekFilterUntil;
      final target = _lastSeekTarget;
      if (filterUntil != null && target != null) {
        if (DateTime.now().isBefore(filterUntil)) {
          final diffMs =
              (position.inMilliseconds - target.inMilliseconds).abs();
          if (diffMs > _kSeekStaleDiffMs) {
            return;
          }
          _seekFilterUntil = null;
        } else {
          _seekFilterUntil = null;
        }
      }
      state = state.copyWith(position: position);
    });
    _durationSub = player.stream.duration.listen((duration) {
      if (mounted) {
        state = state.copyWith(duration: duration);
      }
    });
    _playingSub = player.stream.playing.listen((playing) {
      if (mounted) {
        state = state.copyWith(isPlaying: playing);
      }
    });
    _completedSub = player.stream.completed.listen((completed) async {
      if (completed && mounted) {
        await _handleTrackCompleted();
      }
    });
  }

  Future<void> _handleTrackCompleted() async {
    if (_disposed) return;
    final detail = state.detail;
    if (detail == null) {
      return;
    }

    if (!_recordSaved && (state.args.type == 3 || detail.type == 1)) {
      _recordSaved = true;
      unawaited(repository.saveStudyRecord(detail.id));
    }

    final tracks = detail.tracks;
    final mode = state.playMode;

    // 单曲循环：始终回到当前曲——优先级最高，UI 显式选择，与入口无关。
    if (mode == MusicPlayMode.single) {
      await selectTrack(state.activeTrackIndex);
      return;
    }

    // 多 track 才有"列表/随机循环"的语义；_LoopModeChip 也只在 tracks > 1
    // 时显示，所以这里能进来必然是用户主动选的循环模式，应该一直循环下去，
    // 不受 autoPlayNext 影响（autoPlayNext 只决定"是否跨课跳到下一节"）。
    if (tracks.length > 1) {
      if (mode == MusicPlayMode.shuffle) {
        // 随机循环：永远在课内 N 条 track 中随机抽一条不同的继续播。
        final nextIdx = _shuffleNextIndex(state.activeTrackIndex, tracks.length);
        state = state.copyWith(
          activeTrackIndex: nextIdx,
          activeImageIndex: 0,
          position: Duration.zero,
          duration: Duration.zero,
          frequencyBands: const <double>[],
        );
        await _openActiveTrack(play: true);
        return;
      }

      if (mode == MusicPlayMode.sequence) {
        final nextIndex = state.activeTrackIndex + 1;
        if (nextIndex < tracks.length) {
          // 课内还有下一条，照常推进。
          state = state.copyWith(
            activeTrackIndex: nextIndex,
            activeImageIndex: 0,
            position: Duration.zero,
            duration: Duration.zero,
            frequencyBands: const <double>[],
          );
          await _openActiveTrack(play: true);
          return;
        }
        // 已经播到本节最后一条 track。两种走向：
        //  - autoPlayNext + 有 allLessonIds + 不是最后一节  → 跳到下一节自动播；
        //  - 否则                                          → 回到本节第一条
        //    track 继续循环（这就是 "列表循环" 的字面语义，跟 enum doc 保持一致）。
        if (state.args.autoPlayNext && state.args.allLessonIds.isNotEmpty) {
          final ids = state.args.allLessonIds;
          final currentIdx = ids.indexOf(state.args.id);
          if (currentIdx >= 0 && currentIdx < ids.length - 1) {
            await _switchLesson(1);
            final player = _player;
            if (player != null) {
              try {
                await player.play();
              } catch (_) {}
            }
            return;
          }
        }
        state = state.copyWith(
          activeTrackIndex: 0,
          activeImageIndex: 0,
          position: Duration.zero,
          duration: Duration.zero,
          frequencyBands: const <double>[],
        );
        await _openActiveTrack(play: true);
        return;
      }
    }

    // 单 track 课程 + autoPlayNext：跨课接力（节奏 / 旋律典型用法）。
    if (state.args.autoPlayNext && state.args.allLessonIds.isNotEmpty) {
      final ids = state.args.allLessonIds;
      final currentIdx = ids.indexOf(state.args.id);
      if (currentIdx >= 0 && currentIdx < ids.length - 1) {
        await _switchLesson(1);
        final player = _player;
        if (player != null) {
          try {
            await player.play();
          } catch (_) {}
        }
        return;
      }
    }

    // 默认收尾：seek 回 0 + pause。涵盖单 track 单课、试题等"播完即停"的入口。
    final player = _player;
    if (player != null) {
      try {
        await player.seek(Duration.zero);
        await player.pause();
      } catch (_) {}
    }
    if (mounted) {
      state = state.copyWith(
        isPlaying: false,
        position: Duration.zero,
      );
    }
  }

  bool _hasVipAccess(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return false;
    }
    // myInfo 接口返回结构：{ user: { vipExpireDate, ... }, ... }
    final user = data['user'];
    final source = user is Map<String, dynamic> ? user : data;
    final raw = source['vipExpireDate']?.toString() ?? '';
    if (raw.trim().isEmpty) {
      return false;
    }
    final expire = DateTime.tryParse(raw.replaceAll('/', '-'));
    if (expire == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vipDate = DateTime(expire.year, expire.month, expire.day);
    return !vipDate.isBefore(today);
  }

  MusicPlayDetail _parseDetail(Map<String, dynamic> raw) {
    final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
    final type = int.tryParse(raw['type']?.toString() ?? '') ?? 0;
    final title = raw['title']?.toString().trim().isNotEmpty == true
        ? raw['title'].toString().trim()
        : '未命名教材';
    final coverUrl = _resolveMediaUrl(
      raw['img']?.toString() ??
          raw['cover']?.toString() ??
          raw['icon']?.toString() ??
          '',
    );

    int? firstMenu;
    final fm = raw['firstMenu'];
    if (fm != null) {
      if (fm is int) {
        firstMenu = fm;
      } else {
        firstMenu = int.tryParse(fm.toString());
      }
    }

    final shortText1 = raw['shortText1']?.toString().trim() ?? '';
    final shortText2 = raw['shortText2']?.toString().trim() ?? '';
    // 旧字段 [subtitle] 优先用 shortText2（列表的"主副标题"），落空时再
    // 兜底 shortText1。各处分享 / 列表场景沿用这一兼容值；播放器条副标题
    // 走 _resolveSecondaryTitle 的更细粒度逻辑（多曲目/单曲目分别处理）。
    final compatSubtitle = shortText2.isNotEmpty
        ? shortText2
        : shortText1;

    return MusicPlayDetail(
      id: id,
      type: type,
      title: title,
      subtitle: compatSubtitle,
      shortText1: shortText1,
      shortText2: shortText2,
      coverUrl: coverUrl,
      favorite:
          raw['isFavorite'] == true ||
          raw['isFavorite']?.toString() == '1' ||
          raw['favorite']?.toString() == '1',
      vipOnly: raw['vip']?.toString() == '1',
      questionImages: _parseImageList(raw['img2']),
      answerImages: _parseImageList(raw['img1']),
      tracks: _parseTracks(raw['file1']),
      longTextHtml: raw['longText1']?.toString() ?? '',
      firstMenu: firstMenu,
    );
  }

  List<MusicPlayTrack> _parseTracks(dynamic raw) {
    final values = _normalizeToList(raw);
    if (values.isEmpty) {
      final fallbackUrl = _extractUrl(raw);
      return fallbackUrl.isEmpty
          ? const <MusicPlayTrack>[]
          : <MusicPlayTrack>[MusicPlayTrack(url: fallbackUrl, title: '主音频')];
    }

    final tracks = <MusicPlayTrack>[];
    for (var i = 0; i < values.length; i++) {
      final entry = values[i];
      final url = _extractUrl(entry);
      if (url.isEmpty) continue;
      final title = _extractTitle(entry);
      tracks.add(
        MusicPlayTrack(
          url: url,
          title: (title == null || title.isEmpty) ? '音频 ${i + 1}' : title,
        ),
      );
    }
    return tracks;
  }

  List<String> _parseImageList(dynamic raw) {
    final values = _normalizeToList(raw);
    final result = <String>[];
    for (final entry in values) {
      final url = _extractUrl(entry);
      if (url.isNotEmpty) {
        result.add(url);
      }
    }
    return result;
  }

  /// 解析 `filename` 字段（用于音轨标题），与 [_extractUrl] 对应。
  String? _extractTitle(dynamic entry) {
    if (entry is Map) {
      final raw = entry['filename']?.toString();
      return raw?.split('.').first.trim();
    }
    return null;
  }

  /// 从一项资源中提取一个完整的可访问 URL。
  ///
  /// 兼容三类后端返回：
  ///  - 标准 JSON：`{"url":"https://...","path":"app/upload/..."}`
  ///  - 后端 `Map.toString()` 序列化（key/value 都没有引号）：
  ///    `{path: app/upload/..., url: https://...}`
  ///  - 纯字符串（绝对 URL 或相对 path）。
  ///
  /// 优先取已经带域名的 `url`，否则把 `path` 等字段交给 [MediaUrl.resolve]
  /// 拼接 fileServerUrl，避免在域名后再拼一段 Map 调试字符串。
  String _extractUrl(dynamic entry) {
    if (entry == null) return '';

    if (entry is Map) {
      final url = (entry['url'] ?? entry['fileUrl'])?.toString().trim() ?? '';
      if (url.isNotEmpty) return _resolveMediaUrl(url);
      final path =
          (entry['path'] ?? entry['img'] ?? entry['filePath'])
              ?.toString()
              .trim() ??
          '';
      if (path.isNotEmpty) return _resolveMediaUrl(path);
      return '';
    }

    final text = entry.toString().trim();
    if (text.isEmpty) return '';

    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return _extractUrl(decoded);
        if (decoded is List && decoded.isNotEmpty) {
          return _extractUrl(decoded.first);
        }
      } catch (_) {
        // 落到下面的 Dart 风格解析。
      }
    }

    if (text.startsWith('{') && text.endsWith('}')) {
      final urlMatch = RegExp(r'url:\s*([^,}\s][^,}]*)').firstMatch(text);
      if (urlMatch != null) {
        return _resolveMediaUrl(urlMatch.group(1)!.trim());
      }
      final pathMatch = RegExp(r'path:\s*([^,}\s][^,}]*)').firstMatch(text);
      if (pathMatch != null) {
        return _resolveMediaUrl(pathMatch.group(1)!.trim());
      }
      return '';
    }

    return _resolveMediaUrl(text);
  }

  List<dynamic> _normalizeToList(dynamic raw) {
    if (raw == null) {
      return const <dynamic>[];
    }
    final decoded = _decodeJsonLike(raw);
    if (decoded is List) {
      if (decoded.length == 1 && decoded.first is List) {
        return List<dynamic>.from(decoded.first as List);
      }
      return List<dynamic>.from(decoded);
    }
    if (decoded is Map) {
      return <dynamic>[decoded];
    }
    final text = raw.toString().trim();
    if (text.isEmpty) {
      return const <dynamic>[];
    }
    return <dynamic>[raw];
  }

  dynamic _decodeJsonLike(dynamic value) {
    if (value is List || value is Map) {
      return value;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return value;
    }
    if (!(text.startsWith('{') || text.startsWith('['))) {
      return value;
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      return value;
    }
  }

  String _resolveMediaUrl(String raw) => MediaUrl.resolve(raw);

  bool _defaultShowAnswer(int? pageType, MusicPlayDetail detail) {
    // 试题（answerEnd2）听写 / 乐理：路由参数 `closedByDefault: true` 时默认
    // 先展示题面；「视唱」分类不传该参数，走下方 pageType / 资源逻辑。
    if (state.args.closedByDefault) {
      return false;
    }
    if (pageType == 3) {
      return true;
    }
    if (pageType == 2) {
      return detail.type == 4 || detail.answerImages.isNotEmpty;
    }
    return detail.answerImages.isNotEmpty;
  }

  @override
  void dispose() {
    // 关键：所有"同步停声"动作必须在 super.dispose() 之前完成，
    // 并先把 _disposed 置位，让任何还在 await 的异步链（[togglePlay]、
    // [pressPianoKey]、[_openActiveTrack] 等）都能 short-circuit。
    _disposed = true;

    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();

    final player = _player;
    if (player != null) {
      try {
        unawaited(player.pause());
      } catch (_) {}
      try {
        unawaited(player.dispose());
      } catch (_) {}
    }
    _player = null;

    // 同步把所有钢琴声 stop 掉，再 unawaited dispose。前者立刻静音，
    // 后者负责释放资源；引擎内部的 _disposed 也已经在 .dispose() 调用瞬间
    // 同步置位（见 MusicCompanionAudioEngine.dispose 头部），因此就算
    // pressPianoKey 的异步链此时还在挂起，最终 SoLoud.play 也不会被调到。
    _pianoEngine.stopAllImmediately();
    unawaited(_pianoEngine.dispose());
    super.dispose();
  }
}
