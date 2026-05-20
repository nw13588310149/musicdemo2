import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/consultation_controller.dart';
import '../state/consultation_detail_state.dart';
import '../state/consultation_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class ConsultationPage extends ConsumerWidget {
  const ConsultationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consultationControllerProvider);
    final controller = ref.read(consultationControllerProvider.notifier);

    ref.listen<ConsultationState>(consultationControllerProvider, (
      previous,
      next,
    ) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      AppToast.show(context, msg);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) controller.clearError();
      });
    });

    final ui = DashboardScaleScope.of(context).ui;
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        // 与 ShellPageSurface 默认 panelRadius=16 保持一致，避免 header 顶角溢出。
        borderRadius: BorderRadius.circular(ui(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConsultationHeader(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: state.loading && state.items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : state.items.isEmpty
                  ? const _ConsultationEmpty()
                  : _ConsultationBody(items: state.items),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 顶部 56 header（左返回 + 中标题"资讯"）
// ─────────────────────────────────────────────────────────────────────

class _ConsultationHeader extends StatelessWidget {
  const _ConsultationHeader({required this.onBack});

  final VoidCallback onBack;

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
          ConsultationBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                '资讯',
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(16),
                  fontWeight: AppFont.w600,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
          // 占位与左侧对称（保持标题居中）
          SizedBox(width: ui(32)),
        ],
      ),
    );
  }
}

class ConsultationBackButton extends StatelessWidget {
  const ConsultationBackButton({super.key, required this.onTap});

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
// 主体（banner 200 高度 + 3 列网格）
// ─────────────────────────────────────────────────────────────────────

class _ConsultationBody extends StatelessWidget {
  const _ConsultationBody({required this.items});

  final List<ConsultationItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 外层 vertical 12 padding 让滚动条不顶到 header 分割线和白卡底部；
    // 内层滚动 padding 上下各减 12，整体上下间距与原视觉一致。
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(12)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(ui(20), ui(4), ui(20), ui(8)),
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ConsultationBanner(),
            SizedBox(height: ui(16)),
            _ConsultationGrid(items: items),
          ],
        ),
      ),
    );
  }
}

class _ConsultationBanner extends StatelessWidget {
  const _ConsultationBanner();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(200),
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(12)),
        child: Image.asset(
          'assets/images/home/consultation_banner.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6FA),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: ui(28)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '资讯中心',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ui(22),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                          ),
                        ),
                        SizedBox(height: ui(8)),
                        Text(
                          '艺考热点 · 招生简章一手掌握',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: ui(13),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.campaign_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: ui(56),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConsultationGrid extends StatelessWidget {
  const _ConsultationGrid({required this.items});

  final List<ConsultationItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const columns = 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = ui(16);
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: itemWidth,
                child: _ConsultationCard(
                  item: items[i],
                  showLatestBadge: i < 3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.item, required this.showLatestBadge});

  final ConsultationItem item;
  final bool showLatestBadge;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: const Color(0xFFF5F6FA),
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(12)),
        onTap: () => Navigator.pushNamed(
          context,
          RoutePaths.consultationDetail,
          arguments: ConsultationDetailArgs(id: item.id),
        ),
        child: SizedBox(
          height: ui(116),
          // Stack：底层是原有的卡片内容；顶层把「最新」徽标贴到左上角（距上/左各 8）。
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(ui(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardThumbnail(url: item.coverUrl),
                    SizedBox(width: ui(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF0B081A),
                              fontSize: ui(16),
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w500,
                              height: 24 / 16,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                formatRelativeTime(item.createTime),
                                style: TextStyle(
                                  color: const Color(0xFFB6B5BB),
                                  fontSize: ui(12),
                                  fontFamily: 'PingFang SC',
                                  height: 20 / 12,
                                ),
                              ),
                              SizedBox(width: ui(12)),
                              _ViewCount(count: item.viewCount),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showLatestBadge)
                Positioned(
                  left: ui(8),
                  top: ui(8),
                  child: const _LatestBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardThumbnail extends StatelessWidget {
  const _CardThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(6)),
      child: SizedBox(
        width: ui(92),
        height: ui(92),
        child: url.isEmpty
            ? const _ThumbnailPlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const _ThumbnailPlaceholder(),
              ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: const Color(0xFFEFEFF4),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: const Color(0xFFB6B5BB),
        size: ui(28),
      ),
    );
  }
}

class _ViewCount extends StatelessWidget {
  const _ViewCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.visibility_outlined,
          size: ui(14),
          color: const Color(0xFF928FA0),
        ),
        SizedBox(width: ui(4)),
        Text(
          count.toString(),
          style: TextStyle(
            color: const Color(0xFFB6B5BB),
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _LatestBadge extends StatelessWidget {
  const _LatestBadge();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(4)),
      decoration: BoxDecoration(
        color: const Color(0xFF8741FF),
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        '最新',
        style: TextStyle(
          color: Colors.white,
          fontSize: ui(10),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 16 / 10,
        ),
      ),
    );
  }
}

class _ConsultationEmpty extends StatelessWidget {
  const _ConsultationEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.feed_outlined,
            color: const Color(0xFFB6B5BB),
            size: ui(48),
          ),
          SizedBox(height: ui(12)),
          Text(
            '暂无资讯',
            style: TextStyle(
              color: const Color(0xFFB6B5BB),
              fontSize: ui(14),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}
