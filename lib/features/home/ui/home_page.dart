import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../../core/widgets/seamless_banner_carousel.dart';
import '../state/home_dashboard_controller.dart';
import '../state/home_dashboard_state.dart';
import '../../shell/ui/shell_layout.dart';
import '../../smart_campus/state/smart_campus_controller.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeDashboardControllerProvider);

    return _HomePageView(state: state);
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  const _HomePageView({required this.state});

  final HomeDashboardState state;

  @override
  ConsumerState<_HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  int _bannerIndex = 0;

  /// 跳转到智慧校园「我的课表」视图：先把 SmartCampusController 切到
  /// mySchedule 视图，再 push 智慧校园页，避免落在默认 dashboard 上。
  void _openMySchedule() {
    ref.read(smartCampusControllerProvider.notifier).openMySchedule();
    Navigator.pushNamed(context, RoutePaths.smartCampus);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return LayoutBuilder(
      builder: (context, constraints) {
        // ── 精确计算左右面板尺寸，使右侧底部与器乐卡底部齐平 ──────────
        const rightW = 307.0;
        const mainGap = 16.0;
        const actionH = 313.0;
        final leftW = constraints.maxWidth - rightW - mainGap;
        final bannerH = leftW * 190.0 / 647.0;
        final rightH = bannerH + mainGap + actionH;

        return DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'PingFang SC'),
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 主内容行：左侧内容 + 右侧课表通知 ─────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左侧：Banner + 功能矩阵+声乐器乐
                          SizedBox(
                            width: leftW,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Banner：精确高度 = leftW * 190/647
                                SizedBox(
                                  height: bannerH,
                                  child: _buildBanner(
                                    state.bannerItems,
                                    bannerH,
                                  ),
                                ),
                                const SizedBox(height: mainGap),
                                // 功能矩阵 + 声乐/器乐 横排，固定高度 313
                                SizedBox(
                                  height: actionH,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _buildActionBoard(
                                          state.quickActions,
                                        ),
                                      ),
                                      const SizedBox(width: mainGap),
                                      const _VoiceInstrumentColumn(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: mainGap),
                          // 右侧：高度精确匹配左侧，使底部与器乐卡底部齐平
                          SizedBox(
                            width: rightW,
                            height: rightH,
                            child: _buildRightPanel(state),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildLatestHeader(),
                      const SizedBox(height: 10),
                      _buildNewsRow(state.newsItems),
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
          ),
        );
      },
    );
  }

  Widget _buildBanner(List<HomeBannerItem> bannerItems, double height) {
    final images = _effectiveBannerImages(bannerItems);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFF5F6FA))),
          Positioned.fill(
            child: SeamlessBannerCarousel(
              imageUrls: images,
              placeholder: const ColoredBox(color: Color(0xFFF5F6FA)),
              empty: _buildBannerFallbackBackground(),
              animationDuration: const Duration(milliseconds: 420),
              animationCurve: Curves.easeInOutCubic,
              onPageChanged: (index) {
                if (!mounted || _bannerIndex == index) return;
                setState(() => _bannerIndex = index);
              },
            ),
          ),
          // 分页指示器
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
                  child: _BannerIndicator(
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

  List<String> _effectiveBannerImages(List<HomeBannerItem> banners) {
    return banners
        .map((item) => _normalizeImage(item.imageUrl))
        .where((url) => url.isNotEmpty)
        .toList();
  }

  String _normalizeImage(String raw) => MediaUrl.resolve(raw);

  Widget _buildBannerFallbackBackground() {
    return Stack(children: [Container(color: const Color(0xFFF5F6FA))]);
  }

  Widget _buildActionBoard(List<HomeQuickAction> quickActions) {
    final actions = _resolveQuickActions(quickActions);
    // 按 Figma 严格 9 项布局；不足 9 项时补齐避免错位
    final padded = actions.length >= 9
        ? actions.sublist(0, 9)
        : <HomeQuickAction>[
            ...actions,
            for (int i = actions.length; i < 9; i++) actions.last,
          ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.white,
        child: RepaintBoundary(
          // Figma 规格：
          //   - 容器 padding: 上下 24、左右 66
          //   - flex-wrap, gap: 105px, justify-content: center, align-content: center
          //   - 3×3 共 9 个按钮（width:44），固定列间距 105
          //   - 行间距设计稿值 105，但本工程 actionH=313 不够容纳，
          //     这里改用 spaceBetween 在剩余高度内均匀分布（实测 ~36px）
          // 当容器宽度不够时（Figma 理想宽度 = 3*44 + 2*105 + 2*66 = 474），
          // 通过 LayoutBuilder 等比压缩列间距与左右内边距，保证三列始终
          // 单行展示、不发生溢出。
          child: LayoutBuilder(
            builder: (context, constraints) {
              const itemWidth = 44.0;
              const idealGap = 105.0;
              const idealOuterPad = 66.0;
              const minGap = 8.0;
              const minOuterPad = 12.0;
              const idealExtra = 2 * idealGap + 2 * idealOuterPad; // 342

              final w = constraints.maxWidth;
              final extra = (w - 3 * itemWidth).clamp(0.0, double.infinity);

              double gap;
              double outerPad;
              if (extra >= idealExtra) {
                gap = idealGap;
                outerPad = idealOuterPad;
              } else {
                final factor = extra / idealExtra;
                gap = math.max(minGap, idealGap * factor);
                outerPad = math.max(minOuterPad, idealOuterPad * factor);
              }

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: outerPad,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (rowIdx) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int colIdx = 0; colIdx < 3; colIdx++) ...[
                          if (colIdx > 0) SizedBox(width: gap),
                          _QuickActionItem(
                            action: padded[rowIdx * 3 + colIdx],
                            onTap: () => _onQuickActionTap(
                              padded[rowIdx * 3 + colIdx],
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<HomeQuickAction> _resolveQuickActions(List<HomeQuickAction> input) {
    if (input.isNotEmpty) return input.take(9).toList();
    return buildQuickActions(true);
  }

  Widget _buildRightPanel(HomeDashboardState state) {
    final notices = state.courseNotices;
    // 始终展示完整 7 天
    final weekItems = state.weekItems;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '课表',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF1A1A1A),
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
            ),
          ),
          // Figma 视觉间距 12px。
          // PingFang SC OTF 的 lineGap=0，全局 TextHeightBehavior 开关对其无效，
          // box 仍是 1.4× fontSize，下方有 ~6px 不可见 descender padding，
          // 所以 SizedBox 取 12-6=6 才能视觉对齐 Figma。
          const SizedBox(height: 6),
          // 周一~周日，横向可滑动，无滚动条
          SizedBox(
            height: 88,
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(weekItems.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == weekItems.length - 1 ? 0 : 8,
                      ),
                      child: GestureDetector(
                        onTap: _openMySchedule,
                        child: _WeekCard(item: weekItems[index]),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '通知',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF1A1A1A),
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
            ),
          ),
          // Figma 视觉间距 12px。同上：PingFang SC OTF 因 lineGap=0
          // 不受全局 TextHeightBehavior 影响，需手工扣掉 ~6px descender padding。
          const SizedBox(height: 6),
          Expanded(
            child: notices.isEmpty
                ? const _NoticeEmptyState()
                : ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    itemCount: notices.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: _openMySchedule,
                        child: _CourseNoticeCard(notice: notices[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestHeader() {
    return ShellSectionTitleBar(
      title: '最新',
      onMoreTap: () => Navigator.pushNamed(context, RoutePaths.consultation),
    );
  }

  Widget _buildNewsRow(List<HomeNewsItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final news = items;

    // GridView shrinkWrap：4 列等分，多行可滚动（由外层 SingleChildScrollView 承载）
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 138,
      ),
      itemCount: news.length,
      itemBuilder: (context, index) {
        final item = news[index];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            RoutePaths.consultationDetail,
            arguments: <String, dynamic>{'id': item.id},
          ),
          child: _NewsCard(item: item),
        );
      },
    );
  }

  void _onQuickActionTap(HomeQuickAction action) {
    // 模考 / 商城 暂未实装，统一走 2.0 通用单按钮提示弹窗（"暂未开放"）。
    if (action.route == RoutePaths.mock || action.route == RoutePaths.aiSong) {
      showInfoDialog(context: context, title: '功能暂未开放');
      return;
    }
    Navigator.pushNamed(
      context,
      action.route,
      arguments: action.firstMenu == null
          ? null
          : <String, dynamic>{'firstMenu': action.firstMenu.toString()},
    );
  }
}

class _NoticeEmptyState extends StatelessWidget {
  const _NoticeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '暂无通知',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFFB6B5BB),
          fontWeight: AppFont.w400,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.action, required this.onTap});

  final HomeQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              action.icon,
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
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
      ),
    );
  }
}

