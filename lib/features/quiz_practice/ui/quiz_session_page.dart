import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/quiz_html.dart';
import '../state/quiz_practice_state.dart';
import '../state/quiz_session_controller.dart';
import '../state/quiz_session_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class QuizSessionPage extends ConsumerStatefulWidget {
  const QuizSessionPage({super.key, this.openCompletion = false});

  /// 来自 /camp_over 路由：进入即弹完成对话框。
  final bool openCompletion;

  @override
  ConsumerState<QuizSessionPage> createState() => _QuizSessionPageState();
}

class _QuizSessionPageState extends ConsumerState<QuizSessionPage> {
  QuizSessionPageArgs? _args;
  bool _dialogShowing = false;

  QuizSessionPageArgs _resolveArgs(BuildContext context) {
    if (_args != null) return _args!;
    final raw = ModalRoute.of(context)?.settings.arguments;
    final parsed = QuizSessionPageArgs.fromRaw(raw);
    _args = widget.openCompletion
        ? QuizSessionPageArgs(
            practiceType: parsed.practiceType,
            practiceId: parsed.practiceId,
            startIndex: parsed.startIndex,
            allCount: parsed.allCount,
            openCompletionDialog: true,
          )
        : parsed;
    return _args!;
  }

  @override
  Widget build(BuildContext context) {
    final args = _resolveArgs(context);
    final provider = quizSessionControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<QuizSessionState>(provider, (previous, next) {
      // 错误吐司
      final msg = next.errorMessage;
      if (msg.isNotEmpty && msg != previous?.errorMessage) {
        AppToast.show(context, msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.clearError();
        });
      }

      // 完成/退出弹窗
      if (next.completionDialogVisible && !_dialogShowing) {
        _dialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCompletionDialog(context, controller);
        });
      }
    });

    // DashboardScaffold 已提供外层 padding + #EFF3FC 背景，这里只需要单层白卡。
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: state.loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SessionHeader(
                  title: state.args.practiceType.label,
                  autoNext: state.autoNext,
                  onBack: controller.openExitDialog,
                  onAutoNextChanged: controller.setAutoNext,
                ),
                Expanded(
                  child: state.questions.isEmpty
                      ? const Center(child: Text('暂无题目'))
                      : _SessionBody(
                          state: state,
                          onSelect: controller.selectAnswer,
                          onPrevious: controller.previousQuestion,
                          onNext: controller.nextQuestion,
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _showCompletionDialog(
    BuildContext context,
    QuizSessionController controller,
  ) async {
    if (!mounted) return;
    // showDialog 走 root Overlay，不会继承 ShellScaffold 内层的 DashboardScaleScope，
    // 这里把当前页面的 scale 数据捕获后再透传给 dialog。
    final scale = DashboardScaleScope.of(context);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      barrierDismissible: false,
      builder: (dialogContext) {
        return DashboardScaleScope(
          data: scale,
          child: _CompletionDialog(
            controller: controller,
            providerArgs: _args!,
          ),
        );
      },
    );
    _dialogShowing = false;
    if (mounted) controller.closeCompletionDialog();
  }
}

// ─────────────────────────────────────────────────────────────────────
// 顶部 56px header
// ─────────────────────────────────────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.title,
    required this.autoNext,
    required this.onBack,
    required this.onAutoNextChanged,
  });

  final String title;
  final bool autoNext;
  final VoidCallback onBack;
  final ValueChanged<bool> onAutoNextChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(56),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      child: Row(
        children: [
          _BackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(16),
                  fontWeight: AppFont.w600,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
          Text(
            '自动刷题',
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(16),
              fontFamily: 'PingFang SC',
              height: 1.0,
            ),
          ),
          SizedBox(width: ui(8)),
          _AutoNextSwitch(value: autoNext, onChanged: onAutoNextChanged),
        ],
      ),
    );
  }
}

