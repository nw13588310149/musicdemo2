// ─────────────────────────────────────────────────────────────────────────────
// school_video_tutorial_page.dart
// 校园视频页 — 样式与公开视频页保持一致，当前为空数据占位。
// TODO: 后续接入校园视频接口替换 _schoolVideoProvider。
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../shell/ui/shell_layout.dart';

// ── 校园视频 state ──────────────────────────────────────────────────────────

class _SchoolVideoState {
  const _SchoolVideoState();
}

class _SchoolVideoNotifier extends StateNotifier<_SchoolVideoState> {
  _SchoolVideoNotifier() : super(const _SchoolVideoState());

  // TODO: 接入校园视频接口。
  Future<void> refresh() async {}
}

final _schoolVideoProvider =
    StateNotifierProvider.autoDispose<_SchoolVideoNotifier, _SchoolVideoState>(
      (ref) => _SchoolVideoNotifier(),
    );

// ── 页面入口 ────────────────────────────────────────────────────────────────

class SchoolVideoTutorialPage extends ConsumerWidget {
  const SchoolVideoTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_schoolVideoProvider);
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    return Container(
      padding: EdgeInsets.only(bottom: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          // ── 固定头部（与公开视频页结构一致）──────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(12)),
            child: Column(
              children: [
                // 分类 Tab 行（空列表 + 搜索框）
                _CategoryHeader(ui: ui),
                SizedBox(height: ui(16)),
                // Banner + 最新视频（默认占位图）
                _BannerSection(ui: ui),
                // SubCategoryBar：无数据时不占高度，公开页也是如此
              ],
            ),
          ),
          // ── 视频列表区 ─────────────────────────────────────────────────────
          Expanded(
            child: AppRefreshIndicator(
              onRefresh: ref.read(_schoolVideoProvider.notifier).refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        '暂无视频数据',
                        style: TextStyle(
                          fontSize: ui(14),
                          color: const Color(0xFFB6B5BB),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 分类 Tab 行（与 _VideoCategoryHeader 视觉一致，但无数据） ────────────────

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.ui});

  final double Function(double) ui;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ui(44),
      child: Row(
        children: [
          // 空 tab 区（公开页无数据时也是空 ListView）
          const Expanded(child: SizedBox.shrink()),
          SizedBox(width: ui(16)),
          // 搜索框占位（与公开页搜索框完全一致的视觉）
          Container(
            width: ui(220),
            height: ui(40),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            padding: EdgeInsets.symmetric(horizontal: ui(12)),
            child: Row(
              children: [
                AppAssetGraphic(
                  AppAssets.shellV2Search,
                  width: ui(14),
                  height: ui(14),
                  fit: BoxFit.contain,
                ),
                SizedBox(width: ui(8)),
                Text(
                  '搜索视频',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFFD1D1D1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner 区（与 _BannerAndLatestSection 同高，使用默认占位图） ─────────────

class _BannerSection extends StatelessWidget {
  const _BannerSection({required this.ui});

  final double Function(double) ui;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ui(264),
      child: Row(
        children: [
          // Banner 占位（公开页无数据时显示 video_banner.jpg）
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    AppAssets.videoBanner,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: const Color(0xFFEDEDF2),
                      child: Center(
                        child: Icon(
                          Icons.ondemand_video_rounded,
                          color: const Color(0xFFB6B5BB),
                          size: ui(36),
                        ),
                      ),
                    ),
                  ),
                  // 底部渐变遮罩（与公开页一致）
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: ui(70),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          // 最新视频列表占位（与 _LatestVideoListCard 宽度 210 一致）
          _LatestVideosPlaceholder(ui: ui),
        ],
      ),
    );
  }
}

// ── 最新视频占位卡（与 _LatestVideoListCard 宽高一致） ───────────────────────

class _LatestVideosPlaceholder extends StatelessWidget {
  const _LatestVideosPlaceholder({required this.ui});

  final double Function(double) ui;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ui(210),
      height: ui(264),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Center(
        child: Text(
          '最新视频',
          style: TextStyle(fontSize: ui(13), color: const Color(0xFFB6B5BB)),
        ),
      ),
    );
  }
}
