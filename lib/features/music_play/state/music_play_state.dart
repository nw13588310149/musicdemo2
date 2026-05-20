import 'package:flutter/foundation.dart';

@immutable
class MusicPlayPageArgs {
  const MusicPlayPageArgs({
    required this.id,
    this.type,
    this.allLessonIds = const <int>[],
    this.closedByDefault = false,
    this.autoPlayNext = false,
  });

  final int id;
  final int? type;
  final List<int> allLessonIds;

  /// 进入页面时是否默认隐藏答案（即"关闭状态"，显示题面而非答案）。
  /// 试题模块走 answerEnd2 路由时设为 true，避免默认就把答案露出来。
  final bool closedByDefault;

  /// 单曲播完后是否自动接下一首。
  ///
  /// 默认 false（播完停在当前位置，沿用绝大多数模块的"播完即停"语义）。
  /// 仅在「节奏」「旋律」类目从听写 / 声乐 / 器乐入口跳进来时才置 true：
  /// 这两个类目典型一节课多个 track（节奏型 / 旋律片段），用户期望像
  /// 老款 1.0 一样一气听完整组，再手动决定。
  final bool autoPlayNext;

  factory MusicPlayPageArgs.fromRaw(dynamic raw) {
    if (raw is MusicPlayPageArgs) {
      return raw;
    }
    if (raw is Map) {
      final all = <int>[];
      final rawAll = raw['all'];
      if (rawAll is List) {
        for (final value in rawAll) {
          final parsed = int.tryParse(value?.toString() ?? '');
          if (parsed != null && parsed > 0) {
            all.add(parsed);
          }
        }
      }
      final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
      final type = int.tryParse(raw['type']?.toString() ?? '');
      final closed = raw['closedByDefault'] == true;
      final autoPlayNext = raw['autoPlayNext'] == true;
      return MusicPlayPageArgs(
        id: id,
        type: type,
        allLessonIds: all,
        closedByDefault: closed,
        autoPlayNext: autoPlayNext,
      );
    }
    return const MusicPlayPageArgs(id: 0);
  }

  @override
  bool operator ==(Object other) {
    return other is MusicPlayPageArgs &&
        other.id == id &&
        other.type == type &&
        other.closedByDefault == closedByDefault &&
        other.autoPlayNext == autoPlayNext &&
        listEquals(other.allLessonIds, allLessonIds);
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    closedByDefault,
    autoPlayNext,
    Object.hashAll(allLessonIds),
  );
}

@immutable
class MusicPlayTrack {
  const MusicPlayTrack({required this.url, required this.title});

  final String url;
  final String title;
}

/// 多曲目"列表播放"的循环模式，对应 1.0 中 `sxType` 的三档：
/// - [sequence] 顺序播放（播完最后一首回到第一首）
/// - [single] 单曲循环
/// - [shuffle] 随机循环
enum MusicPlayMode { sequence, single, shuffle }

@immutable
class MusicPlayDetail {
  const MusicPlayDetail({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.shortText1,
    required this.shortText2,
    required this.coverUrl,
    required this.favorite,
    required this.vipOnly,
    required this.questionImages,
    required this.answerImages,
    required this.tracks,
    required this.longTextHtml,
    this.firstMenu,
  });

  final int id;
  final int type;
  final String title;

  /// 兼容字段：保留给老代码（分享、收藏入口等）继续读用。具体 UI 副标题
  /// 走 [shortText1] / [shortText2] 的优先级逻辑（详见 _resolveSecondaryTitle）。
  final String subtitle;

  /// 详情接口的 `shortText1` 字段；多曲目（节奏/和弦类）时通常是分组名，
  /// 例如「均分型节奏」。单曲目场景一般为 null/空字符串。
  final String shortText1;

  /// 详情接口的 `shortText2` 字段；列表里直接展示给用户的副标题主选项，
  /// 例如「标准音上下行二度内单音」「四分、二八、二分、附点二分」。
  final String shortText2;
  final String coverUrl;
  final bool favorite;
  final bool vipOnly;
  final List<String> questionImages;
  final List<String> answerImages;
  final List<MusicPlayTrack> tracks;
  final String longTextHtml;

  /// 详情接口 `firstMenu`（一级菜单 id）。`18` 时隐藏升降调且不应用变调。
  final int? firstMenu;

  /// `firstMenu == 18`：不展示升降调控件，播放保持原调。
  bool get hidePitchShift => firstMenu == 18;
}

@immutable
class MusicPlayShareClass {
  const MusicPlayShareClass({
    required this.id,
    required this.name,
    required this.checked,
  });

  final String id;
  final String name;
  final bool checked;

