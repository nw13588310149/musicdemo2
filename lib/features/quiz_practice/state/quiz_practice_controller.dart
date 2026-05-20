import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_practice_repository.dart';
import 'quiz_practice_state.dart';

final quizPracticeControllerProvider =
    StateNotifierProvider.autoDispose<
      QuizPracticeController,
      QuizPracticeState
    >((ref) {
      final repo = ref.watch(quizPracticeRepositoryProvider);
      return QuizPracticeController(repository: repo);
    });

class QuizPracticeController extends StateNotifier<QuizPracticeState> {
  QuizPracticeController({required QuizPracticeRepository repository})
    : _repository = repository,
      super(QuizPracticeState.initial) {
    unawaited(refresh());
  }

  final QuizPracticeRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearErrorMessage: true);
    final response = await _repository.getSummary();
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        summaries: _fallbackSummaries(),
        errorMessage: response.msg.isEmpty ? '加载刷题数据失败' : response.msg,
      );
      return;
    }

    final summaries = _parseSummaries(response.data);
    state = state.copyWith(loading: false, summaries: summaries);

    // 1.0 行为：status==null 的练习立刻调用 create 初始化（只针对 sequence/random/exam）。
    final missing = summaries
        .where((s) => !s.statusInitialized && s.type != QuizPracticeType.error)
        .toList(growable: false);
    if (missing.isEmpty) return;
    await Future.wait(
      missing.map((s) => _initializePractice(s.type)),
      eagerError: false,
    );
  }

  Future<void> _initializePractice(QuizPracticeType type) async {
    final response = await _repository.createPractice(
      practiceType: type.apiKey,
    );
    if (!mounted || !response.isSuccess) return;
    final updated = _parseSinglePractice(type, response.data);
    if (updated == null) return;

    final next = state.summaries
        .map((s) => s.type == type ? updated : s)
        .toList(growable: false);
    state = state.copyWith(summaries: next);
  }

  List<QuizPracticeSummary> _parseSummaries(dynamic data) {
    if (data is! Map) return _fallbackSummaries();

    QuizPracticeSummary parse(QuizPracticeType t) {
      final raw = data[t.apiKey];
      if (raw is! Map) return QuizPracticeSummary.empty(t);
      return QuizPracticeSummary(
        type: t,
        practiceId: _toInt(raw['practiceId']),
        allCount: _toInt(raw['allCount']) ?? 0,
        doneCount: _toInt(raw['doneCount']) ?? 0,
        errorCount: _toInt(raw['errorCount']) ?? 0,
        notDoneCount: _toInt(raw['notDoneCount']) ?? 0,
        statusInitialized: raw['status'] != null,
      );
    }

    return <QuizPracticeSummary>[
      parse(QuizPracticeType.sequence),
      parse(QuizPracticeType.random),
      parse(QuizPracticeType.exam),
      parse(QuizPracticeType.error),
    ];
  }

  QuizPracticeSummary? _parseSinglePractice(
    QuizPracticeType type,
    dynamic data,
  ) {
    if (data is! Map) return null;
    return QuizPracticeSummary(
      type: type,
      practiceId: _toInt(data['practiceId']),
      allCount: _toInt(data['allCount']) ?? 0,
      doneCount: _toInt(data['doneCount']) ?? 0,
      errorCount: _toInt(data['errorCount']) ?? 0,
      notDoneCount: _toInt(data['notDoneCount']) ?? 0,
      statusInitialized: true,
    );
  }

  List<QuizPracticeSummary> _fallbackSummaries() => <QuizPracticeSummary>[
    QuizPracticeSummary.empty(QuizPracticeType.sequence),
    QuizPracticeSummary.empty(QuizPracticeType.random),
    QuizPracticeSummary.empty(QuizPracticeType.exam),
    QuizPracticeSummary.empty(QuizPracticeType.error),
  ];

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
