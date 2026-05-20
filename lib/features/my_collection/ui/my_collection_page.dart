import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/class_share_drawer.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../../video_tutorial/data/video_publisher_data.dart';
import '../state/my_collection_controller.dart';
import '../state/my_collection_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 我的收藏页：
/// - 顶部 6 个 Tab（声乐 / 器乐 / 听写 / 视唱 / 乐理 / 视频），样式与设计稿
///   分段控件一致：#F5F6FA 胶囊容器 + 选中态白色卡片+阴影。
/// - 主体区域根据 [activeType] 渲染三种网格之一：
///     * 声乐 / 器乐：仿首页 `_VoiceSongCard`（173×182、#F4F4FF 卡片）
///     * 听写 / 视唱 / 乐理：仿学习目录 `_LessonCard`（220×100、左侧 60×80 紫色封面）
///     * 视频：仿视频中心 `_VideoGridCard`（220×180，封面+缩略图+作者）
class MyCollectionPage extends ConsumerWidget {
  const MyCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCollectionControllerProvider);
    final controller = ref.read(myCollectionControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: Stack(
            children: [
              // 顶部 Tab 与下方网格区分别绝对定位，与设计稿 left:20 / top:20 / 84 对齐。
              Positioned(
                left: ui(20),
                top: ui(20),
                child: _CollectionTabs(
                  tabs: state.tabs,
                  activeType: state.activeType,
                  onSelect: controller.selectType,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(ui(20), ui(82), ui(20), ui(20)),
                  child: state.loading && state.items.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.items.isEmpty
                      ? const _CollectionEmpty()
                      : _CollectionGrid(
                          state: state,
                          onOpenItem: (item) => _openItem(context, item),
                          onRemove: (item) => _removeItem(context, ref, item),
                          onShare: (item) => _openShare(context, ref, item),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (state.busy && state.shareTarget == null)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x22000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  void _openItem(BuildContext context, CollectionEntry item) {
    final targetId = item.targetId > 0 ? item.targetId : item.id;
    if (targetId <= 0) {
      AppToast.showError(context, '收藏内容已失效');
      return;
    }
    switch (item.type) {
      case 1: // 视唱
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: <String, dynamic>{'id': '$targetId', 'type': 3},
        );
      case 2: // 乐理
        Navigator.pushNamed(
          context,
          RoutePaths.theory,
          arguments: <String, dynamic>{'id': '$targetId'},
        );
      case 3: // 听写
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: <String, dynamic>{'id': '$targetId'},
        );
      case 4: // 声乐
      case 5: // 器乐
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: <String, dynamic>{'id': '$targetId', 'type': 2},
        );
      case 6: // 视频
        // 视频详情接口（videoTutorialDetail）期望的 id 与 videoTutorialList
        // 返回的 id 一致——它就藏在收藏接口给到的 target 快照（rawPayload）
        // 里。优先从 rawPayload['id'] 直接取字符串，避免 CollectionEntry.targetId
        // 走 _toInt 时把非数字 id 折成 0；为空时再退回 targetId。
        final rawVideoId = item.rawPayload['id']?.toString().trim() ?? '';
        final openVideoId = rawVideoId.isNotEmpty ? rawVideoId : '$targetId';
        Navigator.pushNamed(
          context,
          RoutePaths.videoTutorial,
          arguments: <String, dynamic>{'openVideoId': openVideoId},
        );
      case 10: // 试题
        // 按"是否带可播放音频"分流：试题项的 `file1` 是 JSON 字符串数组，
        // 任一 URL 为音频文件（按扩展名识别）→ answerEnd2（musicPlay
        // 题面+答案 + 播放器），否则 → answerEnd（PDF / 阅读式答案页）。
        if (_hasPlayableAudioFile1(item)) {
          Navigator.pushNamed(
            context,
            RoutePaths.answerEnd2,
            arguments: <String, dynamic>{
              'id': '$targetId',
              'closedByDefault': true,
            },
          );
        } else {
          Navigator.pushNamed(
            context,
            RoutePaths.answerEnd,
            arguments: <String, dynamic>{
              'id': '$targetId',
              'answerEndMode': true,
            },
          );
        }
      default:
        AppToast.showError(context, '暂不支持的收藏类型');
    }
  }

  /// 收藏项的 `target.file1` 是否包含可播放音频。
  ///
  /// `file1` 一般是 JSON 字符串数组（如
  /// `'["https://.../1.mp3","https://.../2.mp3"]'`），偶尔是单条 URL；
  /// 只要其中任意一项的扩展名命中常见音频格式即返回 true。
  bool _hasPlayableAudioFile1(CollectionEntry item) {
    final raw = item.rawPayload['file1'];
    if (raw == null) return false;
    final str = raw.toString().trim();
    if (str.isEmpty) return false;

    final urls = <String>[];
    try {
      final decoded = jsonDecode(str);
      if (decoded is List) {
        for (final u in decoded) {
          if (u is String) urls.add(u.trim());
        }
      } else if (decoded is String) {
        urls.add(decoded.trim());
      }
    } catch (_) {
      // 不是合法 JSON：可能就是裸 URL，整体当一项处理。
      urls.add(str);
    }
    // jsonDecode 解析成空 list 的兜底（极少见）。
    if (urls.isEmpty && !str.startsWith('[')) {
      urls.add(str);
    }

    const audioExt = <String>[
      '.mp3',
      '.wav',
      '.m4a',
      '.aac',
      '.ogg',
      '.flac',
      '.opus',
      '.amr',
      '.wma',
    ];
    for (final url in urls) {
      if (url.isEmpty) continue;
      final lower = url.toLowerCase();
      final qIdx = lower.indexOf('?');
      final clean = qIdx >= 0 ? lower.substring(0, qIdx) : lower;
      if (audioExt.any(clean.endsWith)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _openShare(
    BuildContext context,
    WidgetRef ref,
    CollectionEntry item,
  ) async {
    final controller = ref.read(myCollectionControllerProvider.notifier);
    final message = await controller.openShare(item);
    if (!context.mounted) {
      return;
    }
    if (message != null) {
      AppToast.show(context, message);
      return;
    }
    // 复用公共"班级分享"左侧抽屉组件，与课件 / 视频 / 乐理详情等分享 UI 保持一致。
    await showClassShareDrawer<void>(
      context: context,
      child: const _CollectionShareDrawer(),
    );
    // 抽屉被点击外部关闭或发送完成后，清掉控制器里的分享状态，
    // 避免下一次点击 "分享" 时复用旧的目标 / 班级勾选。
    controller.closeShare();
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CollectionEntry item,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '取消收藏',
      content: '确定将“${item.title}”从收藏中移除吗？',
      confirmLabel: '取消收藏',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final message = await ref
        .read(myCollectionControllerProvider.notifier)
        .removeFavorite(item);
    if (context.mounted) {
      AppToast.showSuccess(context, message ?? '已取消收藏');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 顶部 Tab 分段控件
// ──────────────────────────────────────────────────────────────────────────────

class _CollectionTabs extends StatelessWidget {
  const _CollectionTabs({
    required this.tabs,
    required this.activeType,
    required this.onSelect,
  });

  final List<CollectionTabItem> tabs;
  final int activeType;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 不设固定总高度：固定 44px + 上下 padding 后，留给文字的垂直空间不足，
    // 中文（尤其 PingFang）笔画底部会被裁切；高度交给 Row + Tab 子项撑开。
    return Container(
      padding: EdgeInsets.fromLTRB(ui(4), ui(6), ui(3), ui(6)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: ui(16)),
            _CollectionTabItemView(
              label: tabs[i].label,
              active: tabs[i].type == activeType,
              onTap: () => onSelect(tabs[i].type),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollectionTabItemView extends StatelessWidget {
  const _CollectionTabItemView({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: active
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59B5B5B5),
                    blurRadius: 20,
                    offset: Offset(0, 0),
                  ),
                ],
              )
            : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.25,
            leadingDistribution: TextLeadingDistribution.even,
            color: active ? const Color(0xFF0B081A) : const Color(0xFF6D6B75),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 主体网格（根据当前 Tab 切换三种卡片布局）
// ──────────────────────────────────────────────────────────────────────────────

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({
    required this.state,
    required this.onOpenItem,
    required this.onRemove,
    required this.onShare,
  });

  final MyCollectionState state;
  final ValueChanged<CollectionEntry> onOpenItem;
  final ValueChanged<CollectionEntry> onRemove;
  final ValueChanged<CollectionEntry> onShare;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final activeType = state.activeType;

    // 设计稿三种卡片的栅格规格：
    //   - 声乐/器乐：5 列 / 173×182 / 间距 16,14
    //   - 听写/视唱/乐理：4 列 / 220×100 / 间距 16
    //   - 视频：4 列 / 220×180 / 间距 16
    if (activeType == 4 || activeType == 5) {
      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: ui(189),
          childAspectRatio: 173 / 182,
          crossAxisSpacing: ui(16),
          mainAxisSpacing: ui(14),
        ),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          // 声乐 / 器乐：右下角图标点击后弹出 "分享 / 取消收藏" 菜单
          // （样式同 my-notes 左侧分类菜单）。
          return _SongCollectionCard(
            item: item,
            onTap: () => onOpenItem(item),
            onShare: () => onShare(item),
            onRemove: () => onRemove(item),
          );
        },
      );
    }

    if (activeType == 6) {
      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: ui(236),
          childAspectRatio: 220 / 180,
          crossAxisSpacing: ui(16),
          mainAxisSpacing: ui(16),
        ),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          return _VideoCollectionCard(
            item: item,
            onTap: () => onOpenItem(item),
            onMenu: () =>
                _showItemActionSheet(context, item, onRemove, onShare),
          );
        },
      );
    }

    // 听写 / 视唱 / 乐理
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: ui(236),
        mainAxisExtent: ui(100),
        crossAxisSpacing: ui(16),
        mainAxisSpacing: ui(16),
      ),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _LessonCollectionCard(
          item: item,
          onOpen: () => onOpenItem(item),
          onMenu: () => _showItemActionSheet(context, item, onRemove, onShare),
        );
      },
    );
  }
}

