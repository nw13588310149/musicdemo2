import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../../core/widgets/seamless_banner_carousel.dart';
import '../../home/state/home_dashboard_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/school_page_controller.dart';
import '../state/school_page_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ── Page entry ────────────────────────────────────────────────────────────────
class SchoolCoursewareV2Page extends ConsumerWidget {
  const SchoolCoursewareV2Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolPageControllerProvider);
    final ctrl = ref.read(schoolPageControllerProvider.notifier);
    return _SchoolView(state: state, onRefresh: ctrl.refresh);
  }
}

// ── Main view ─────────────────────────────────────────────────────────────────
class _SchoolView extends StatelessWidget {
  const _SchoolView({required this.state, required this.onRefresh});

  final SchoolPageState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final actions = _resolveActions(state.quickActions);
    final learningItems = _resolveLearningItems(state.learningItems);
    final newsItems = _resolveNews(state.newsItems);

    return Stack(
      children: [
        AppRefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Main row — LayoutBuilder 精确对齐右侧底部 ────────────
                LayoutBuilder(
                  builder: (ctx, bc) {
                    // 固定参数
                    const rightW = 307.0;
                    const gap = 16.0;

                    // ── Right panel 固定 520（按 Figma 学习进度面板设计高度） ─
                    // 内部布局: 16(top) + 18(标题) + 12(gap) + 146(card) + 8 +
                    //          146 + 8 + 146 + 16(bottom) = 516 ≈ 520。
                    // 左列与右栏底部严格对齐，故强制 leftH = 520。
                    const leftH = 520.0;

                    final leftW = math.max(0.0, bc.maxWidth - gap - rightW);

                    // Banner 高度（647:190 比例）—— 保持响应式比例不变。
                    final bannerH = leftW * 190.0 / 647.0;

                    // 声乐/器乐：每张卡宽 = (leftW - 16) / 2，高 = 宽 × 121/315
                    // —— 保持响应式比例不变。
                    final voiceCardW = math.max(0.0, (leftW - gap) / 2.0);
                    final voiceH = voiceCardW * 121.0 / 315.0;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column — 固定高度 520，与右栏严格对齐底部。
                        // Banner / Voice 维持各自 Figma 比例，剩余空间全部
                        // 给快捷按钮区域（用 Expanded 自动吸收）。
                        SizedBox(
                          width: leftW,
                          height: leftH,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: bannerH,
                                child: _HeroBanner(height: bannerH),
                              ),
                              const SizedBox(height: gap),
                              // 快捷按钮：高度 = leftH - banner - voice - 2*gap
                              // —— 由 Expanded 自动撑开。
                              Expanded(
                                child: _QuickActionsBoard(
                                  actions: actions,
                                  schoolId: state.schoolId,
                                ),
                              ),
                              const SizedBox(height: gap),
                              // 声乐 / 器乐：紧贴底部，与右栏底部对齐。
                              SizedBox(
                                height: voiceH,
                                child: _VoiceInstrumentRow(
                                  schoolId: state.schoolId,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: gap),
                        // Right panel — 固定 520 严格还原 Figma 学习进度面板。
                        SizedBox(
                          width: rightW,
                          height: leftH,
                          child: _LearningProgressPanel(items: learningItems),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // ── 校园资讯 section ──────────────────────────────────────
                // 与首页"最新"区域保持一致：使用 Shell 共享的标题栏 + 同款资讯卡。
                ShellSectionTitleBar(
                  title: '校园资讯',
                  onMoreTap: () =>
                      Navigator.pushNamed(context, RoutePaths.consultation),
                ),
                const SizedBox(height: 10),
                _NewsGrid(items: newsItems),
                const SizedBox(height: 16),
                // Error message
                if (state.errorMessage.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        state.errorMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8B8B8B),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (state.loading)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<SchoolQuickAction> _resolveActions(List<SchoolQuickAction> input) {
    if (input.length >= 6) return input.take(6).toList();
    final merged = <SchoolQuickAction>[...input];
    final existing = input.map((e) => e.name).toSet();
    for (final a in buildSchoolQuickActions()) {
      if (!existing.contains(a.name)) merged.add(a);
    }
    return merged.take(6).toList();
  }

  List<SchoolLearningItem> _resolveLearningItems(
    List<SchoolLearningItem> input,
  ) {
    if (input.length >= 3) return input.take(3).toList();
    const fallback = <SchoolLearningItem>[
      SchoolLearningItem(
        text: '听写',
        value: 40,
        color: Color(0xFFB184FF),
        background: Color(0xFFF0EBFA),
      ),
      SchoolLearningItem(
        text: '视唱',
        value: 40,
        color: Color(0xFF13E8BE),
        background: Color(0xFFF0EBFA),
      ),
      SchoolLearningItem(
        text: '乐理',
        value: 100,
        color: Color(0xFFFF5681),
        background: Color(0xFFF0EBFA),
      ),
    ];
    if (input.isEmpty) return fallback;
    final merged = <SchoolLearningItem>[...input];
    final existing = input.map((e) => e.text).toSet();
    for (final item in fallback) {
      if (!existing.contains(item.text)) merged.add(item);
    }
    return merged.take(3).toList();
  }

  List<SchoolNewsItem> _resolveNews(List<SchoolNewsItem> input) {
    if (input.isNotEmpty) return input.take(4).toList();
    final now = DateTime.now();
    return <SchoolNewsItem>[
      SchoolNewsItem(
        id: -1,
        title: '新疆艺术学院2026年普通本科统招',
        shortTitle: '新疆艺术学院招生简章',
        tags: const ['招生资讯', '元宵资讯', 'C宫系统'],
        viewCount: 0,
        createTime: now.subtract(const Duration(days: 2)),
      ),
      SchoolNewsItem(
        id: -2,
        title: '云南艺术学院2026年普通本科统招',
        shortTitle: '云南艺术学院招生简章',
        tags: const ['统考', '成绩查询'],
        viewCount: 0,
        createTime: now.subtract(const Duration(days: 13)),
      ),
      SchoolNewsItem(
        id: -3,
        title: '四川成都2026年成绩查询',
        shortTitle: '四川成都成绩查询',
        tags: const ['招生简章', '统考', '成绩查询'],
        viewCount: 0,
        createTime: now.subtract(const Duration(days: 16)),
      ),
      SchoolNewsItem(
        id: -4,
        title: '新疆艺术学院2026年普通本科统招',
        shortTitle: '新疆艺术学院招生简章',
        tags: const ['招生简章', '元宵资讯', 'C宫系统'],
        viewCount: 0,
        createTime: now.subtract(const Duration(days: 23)),
      ),
    ];
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────
/// 校园页轮播 Banner。
/// 与首页 `_buildBanner` 保持完全一致：使用通用的 [SeamlessBannerCarousel]，
/// 指示器位置/尺寸与首页严格对齐（right:36, bottom:20, active 21×4，opacity 0.85/1）。
class _HeroBanner extends ConsumerStatefulWidget {
  const _HeroBanner({required this.height});

  final double height;

  @override
  ConsumerState<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<_HeroBanner> {
  int _bannerIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bannerItems = ref.watch(homeDashboardControllerProvider).bannerItems;
    final images = bannerItems
        .map((e) => MediaUrl.resolve(e.imageUrl))
        .where((url) => url.isNotEmpty)
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFF5F6FA))),
          Positioned.fill(
            child: SeamlessBannerCarousel(
              imageUrls: images,
              placeholder: const ColoredBox(color: Color(0xFFF5F6FA)),
              empty: Container(color: const Color(0xFFF5F6FA)),
              animationDuration: const Duration(milliseconds: 420),
              animationCurve: Curves.easeInOutCubic,
              onPageChanged: (index) {
                if (!mounted || _bannerIndex == index) return;
                setState(() => _bannerIndex = index);
              },
            ),
          ),
          Positioned(
            right: 36,
            bottom: 20,
            child: Row(
              children: List.generate(images.isEmpty ? 3 : images.length, (
                index,
              ) {
                final active = images.isEmpty
                    ? index == 0
                    : index == _bannerIndex;
                return Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
                  child: _SchoolBannerIndicator(
                    width: active ? 21 : 4,
                    opacity: active ? 1 : 0.85,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolBannerIndicator extends StatelessWidget {
  const _SchoolBannerIndicator({required this.width, this.opacity = 1});

  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

// ── Quick actions (6 icons in a row) ─────────────────────────────────────────
class _QuickActionsBoard extends StatelessWidget {
  const _QuickActionsBoard({required this.actions, required this.schoolId});

  final List<SchoolQuickAction> actions;
  final int schoolId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions
            .map(
              (a) => _QuickActionItem(
                action: a,
                onTap: () => _handleTap(context, a),
              ),
            )
            .toList(),
      ),
    );
  }

  /// 1.0 `school.vue.onButtonClick` 的 Flutter 等价实现：
  ///   - comingSoon 按钮（商城/模考）→ 弹出"即将上线"占位
  ///   - 其他按钮 → 带上 school 标记 + firstMenu(若有) 推入二级页
  ///     二级页解析 `school` 时使用 truthy 检查，所以传 schoolId（非零 int）也能激活 schoolMode
  void _handleTap(BuildContext context, SchoolQuickAction action) {
    if (action.comingSoon) {
      _showComingSoon(context);
      return;
    }
    final args = <String, dynamic>{};
    // 1.0 通过 `state:{school:schoolInfo.id}` 传递校园上下文；这里保留 id 透传，
    // 以便后续若需要按学校做更细粒度的过滤可直接读取；同时它在二级页面会被
    // truthy 化为 schoolMode=true。
    if (schoolId > 0) {
      args['school'] = schoolId;
    } else {
      args['school'] = true;
    }
    if (action.firstMenu != null) {
      args['firstMenu'] = action.firstMenu.toString();
    }
    Navigator.pushNamed(context, action.route, arguments: args);
  }

  void _showComingSoon(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                AppAssets.homeComingSoon,
                width: 520,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Image.asset(
                AppAssets.homeDialogClose,
                width: 40,
                height: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.action, required this.onTap});

  final SchoolQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const iconSlotSize = 44.0;
    final iconVisualSize = action.route == RoutePaths.videoTutorial
        ? 36.0
        : 44.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: iconSlotSize,
            height: iconSlotSize,
            child: Center(
              child: action.icon.endsWith('.svg')
                  ? AppAssetGraphic(
                      action.icon,
                      width: iconVisualSize,
                      height: iconVisualSize,
                      fit: BoxFit.contain,
                    )
                  : Image.asset(
                      action.icon,
                      width: iconVisualSize,
                      height: iconVisualSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            action.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Voice / Instrument row (315:121 aspect ratio, gap 16) ────────────────────
class _VoiceInstrumentRow extends StatelessWidget {
  const _VoiceInstrumentRow({required this.schoolId});

  final int schoolId;

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    // 通过 LayoutBuilder 计算自适应宽度，再由 315:121 推算按钮高度。
    return LayoutBuilder(
      builder: (_, bc) {
        final cardW = (bc.maxWidth - gap) / 2.0;
        final cardH = cardW * 121.0 / 315.0;
        return SizedBox(
          height: cardH,
          child: Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  bgAsset: AppAssets.homeShengyeu2Bg,
                  iconAsset: AppAssets.homeShengyue2Icon,
                  title: '声乐',
                  subtitle: '掌握技巧，释放天籁之音',
                  iconRightPadding: 22,
                  onTap: () => _go(context, RoutePaths.voice),
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: _FeatureCard(
                  bgAsset: AppAssets.homeQiyue2Bg,
                  iconAsset: AppAssets.homeQieyue2Icon,
                  title: '器乐',
                  subtitle: '习器乐技法，奏美妙乐章',
                  iconRightPadding: 17,
                  onTap: () => _go(context, RoutePaths.instrumental),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 与 1.0 `gosY` / `goQY` 一致：
  ///   - 移除 firstMenu/secondMenu（这里不传即等价于"清空"）
  ///   - 带上 school 标记，让 voice/instrumental 二级页走 schoolTextbookList 接口
  void _go(BuildContext context, String route) {
    final args = <String, dynamic>{'school': schoolId > 0 ? schoolId : true};
    Navigator.pushNamed(context, route, arguments: args);
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.bgAsset,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.iconRightPadding,
    required this.onTap,
  });

  final String bgAsset;
  final String iconAsset;
  final String title;
  final String subtitle;
  final double iconRightPadding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(bgAsset, alignment: Alignment.center),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: iconRightPadding,
              top: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 81.1,
                  height: 87.3,
                  child: Image.asset(iconAsset, alignment: Alignment.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Learning progress panel ──────────────────────────────────────────────────
class _LearningProgressPanel extends StatelessWidget {
  const _LearningProgressPanel({required this.items});

  final List<SchoolLearningItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      // Column 不设 mainAxisSize.min，让其填满 SizedBox 给定的高度
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习进度',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF1A1A1A),
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          // 进度卡占满剩余高度，3 张等分
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  Expanded(child: _ProgressCard(item: items[i])),
                  if (i < items.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.item});

  final SchoolLearningItem item;

  @override
  Widget build(BuildContext context) {
    final meta = _ProgressMeta.fromText(item.text, item.value);

    // 不设固定高度 — 由父级 Expanded 决定高度，内容用 Spacer 撑开
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject + completion tip
          Row(
            children: [
              Text(
                item.text,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A1A),
                  fontWeight: AppFont.w500,
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
              const Spacer(),
              if (meta.tip.isNotEmpty)
                Flexible(
                  child: Text(
                    meta.tip,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      height: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Stats row —— Figma 中三组 _Stat 在卡内（283 宽，左右 16 padding）
          // 平铺，故使用 spaceBetween 严格均分剩余空间。
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(value: meta.totalHours, label: '总共'),
              _Stat(value: meta.completedHours, label: '已上'),
              _Stat(value: meta.remainingHours, label: '剩余'),
            ],
          ),
          const Spacer(),
          // Progress bar row
          Row(
            children: [
              // Figma: 10/500/PingFang SC/#B6B5BB（之前 w400 错位）
              Text(
                '课程进度',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFB6B5BB),
                  fontWeight: AppFont.w500,
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bc) {
                    final trackW = bc.maxWidth;
                    final fillW = (trackW * meta.progress / 100).clamp(
                      0.0,
                      trackW,
                    );
                    const chipW = 31.0;
                    // 气泡中心贴齐 fill 终点；100% 时 clamp 防止溢出 track。
                    final chipCenter = fillW;
                    final chipLeft = (chipCenter - chipW / 2).clamp(
                      0.0,
                      trackW - chipW,
                    );

                    return SizedBox(
                      height: 16,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          // Track（背景 196×8，#F0EBFA，radius 23）
                          Positioned.fill(
                            top: 4,
                            bottom: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0EBFA),
                                borderRadius: BorderRadius.circular(23),
                              ),
                            ),
                          ),
                          // Fill（按 progress% 比例填充，gradient）
                          Positioned(
                            left: 0,
                            top: 4,
                            child: Container(
                              width: fillW,
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    meta.gradientStart,
                                    meta.gradientEnd,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(23),
                              ),
                            ),
                          ),
                          // Percentage chip：31×15、chipColor、white 1px outline、radius 7.5
                          Positioned(
                            left: chipLeft,
                            top: 0,
                            child: Container(
                              width: chipW,
                              height: 15,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: meta.chipColor,
                                borderRadius: BorderRadius.circular(7.5),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${meta.progress.round()}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Barlow',
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 数字（18/600/Barlow）与"课时"（10/400/PingFang）按字母基线对齐，
        // 避免之前用 padding-bottom:2 手工垫高造成的像素偏移。
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
                fontFamily: 'Barlow',
                height: 1,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              '课时',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFFCECED1),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF0B081A),
            fontWeight: AppFont.w500,
            fontFamily: 'PingFang SC',
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ── News grid (4 equal-width cards) ──────────────────────────────────────────
class _NewsGrid extends StatelessWidget {
  const _NewsGrid({required this.items});

  final List<SchoolNewsItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 138,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _NewsCard(item: items[i]),
    );
  }
}

/// 校园资讯卡片：与首页"最新"区域的资讯卡完全一致的视觉规格
/// （字号 / 颜色 / line-height / 元素绝对定位），仅数据来源换为 SchoolNewsItem。
class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final SchoolNewsItem item;

  @override
  Widget build(BuildContext context) {
    final tags = item.tags.take(3).toList();

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        RoutePaths.consultationDetail,
        arguments: <String, dynamic>{'id': item.id},
      ),
      child: RepaintBoundary(
        child: Container(
          height: 138,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              const Positioned(left: 16, top: 17.5, child: _SchoolNewsBadge()),
              // 主标题：16/500/#0B081A，line-height 1.375
              Positioned(
                left: 55,
                top: 15,
                right: 14,
                child: Text(
                  item.shortTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0B081A),
                    fontWeight: AppFont.w500,
                    fontFamily: 'PingFang SC',
                    height: 1.375,
                  ),
                ),
              ),
              // 副标题：14/400/#6D6B75，line-height 1.43
              Positioned(
                left: 16,
                top: 44.5,
                right: 16,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6D6B75),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.43,
                  ),
                ),
              ),
              // 标签行：9.52/400/#6D6B75，背景 #F4F4FF，圆角 4
              Positioned(
                left: 16,
                top: 72.5,
                right: 16,
                height: 18,
                child: Row(
                  children: [
                    for (int i = 0; i < tags.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tags[i],
                          style: TextStyle(
                            fontSize: 9.52,
                            color: Color(0xFF6D6B75),
                            fontWeight: AppFont.w400,
                            height: 11.43 / 9.52,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 时间：11/400/#788698，opacity 0.8，line-height 1.36
              Positioned(
                left: 16,
                top: 110.5,
                child: Opacity(
                  opacity: 0.8,
                  child: Text(
                    _formatTime(item.createTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF788698),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.36,
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

  String _formatTime(DateTime? time) {
    if (time == null) return '刚刚';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    final days = diff.inDays;
    if (days < 30) return '$days天前';
    if (days < 365) return '${(days / 30).floor()}月前';
    return '${(days / 365).floor()}年前';
  }
}

/// 与首页 _NewsBadge 视觉一致的 NEW 标签：紫色背景 + Gilroy 12/500 白字。
class _SchoolNewsBadge extends StatelessWidget {
  const _SchoolNewsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFA773FF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white,
          height: 1,
          fontWeight: FontWeight.w500,
          fontFamily: 'Gilroy',
        ),
      ),
    );
  }
}

// ── Progress meta ─────────────────────────────────────────────────────────────
class _ProgressMeta {
  const _ProgressMeta({
    required this.totalHours,
    required this.completedHours,
    required this.remainingHours,
    required this.progress,
    required this.gradientStart,
    required this.gradientEnd,
    required this.chipColor,
    this.tip = '',
  });

  final int totalHours;
  final int completedHours;
  final int remainingHours;
  final double progress;
  final Color gradientStart;
  final Color gradientEnd;
  // Figma 中进度气泡颜色不等同 gradientEnd —— 听写 #B991FF / 视唱 #20E7C0 /
  // 乐理 #FF7699，单独维护一个字段以便严格还原。
  final Color chipColor;
  final String tip;

  factory _ProgressMeta.fromText(String text, int apiValue) {
    if (text.contains('乐理')) {
      return const _ProgressMeta(
        totalHours: 60,
        completedHours: 60,
        remainingHours: 0,
        progress: 100,
        gradientStart: Color(0xFFFFBECE),
        gradientEnd: Color(0xFFFF5681),
        chipColor: Color(0xFFFF7699),
        tip: '恭喜你！  你完成了乐理的全部课程。',
      );
    }
    if (text.contains('视唱')) {
      return _ProgressMeta(
        totalHours: 60,
        completedHours: 5,
        remainingHours: 55,
        progress: apiValue == 0 ? 40.0 : apiValue.toDouble(),
        gradientStart: const Color(0xFF4DE6C8),
        gradientEnd: const Color(0xFF13E8BE),
        chipColor: const Color(0xFF20E7C0),
      );
    }
    return _ProgressMeta(
      totalHours: 60,
      completedHours: 5,
      remainingHours: 55,
      progress: apiValue == 0 ? 40.0 : apiValue.toDouble(),
      gradientStart: const Color(0xFFD4BFFF),
      gradientEnd: const Color(0xFFB184FF),
      chipColor: const Color(0xFFB991FF),
    );
  }
}