class _VoiceInstrumentColumn extends StatelessWidget {
  const _VoiceInstrumentColumn();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 146,
      child: Column(
        children: [
          _VoiceCard(
            asset: AppAssets.homeShengyue,
            onTap: () => Navigator.pushNamed(context, RoutePaths.voice),
          ),
          const SizedBox(height: 19),
          _VoiceCard(
            asset: AppAssets.homeQiyue,
            onTap: () => Navigator.pushNamed(context, RoutePaths.instrumental),
          ),
        ],
      ),
    );
  }
}

/// 声乐/器乐卡片：直接使用完整背景图，146×147，圆角 16
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          asset,
          width: 146,
          height: 147,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _BannerIndicator extends StatelessWidget {
  const _BannerIndicator({required this.width, this.opacity = 1});

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

/// 隐藏滚动条的 ScrollBehavior
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.item});

  final HomeWeekDayItem item;

  @override
  Widget build(BuildContext context) {
    final active = item.isToday;

    return Container(
      width: 64,
      height: 88,
      decoration: BoxDecoration(
        // 「今日」高亮背景：从代码渐变改为预设 PNG（[AppAssets.homeWeekTodayBg]
        // = bgc.png，64×88 顶紫底浅渐变，自带 12 圆角）。BoxFit.cover 让位图
        // 撑满整个卡片；外层 borderRadius 仍保留 12，与图本身的圆角对齐时
        // 顺便裁掉 PNG 边缘可能的透明像素，避免在白底上露出锯齿。
        image: active
            ? const DecorationImage(
                image: AssetImage(AppAssets.homeWeekTodayBg),
                fit: BoxFit.cover,
              )
            : null,
        // Figma：非今天卡片底色为 white（与右侧面板同色，仅 chip/文本可见）
        color: active ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            child: Text(
              item.weekText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: active
                    ? const Color(0xFFBBB5F3)
                    : const Color(0xFFA9A9A9),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.43,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 27,
            child: Text(
              item.dayText,
              textAlign: TextAlign.center,
              // 设计稿要求：周课表日期数字 = Manrope Medium（w500）。
              // 字体文件 [assets/fonts/Manrope Medium.ttf] 在 pubspec 里以
              // weight: 500 注册到 Manrope family，下面 w500 直接命中。
              style: TextStyle(
                fontSize: 20,
                color: active ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
                height: 1.35,
                fontFamily: 'Manrope',
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 61,
            child: Container(
              width: 52,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? Colors.white : const Color(0xFFF1F2F7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.courseCount}节',
                style: TextStyle(
                  fontSize: 14,
                  color: active
                      ? const Color(0xFF8741FF)
                      : const Color(0xFFA9A9A9),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.43,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseNoticeCard extends StatelessWidget {
  const _CourseNoticeCard({required this.notice});

  final HomeCourseNotice notice;

  @override
  Widget build(BuildContext context) {
    final statusColor = notice.status == HomeCourseStatus.ended
        ? const Color(0xFFE6E9F1)
        : const Color(0xFFEAE5FF);
    final statusTextColor = notice.status == HomeCourseStatus.ended
        ? const Color(0xFFB6B5BB)
        : const Color(0xFF0B081A);
    final timeTextColor = notice.status == HomeCourseStatus.upcoming
        ? const Color(0xFF0B081A)
        : const Color(0xFF1A1A1A);

    return Container(
      width: double.infinity,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // 时间 + 科目标签：单行排列，CrossAxis center 中线对齐，6px 间距
          // 给状态标签留出 76px 右侧空间（68w + 8 间距）
          Positioned(
            left: 16,
            top: 14,
            right: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 18,
                      color: timeTextColor,
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                    children: [
                      TextSpan(text: '${notice.startTime} '),
                      const TextSpan(
                        text: '- ',
                        style: TextStyle(color: Color(0xFFB6B5BB)),
                      ),
                      TextSpan(text: notice.endTime),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _CourseSubjectTag(name: notice.subjectName),
              ],
            ),
          ),
          // 状态标签：68×22，左下/右上圆角 12
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 68,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Text(
                notice.statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusTextColor,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
          ),
          // 教师头像：40×40 圆形
          Positioned(
            left: 16,
            top: 48,
            child: _NoticeAvatar(primaryUrl: notice.teacherAvatar, size: 40),
          ),
          // 教师姓名 + 课时描述
          Positioned(
            left: 64,
            top: 50,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.teacherName,
                  style: TextStyle(
                    fontSize: 14,
                    height: 22 / 14,
                    color: Color(0xFF0B081A),
                    fontWeight: AppFont.w600,
                    fontFamily: 'PingFang SC',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  notice.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB6B5BB),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 课程科目标签 12px PingFang SC w400，按学科分类切换配色：
/// • 视唱/听音/乐理/钢琴等理论与基础类  → 紫（#EAE5FF / #8741FF）
/// • 笛/箫/笙/胡/筝/吉他等器乐类        → 绿（#DFFCF0 / #0CAC40）
class _CourseSubjectTag extends StatelessWidget {
  const _CourseSubjectTag({required this.name});

  final String name;

  /// 仅用于器乐类匹配的关键字（按设计稿"竹笛课"等绿色样式归类）
  /// 注：钢琴归到默认紫色（属于"基础键盘类"）
  static const List<String> _instrumentKeywords = <String>[
    '笛',
    '箫',
    '笙',
    '胡',
    '筝',
    '阮',
    '琵琶',
    '吉他',
    '提琴',
    '萨克斯',
    '单簧',
    '双簧',
    '长号',
    '小号',
    '圆号',
    '手风琴',
    '竖琴',
    '葫芦丝',
    '陶笛',
    '口琴',
    '鼓',
    '木琴',
  ];

  bool get _isInstrument => _instrumentKeywords.any((kw) => name.contains(kw));

  @override
  Widget build(BuildContext context) {
    final bg = _isInstrument
        ? const Color(0xFFDFFCF0)
        : const Color(0xFFEAE5FF);
    final fg = _isInstrument
        ? const Color(0xFF0CAC40)
        : const Color(0xFF8741FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final HomeNewsItem item;

  @override
  Widget build(BuildContext context) {
    final tags = item.tags.take(3).toList();

    return RepaintBoundary(
      child: Container(
        height: 138,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            const Positioned(left: 16, top: 17.5, child: _NewsBadge()),
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

class _NewsBadge extends StatelessWidget {
  const _NewsBadge();

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

class _NoticeAvatar extends StatelessWidget {
  const _NoticeAvatar({required this.primaryUrl, required this.size});

  final String primaryUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: primaryUrl.isNotEmpty
            ? Image.network(
                primaryUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFEAE5FF),
    alignment: Alignment.center,
    child: Icon(
      Icons.person,
      color: const Color(0xFF8741FF),
      size: size * 0.55,
    ),
  );
}