Future<void> _showItemActionSheet(
  BuildContext context,
  CollectionEntry item,
  ValueChanged<CollectionEntry> onRemove,
  ValueChanged<CollectionEntry> onShare,
) async {
  final ui = DashboardScaleScope.of(context).ui;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('分享给班级'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onShare(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('取消收藏'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onRemove(item);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// 声乐 / 器乐 卡片：173×182，对齐首页 _VoiceSongCard 设计
// ──────────────────────────────────────────────────────────────────────────────

class _SongCollectionCard extends StatefulWidget {
  const _SongCollectionCard({
    required this.item,
    required this.onTap,
    required this.onShare,
    required this.onRemove,
  });

  final CollectionEntry item;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onRemove;

  @override
  State<_SongCollectionCard> createState() => _SongCollectionCardState();
}

class _SongCollectionCardState extends State<_SongCollectionCard> {
  // 用于把"分享 / 取消收藏"菜单锚定在右下角图标上。
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    final action = await _showSongCollectionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _SongMenuAction.share:
        widget.onShare();
      case _SongMenuAction.remove:
        widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final item = widget.item;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.all(ui(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ui(8)),
                child: _SongCover(coverUrl: item.coverUrl),
              ),
            ),
            SizedBox(height: ui(10)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PingFang SC',
                          fontSize: ui(14),
                          fontWeight: AppFont.w500,
                          color: const Color(0xFF0B081A),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: ui(7)),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PingFang SC',
                          fontSize: ui(12),
                          fontWeight: AppFont.w400,
                          color: const Color(0xFFB6B5BB),
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ui(8)),
                _SongActionButton(
                  key: _menuTriggerKey,
                  onTap: _openActionMenu,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SongCover extends StatelessWidget {
  const _SongCover({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveRemoteUrl(coverUrl);
    if (resolved != null) {
      return CachedNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Image.asset(
      AppAssets.homeFmCover,
      fit: BoxFit.cover,
      width: double.infinity,
    );
  }
}

/// 卡片右下角 20×20 操作图标。设计稿要求此处展示
/// `assets/images/note/1.png`，点击后弹出"分享 / 取消收藏"菜单。
///
/// 图标尺寸 20×20 与「录音」/「我的云盘」**文件夹卡片**右上角的「⋯」
/// （[AppAssets.cloudActionMore]，统一 ui(20)×ui(20)）保持一致，避免
/// 不同列表里"三个点"忽大忽小。资源仍用 `note/1.png` —— 收藏卡片是
/// 浅色填充小圆图标的另一种视觉，与云盘文件夹的纯线性 ⋯ 是不同图，
/// 这次只统一**尺寸**而不换图。
class _SongActionButton extends StatelessWidget {
  const _SongActionButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: ui(20),
        height: ui(20),
        child: Image.asset(
          'assets/images/note/1.png',
          width: ui(20),
          height: ui(20),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 听写 / 视唱 / 乐理 卡片：220×100，对齐学习目录 _LessonCard 设计
// ──────────────────────────────────────────────────────────────────────────────

class _LessonCollectionCard extends StatelessWidget {
  const _LessonCollectionCard({
    required this.item,
    required this.onOpen,
    required this.onMenu,
  });

  final CollectionEntry item;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return GestureDetector(
      onTap: onOpen,
      onLongPress: onMenu,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(ui(10)),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LessonArtwork(type: item.type, title: item.title),
            SizedBox(width: ui(8)),
            Expanded(
              child: SizedBox(
                height: ui(80),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(13),
                              fontWeight: AppFont.w500,
                              color: const Color(0xFF0B081A),
                              fontFamily: 'PingFang SC',
                              height: 1.2,
                            ),
                          ),
                          if (item.subtitle.isNotEmpty) ...[
                            SizedBox(height: ui(6)),
                            Text(
                              item.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ui(11),
                                color: const Color(0xFFB6B5BB),
                                fontFamily: 'PingFang SC',
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _LessonStudyButton(onTap: onOpen),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: onMenu,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.only(left: ui(6), bottom: ui(6)),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: ui(16),
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
      ),
    );
  }
}

class _LessonStudyButton extends StatelessWidget {
  const _LessonStudyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: const Color(0xFF292151),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: Text(
          '去学习',
          style: TextStyle(
            fontSize: ui(11),
            color: Colors.white,
            fontWeight: AppFont.w500,
            fontFamily: 'PingFang SC',
            height: 12 / 11,
          ),
        ),
      ),
    );
  }
}

class _LessonArtwork extends StatelessWidget {
  const _LessonArtwork({required this.type, required this.title});

  final int type;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        width: ui(60),
        height: ui(80),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeDictationBookCover,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: ui(10),
              child: Text(
                _coverText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(12),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB16AFF),
                  fontFamily: 'Alimama ShuHeiTi',
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 与首页 _LessonArtwork 同款两行封面文字：
  ///   听写 → "听选\n单音"
  ///   视唱 → "视唱\n训练"
  ///   乐理 → "乐理\n练习"
  ///   试题 → "试题\n练习"
  String _coverText() {
    return switch (type) {
      1 => '视唱\n训练',
      2 => '乐理\n练习',
      3 => '听选\n单音',
      10 => '试题\n练习',
      _ => '收藏\n内容',
    };
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 视频 卡片：220×180，对齐视频中心 _VideoGridCard 设计
// ──────────────────────────────────────────────────────────────────────────────

class _VideoCollectionCard extends StatelessWidget {
  const _VideoCollectionCard({
    required this.item,
    required this.onTap,
    required this.onMenu,
  });

  final CollectionEntry item;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cw = box.maxWidth;
        final s = cw / 220.0;
        final coverH = 124.0 * s;
        final thumbL = 10.0 * s;
        final thumbTop = 95.0 * s;
        final thumbW = 52.0 * s;
        final thumbH = 70.0 * s;
        final infoLeft = 66.0 * s;

        final coverUrl = MediaUrl.resolve(item.coverUrl);
        final publisher = item.authorName.isNotEmpty
            ? _StaticPublisher(
                nickname: item.authorName,
                avatarAsset: 'assets/images/avtor/1.jpg',
              )
            : _publisherFor(item);

        return Material(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12.0 * s),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: onTap,
            onLongPress: onMenu,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: coverH,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _CollectionImage(
                                url: coverUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 8.0 * s,
                              bottom: 8.0 * s,
                              child: Container(
                                height: 18.0 * s,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.0 * s,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(18.0 * s),
                                ),
                                child: Center(
                                  child: Text(
                                    item.durationText,
                                    style: TextStyle(
                                      fontSize: 12.0 * s,
                                      color: Colors.white,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: AppFont.w400,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            infoLeft,
                            4.0 * s,
                            10.0 * s,
                            15.0 * s,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.0 * s,
                                  color: const Color(0xFF0B081A),
                                  fontWeight: AppFont.w500,
                                  fontFamily: 'PingFang SC',
                                  height: 1.3,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      publisher.avatarAsset,
                                      width: 16.0 * s,
                                      height: 16.0 * s,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 16.0 * s,
                                        height: 16.0 * s,
                                        color: const Color(0xFFE0DEFF),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4.0 * s),
                                  Expanded(
                                    child: Text(
                                      publisher.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.0 * s,
                                        color: const Color(0xFFB6B5BB),
                                        fontFamily: 'PingFang SC',
                                        fontWeight: AppFont.w500,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  Image.asset(
                                    AppAssets.videoV2CardViews,
                                    width: 12.0 * s,
                                    height: 12.0 * s,
                                  ),
                                  SizedBox(width: 4.0 * s),
                                  Text(
                                    item.metricText,
                                    style: TextStyle(
                                      fontSize: 12.0 * s,
                                      color: const Color(0xFFB6B5BB),
                                      fontFamily: 'PingFang SC',
                                      fontWeight: AppFont.w500,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: thumbL,
                  top: thumbTop,
                  width: thumbW,
                  height: thumbH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.0 * s),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.0 * s),
                      child: _CollectionImage(url: coverUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StaticPublisher {
  const _StaticPublisher({required this.nickname, required this.avatarAsset});

  final String nickname;
  final String avatarAsset;
}

_StaticPublisher _publisherFor(CollectionEntry item) {
  final id = item.targetId > 0 ? item.targetId : item.id;
  final info = videoPublisherFor('$id');
  return _StaticPublisher(
    nickname: info.nickname,
    avatarAsset: info.avatarAsset,
  );
}

class _CollectionImage extends StatelessWidget {
  const _CollectionImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _fallback();
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, _) => _fallback(),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFEDEDF2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.ondemand_video_rounded,
        color: Color(0xFFB6B5BB),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 共用：URL 解析、空态、分享面板
// ──────────────────────────────────────────────────────────────────────────────

String? _resolveRemoteUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'string') {
    return null;
  }
  final resolved = MediaUrl.resolve(value);
  return resolved.isEmpty ? null : resolved;
}

class _CollectionEmpty extends StatelessWidget {
  const _CollectionEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.emptyCoursePlaceholder,
            width: ui(163),
            height: ui(163),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(4)),
          Text(
            '暂无收藏',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontSize: ui(16),
              fontWeight: AppFont.w400,
              color: const Color(0xFF0B081A),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 声乐 / 器乐 卡片右下角图标的弹出菜单：分享 + 取消收藏
// 视觉与 my_notes_page 左侧分类的省略号菜单一致：
//   - 142×N 白色面板，圆角 12，浅灰描边 + 双层投影
//   - 行高 36，左侧 20×20 图标 + 13/20 文字
//   - "取消收藏" 行使用红色文字 + 删除图标，与"删除"语义统一
// ──────────────────────────────────────────────────────────────────────────────

enum _SongMenuAction { share, remove }

Future<_SongMenuAction?> _showSongCollectionMenu({
  required BuildContext context,
  required GlobalKey triggerKey,
}) {
  final triggerCtx = triggerKey.currentContext;
  if (triggerCtx == null) {
    return Future<_SongMenuAction?>.value(null);
  }
  final renderBox = triggerCtx.findRenderObject() as RenderBox;
  final overlayBox =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()
          as RenderBox;

  final origin = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = renderBox.size;
  final scale = DashboardScaleScope.of(context);
  final menuWidth = scale.ui(142);
  // 估算高度：top padding(8) + 36 + 6(divider) + 36 + bottom padding(8) ≈ 94
  final approxMenuHeight = scale.ui(96);

  // 与 my_notes_page._showNoteActionMenu 的定位逻辑保持一致：
  // 默认从触发点中心向右下展开；越过右边界则左对齐到按钮中心；
  // 越过下边界则贴底；上 / 左两个方向再做一次 8px 安全边距兜底。
  var left = origin.dx + size.width / 2;
  var top = origin.dy + size.height / 2;

  if (left + menuWidth > overlayBox.size.width - scale.ui(8)) {
    left = origin.dx + size.width / 2 - menuWidth;
  }
  if (left < scale.ui(8)) {
    left = scale.ui(8);
  }
  if (top + approxMenuHeight > overlayBox.size.height - scale.ui(8)) {
    top = overlayBox.size.height - approxMenuHeight - scale.ui(8);
  }
  if (top < scale.ui(8)) {
    top = scale.ui(8);
  }

  return showMenu<_SongMenuAction>(
    context: context,
    elevation: 0,
    color: Colors.transparent,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    constraints: BoxConstraints.tightFor(width: menuWidth),
    position: RelativeRect.fromLTRB(
      left,
      top,
      overlayBox.size.width - left - menuWidth,
      overlayBox.size.height - top,
    ),
    items: <PopupMenuEntry<_SongMenuAction>>[
      PopupMenuItem<_SongMenuAction>(
        enabled: false,
        padding: EdgeInsets.zero,
        // PopupMenu 走独立 Overlay，捕获不到外层 DashboardScaleScope，
        // 这里重新注入一份，保证内部 ui() 计算与卡片一致。
        child: DashboardScaleScope(
          data: scale,
          child: Builder(
            builder: (panelCtx) => _SongMenuPanel(
              onSelected: (action) => Navigator.of(panelCtx).pop(action),
            ),
          ),
        ),
      ),
    ],
  );
}

class _SongMenuPanel extends StatelessWidget {
  const _SongMenuPanel({required this.onSelected});

  final ValueChanged<_SongMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(142),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1.11)),
        boxShadow: [
          BoxShadow(color: const Color(0x050B081A), blurRadius: ui(1)),
          BoxShadow(
            color: const Color(0x0F0B081A),
            blurRadius: ui(40),
            offset: Offset(0, ui(12)),
          ),
          BoxShadow(
            color: const Color(0x050B081A),
            blurRadius: ui(24),
            offset: Offset(0, ui(12)),
            spreadRadius: ui(-16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: ui(8)),
          _SongMenuRow(
            label: '分享',
            icon: AppAssets.coursewareActionShare,
            onTap: () => onSelected(_SongMenuAction.share),
          ),
          SizedBox(height: ui(2)),
          Container(
            margin: EdgeInsets.symmetric(horizontal: ui(8)),
            height: ui(1),
            color: const Color(0xFFF3F4F6),
          ),
          SizedBox(height: ui(3)),
          _SongMenuRow(
            label: '取消收藏',
            icon: AppAssets.coursewareActionDelete,
            danger: true,
            onTap: () => onSelected(_SongMenuAction.remove),
          ),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _SongMenuRow extends StatelessWidget {
  const _SongMenuRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: ui(36),
        child: Row(
          children: [
            SizedBox(width: ui(14)),
            Image.asset(
              icon,
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(10)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: danger
                    ? const Color(0xFFFF323C)
                    : const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 收藏分享：复用公共 ClassShareDrawer（左侧抽屉）
// ──────────────────────────────────────────────────────────────────────────────
//
// 数据流：MyCollectionPage._openShare 先 await `controller.openShare(item)` 拉
// 班级列表，然后通过 `showClassShareDrawer` 把这个 Widget 推入 Navigator。
// Drawer 内部 watch 控制器状态，把班级勾选 / 发送转交给 controller，由
// controller 完成与 1.0 后端的交互；用户外部点击关闭后，外层会再调用
// `controller.closeShare()` 兜底清理状态。
class _CollectionShareDrawer extends ConsumerWidget {
  const _CollectionShareDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCollectionControllerProvider);
    final controller = ref.read(myCollectionControllerProvider.notifier);
    final target = state.shareTarget;
    if (target == null) {
      // 控制器在外部点击关闭抽屉时已经清掉 shareTarget；此时直接渲染
      // 一个空抽屉避免崩溃，Navigator 会立即被外部关闭流程出栈。
      return const ClassShareDrawer(
        title: '分享收藏',
        targetCard: SizedBox.shrink(),
        classes: <ClassShareItem>[],
        loading: false,
        sending: false,
        onToggleClass: _noopToggle,
        onSend: _noopSend,
      );
    }
    final hasClasses = state.shareClasses.isNotEmpty;
    return ClassShareDrawer(
      title: '分享收藏',
      targetCard: ShareTargetCard(
        label: '您将分享的内容',
        title: target.title,
        coverUrl: target.coverUrl,
        resolveUrl: MediaUrl.resolve,
      ),
      classes: state.shareClasses
          .map(
            (c) => ClassShareItem(
              id: '${c.id}',
              name: c.name,
              checked: c.selected,
            ),
          )
          .toList(growable: false),
      // openShare 完成前类列表必为空 + busy=true → loading；
      // 已有班级数据后再点 "发送" 期间 busy=true → sending。
      loading: state.busy && !hasClasses,
      sending: state.busy && hasClasses,
      onToggleClass: (id) {
        final intId = int.tryParse(id) ?? 0;
        if (intId > 0) {
          controller.toggleShareClass(intId);
        }
      },
      onSend: () async {
        final message = await controller.sendShare();
        if (!context.mounted) return;
        if (message != null) {
          AppToast.showError(context, message);
          return;
        }
        Navigator.of(context).pop();
        AppToast.showSuccess(context, '分享成功');
      },
    );
  }
}

void _noopToggle(String _) {}
Future<void> _noopSend() async {}
