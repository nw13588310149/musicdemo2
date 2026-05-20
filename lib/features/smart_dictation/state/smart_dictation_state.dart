import 'package:flutter/foundation.dart';

enum SmartDictationTrack { absolute, interval, chord }

enum SmartDictationMode { stage, smart }

enum SmartIntervalPlayMode { melodic, harmonic }

@immutable
class SmartDictationLesson {
  const SmartDictationLesson({
    required this.id,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.stars,
    required this.pattern,
    required this.optionsRaw,
  });

  final int id;
  final int number;
  final String title;
  final String subtitle;
  final bool unlocked;
  final int stars;
  final String pattern;
  final String optionsRaw;
}

@immutable
class SmartPracticeConfig {
  const SmartPracticeConfig({
    required this.optionPool,
    required this.selectedOptions,
    required this.answerSeconds,
    required this.questionCount,
    this.minNote = '',
    this.maxNote = '',
    this.standardToneEnabled = false,
    this.basicOnly = false,
    this.intervalPlayMode = SmartIntervalPlayMode.melodic,
  });

  final List<String> optionPool;
  final List<String> selectedOptions;
  final int answerSeconds;
  final int questionCount;
  final String minNote;
  final String maxNote;
  final bool standardToneEnabled;
  final bool basicOnly;
  final SmartIntervalPlayMode intervalPlayMode;

  SmartPracticeConfig copyWith({
    List<String>? optionPool,
    List<String>? selectedOptions,
    int? answerSeconds,
    int? questionCount,
    String? minNote,
    String? maxNote,
    bool? standardToneEnabled,
    bool? basicOnly,
    SmartIntervalPlayMode? intervalPlayMode,
  }) {
    return SmartPracticeConfig(
      optionPool: optionPool ?? this.optionPool,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      answerSeconds: answerSeconds ?? this.answerSeconds,
      questionCount: questionCount ?? this.questionCount,
      minNote: minNote ?? this.minNote,
      maxNote: maxNote ?? this.maxNote,
      standardToneEnabled: standardToneEnabled ?? this.standardToneEnabled,
      basicOnly: basicOnly ?? this.basicOnly,
      intervalPlayMode: intervalPlayMode ?? this.intervalPlayMode,
    );
  }
}

@immutable
class SmartPracticeQuestion {
  const SmartPracticeQuestion({
    required this.title,
    required this.playTokens,
    required this.correctOption,
    required this.optionPool,
    required this.harmonic,
  });

  final String title;
  final List<String> playTokens;
  final String correctOption;
  final List<String> optionPool;
  final bool harmonic;
}

@immutable
class SmartPracticeSession {
  const SmartPracticeSession({
    required this.track,
    required this.sourceMode,
    required this.title,
    required this.questions,
    required this.currentIndex,
    required this.correctCount,
    required this.wrongCount,
    required this.remainingMillis,
    required this.answerSeconds,
    required this.running,
    required this.started,
    required this.finished,
    required this.showExitDialog,
    required this.linkedLessonId,
    required this.trail,
  });

  final SmartDictationTrack track;
  final SmartDictationMode sourceMode;
  final String title;
  final List<SmartPracticeQuestion> questions;
  final int currentIndex;
  final int correctCount;
  final int wrongCount;
  final int remainingMillis;
  final int answerSeconds;
  final bool running;
  final bool started;
  final bool finished;
  final bool showExitDialog;
  final int linkedLessonId;
  final List<String> trail;

  SmartPracticeQuestion get currentQuestion => questions[currentIndex];

  int get totalQuestions => questions.length;

  bool get timedMode => answerSeconds > 0;