class _AutoNextSwitch extends StatelessWidget {
  const _AutoNextSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final trackWidth = ui(44);
    final trackHeight = ui(26);
    final thumbSize = ui(20);
    final inset = ui(3);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: trackWidth,
        height: trackHeight,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: trackWidth,
              height: trackHeight,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFFA773FF)
                    : const Color(0xFFE6E9F1),
                borderRadius: BorderRadius.circular(ui(13.5)),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: value ? trackWidth - thumbSize - inset : inset,
              top: inset,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.chevron_left,
          color: const Color(0xFF1C274C),
          size: ui(20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 主体：题型 chip / 题干 / 选项 / 解析 / 上下一题按钮
// ─────────────────────────────────────────────────────────────────────

class _SessionBody extends StatefulWidget {
  const _SessionBody({
    required this.state,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  final QuizSessionState state;
  final ValueChanged<int> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<_SessionBody> createState() => _SessionBodyState();
}

class _SessionBodyState extends State<_SessionBody> {
  final ScrollController _scrollController = ScrollController();
  int? _lastQuestionId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 题目切换时把滚动条复位到顶部。否则上一题滑到底，新一题
  /// 进来仍停在底，看起来就是一片"白屏"。
  void _maybeResetScrollOnQuestionChange(int? newQuestionId) {
    if (newQuestionId == _lastQuestionId) return;
    _lastQuestionId = newQuestionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      // jumpTo 0；用 jumpTo 而不是 animateTo——题目切换是"跳变"，
      // 不要带动画，免得用户看到上一题的内容滑出去。
      _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final question = widget.state.currentQuestion;
    _maybeResetScrollOnQuestionChange(question?.itemId);

    if (question == null) {
      return const Center(child: Text('暂无题目'));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              // ValueKey(itemId) 是这次重构最关键的一笔——题目
              // ID 一变，_QuestionContent 整棵子树会被 Element 层
              // unmount + remount，HtmlWidget / Image 等带内部状
              // 态的 widget 全部新建，杜绝"上一题的字 / 图遗留
              // 到这一题"。
              child: _QuestionContent(
                key: ValueKey<int>(question.itemId),
                question: question,
                questionNumber: widget.state.currentIndex + 1,
                onSelect: widget.onSelect,
              ),
            ),
          ),
          SizedBox(height: ui(20)),
          _NavButtons(
            onPrevious: widget.onPrevious,
            onNext: widget.onNext,
          ),
        ],
      ),
    );
  }
}

/// 题目主体（题型 chip + 题干 + 选项 + 解析）。
///
/// 内部不持有任何状态——所有"切题需要 reset"的副作用都靠外层
/// 给本 widget 传入的 `ValueKey(question.itemId)` 触发整棵子树
/// 在 Element 层 unmount + remount。
class _QuestionContent extends StatelessWidget {
  const _QuestionContent({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.onSelect,
  });