  MusicPlayShareClass copyWith({bool? checked}) =>
      MusicPlayShareClass(id: id, name: name, checked: checked ?? this.checked);

  factory MusicPlayShareClass.fromJson(Map raw) {
    return MusicPlayShareClass(
      id: raw['id']?.toString() ?? '',
      name: raw['name']?.toString() ?? '',
      checked: false,
    );
  }
}

@immutable
class MusicPlayState {
  const MusicPlayState({
    required this.args,
    required this.loading,
    required this.ready,
    required this.detail,
    required this.errorMessage,
    required this.showAnswer,
    required this.activeImageIndex,
    required this.activeTrackIndex,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.speed,
    required this.pitchSemitones,
    required this.playMode,
    required this.activePianoNotes,
    required this.frequencyBands,
    required this.shareDialogVisible,
    required this.classLoading,
    required this.sending,
    required this.classList,
  });

  final MusicPlayPageArgs args;
  final bool loading;
  final bool ready;
  final MusicPlayDetail? detail;
  final String errorMessage;
  final bool showAnswer;
  final int activeImageIndex;
  final int activeTrackIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;

  /// 独立于倍速的"升降调"（半音数）。0 表示原调；
  /// 1 = 升一个半音、-1 = 降一个半音；与 [speed] 完全独立。
  final int pitchSemitones;

  /// 多曲目时的循环模式（顺序 / 单曲 / 随机）。
  /// 仅当 [MusicPlayDetail.tracks] 长度大于 1 时才在 UI 上暴露切换入口。
  final MusicPlayMode playMode;
  final Set<String> activePianoNotes;
  final List<double> frequencyBands;
  final bool shareDialogVisible;
  final bool classLoading;
  final bool sending;
  final List<MusicPlayShareClass> classList;

  bool get hasDetail => detail != null;

  List<String> get visibleImages {
    final current = detail;
    if (current == null) {
      return const <String>[];
    }
    if (showAnswer) {
      return current.answerImages;
    }
    return current.questionImages;
  }

  MusicPlayTrack? get activeTrack {
    final current = detail;
    if (current == null || current.tracks.isEmpty) {
      return null;
    }
    final safeIndex = activeTrackIndex.clamp(0, current.tracks.length - 1);
    return current.tracks[safeIndex];
  }

  bool get showsKeyboard {
    final current = detail;
    if (current == null) {
      return true;
    }
    return current.type != 4 && current.type != 5;
  }

  /// 声乐(type=4) 或 器乐(type=5) 课程，使用与 1.0 一致的"五线谱/简谱"布局。
  bool get isVocalOrInstrumental {
    final t = detail?.type;
    return t == 4 || t == 5;
  }

  MusicPlayState copyWith({
    MusicPlayPageArgs? args,
    bool? loading,
    bool? ready,
    MusicPlayDetail? detail,
    bool clearDetail = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? showAnswer,
    int? activeImageIndex,
    int? activeTrackIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? speed,
    int? pitchSemitones,
    MusicPlayMode? playMode,
    Set<String>? activePianoNotes,
    List<double>? frequencyBands,
    bool? shareDialogVisible,
    bool? classLoading,
    bool? sending,
    List<MusicPlayShareClass>? classList,
  }) {
    return MusicPlayState(
      args: args ?? this.args,
      loading: loading ?? this.loading,
      ready: ready ?? this.ready,
      detail: clearDetail ? null : (detail ?? this.detail),
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
      showAnswer: showAnswer ?? this.showAnswer,
      activeImageIndex: activeImageIndex ?? this.activeImageIndex,
      activeTrackIndex: activeTrackIndex ?? this.activeTrackIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      pitchSemitones: pitchSemitones ?? this.pitchSemitones,
      playMode: playMode ?? this.playMode,
      activePianoNotes: activePianoNotes ?? this.activePianoNotes,
      frequencyBands: frequencyBands ?? this.frequencyBands,
      shareDialogVisible: shareDialogVisible ?? this.shareDialogVisible,
      classLoading: classLoading ?? this.classLoading,
      sending: sending ?? this.sending,
      classList: classList ?? this.classList,
    );
  }

  static MusicPlayState initial(MusicPlayPageArgs args) => MusicPlayState(
    args: args,
    loading: true,
    ready: false,
    detail: null,
    errorMessage: '',
    showAnswer: true,
    activeImageIndex: 0,
    activeTrackIndex: 0,
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
    speed: 1,
    pitchSemitones: 0,
    playMode: MusicPlayMode.sequence,
    activePianoNotes: const <String>{},
    frequencyBands: const <double>[],
    shareDialogVisible: false,
    classLoading: false,
    sending: false,
    classList: const <MusicPlayShareClass>[],
  );
}
