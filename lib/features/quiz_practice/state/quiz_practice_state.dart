import 'package:flutter/material.dart';

/// 1.0 中的 4 类练习：sequence/random/exam/error。
enum QuizPracticeType { sequence, random, exam, error }

extension QuizPracticeTypeX on QuizPracticeType {
  String get apiKey {
    switch (this) {
      case QuizPracticeType.sequence:
        return 'sequence';
      case QuizPracticeType.random:
        return 'random';
      case QuizPracticeType.exam:
        return 'exam';
      case QuizPracticeType.error:
        return 'error';
    }
  }

  String get label {
    switch (this) {
      case QuizPracticeType.sequence:
        return '顺序练习';
      case QuizPracticeType.random:
        return '随机练习';
      case QuizPracticeType.exam:
        return '考前密卷';
      case QuizPracticeType.error:
        return '错题集';
    }
  }

  /// 与 1.0 一致的进度环主色（顺序绿/随机粉/考前紫/错题红）。
  Color get accentColor {
    switch (this) {
      case QuizPracticeType.sequence:
        return const Color(0xFF00C9A4);
      case QuizPracticeType.random:
        return const Color(0xFFFE83A2);
      case QuizPracticeType.exam:
        return const Color(0xFF775DFE);
      case QuizPracticeType.error:
        return const Color(0xFFE61F62);
    }
  }
}

QuizPracticeType? quizPracticeTypeFromKey(String? key) {
  switch (key) {
    case 'sequence':
      return QuizPracticeType.sequence;
    case 'random':
      return QuizPracticeType.random;
    case 'exam':
      return QuizPracticeType.exam;
    case 'error':
      return QuizPracticeType.error;
    default:
      return null;
  }
}

/// 单类练习的统计数据。
@immutable
class QuizPracticeSummary {
  const QuizPracticeSummary({
    required this.type,
    required this.practiceId,
    required this.allCount,
    required this.doneCount,
    required this.errorCount,
    required this.notDoneCount,
    required this.statusInitialized,
  });

  final QuizPracticeType type;
  final int? practiceId;
  final int allCount;
  final int doneCount;
  final int errorCount;
  final int notDoneCount;

  /// 1.0 用 status==null 判断是否需要 questionPracticeCreate 初始化。
  final bool statusInitialized;

  double get progress {
    if (allCount <= 0) return 0;
    return (doneCount / allCount).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  double get accuracy {
    if (doneCount <= 0) return 0;
    return ((doneCount - errorCount) / doneCount).clamp(0.0, 1.0);
  }

  int get accuracyPercent => (accuracy * 100).round();

  QuizPracticeSummary copyWith({
    int? practiceId,
    int? allCount,
    int? doneCount,
    int? errorCount,
    int? notDoneCount,
    bool? statusInitialized,
  }) {
    return QuizPracticeSummary(
      type: type,
      practiceId: practiceId ?? this.practiceId,
      allCount: allCount ?? this.allCount,
      doneCount: doneCount ?? this.doneCount,
      errorCount: errorCount ?? this.errorCount,
      notDoneCount: notDoneCount ?? this.notDoneCount,
      statusInitialized: statusInitialized ?? this.statusInitialized,
    );
  }

  static QuizPracticeSummary empty(QuizPracticeType type) =>
      QuizPracticeSummary(
        type: type,
        practiceId: null,
        allCount: 0,
        doneCount: 0,
        errorCount: 0,
        notDoneCount: 0,
        statusInitialized: false,
      );
}

@immutable
class QuizPracticeState {
  const QuizPracticeState({
    required this.loading,
    required this.summaries,
    required this.errorMessage,
  });

  final bool loading;
  final List<QuizPracticeSummary> summaries;
  final String errorMessage;

  QuizPracticeSummary? summaryOf(QuizPracticeType type) {
    for (final s in summaries) {
      if (s.type == type) return s;
    }
    return null;
  }

  QuizPracticeState copyWith({
    bool? loading,
    List<QuizPracticeSummary>? summaries,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return QuizPracticeState(
      loading: loading ?? this.loading,
      summaries: summaries ?? this.summaries,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
    );
  }

  static const QuizPracticeState initial = QuizPracticeState(
    loading: true,
    summaries: <QuizPracticeSummary>[],
    errorMessage: '',
  );
}
