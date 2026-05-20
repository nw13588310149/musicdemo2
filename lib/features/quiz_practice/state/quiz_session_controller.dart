import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_practice_repository.dart';
import 'quiz_practice_state.dart';
import 'quiz_session_state.dart';

final quizSessionControllerProvider = StateNotifierProvider.autoDispose
    .family<QuizSessionController, QuizSessionState, QuizSessionPageArgs>((
      ref,
      args,
    ) {
      final repo = ref.watch(quizPracticeRepositoryProvider);
      return QuizSessionController(repository: repo, args: args);
    });

class QuizSessionController extends StateNotifier<QuizSessionState> {
  QuizSessionController({
    required QuizPracticeRepository repository,
    required QuizSessionPageArgs args,
  }) : _repository = repository,
       super(QuizSessionState.fromArgs(args)) {
    unawaited(_bootstrap());
  }

  final QuizPracticeRepository _repository;
  Timer? _autoAdvanceTimer;

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final args = state.args;
    int? practiceId = args.practiceId;

    // 1.0 行为：camp_over 进入直接拉 summary 弹窗，不需要题目列表。
    if (args.openCompletionDialog) {
      await _refreshSummariesForCompletion();
      if (!mounted) return;
      state = state.copyWith(loading: false, completionDialogVisible: true);
      return;
    }

    // practiceId 缺失时（直接通过 deep link 进入），先调用 create 兜底。
    if (practiceId == null || practiceId <= 0) {
      final created = await _repository.createPractice(
        practiceType: args.practiceType.apiKey,
      );
      if (!mounted) return;
      if (created.isSuccess && created.data is Map) {
        practiceId = _toInt((created.data as Map)['practiceId']);
      }
    }

    if (practiceId == null || practiceId <= 0) {
      state = state.copyWith(loading: false, errorMessage: '初始化练习失败，请稍后重试');
      return;
    }