  final QuizQuestion question;
  final int questionNumber;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TypeChip(),
        SizedBox(height: ui(20)),
        // 题干：左侧"第 N 题"前缀 + 富文本（可能含 <img>、
        // <sup>/<sub> 等）。
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第$questionNumber题  ',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(18),
                fontWeight: AppFont.w500,
                fontFamily: 'PingFang SC',
                height: 1.5,
              ),
            ),
            Expanded(
              child: _QuizHtml(
                html: question.questionHtml,
                fallbackText: question.questionStripped,
                hasMedia: question.questionHasMedia,
                hasInlineRich: question.questionHasInlineRich,
                textStyle: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(18),
                  fontWeight: AppFont.w500,
                  fontFamily: 'PingFang SC',
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: ui(24)),
        _OptionsGrid(question: question, onSelect: onSelect),
        if (question.answered) ...[
          SizedBox(height: ui(28)),
          const Divider(height: 1, color: Color(0xFFF3F2F3)),
          SizedBox(height: ui(20)),
          _AnswerRow(question: question),
          SizedBox(height: ui(24)),
          Text(
            '题目解析',
            style: TextStyle(
              color: const Color(0xFF6D6B75),
              fontSize: ui(18),
              fontWeight: AppFont.w600,
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(10)),
          if (question.parseStripped.isEmpty &&
              !question.parseHasMedia &&
              !question.parseHasInlineRich)
            Text(
              '暂无解析',
              style: TextStyle(
                color: const Color(0xFFB6B5BB),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                height: 1.6,
              ),
            )
          else
            _QuizHtml(
              html: question.parseHtml,
              fallbackText: question.parseStripped,
              hasMedia: question.parseHasMedia,
              hasInlineRich: question.parseHasInlineRich,
              textStyle: TextStyle(
                color: const Color(0xFFB6B5BB),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                height: 1.6,
              ),
            ),
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
        decoration: BoxDecoration(
          color: const Color(0xFFEAE5FF),
          borderRadius: BorderRadius.circular(ui(4)),
        ),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              height: 1.0,
            ),
            children: const [
              TextSpan(text: '当前题型：'),
              TextSpan(text: '单选题'),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionsGrid extends StatelessWidget {
  const _OptionsGrid({required this.question, required this.onSelect});

  final QuizQuestion question;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      children: [
        // crossAxisAlignment.stretch 让每行的两个选项高度对齐——
        // 如果一边是文字、一边是图片，两个卡片仍然一样高。
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Option(question: question, index: 0, onSelect: onSelect)),
              SizedBox(width: ui(20)),
              Expanded(child: _Option(question: question, index: 1, onSelect: onSelect)),
            ],
          ),
        ),
        SizedBox(height: ui(20)),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Option(question: question, index: 2, onSelect: onSelect)),
              SizedBox(width: ui(20)),
              Expanded(child: _Option(question: question, index: 3, onSelect: onSelect)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 单个选项卡（A/B/C/D 之一）。
///
/// 拆成独立 widget + key（itemId+index）让 Flutter 在题目切换 /
/// 选项内容变化时彻底走 unmount → mount，避免 Element 复用把上
/// 一题选项里的 HtmlWidget DOM / 图片留给新题用。
class _Option extends StatelessWidget {
  _Option({
    required this.question,
    required this.index,
    required this.onSelect,
  }) : super(
         key: ValueKey<String>(
           'opt-${question.itemId}-$index',
         ),
       );

  final QuizQuestion question;
  final int index;
  final ValueChanged<int> onSelect;

  static const _letters = <String>['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final letter = _letters[index];
    final rawHtml = index < question.options.length
        ? question.options[index]
        : '';
    final stripped = index < question.optionsStripped.length
        ? question.optionsStripped[index]
        : '';
    final hasMedia = index < question.optionsHasMedia.length
        ? question.optionsHasMedia[index]
        : false;
    final hasInlineRich = index < question.optionsHasInlineRich.length
        ? question.optionsHasInlineRich[index]
        : false;

    final answered = question.answered;
    final isCorrectOption = index == question.correctAnswer;
    final isUserPick = index == question.userAnswer;
    final showCorrect = answered && isCorrectOption;
    final showWrong = answered && isUserPick && !isCorrectOption;

    Color bg = const Color(0xFFF5F6FA);
    Color textColor = const Color(0xFF0B081A);
    Widget? trailing;
    if (showCorrect) {
      bg = const Color(0xFFE8F5EC);
      textColor = const Color(0xFF1AAB5B);
      trailing = Icon(Icons.check_rounded, color: textColor, size: ui(20));
    } else if (showWrong) {
      bg = const Color(0xFFFCEBEB);
      textColor = const Color(0xFFE0494B);
      trailing = Icon(Icons.close_rounded, color: textColor, size: ui(20));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(8)),
        onTap: answered ? null : () => onSelect(index),
        child: Container(
          // 最小 44，让纯图片选项可以撑大；IntrinsicHeight 在外面
          // 保证同一行两个选项卡片等高。
          constraints: BoxConstraints(minHeight: ui(44)),
          padding: EdgeInsets.symmetric(
            horizontal: ui(20),
            vertical: ui(8),
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: ui(22),
                child: Text(
                  '$letter.',
                  style: TextStyle(
                    color: textColor,
                    fontSize: ui(16),
                    fontWeight: AppFont.w600,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
              SizedBox(width: ui(9)),
              Expanded(
                child: _QuizHtml(
                  html: rawHtml,
                  fallbackText: stripped,
                  hasMedia: hasMedia,
                  hasInlineRich: hasInlineRich,
                  textStyle: TextStyle(
                    color: textColor,
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
              if (trailing != null) ...[SizedBox(width: ui(8)), trailing],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final letters = ['A', 'B', 'C', 'D'];
    final correctLetter = letters[question.correctAnswer.clamp(0, 3)];
    final pickIndex = question.userAnswer ?? -1;
    final pickLetter = (pickIndex >= 0 && pickIndex < 4)
        ? letters[pickIndex]
        : '-';
    final pickColor = question.status == 1
        ? const Color(0xFF1AAB5B)
        : const Color(0xFFE0494B);

    final labelStyle = TextStyle(
      color: const Color(0xFF0B081A),
      fontSize: ui(18),
      fontWeight: AppFont.w500,
      fontFamily: 'PingFang SC',
    );
    final valueStyle = TextStyle(
      fontSize: ui(18),
      fontWeight: AppFont.w600,
      fontFamily: 'PingFang SC',
    );

    return Row(
      children: [
        Text('正确答案：', style: labelStyle),
        Text(
          correctLetter,
          style: valueStyle.copyWith(color: const Color(0xFF1AAB5B)),
        ),
        SizedBox(width: ui(36)),
        Text('已选答案：', style: labelStyle),
        Text(pickLetter, style: valueStyle.copyWith(color: pickColor)),
      ],
    );
  }
}

class _NavButtons extends StatelessWidget {
  const _NavButtons({required this.onPrevious, required this.onNext});

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GhostButton(label: '上一题', onTap: onPrevious),
          SizedBox(width: ui(16)),
          _PrimaryButton(label: '下一题', onTap: onNext),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(182),
        height: ui(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(182),
        height: ui(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x59AD80FF),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 完成 / 退出弹窗
// ─────────────────────────────────────────────────────────────────────

class _CompletionDialog extends ConsumerWidget {
  const _CompletionDialog({
    required this.controller,
    required this.providerArgs,
  });

  final QuizSessionController controller;
  final QuizSessionPageArgs providerArgs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizSessionControllerProvider(providerArgs));
    final ui = DashboardScaleScope.of(context).ui;

    final summary = _summaryOf(state, providerArgs.practiceType);
    final notDone = summary?.notDoneCount ?? state.notDoneCount;
    final done = summary?.doneCount ?? state.answeredCount;
    final wrong = summary?.errorCount ?? state.errorCount;
    final accuracyPercent = summary?.accuracyPercent ?? state.accuracyPercent;

    final isExam = providerArgs.practiceType == QuizPracticeType.exam;
    final recommendedLabel = isExam ? '随机练习' : '考前密卷';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: ui(428),
        padding: EdgeInsets.fromLTRB(ui(19), ui(28), ui(19), ui(28)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatGrid(
              notDone: notDone,
              done: done,
              wrong: wrong,
              accuracyPercent: accuracyPercent,
            ),
            SizedBox(height: ui(20)),
            _RecommendedSwitchCard(
              label: recommendedLabel,
              onTap: () async {
                final next = await controller.switchToRecommended();
                if (next == null) {
                  if (context.mounted) {
                    AppToast.show(context, '暂无可切换的练习');
                  }
                  return;
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(
                  context,
                  RoutePaths.campAnswer,
                  arguments: next,
                );
              },
            ),
            SizedBox(height: ui(20)),
            Row(
              children: [
                Expanded(
                  child: _GhostButton(
                    label: '退出',
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.pop(true);
                    },
                  ),
                ),
                SizedBox(width: ui(16)),
                Expanded(
                  child: _PrimaryButton(
                    label: '继续学习',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  QuizPracticeSummary? _summaryOf(
    QuizSessionState state,
    QuizPracticeType type,
  ) {
    for (final s in state.summaryAfter) {
      if (s.type == type) return s;
    }
    return null;
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.notDone,
    required this.done,
    required this.wrong,
    required this.accuracyPercent,
  });

  final int notDone;
  final int done;
  final int wrong;
  final int accuracyPercent;

  @override
  Widget build(BuildContext context) {
    // 设计宽度 = 弹窗宽 428 - 左右各 19 padding = 390
    // 4 个统计格 90×86 + 3 个间距 10 = 360 + 30 = 390，正好填满。
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatCell(value: '$notDone', label: '未做题'),
        _StatCell(value: '$done', label: '已做题'),
        _StatCell(value: '$wrong', label: '错题'),
        _StatCell(value: '$accuracyPercent%', label: '正确率'),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(90),
      height: ui(86),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(24),
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF6D6B75),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedSwitchCard extends StatelessWidget {
  const _RecommendedSwitchCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Stack 让"推荐 badge + 下指小三角"作为浮层"挂"在卡片右上方，
    // badge 顶部超出卡片 5px，三角紧贴 badge 底部指向卡片，
    // 形成消息气泡的视觉。clipBehavior.none 允许超出。
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 卡片本体
          Container(
            height: ui(66),
            padding: EdgeInsets.symmetric(horizontal: ui(20)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5F6FA), Colors.white],
              ),
              borderRadius: BorderRadius.circular(ui(12)),
              border: Border.all(
                color: const Color(0xFFF3F2F3),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                height: 1.0,
              ),
            ),
          ),
          // 浮层"推荐"气泡：定位参考设计稿
          //   弹窗 428、内容宽 390（左右 19 padding）
          //   badge 全局 left=246, top=90；卡片 left=19, top=95
          //   ⇒ badge 在卡片内 right ≈ 390-(246-19)-38 = 125, top = -5
          Positioned(
            right: ui(125),
            top: ui(-5),
            child: Image.asset(
              AppAssets.quizRecommendBubble,
              width: ui(38),
              height: ui(30),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 富文本渲染：题干 / 选项 / 解析共用一套
// ─────────────────────────────────────────────────────────────────────
//
// 工具函数 stripHtmlToText / htmlHasMedia / htmlHasInlineRich 抽到
// `data/quiz_html.dart`，并在 QuizQuestion 构造时算一次，UI 层只
// 消费现成的 fallbackText / hasMedia / hasInlineRich 三个字段。

/// 题干、选项、解析的富文本渲染入口。
///
/// 后端字段是富文本编辑器吐出来的 HTML，常见结构有 `<p>`、`<br>`、
/// `<strong>`、`<em>`、`<sub>`、`<sup>`、`<img>`、`<div>` 等。这
/// 里按内容形态分发到三条最合适的渲染管线：
///
/// 1. **纯文本**（无 `<img>`/无 inline rich）→ `Text(fallbackText)`。
///    最便宜，绕开 HtmlWidget 对 `<p>` 块级 margin 带来的"看似
///    空白"问题。
/// 2. **图文混排**（只有 `<img>`，可能搭配文字）→ 自定义 inline
///    span 解析 → `Text.rich`，让"`[图]文字`"在同一行流动。
///    `HtmlWidget.customWidgetBuilder` 永远把返回的 widget 渲染
///    成块级，会把图片独占一行，所以这种情况必须自己解析。
/// 3. **真正的富文本**（含 `<sup>`/`<sub>`/`<strong>` 或 `<table>`/
///    `<svg>`/`<iframe>` 等复杂结构）→ `HtmlWidget`，并用
///    `customWidgetBuilder` 接管 `<img>` 渲染成响应式图片。
///
/// 题目切换时的"残留"问题统一由 `_SessionBody` 那边给本 widget
/// 的祖先 `_QuestionContent` 加的 `ValueKey(itemId)` 兜底——
/// itemId 一变整个子树 unmount，HtmlWidget 内部的 DOM 缓存 /
/// Image 的 ImageStream 都不会被复用。
class _QuizHtml extends StatelessWidget {
  const _QuizHtml({
    required this.html,
    required this.fallbackText,
    required this.hasMedia,
    required this.hasInlineRich,
    required this.textStyle,
  });

  /// 后端原始 HTML 字符串。
  final String html;

  /// 预 strip 出来的纯文本，HTML 走非 rich 分支 / 空判定时用。
  final String fallbackText;

  /// 是否含图片 / 表格 / 视频 / iframe 等媒体（构造 QuizQuestion
  /// 时就算好的）。
  final bool hasMedia;

  /// 是否含 inline 富文本（`<sup>`/`<sub>`/`<strong>`/`<br>` 等）。
  final bool hasInlineRich;

  /// 普通文本样式（颜色 / 字号 / 字体）。
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) {
      return Text(fallbackText, style: textStyle);
    }

    // ① 纯文本快路径。
    if (!hasMedia && !hasInlineRich) {
      return Text(fallbackText, style: textStyle);
    }

    // ② 含 inline rich 或非 img 的复杂 media（table/svg/...）→
    //    走 HtmlWidget，customWidgetBuilder 接管 img。
    if (hasInlineRich || _hasNonImgMedia(trimmed)) {
      return _buildHtmlWidget(trimmed);
    }

    // ③ 只有 <img> + 文字 → 自定义 inline span 解析，让图文同行。
    final spans = _parseInlineSpans(trimmed, textStyle);
    if (spans.isEmpty) {
      return Text(fallbackText, style: textStyle);
    }
    return Text.rich(TextSpan(children: spans), style: textStyle);
  }

  Widget _buildHtmlWidget(String trimmed) {
    return HtmlWidget(
      trimmed,
      textStyle: textStyle,
      // 关闭默认 ext renderer，自己接管 <img>，避免 _core 包对
      // img 的占位 / 默认行为。
      customWidgetBuilder: (element) {
        if (element.localName != 'img') {
          return null;
        }
        final src = element.attributes['src']?.trim() ?? '';
        if (src.isEmpty) {
          return null;
        }
        final designW = double.tryParse(element.attributes['width'] ?? '');
        final designH = double.tryParse(element.attributes['height'] ?? '');
        return _ResponsiveNetworkImage(
          url: src,
          designWidth: designW,
          designHeight: designH,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// inline span 解析：把"<p><img/>文字</p>"这种简单图文混排 HTML
// 拆成 `List<InlineSpan>`，喂给 `Text.rich` 实现真正的图文同行。
//
// 不试图覆盖所有 HTML（那是 HtmlWidget 的事），只接管"纯文本 +
// `<p>` / `<div>` / `<br>` / `<img>`"这套最常见的形态——后端的
// 题目 / 选项 / 解析里 90%+ 都是这种结构。
// ─────────────────────────────────────────────────────────────────────

final RegExp _inlineImgRegExp = RegExp(
  r'<img\b[^>]*?/?>',
  caseSensitive: false,
);
final RegExp _inlineBrRegExp = RegExp(r'<br\s*/?>', caseSensitive: false);
final RegExp _inlineBlockEndRegExp = RegExp(
  r'</(p|div|li|tr|h[1-6])>',
  caseSensitive: false,
);
final RegExp _inlineBlockStartRegExp = RegExp(
  r'<(p|div|li|tr|h[1-6])\b[^>]*>',
  caseSensitive: false,
);
final RegExp _nonImgMediaRegExp = RegExp(
  r'<(svg|video|audio|iframe|table)\b',
  caseSensitive: false,
);
final RegExp _imgAttrSrcRegExp = RegExp(
  r'''src\s*=\s*(['"])(.*?)\1''',
  caseSensitive: false,
);
final RegExp _imgAttrWidthRegExp = RegExp(
  r'''width\s*=\s*(['"])([^'"]*)\1''',
  caseSensitive: false,
);
final RegExp _imgAttrHeightRegExp = RegExp(
  r'''height\s*=\s*(['"])([^'"]*)\1''',
  caseSensitive: false,
);

bool _hasNonImgMedia(String html) {
  return _nonImgMediaRegExp.hasMatch(html);
}

enum _InlineTokenKind { img, br, blockEnd, blockStart }

class _InlineToken {
  const _InlineToken(this.kind, this.start, this.end, this.match);
  final _InlineTokenKind kind;
  final int start;
  final int end;
  final String match;
}

List<InlineSpan> _parseInlineSpans(String html, TextStyle textStyle) {
  final tokens = <_InlineToken>[];
  for (final m in _inlineImgRegExp.allMatches(html)) {
    tokens.add(_InlineToken(_InlineTokenKind.img, m.start, m.end, m.group(0)!));
  }
  for (final m in _inlineBrRegExp.allMatches(html)) {
    tokens.add(_InlineToken(_InlineTokenKind.br, m.start, m.end, m.group(0)!));
  }
  for (final m in _inlineBlockEndRegExp.allMatches(html)) {
    tokens.add(
      _InlineToken(_InlineTokenKind.blockEnd, m.start, m.end, m.group(0)!),
    );
  }
  for (final m in _inlineBlockStartRegExp.allMatches(html)) {
    tokens.add(
      _InlineToken(_InlineTokenKind.blockStart, m.start, m.end, m.group(0)!),
    );
  }
  tokens.sort((a, b) => a.start.compareTo(b.start));

  final spans = <InlineSpan>[];
  final pendingText = StringBuffer();

  void flushText() {
    if (pendingText.isEmpty) return;
    final decoded = decodeHtmlEntities(pendingText.toString());
    pendingText.clear();
    if (decoded.isEmpty) return;
    spans.add(TextSpan(text: decoded, style: textStyle));
  }

  void appendNewline() {
    flushText();
    if (spans.isEmpty) return;
    final last = spans.last;
    if (last is TextSpan && (last.text ?? '').endsWith('\n')) return;
    spans.add(const TextSpan(text: '\n'));
  }

  var cursor = 0;
  for (final tok in tokens) {
    if (tok.start < cursor) continue; // 罕见的标签区间重叠，跳过
    if (tok.start > cursor) {
      pendingText.write(html.substring(cursor, tok.start));
    }
    cursor = tok.end;

    switch (tok.kind) {
      case _InlineTokenKind.img:
        flushText();
        final src = _imgAttrSrcRegExp.firstMatch(tok.match)?.group(2)?.trim();
        if (src != null && src.isNotEmpty) {
          final w = double.tryParse(
            _imgAttrWidthRegExp.firstMatch(tok.match)?.group(2) ?? '',
          );
          final h = double.tryParse(
            _imgAttrHeightRegExp.firstMatch(tok.match)?.group(2) ?? '',
          );
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _InlineNetworkImage(
                url: src,
                designWidth: w,
                designHeight: h,
              ),
            ),
          );
        }
      case _InlineTokenKind.br:
      case _InlineTokenKind.blockEnd:
        appendNewline();
      case _InlineTokenKind.blockStart:
        // 开标签不引入分隔，纯粹忽略。
        break;
    }
  }
  if (cursor < html.length) {
    pendingText.write(html.substring(cursor));
  }
  flushText();

  // 去掉首尾的纯空白 TextSpan（包括首尾 "\n"）。
  bool isBlank(InlineSpan s) =>
      s is TextSpan && (s.text ?? '').trim().isEmpty;
  while (spans.isNotEmpty && isBlank(spans.first)) {
    spans.removeAt(0);
  }
  while (spans.isNotEmpty && isBlank(spans.last)) {
    spans.removeLast();
  }
  return spans;
}

/// 内联用的网络图片——专门给 `WidgetSpan` 当孩子用，不带 Align /
/// FittedBox，让它能跟周围文字一起按 baseline 走流式布局。
class _InlineNetworkImage extends StatelessWidget {
  const _InlineNetworkImage({
    required this.url,
    this.designWidth,
    this.designHeight,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;

  @override
  Widget build(BuildContext context) {
    final w = designWidth;
    final h = designHeight;
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      width: w,
      height: h,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) =>
          SizedBox(width: w ?? 40, height: h ?? 40),
      errorWidget: (context, _, _) => Container(
        width: w ?? 60,
        height: h ?? 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.broken_image_rounded,
          color: Color(0xFFC9C6D8),
        ),
      ),
    );
  }
}

/// 把后端给的 `<img src=".." width="W" height="H" />` 渲染成
/// 响应式网络图片：
/// - 设计尺寸 ≤ 容器最大宽度：按设计尺寸 1:1 渲染；
/// - 设计尺寸 > 容器最大宽度：`FittedBox(scaleDown)` 自动等比缩放；
/// - 走 [CachedNetworkImage]：磁盘缓存命中时秒出，同一 URL 同 cacheKey
///   避免 image stream 复用时出现"前一帧旧图"残影；
/// - 加载失败退化成灰色 broken image 占位，不会让整张题目崩掉。
///
/// ⚠️ 关键约束：本 widget 的祖先链上有 `IntrinsicHeight`（用于
/// 让 A/B/C/D 同一行两个卡片等高）。`IntrinsicHeight` 会向所有子
/// 孙查询 intrinsic 尺寸，**绝不能**在这里用 `LayoutBuilder`——
/// `LayoutBuilder` 不支持 intrinsic 查询，会直接抛断言导致整页
/// 白屏（典型表现：一行内一个文本一个图片选项时整页空白）。
/// 当前实现链：`Align → FittedBox(scaleDown) → SizedBox(w,h) → CachedNetworkImage`
/// 全部 intrinsic-friendly。
class _ResponsiveNetworkImage extends StatelessWidget {
  const _ResponsiveNetworkImage({
    required this.url,
    this.designWidth,
    this.designHeight,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;

  @override
  Widget build(BuildContext context) {
    final w = designWidth;
    final h = designHeight;

    final image = CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      width: w,
      height: h,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) => SizedBox(
        width: w ?? 40,
        height: h ?? 40,
      ),
      errorWidget: (context, _, _) => Container(
        width: w ?? 60,
        height: h ?? 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.broken_image_rounded,
          color: Color(0xFFC9C6D8),
        ),
      ),
    );

    // 没有设计尺寸：直接交给图片自身的 intrinsic 尺寸 + 父约束
    // 控制大小，左对齐避免被居中拉伸。
    if (w == null || h == null || w <= 0 || h <= 0) {
      return Align(alignment: Alignment.centerLeft, child: image);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        // SizedBox 给 FittedBox 一个明确的"原始尺寸"，FittedBox
        // 才能在父容器变窄时按比例 scaleDown。
        child: SizedBox(width: w, height: h, child: image),
      ),
    );
  }
}