  SmartPracticeSession copyWith({
    SmartDictationTrack? track,
    SmartDictationMode? sourceMode,
    String? title,
    List<SmartPracticeQuestion>? questions,
    int? currentIndex,
    int? correctCount,
    int? wrongCount,
    int? remainingMillis,
    int? answerSeconds,
    bool? running,
    bool? started,
    bool? finished,
    bool? showExitDialog,
    int? linkedLessonId,
    List<String>? trail,
  }) {
    return SmartPracticeSession(
      track: track ?? this.track,
      sourceMode: sourceMode ?? this.sourceMode,
      title: title ?? this.title,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      remainingMillis: remainingMillis ?? this.remainingMillis,
      answerSeconds: answerSeconds ?? this.answerSeconds,
      running: running ?? this.running,
      started: started ?? this.started,
      finished: finished ?? this.finished,
      showExitDialog: showExitDialog ?? this.showExitDialog,
      linkedLessonId: linkedLessonId ?? this.linkedLessonId,
      trail: trail ?? this.trail,
    );
  }
}

@immutable
class SmartDictationState {
  const SmartDictationState({
    required this.bootstrapping,
    required this.audioLoading,
    required this.audioReady,
    required this.loadingLessons,
    required this.activeTrack,
    required this.activeMode,
    required this.absoluteLessons,
    required this.intervalLessons,
    required this.chordLessons,
    required this.absoluteConfig,
    required this.intervalConfig,
    required this.chordConfig,
    required this.session,
    required this.frequencyBands,
    required this.errorMessage,
    required this.noticeMessage,
    required this.vipExpireDateText,
  });

  final bool bootstrapping;
  final bool audioLoading;
  final bool audioReady;
  final bool loadingLessons;
  final SmartDictationTrack activeTrack;
  final SmartDictationMode activeMode;
  final List<SmartDictationLesson> absoluteLessons;
  final List<SmartDictationLesson> intervalLessons;
  final List<SmartDictationLesson> chordLessons;
  final SmartPracticeConfig absoluteConfig;
  final SmartPracticeConfig intervalConfig;
  final SmartPracticeConfig chordConfig;
  final SmartPracticeSession? session;
  final List<double> frequencyBands;
  final String errorMessage;
  final String noticeMessage;
  final String vipExpireDateText;

  List<SmartDictationLesson> get activeLessons {
    switch (activeTrack) {
      case SmartDictationTrack.absolute:
        return absoluteLessons;
      case SmartDictationTrack.interval:
        return intervalLessons;
      case SmartDictationTrack.chord:
        return chordLessons;
    }
  }

  SmartPracticeConfig get activeConfig {
    switch (activeTrack) {
      case SmartDictationTrack.absolute:
        return absoluteConfig;
      case SmartDictationTrack.interval:
        return intervalConfig;
      case SmartDictationTrack.chord:
        return chordConfig;
    }
  }

  SmartDictationState copyWith({
    bool? bootstrapping,
    bool? audioLoading,
    bool? audioReady,
    bool? loadingLessons,
    SmartDictationTrack? activeTrack,
    SmartDictationMode? activeMode,
    List<SmartDictationLesson>? absoluteLessons,
    List<SmartDictationLesson>? intervalLessons,
    List<SmartDictationLesson>? chordLessons,
    SmartPracticeConfig? absoluteConfig,
    SmartPracticeConfig? intervalConfig,
    SmartPracticeConfig? chordConfig,
    SmartPracticeSession? session,
    bool clearSession = false,
    List<double>? frequencyBands,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
    String? vipExpireDateText,
  }) {
    return SmartDictationState(
      bootstrapping: bootstrapping ?? this.bootstrapping,
      audioLoading: audioLoading ?? this.audioLoading,
      audioReady: audioReady ?? this.audioReady,
      loadingLessons: loadingLessons ?? this.loadingLessons,
      activeTrack: activeTrack ?? this.activeTrack,
      activeMode: activeMode ?? this.activeMode,
      absoluteLessons: absoluteLessons ?? this.absoluteLessons,
      intervalLessons: intervalLessons ?? this.intervalLessons,
      chordLessons: chordLessons ?? this.chordLessons,
      absoluteConfig: absoluteConfig ?? this.absoluteConfig,
      intervalConfig: intervalConfig ?? this.intervalConfig,
      chordConfig: chordConfig ?? this.chordConfig,
      session: clearSession ? null : (session ?? this.session),
      frequencyBands: frequencyBands ?? this.frequencyBands,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNoticeMessage
          ? ''
          : (noticeMessage ?? this.noticeMessage),
      vipExpireDateText: vipExpireDateText ?? this.vipExpireDateText,
    );
  }