    final response = await _repository.getItemList(practiceId: practiceId);
    if (!mounted) return;

    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: response.msg.isEmpty ? '题目加载失败' : response.msg,
      );
      return;
    }

    final questions = _parseQuestions(response.data);
    final total = questions.isEmpty ? args.allCount : questions.length;

    // 起始题号取传入 num，但若已超过题量则从最后一题开始（与 1.0 一致）。
    var startIndex = args.startIndex;
    if (total > 0 && startIndex >= total) {
      startIndex = total - 1;
    }
    if (startIndex < 0) startIndex = 0;

    state = state.copyWith(
      loading: false,
      questions: questions,
      currentIndex: startIndex,
      args: state.args,
    );
  }

  /// 选择 A/B/C/D。answer = 0/1/2/3。
  Future<void> selectAnswer(int answer) async {
    final question = state.currentQuestion;
    if (question == null || question.answered) return;

    // 关键：捕获题目 itemId，await 之后用 itemId 定位回写——
    // 用户在网络请求期间可能已经"下一题"，此时 state.currentIndex
    // 早就指到别的题，按 index 写就把答案盖到错的题上去了。
    final itemId = question.itemId;
    final status = answer == question.correctAnswer ? 1 : 2;
    final response = await _repository.reportAnswer(
      questionPracticeItemId: itemId,
      answer: answer,
      status: status,
    );
    if (!mounted) return;

    if (!response.isSuccess) {
      state = state.copyWith(
        errorMessage: response.msg.isEmpty ? '提交失败' : response.msg,
      );
      return;
    }

    final list = List<QuizQuestion>.from(state.questions);
    final idx = list.indexWhere((q) => q.itemId == itemId);
    if (idx < 0) return; // 题目已不在当前列表
    if (list[idx].answered) return; // 已被其它路径回写过
    list[idx] = list[idx].copyWith(userAnswer: answer, status: status);
    state = state.copyWith(questions: list, clearErrorMessage: true);

    // 自动刷题：仅当用户停留在刚刚作答的这道题时才跳——若用户
    // 已经手动切到下一题，就别再"自动跳"覆盖他的操作。
    if (state.autoNext && state.currentIndex == idx) {
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        nextQuestion();
      });
    }
  }

  void previousQuestion() {
    final i = state.currentIndex - 1;
    if (i < 0) {
      state = state.copyWith(errorMessage: '已经是第一题了！');
      return;
    }
    state = state.copyWith(currentIndex: i, clearErrorMessage: true);
  }

  /// 下一题。若已是最后一题则触发完成流程（拉 summary 并弹窗）。
  void nextQuestion() {
    final i = state.currentIndex + 1;
    if (state.questions.isEmpty) return;
    if (i >= state.questions.length) {
      unawaited(_refreshSummariesForCompletion());
      state = state.copyWith(completionDialogVisible: true);
      return;
    }
    state = state.copyWith(currentIndex: i, clearErrorMessage: true);
  }

  void setAutoNext(bool value) {
    if (!value) {
      _autoAdvanceTimer?.cancel();
    }
    state = state.copyWith(autoNext: value);
  }

  /// 顶部返回时打开退出弹窗（同时刷新一次 summary）。
  Future<void> openExitDialog() async {
    await _refreshSummariesForCompletion();
    if (!mounted) return;
    state = state.copyWith(completionDialogVisible: true);
  }

  void closeCompletionDialog() {
    state = state.copyWith(completionDialogVisible: false);
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<void> _refreshSummariesForCompletion() async {
    final response = await _repository.getSummary();
    if (!mounted || !response.isSuccess || response.data is! Map) return;

    QuizPracticeSummary parse(QuizPracticeType t, Map raw) {
      final node = raw[t.apiKey];
      if (node is! Map) return QuizPracticeSummary.empty(t);
      return QuizPracticeSummary(
        type: t,
        practiceId: _toInt(node['practiceId']),
        allCount: _toInt(node['allCount']) ?? 0,
        doneCount: _toInt(node['doneCount']) ?? 0,
        errorCount: _toInt(node['errorCount']) ?? 0,
        notDoneCount: _toInt(node['notDoneCount']) ?? 0,
        statusInitialized: node['status'] != null,
      );
    }

    final raw = response.data as Map;
    final list = <QuizPracticeSummary>[
      parse(QuizPracticeType.sequence, raw),
      parse(QuizPracticeType.random, raw),
      parse(QuizPracticeType.exam, raw),
      parse(QuizPracticeType.error, raw),
    ];
    state = state.copyWith(summaryAfter: list);
  }

  /// 1.0 中弹窗的"考前密卷/随机练习"切换：当前是 exam 切到 random，否则切到 exam。
  Future<QuizSessionPageArgs?> switchToRecommended() async {
    final summaries = state.summaryAfter;
    if (summaries.isEmpty) return null;
    final isExam = state.args.practiceType == QuizPracticeType.exam;
    final targetType = isExam ? QuizPracticeType.random : QuizPracticeType.exam;
    QuizPracticeSummary? target;
    for (final s in summaries) {
      if (s.type == targetType) {
        target = s;
        break;
      }
    }
    if (target == null) return null;

    var practiceId = target.practiceId;
    var startIndex = target.doneCount;
    var allCount = target.allCount;

    if (practiceId == null || practiceId <= 0) {
      final created = await _repository.createPractice(
        practiceType: targetType.apiKey,
      );
      if (!mounted) return null;
      if (created.isSuccess && created.data is Map) {
        final data = created.data as Map;
        practiceId = _toInt(data['practiceId']);
        startIndex = _toInt(data['doneCount']) ?? 0;
        allCount = _toInt(data['allCount']) ?? 0;
      }
    }

    if (practiceId == null || practiceId <= 0) return null;
    return QuizSessionPageArgs(
      practiceType: targetType,
      practiceId: practiceId,
      startIndex: startIndex,
      allCount: allCount,
    );
  }

  List<QuizQuestion> _parseQuestions(dynamic data) {
    if (data is! List) return const <QuizQuestion>[];
    final list = <QuizQuestion>[];
    for (final item in data) {
      if (item is! Map) continue;
      final question = item['question'];
      if (question is! Map) continue;
      final id = _toInt(item['id']);
      if (id == null) continue;
      list.add(
        QuizQuestion(
          itemId: id,
          questionHtml: _asString(question['question']),
          options: <String>[
            _asString(question['param1']),
            _asString(question['param2']),
            _asString(question['param3']),
            _asString(question['param4']),
          ],
          correctAnswer: _toInt(question['answer']) ?? 0,
          parseHtml: _asString(question['parse']),
          userAnswer: _toInt(item['answer']),
          status: _toInt(item['status']) ?? 0,
        ),
      );
    }
    return list;
  }

  String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
