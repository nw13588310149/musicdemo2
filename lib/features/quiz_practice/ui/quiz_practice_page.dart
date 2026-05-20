import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/quiz_practice_controller.dart';
import '../state/quiz_practice_state.dart';
import '../state/quiz_session_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class QuizPracticePage extends ConsumerWidget {
  const QuizPracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizPracticeControllerProvider);
    final controller = ref.read(quizPracticeControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    ref.listen<QuizPracticeState>(quizPracticeControllerProvider, (
      previous,
      next,
    ) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      AppToast.show(context, msg);
    });

    // 1.0 布局：banner（240 高度）+ 12px 间距 + 白色卡片（剩余高度），
    // 卡片内 4 个 25% 宽度的圆环。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: ui(240), child: const _CampBanner()),
        SizedBox(height: ui(12)),
        Expanded(
          child: ShellPageSurface(
            padding: EdgeInsets.symmetric(horizontal: ui(25)),
            child: state.loading && state.summaries.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _PracticeRingRow(
                    summaries: state.summaries,
                    onSelect: (summary) =>
                        _openSession(context, controller, summary),
                    onRefresh: controller.refresh,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSession(
    BuildContext context,
    QuizPracticeController controller,
    QuizPracticeSummary summary,
  ) async {
    if (summary.allCount <= 0) {
      AppToast.show(context, '暂无可练习题目');
      return;
    }
    final args = QuizSessionPageArgs(
      practiceType: summary.type,
      practiceId: summary.practiceId,
      startIndex: summary.doneCount,
      allCount: summary.allCount,
    );
    await Navigator.pushNamed(context, RoutePaths.campAnswer, arguments: args);
    if (!context.mounted) {
      return;
    }
    await controller.refresh();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Banner：复用 1.0 的封面图（assets/images/home/camp_banner.jpg），
// 加载失败时回落到紫色渐变占位，避免空白。
// ─────────────────────────────────────────────────────────────────────

class _CampBanner extends StatelessWidget {
  const _CampBanner();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(16)),
      child: Image.asset(
        'assets/images/home/camp_banner.jpg',
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stack) => const _CampBannerFallback(),
      ),
    );
  }
}

class _CampBannerFallback extends StatelessWidget {
  const _CampBannerFallback();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(36)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '刷题练习',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ui(26),
                    fontWeight: AppFont.w600,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(8)),
                Text(
                  '夯实基础 · 知识点专项突破',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.menu_book_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: ui(64),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 4 个圆环卡片（25% 宽度水平排列）
// ─────────────────────────────────────────────────────────────────────

class _PracticeRingRow extends StatelessWidget {
  const _PracticeRingRow({
    required this.summaries,
    required this.onSelect,
    required this.onRefresh,
  });

  final List<QuizPracticeSummary> summaries;
  final ValueChanged<QuizPracticeSummary> onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return Center(
        child: TextButton(onPressed: onRefresh, child: const Text('点击重试')),
      );
    }
    // 1.0：btn_box 高度 188px，内部 4 列居中，每列 25%。
    return Center(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final s in summaries)
            Expanded(
              child: _PracticeRingCard(summary: s, onTap: () => onSelect(s)),
            ),
        ],
      ),
    );
  }
}

class _PracticeRingCard extends StatelessWidget {
  const _PracticeRingCard({required this.summary, required this.onTap});

  final QuizPracticeSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final accent = summary.type.accentColor;
    // 1.0 关键尺寸
    final ringSize = ui(187);
    final innerSize = ui(134);
    final pillWidth = ui(84);
    final pillHeight = ui(42);
    final pillInnerWidth = ui(66);
    final pillInnerHeight = ui(22);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ringSize / 2),
        child: SizedBox(
          height: ringSize + pillHeight / 2,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: summary.progress,
                    color: accent,
                    trackColor: const Color(0xFFF8F8F8),
                    strokeWidth: ui(8),
                  ),
                ),
              ),
              Positioned(
                top: (ringSize - innerSize) / 2,
                child: Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: ui(20),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${summary.progressPercent}%',
                        style: TextStyle(
                          color: const Color(0xFF000000),
                          fontSize: ui(30),
                          fontFamily: 'PingFang SC',
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: ui(8)),
                      Text(
                        summary.type.label,
                        style: TextStyle(
                          color: const Color(0xFF000000),
                          fontSize: ui(14),
                          fontWeight: AppFont.w400,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: pillWidth,
                  height: pillHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(pillHeight / 2),
                  ),
                  child: Container(
                    width: pillInnerWidth,
                    height: pillInnerHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(pillInnerHeight / 2),
                    ),
                    child: Text(
                      '${summary.doneCount}/${summary.allCount}',
                      style: TextStyle(
                        color: const Color(0xFF000000),
                        fontSize: ui(11),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 圆环 painter（1.0：从底部 90° 起，顺时针推进；layer-color #F8F8F8）
// ─────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (progress <= 0) return;
    final fg = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