  static SmartDictationState initial() {
    const absolutePool = <String>[
      'f',
      '#f',
      'g',
      '#g',
      'a',
      'bb',
      'b',
      'c1',
      '#c1',
      'd1',
      'be1',
      'e1',
      'f1',
      '#f1',
      'g1',
      '#g1',
      'a1',
      'bb1',
      'b1',
      'c2',
      '#c2',
      'd2',
      'be2',
      'e2',
      'f2',
      '#f2',
      'g2',
      '#g2',
      'a2',
    ];

    // 音程识别按钮文案：去掉「度」字 + 按用户提供的截图顺序排版。
    // 顺序：纯一 / 纯八 / 大二 / 小二 / 大三 → 小三 / 纯四 / 增四减五
    //       / 纯五 / 大六 → 小六 / 大七 / 小七。
    // 这里的字面值同时被 [_intervalSemitoneMap] 当作 key 使用，两边
    // 必须保持一致；改这里别忘了同步更新 controller 里的半音映射表。
    const intervalPool = <String>[
      '纯一',
      '纯八',
      '大二',
      '小二',
      '大三',
      '小三',
      '纯四',
      '增四/减五',
      '纯五',
      '大六',
      '小六',
      '大七',
      '小七',
    ];

    // 和弦识别按钮文案：去掉「和弦」二字，保留种类前缀。
    // 顺序按用户截图：大三 / 小三 / 减三 / 增三 / 大六 → 小六 / 减六
    //                / 大四六 / 小四六 / 减四六。
    // 字面值同时是 [_chordIntervalMap] 的 key，改动需同步 controller。
    const chordPool = <String>[
      '大三',
      '小三',
      '减三',
      '增三',
      '大六',
      '小六',
      '减六',
      '大四六',
      '小四六',
      '减四六',
    ];

    return const SmartDictationState(
      bootstrapping: true,
      audioLoading: false,
      audioReady: false,
      loadingLessons: false,
      activeTrack: SmartDictationTrack.absolute,
      activeMode: SmartDictationMode.stage,
      absoluteLessons: <SmartDictationLesson>[],
      intervalLessons: <SmartDictationLesson>[],
      chordLessons: <SmartDictationLesson>[],
      absoluteConfig: SmartPracticeConfig(
        optionPool: absolutePool,
        selectedOptions: <String>[],
        answerSeconds: 20,
        questionCount: 15,
        minNote: 'f',
        maxNote: 'a2',
        standardToneEnabled: true,
      ),
      intervalConfig: SmartPracticeConfig(
        optionPool: intervalPool,
        selectedOptions: <String>[],
        answerSeconds: 20,
        questionCount: 15,
        minNote: 'f',
        maxNote: 'a2',
        // 应用户要求：音程识别的"音程方式"默认值改为「和声音程」（同时奏响），
        // 与和弦练习一致；旧版默认是「旋律音程」（先后奏响）。
        intervalPlayMode: SmartIntervalPlayMode.harmonic,
      ),
      chordConfig: SmartPracticeConfig(
        optionPool: chordPool,
        selectedOptions: <String>[],
        answerSeconds: 20,
        questionCount: 15,
        minNote: 'f',
        maxNote: 'd2',
        intervalPlayMode: SmartIntervalPlayMode.harmonic,
      ),
      session: null,
      frequencyBands: <double>[],
      errorMessage: '',
      noticeMessage: '',
      vipExpireDateText: '',
    );
  }
}
