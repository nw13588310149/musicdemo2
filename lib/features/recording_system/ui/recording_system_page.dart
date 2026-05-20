import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/action_menu.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/recording_system_controller.dart';
import '../state/recording_system_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 录音系统的根页面。
///
/// 升级为 [ConsumerStatefulWidget] 是为了挂上两条页面级生命周期钩子，解决
/// 之前两个用户痛点：
///
/// 1. **退出该页要停止"在跑"的录音**：录音控制器是全局 Riverpod
///    [recordingSystemControllerProvider]，导航到别的功能页时它本身不会
///    dispose，老代码也没人调 `recorder.cancel()`，于是 [Timer.periodic] +
///    [AudioRecorder] + 振幅订阅会在后台继续吃 CPU / 麦克风，直到再次回来
///    或彻底崩溃。这里在 [State.dispose] 里调
///    [RecordingSystemController.abandonActiveSession] 把它们一次性收掉。
///
/// 2. **再次进入应该回到列表首页**：上次离开时若停留在录制页 / 试听页，
///    那些视图状态会被 Riverpod 全局 state 一直留着，下次再进来直接掉回
///    录制 / 试听。改成在 [State.initState] 里调 [enterListHome]，无论之前
///    停在哪一层都先归位到分类 / 文件夹列表。
///
/// 同时挂 [WidgetsBindingObserver]，App 切到后台 / inactive 时也立即停掉
/// 录音占用，避免锁屏或切窗口时麦克风被持续占用。
class RecordingSystemPage extends ConsumerStatefulWidget {
  const RecordingSystemPage({super.key});

  @override
  ConsumerState<RecordingSystemPage> createState() =>
      _RecordingSystemPageState();
}

class _RecordingSystemPageState extends ConsumerState<RecordingSystemPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 进入页面立即把视图归位：哪怕全局 state 还停在 record / preview，
    // initState 调用 enterListHome 之后 build 就会渲染列表首页。
    // 用 post-frame 是为了避开 initState 阶段直接同步改 Riverpod 触发的
    // "build 期间通知 listener" 警告。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(recordingSystemControllerProvider.notifier)
          .enterListHome();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 这里不能 await：State.dispose 是同步的。controller.abandonActiveSession
    // 内部全部包了 try-catch，且对 stream / timer 的 cancel 不需要等待回执，
    // 把它当成"发出指令立刻返回"即可。
    ref
        .read(recordingSystemControllerProvider.notifier)
        .abandonActiveSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // App 不再前台可见时（锁屏 / 切到其他 App / 多窗口失焦），无论当前
    // 在录音的哪一层都把麦克风、播放器、振幅订阅收掉。回到前台时不会
    // 自动恢复——用户需要手动重新点击「开始录制」，符合预期。
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref
          .read(recordingSystemControllerProvider.notifier)
          .abandonActiveSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingSystemControllerProvider);
    return switch (state.viewMode) {
      RecordingViewMode.list => _RecordingListView(state: state),
      RecordingViewMode.record => _RecordingEditorView(state: state),
      RecordingViewMode.preview => _RecordingPreviewView(state: state),
    };
  }
}

// ===========================================================================
// 列表页（一/二级）—— 与「我的云盘」一级页面保持一致的布局
// ===========================================================================

class _RecordingListView extends ConsumerStatefulWidget {
  const _RecordingListView({required this.state});

  final RecordingSystemState state;

  @override
  ConsumerState<_RecordingListView> createState() => _RecordingListViewState();
}

class _RecordingListViewState extends ConsumerState<_RecordingListView> {
  late final TextEditingController _searchController;
  String _keyword = '';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.searchQuery);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final value = _searchController.text;
    if (value == _keyword) {
      return;
    }
    setState(() => _keyword = value);
    ref
        .read(recordingSystemControllerProvider.notifier)
        .updateSearchQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                Row(
                  children: [
                    Container(
                      width: ui(180),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(ui(16)),
                        ),
                        border: Border(
                          right: BorderSide(
                            color: const Color(0xFFF3F2F3),
                            width: ui(1),
                          ),
                        ),
                      ),
                      child: _RecordingSidebar(
                        state: state,
                        onSelectCategory: controller.selectCategory,
                        onAddCategory: _showAddCategoryDialog,
                        onCategoryAction: _handleCategoryAction,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(ui(16)),
                          ),
                        ),
                        child: _RecordingContentArea(
                          state: state,
                          keyword: _keyword,
                          searchController: _searchController,
                          sortAscending: _sortAscending,
                          onToggleSort: () =>
                              setState(() => _sortAscending = !_sortAscending),
                          onRefresh: () async {
                            // 文件视图下"刷新"重新拉取该文件夹下的录音；
                            // 文件夹视图下刷新整个列表（含分类）。
                            if (state.isInsideFolder) {
                              await controller.openFolder(
                                RecordingFolderItem(
                                  id: state.currentFolderId,
                                  categoryId: state.selectedCategoryId,
                                  name: state.currentFolderName,
                                ),
                              );
                            } else {
                              await controller.refresh();
                            }
                          },
                          onOpenItem: controller.openPreview,
                          onItemAction: _handleItemAction,
                          onOpenFolder: controller.openFolder,
                          onBackToOverview: controller.backToFolderOverview,
                          onFolderAction: _handleFolderAction,
                          onCreateFolder: _showAddFolderDialog,
                          onCreateRecording: controller.openNewRecording,
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.busy)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(ui(16)),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: ui(28),
                            height: ui(28),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
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

  Future<void> _showAddCategoryDialog() async {
    final name = await showTextInputDialog(
      context: context,
      title: '添加分类',
      hintText: '请输入分类名称',
      confirmLabel: '确认',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    final message = await ref
        .read(recordingSystemControllerProvider.notifier)
        .addCategory(name);
    if (!mounted) {
      return;
    }
    _showMessage(context, message ?? '分类已添加');
  }

  Future<void> _handleCategoryAction(
    RecordingCategoryItem item,
    ItemMenuAction action,
  ) async {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    switch (action) {
      case ItemMenuAction.rename:
        final nextName = await showTextInputDialog(
          context: context,
          title: '重命名分类',
          hintText: '请输入新的分类名称',
          initialValue: item.name,
          confirmLabel: '保存',
        );
        if (nextName == null || nextName.isEmpty || nextName == item.name) {
          return;
        }
        if (!mounted) {
          return;
        }
        final message = await controller.renameCategory(item.id, nextName);
        if (!mounted) {
          return;
        }
        _showMessage(context, message ?? '分类名称已更新');
        break;
      case ItemMenuAction.share:
      case ItemMenuAction.copy:
        // 侧边栏菜单已通过 `showItemActionMenu(actions: ...)` 过滤掉
        // 分享 / 复制项，这里仅为满足 switch 穷举校验的兜底分支。
        break;
      case ItemMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除分类',
          content: '删除"${item.name}"后，该分类下的录音会一并移除，确认继续吗？',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteCategory(item.id);
        if (!mounted) {
          return;
        }
        _showMessage(context, message ?? '分类已删除');
        break;
    }
  }

  Future<void> _showAddFolderDialog() async {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    if (widget.state.selectedCategoryId <= 0) {
      _showMessage(context, '请先选择一个分类');
      return;
    }
    final name = await showTextInputDialog(
      context: context,
      title: '新建文件夹',
      hintText: '请输入文件夹名称',
      confirmLabel: '确认',
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    final message = await controller.addFolder(name);
    if (!mounted) {
      return;
    }
    _showMessage(context, message ?? '文件夹已新建');
  }

  Future<void> _handleFolderAction(
    RecordingFolderItem item,
    ItemMenuAction action,
  ) async {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    switch (action) {
      case ItemMenuAction.rename:
        final nextName = await showTextInputDialog(
          context: context,
          title: '重命名文件夹',
          hintText: '请输入新的文件夹名称',
          initialValue: item.name,
          confirmLabel: '保存',
        );
        if (nextName == null || nextName.isEmpty || nextName == item.name) {
          return;
        }
        if (!mounted) {
          return;
        }
        final message = await controller.renameFolder(item, nextName);
        if (!mounted) {
          return;
        }
        _showMessage(context, message ?? '文件夹已重命名');
        break;
      case ItemMenuAction.share:
      case ItemMenuAction.copy:
        // 文件夹菜单已在 `showItemActionMenu` 中过滤；此分支仅为穷举兜底。
        break;
      case ItemMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除文件夹',
          content: '删除"${item.name}"后，文件夹内的录音也会一并移除，确认继续吗？',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteFolder(item);
        if (!mounted) {
          return;
        }
        _showMessage(context, message ?? '文件夹已删除');
        break;
    }
  }

  Future<void> _handleItemAction(
    RecordingEntry item,
    _RecordingItemAction action,
  ) async {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    switch (action) {
      case _RecordingItemAction.preview:
        await controller.openPreview(item);
        break;
      case _RecordingItemAction.rename:
        // 弹出标题输入框（沿用公共组件），确认后调 controller 走
        // recordingSave 接口（id > 0 触发"按 id 更新"）。
        final nextName = await showTextInputDialog(
          context: context,
          title: '重命名录音',
          hintText: '请输入新的录音名称',
          initialValue: item.name,
          confirmLabel: '保存',
        );
        if (nextName == null || nextName.isEmpty || nextName == item.name) {
          return;
        }
        if (!mounted) {
          return;
        }
        final message = await controller.renameRecording(item, nextName);
        if (!mounted) {
          return;
        }
        _showMessage(context, message ?? '录音已重命名');
        break;
      case _RecordingItemAction.share:
        await controller.openPreview(item);
        if (!mounted) {
          return;
        }
        final message = await controller.openShare();
        if (!mounted) {
          return;
        }
        if (message != null) {
          _showMessage(context, message);
        }
        break;
      case _RecordingItemAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除录音',
          content: '删除后不可恢复，确认删除"${item.name}"吗？',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteRecording(item);
        if (!mounted) {
          return;
        }
        _showMessage(context, message ?? '录音已删除');
        break;
    }
  }
}

class _RecordingSidebar extends StatelessWidget {
  const _RecordingSidebar({
    required this.state,
    required this.onSelectCategory,
    required this.onAddCategory,
    required this.onCategoryAction,
  });

  final RecordingSystemState state;
  final ValueChanged<int> onSelectCategory;
  final VoidCallback onAddCategory;
  final Future<void> Function(RecordingCategoryItem item, ItemMenuAction action)
  onCategoryAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(8), ui(8), ui(8), ui(10)),
      child: Column(
        children: [
          Expanded(
            // 刚进入页面（loading 中且尚未拿到数据）时，侧栏保持空白，
            // 不展示 loading 转圈，避免与右侧 loading 同时出现造成视觉干扰。
            // 加载完成后若仍无数据则提示"暂无分类"，否则展示分类列表。
            child: state.categories.isEmpty
                ? (state.loading
                      ? const SizedBox.shrink()
                      : Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: ui(8)),
                            child: Text(
                              '暂无分类\n点击下方"添加分类"创建',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: ui(12),
                                color: const Color(0xFFB6B5BB),
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ))
                : ListView.separated(
                    itemCount: state.categories.length,
                    separatorBuilder: (_, _) => SizedBox(height: ui(8)),
                    itemBuilder: (context, index) {
                      final item = state.categories[index];
                      return _RecordingCategoryCard(
                        item: item,
                        selected: item.id == state.selectedCategoryId,
                        onTap: () => onSelectCategory(item.id),
                        onAction: (action) => onCategoryAction(item, action),
                      );
                    },
                  ),
          ),
          SizedBox(height: ui(12)),
          _AddCategoryCard(onTap: onAddCategory),
        ],
      ),
    );
  }
}

class _RecordingCategoryCard extends StatefulWidget {
  const _RecordingCategoryCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final RecordingCategoryItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<ItemMenuAction> onAction;

  @override
  State<_RecordingCategoryCard> createState() => _RecordingCategoryCardState();
}

class _RecordingCategoryCardState extends State<_RecordingCategoryCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    // 录音系统侧边栏与「我的笔记」/「我的云盘」分类菜单一致：
    // 只保留「重命名 / 删除」，不暴露分享与复制。
    final action = await showItemActionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
      actions: const <ItemMenuAction>[
        ItemMenuAction.rename,
        ItemMenuAction.delete,
      ],
    );
    if (action != null) {
      widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selected = widget.selected;
    final item = widget.item;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        height: ui(60),
        padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(8), ui(12)),
        decoration: BoxDecoration(
          // Selected: lavender card #EEEAFF with 8 radius (per CSS spec).
          // Non-selected: white card with 16 radius (matches my_notes).
          color: selected ? const Color(0xFFEEEAFF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(selected ? 8 : 16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 选中：保留 CSS 还原的黄色文件夹手绘 glyph；
            // 未选中：使用设计稿提供的灰色文件夹素材 ly.png。
            SizedBox(
              width: ui(36),
              height: ui(36),
              child: selected
                  ? const _RecordingFolderGlyph()
                  : Image.asset(
                      AppAssets.recordingCategoryIdleIcon,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
            ),
            SizedBox(width: ui(5)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 12 / 13,
                    ),
                  ),
                  SizedBox(height: ui(3)),
                  Text(
                    '已存储${item.count}个文件',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(10),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 12 / 10,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              key: _menuTriggerKey,
              behavior: HitTestBehavior.opaque,
              onTap: _openActionMenu,
              child: SizedBox(
                width: ui(24),
                height: ui(24),
                child: const _RecordingDotsGlyph(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yellow folder glyph drawn from the Figma CSS spec
/// (white round bg + yellow folder body, with a tab peeking above).
class _RecordingFolderGlyph extends StatelessWidget {
  const _RecordingFolderGlyph();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(36),
      height: ui(36),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: ui(36),
            height: ui(36),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Folder tab (gradient yellow) sticking up behind the body.
          Positioned(
            left: ui(9),
            top: ui(10),
            width: ui(14),
            height: ui(13),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFB02C), Color(0xFFFFA000)],
                ),
                borderRadius: BorderRadius.circular(ui(1)),
              ),
            ),
          ),
          // Folder body (#FFCA28) covering most of the icon.
          Positioned(
            left: ui(9),
            top: ui(13),
            width: ui(18),
            height: ui(13),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFCA28),
                borderRadius: BorderRadius.circular(ui(1)),
              ),
            ),
          ),
          // Subtle white label strip near the top edge of the body.
          Positioned(
            left: ui(10),
            top: ui(14),
            width: ui(11),
            height: ui(1.4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three vertically-stacked grey dots (the menu trigger glyph).
class _RecordingDotsGlyph extends StatelessWidget {
  const _RecordingDotsGlyph();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final dot = SizedBox(
      width: ui(3.1),
      height: ui(3.1),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFB6B5BB),
          shape: BoxShape.circle,
        ),
      ),
    );
    return SizedBox(
      width: ui(24),
      height: ui(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            SizedBox(height: ui(2)),
            dot,
            SizedBox(height: ui(2)),
            dot,
          ],
        ),
      ),
    );
  }
}

class _AddCategoryCard extends StatelessWidget {
  const _AddCategoryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 设计稿：163×60 的胶囊背景 (#F5F6FA, r=8)，中心向上排版：
    // 18×18 灰色圆形加号 (在 y=13.84 起) + 4px 间距 + 13/12 标题 (在 y=35.84 起)。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(60),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          color: const Color(0xFFF5F6FA),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ui(18),
              height: ui(18),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFB6B5BB),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: ui(12), color: Colors.white),
            ),
            SizedBox(height: ui(4)),
            Text(
              '添加分类',
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 12 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingContentArea extends StatelessWidget {
  const _RecordingContentArea({
    required this.state,
    required this.keyword,
    required this.searchController,
    required this.sortAscending,
    required this.onToggleSort,
    required this.onRefresh,
    required this.onOpenItem,
    required this.onItemAction,
    required this.onOpenFolder,
    required this.onBackToOverview,
    required this.onFolderAction,
    required this.onCreateFolder,
    required this.onCreateRecording,
  });

  final RecordingSystemState state;
  final String keyword;
  final TextEditingController searchController;
  final bool sortAscending;
  final VoidCallback onToggleSort;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecordingEntry> onOpenItem;
  final Future<void> Function(RecordingEntry item, _RecordingItemAction action)
  onItemAction;
  final ValueChanged<RecordingFolderItem> onOpenFolder;
  final Future<void> Function() onBackToOverview;
  final Future<void> Function(RecordingFolderItem item, ItemMenuAction action)
  onFolderAction;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateRecording;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selectedCategoryName = state.selectedCategory?.name ?? '';
    final isInsideFolder = state.isInsideFolder;
    final visibleFolders = _sortedFolders(
      _filterFolders(state.folders, keyword),
      sortAscending,
    );
    final visibleFiles = _sortedFiles(
      _filterFiles(state.items, keyword),
      sortAscending,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(30), ui(28), ui(20), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：进入文件夹后展示面包屑（录音系统 > 分类 > 文件夹），
          // 否则只显示当前选中的分类名（无分类时空占位避免布局抖动）。
          if (isInsideFolder)
            _FolderBreadcrumb(
              items: <String>[
                '录音系统',
                selectedCategoryName,
                state.currentFolderName,
              ],
              onItemTap: (_) => onBackToOverview(),
            )
          else if (selectedCategoryName.isNotEmpty)
            Text(
              selectedCategoryName,
              style: TextStyle(
                fontSize: ui(15),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 12 / 15,
              ),
            )
          else
            SizedBox(height: ui(15)),
          SizedBox(height: ui(16)),
          Row(
            children: [
              SizedBox(
                width: ui(324),
                child: _RecordingSearchField(controller: searchController),
              ),
              const Spacer(),
              _ToolbarChip(
                imageAsset: AppAssets.coursewareSort,
                label: sortAscending ? '正序' : '排序',
                onTap: onToggleSort,
              ),
              SizedBox(width: ui(12)),
              _ToolbarChip(
                imageAsset: AppAssets.coursewareRefresh,
                label: '刷新',
                onTap: () => onRefresh(),
              ),
            ],
          ),
          SizedBox(height: ui(16)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.categories.isEmpty
                      ? const _RecordingEmpty(message: '暂无分类')
                      : isInsideFolder
                      ? (visibleFiles.isEmpty
                            ? const _RecordingEmpty(message: '当前文件夹下还没有录音')
                            : _RecordingFilesGrid(
                                items: visibleFiles,
                                onOpen: onOpenItem,
                                onAction: onItemAction,
                              ))
                      : (visibleFolders.isEmpty
                            ? const _RecordingEmpty(message: '当前分类下还没有文件夹')
                            : _RecordingFoldersGrid(
                                items: visibleFolders,
                                onOpen: onOpenFolder,
                                onAction: onFolderAction,
                              )),
                ),
                Positioned(
                  right: 0,
                  bottom: ui(8),
                  child: _RecordingFab(
                    // 文件夹概览：新建文件夹（与「我的云盘」一致的图标）；
                    // 进入文件夹后：新建录音（保留麦克风图标以示区别）。
                    label: isInsideFolder ? '新建录音' : '新建文件夹',
                    iconAsset: isInsideFolder
                        ? AppAssets.soundFabIcon
                        : AppAssets.coursewareNewFolder,
                    onTap: isInsideFolder ? onCreateRecording : onCreateFolder,
                  ),
                ),
              ],
            ),
          ),
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            Text(
              state.errorMessage!,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFFFF5681),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<RecordingEntry> _filterFiles(
    List<RecordingEntry> items,
    String keyword,
  ) {
    final query = keyword.trim();
    if (query.isEmpty) {
      return items;
    }
    return items
        .where((item) => item.name.contains(query))
        .toList(growable: false);
  }

  List<RecordingEntry> _sortedFiles(
    List<RecordingEntry> items,
    bool ascending,
  ) {
    final list = [...items];
    list.sort((left, right) {
      final byName = left.name.compareTo(right.name);
      return ascending ? byName : -byName;
    });
    return list;
  }

  List<RecordingFolderItem> _filterFolders(
    List<RecordingFolderItem> items,
    String keyword,
  ) {
    final query = keyword.trim();
    if (query.isEmpty) {
      return items;
    }
    return items
        .where((item) => item.name.contains(query))
        .toList(growable: false);
  }

  List<RecordingFolderItem> _sortedFolders(
    List<RecordingFolderItem> items,
    bool ascending,
  ) {
    final list = [...items];
    list.sort((left, right) {
      final byName = left.name.compareTo(right.name);
      return ascending ? byName : -byName;
    });
    return list;
  }
}

/// 与「我的云盘」一致的面包屑：自顶向下显示层级文本，最末位为当前层级（不可点）。
class _FolderBreadcrumb extends StatelessWidget {
  const _FolderBreadcrumb({required this.items, required this.onItemTap});

  final List<String> items;

  /// 点击非末位条目时触发，传入条目索引。
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: ui(6),
      runSpacing: ui(6),
      children: List<Widget>.generate(items.length * 2 - 1, (index) {
        if (index.isOdd) {
          return Icon(
            Icons.chevron_right_rounded,
            size: ui(14),
            color: const Color(0xFFB6B5BB),
          );
        }
        final itemIndex = index ~/ 2;
        final label = items[itemIndex];
        final isLast = itemIndex == items.length - 1;
        final text = Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: isLast ? const Color(0xFF1A1A1A) : const Color(0xFF788698),
            fontFamily: 'PingFang SC',
            fontWeight: isLast ? AppFont.w600 : AppFont.w400,
          ),
        );
        if (isLast) {
          return text;
        }
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onItemTap(itemIndex),
            child: text,
          ),
        );
      }),
    );
  }
}

class _RecordingSearchField extends StatelessWidget {
  const _RecordingSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 写法对齐「我的云盘」的 _CloudSearchField：
    // - 外层固定高度 SizedBox 把 TextField 撑成胶囊；
    // - contentPadding 置零、不开 isDense，让 Material 自带的
    //   textAlignVertical=center 接管，避免 iOS iPad 上 PingFang
    //   字形 line metrics 偏移导致文字偏上 / 偏下。
    return SizedBox(
      height: ui(40),
      child: TextField(
        controller: controller,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: ui(15),
        decoration: InputDecoration(
          hintText: '搜索录音名称',
          hintStyle: TextStyle(
            fontSize: ui(13),
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: ui(12), right: ui(8)),
            child: Image.asset(
              AppAssets.cloudSearch,
              width: ui(16),
              height: ui(16),
              fit: BoxFit.contain,
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: ui(36)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFF3F2F3),
              width: ui(1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFF3F2F3),
              width: ui(1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFD9C7FF),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.imageAsset,
    required this.label,
    required this.onTap,
  });

  final String imageAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imageAsset,
              width: ui(18),
              height: ui(18),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 12 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingFoldersGrid extends StatelessWidget {
  const _RecordingFoldersGrid({
    required this.items,
    required this.onOpen,
    required this.onAction,
  });

  final List<RecordingFolderItem> items;
  final ValueChanged<RecordingFolderItem> onOpen;
  final Future<void> Function(RecordingFolderItem item, ItemMenuAction action)
  onAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: ui(16),
        crossAxisSpacing: ui(16),
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _RecordingFolderCard(
          item: item,
          onTap: () => onOpen(item),
          onAction: (action) => onAction(item, action),
        );
      },
    );
  }
}

class _RecordingFolderCard extends StatefulWidget {
  const _RecordingFolderCard({
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  final RecordingFolderItem item;
  final VoidCallback onTap;
  final ValueChanged<ItemMenuAction> onAction;

  @override
  State<_RecordingFolderCard> createState() => _RecordingFolderCardState();
}

class _RecordingFolderCardState extends State<_RecordingFolderCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    final action = await showItemActionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
      actions: const [ItemMenuAction.rename, ItemMenuAction.delete],
    );
    if (action != null) {
      widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final item = widget.item;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(ui(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(14)),
              child: Stack(
                children: [
                  // 与「我的云盘」相同的文件夹底图（已含日期/大小占位区位置）。
                  Positioned.fill(
                    child: Image.asset(
                      AppAssets.cloudFolderFilledBg,
                      fit: BoxFit.fill,
                    ),
                  ),
                  if (item.dateLabel.isNotEmpty)
                    Positioned(
                      left: ui(10),
                      bottom: ui(28),
                      child: Text(
                        item.dateLabel,
                        style: TextStyle(
                          fontSize: ui(11),
                          color: const Color(0xFF9C91BE),
                          fontFamily: 'Barlow',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  Positioned(
                    left: ui(10),
                    bottom: ui(8),
                    child: Text(
                      item.sizeLabel.isEmpty
                          ? '${item.count} 个录音'
                          : item.sizeLabel,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: const Color(0xFF7F70A8),
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // 右上角操作菜单热区（覆盖底图自带的三点位置）。
                  Positioned(
                    top: ui(32),
                    right: ui(12),
                    child: GestureDetector(
                      key: _menuTriggerKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: _openActionMenu,
                      child: SizedBox(width: ui(34), height: ui(34)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: ui(10)),
          Center(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              // fontWeight 故意写 FontWeight.w400 而不是 AppFont.w400：
              // AppFont.w400 在 iOS 会被上浮一档（→ w500，命中
              // PingFangSC-Medium.otf）做 CJK 视觉补偿；这里设计稿明确
              // 要求字面用 PingFangSC-Regular.otf，不接受补偿，因此绕开
              // [AppFont] 直接用原生 [FontWeight] 锁住 w400 槽位。
              // 与「我的云盘」文件夹卡片（courseware_page.dart 中的
              // [_FolderCard]）的标题样式严格保持一致。
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 15 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingFilesGrid extends StatelessWidget {
  const _RecordingFilesGrid({
    required this.items,
    required this.onOpen,
    required this.onAction,
  });

  final List<RecordingEntry> items;
  final ValueChanged<RecordingEntry> onOpen;
  final Future<void> Function(RecordingEntry item, _RecordingItemAction action)
  onAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: ui(16),
        crossAxisSpacing: ui(16),
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _RecordingFileCard(
          item: item,
          onTap: () => onOpen(item),
          onAction: (action) => onAction(item, action),
        );
      },
    );
  }
}

class _RecordingFileCard extends StatefulWidget {
  const _RecordingFileCard({
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  final RecordingEntry item;
  final VoidCallback onTap;
  final ValueChanged<_RecordingItemAction> onAction;

  @override
  State<_RecordingFileCard> createState() => _RecordingFileCardState();
}

class _RecordingFileCardState extends State<_RecordingFileCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    final action = await showItemActionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
      actions: const [
        ItemMenuAction.rename,
        ItemMenuAction.share,
        ItemMenuAction.delete,
      ],
    );
    if (action == null) return;
    switch (action) {
      case ItemMenuAction.rename:
        widget.onAction(_RecordingItemAction.rename);
        break;
      case ItemMenuAction.share:
        widget.onAction(_RecordingItemAction.share);
        break;
      case ItemMenuAction.delete:
        widget.onAction(_RecordingItemAction.delete);
        break;
      case ItemMenuAction.copy:
        // 文件菜单不暴露"复制"，此分支仅为穷举兜底。
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final item = widget.item;
    // 与「我的云盘」文件卡保持完全一致的结构：上半部分仅放占位图（不要类型徽标），
    // 下半部分 58px 灰色信息条里放 [标题 | ⋯] 和 [大小 | 日期]。
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: const Color(0xFFF5F6FA), width: ui(1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  // 录音文件占位图（sound/18.png：录音波形 + "录音"标签）。
                  // 与云盘 88×88 的类型图标尺寸保持一致。
                  child: Image.asset(
                    AppAssets.soundRecordingFile,
                    width: ui(88),
                    height: ui(88),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // 底部 58px 信息条 (#F5F6FA)：[标题 | ⋯] + [大小 | 日期]。
              Container(
                height: ui(58),
                color: const Color(0xFFF5F6FA),
                padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(8), ui(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(13),
                              color: const Color(0xFF0B081A),
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w500,
                              height: 12 / 13,
                            ),
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        GestureDetector(
                          key: _menuTriggerKey,
                          behavior: HitTestBehavior.opaque,
                          onTap: _openActionMenu,
                          child: SizedBox(
                            width: ui(20),
                            height: ui(20),
                            child: Image.asset(
                              AppAssets.cloudActionMore,
                              width: ui(20),
                              height: ui(20),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(6)),
                    Padding(
                      padding: EdgeInsets.only(right: ui(4)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.sizeLabel.isEmpty
                                ? item.durationLabel
                                : item.sizeLabel,
                            style: TextStyle(
                              fontSize: ui(10),
                              color: const Color(0xFFB6B5BB),
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w500,
                              height: 12 / 10,
                            ),
                          ),
                          Text(
                            item.dateLabel,
                            style: TextStyle(
                              fontSize: ui(10),
                              color: const Color(0xFFB6B5BB),
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w500,
                              height: 12 / 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingFab extends StatelessWidget {
  const _RecordingFab({
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(13), vertical: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconAsset,
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(16),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 12 / 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingEmpty extends StatelessWidget {
  const _RecordingEmpty({this.message = '暂无录音'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/404/ly.png',
            width: ui(200),
            height: ui(200),
            fit: BoxFit.contain,
          ),
          Text(
            message,
            style: TextStyle(
              fontSize: ui(15),
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 三级页面：录音编辑 / 播放试听（按 Figma 设计）
// ===========================================================================

/// 录音「录制」视图。
///
/// 性能要点（record + just_audio 重写版）：
/// - 高频更新——秒表 / 实时波形 / 滚动进度条——全部由 controller 暴露的
///   两个 [ValueNotifier]（`elapsedMs` / `liveAmplitudes`）驱动，UI 用
///   [ValueListenableBuilder] 局部订阅。本视图外层只读 Riverpod 的低频
///   字段（`recordingPhase` / `errorMessage`），开始 / 暂停 / 继续等手势
///   才会触发整页骨架重建。
/// - 波形面板内部由自绘 [_LiveWavePainter] 渲染最近 N 个振幅样本，画在
///   一层 [RepaintBoundary] 里，外层 stage（含返回按钮、标题栏、左右
///   pill、中间大圆按钮）始终不进 raster 任务，避开了之前用户反馈的
///   "录制时整页 jank"。
class _RecordingEditorView extends ConsumerWidget {
  const _RecordingEditorView({required this.state});

  final RecordingSystemState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final phase = state.recordingPhase;

    // 左侧 pill：idle 状态展示「暂停」白底胶囊（视觉占位、不可点）；
    // 录制 / 暂停状态展示「继续」红字胶囊（仅在 paused 时点击恢复）。
    // 仅依赖 phase，可以在外层算一次。
    final Widget leftPill;
    switch (phase) {
      case RecordingPhase.idle:
        leftPill = _SoundControlButton(
          asset: AppAssets.soundRecordPauseButton,
          onTap: null,
        );
        break;
      case RecordingPhase.recording:
        leftPill = _SoundControlButton(
          asset: AppAssets.soundContinueButton,
          onTap: null,
        );
        break;
      case RecordingPhase.paused:
        leftPill = _SoundControlButton(
          asset: AppAssets.soundContinueButton,
          onTap: () async {
            final message = await controller.resumeRecording();
            if (message != null && context.mounted) {
              _showMessage(context, message);
            }
          },
        );
        break;
    }

    // 中间大圆形按钮：图标表示「当前状态」、点击切换到对应动作。
    final centerAsset = switch (phase) {
      RecordingPhase.idle => AppAssets.soundRecordIdle,
      RecordingPhase.recording => AppAssets.soundPlayCircle,
      RecordingPhase.paused => AppAssets.soundPauseCircle,
    };
    final centerControls = _RecordTransportControls(
      centerAsset: centerAsset,
      onCenterTap: () async {
        final message = switch (phase) {
          RecordingPhase.idle => await controller.startRecording(),
          RecordingPhase.recording => await controller.pauseRecording(),
          RecordingPhase.paused => await controller.resumeRecording(),
        };
        if (message != null && context.mounted) {
          _showMessage(context, message);
        }
      },
    );

    final errorMessage = state.errorMessage;

    return _RecordingStage(
      title: '音频录制',
      onBack: controller.backToList,
      headerActions: const [],
      body: _RecordingStageBody(
        // 实时波形：订阅 controller.liveAmplitudes，仅波形面板这一格重建。
        wavePanel: _LiveDarkWavePanel(samples: controller.liveAmplitudes),
        // 进度滚动条：订阅 controller.elapsedMs，仅 scrubber 重建。
        scrubberPanel: ValueListenableBuilder<int>(
          valueListenable: controller.elapsedMs,
          builder: (context, elapsedMs, _) {
            final displayDurationMs = math.max(elapsedMs, 8000);
            final progressRatio = (elapsedMs / displayDurationMs)
                .clamp(0.0, 1.0)
                .toDouble();
            return _DarkScrubberPanel(
              progressRatio: progressRatio,
              startLabel: _formatSecondsClock(elapsedMs),
              endLabel: _formatSecondsClock(displayDurationMs),
            );
          },
        ),
        // 秒表 capsule：订阅 controller.elapsedMs，单个 Text 子树重建。
        timerCapsule: ValueListenableBuilder<int>(
          valueListenable: controller.elapsedMs,
          builder: (context, elapsedMs, _) =>
              _GraniteTimerCapsule(label: _formatClock(elapsedMs)),
        ),
        // 底部提示 + 试听按钮：根据 elapsedMs 切两个状态。
        bottomCenter: ValueListenableBuilder<int>(
          valueListenable: controller.elapsedMs,
          builder: (context, elapsedMs, _) {
            final canListenWhileRecording =
                elapsedMs >= 1000 &&
                elapsedMs < 5000 &&
                (phase == RecordingPhase.recording ||
                    phase == RecordingPhase.paused);
            final tipText = canListenWhileRecording
                ? '未满 5 秒可先试听当前录音（将结束本条录制）'
                : '录制不能低于5秒';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tipText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: DashboardScaleScope.of(context).ui(12),
                    color: const Color(0xFFB6B5BB),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                ),
                if (canListenWhileRecording) ...[
                  SizedBox(height: DashboardScaleScope.of(context).ui(8)),
                  TextButton(
                    onPressed: () async {
                      final message =
                          await controller.finalizeRecordingForListening();
                      if (message != null && context.mounted) {
                        _showMessage(context, message);
                      }
                    },
                    child: Text(
                      '试听当前录音',
                      style: TextStyle(
                        fontSize: DashboardScaleScope.of(context).ui(14),
                        color: const Color(0xFF8741FF),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        leftPill: leftPill,
        centerControls: centerControls,
        // 右侧「完成」按钮：可用态依赖 elapsedMs ≥ 5s。
        rightPill: ValueListenableBuilder<int>(
          valueListenable: controller.elapsedMs,
          builder: (context, elapsedMs, _) {
            final canFinish = elapsedMs >= 5000;
            return _SoundControlButton(
              asset: AppAssets.soundFinishButton,
              onTap: canFinish
                  ? () async {
                      final message = await controller.finishRecording();
                      if (message != null && context.mounted) {
                        _showMessage(context, message);
                      }
                    }
                  : null,
            );
          },
        ),
        errorMessage: errorMessage,
      ),
    );
  }
}

class _RecordingPreviewView extends ConsumerWidget {
  const _RecordingPreviewView({required this.state});

  final RecordingSystemState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;
    final item = state.previewItem;
    // 试听页 position / duration 都由 controller 暴露的 ValueNotifier 驱动
    // （内部由 just_audio 的 positionStream / durationStream 灌进去），
    // UI 这边纯粹用 ValueListenableBuilder 局部订阅，不再走 audio_waveforms
    // 双引擎 / kIsWeb 分支那一套。本视图外层只读 Riverpod 的低频字段
    // （previewItem / previewPlaying / errorMessage）。
    final fallbackTotalMs = state.previewDurationMs > 0
        ? state.previewDurationMs
        : _parseDurationLabel(item?.durationLabel ?? '00:00.00');

    // 「音频录制」播放页：草稿试听与已保存回放共用同一套布局。
    // - 顶部：本地草稿显示「保存」（手动打开保存弹窗）；已入库作品不显示。
    // - 「分享 / 删除」保留。
    // - 底部：-15s、播放/暂停、+15s。
    final headerActions = <Widget>[
      if (item?.isLocalDraft == true &&
          state.recordedBytes != null &&
          state.recordedBytes!.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(right: ui(8)),
          child: InkWell(
            onTap: controller.requestSaveDialog,
            borderRadius: BorderRadius.circular(ui(8)),
            child: Container(
              height: ui(32),
              padding: EdgeInsets.symmetric(horizontal: ui(12)),
              decoration: BoxDecoration(
                color: const Color(0xFF8741FF),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save_rounded, size: ui(16), color: Colors.white),
                  SizedBox(width: ui(4)),
                  Text(
                    '保存',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      _LightHeaderButton(
        iconAsset: AppAssets.coursewareActionShare,
        label: '分享',
        onTap: () async {
          final message = await controller.openShare();
          if (message != null && context.mounted) {
            _showMessage(context, message);
          }
        },
      ),
      _LightHeaderButton(
        iconAsset: AppAssets.coursewareActionDelete,
        label: '删除',
        onTap: () async {
          if (item == null) {
            return;
          }
          final confirmed = await showConfirmDialog(
            context: context,
            title: '删除录音',
            content: '删除后不可恢复，确认删除"${item.name}"吗？',
            confirmLabel: '删除',
          );
          if (!confirmed || !context.mounted) {
            return;
          }
          final message = await controller.deleteRecording(item);
          if (message != null && context.mounted) {
            _showMessage(context, message);
          }
        },
      ),
    ];

    // 波形面板：用录音时捕获的振幅快照（已保存的作品退而求其次用 seed
    // 生成的占位波形），叠加一个跟随 previewPositionMs 移动的进度光标。
    // 同一份代码 native + web 通用，省掉了之前 kIsWeb 双分支。
    final wavePanel = _PreviewDarkWavePanel(
      waveform: item?.waveform ?? const <double>[],
      positionMs: controller.previewPositionMs,
      durationMs: controller.previewDurationMs,
      fallbackDurationMs: fallbackTotalMs,
      onSeekRatio: (ratio) {
        final dur = controller.previewDurationMs.value > 0
            ? controller.previewDurationMs.value
            : fallbackTotalMs;
        if (dur <= 0) return;
        controller.seekPreviewTo((dur * ratio).round());
      },
    );

    final scrubber = ValueListenableBuilder<int>(
      valueListenable: controller.previewPositionMs,
      builder: (context, positionMs, _) {
        return ValueListenableBuilder<int>(
          valueListenable: controller.previewDurationMs,
          builder: (context, durationMs, _) {
            final totalMs = durationMs > 0 ? durationMs : fallbackTotalMs;
            final clampedTotalMs = math.max(totalMs, 8000);
            final progressRatio = totalMs <= 0
                ? 0.0
                : (positionMs / totalMs).clamp(0.0, 1.0).toDouble();
            return _DarkScrubberPanel(
              progressRatio: progressRatio,
              startLabel: _formatSecondsClock(positionMs),
              endLabel: _formatSecondsClock(clampedTotalMs),
            );
          },
        );
      },
    );

    final timer = ValueListenableBuilder<int>(
      valueListenable: controller.previewPositionMs,
      builder: (context, positionMs, _) =>
          _GraniteTimerCapsule(label: _formatClock(positionMs)),
    );

    return _RecordingStage(
      title: '音频录制',
      onBack: controller.backToList,
      headerActions: headerActions,
      body: _RecordingStageBody(
        wavePanel: wavePanel,
        scrubberPanel: scrubber,
        timerCapsule: timer,
        bottomCenter: Text(
          '录制不能低于5秒',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(12),
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
        ),
        leftPill: const SizedBox.shrink(),
        rightPill: const SizedBox.shrink(),
        centerControls: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _SoundIconButton(
              asset: AppAssets.soundSeekBack15,
              size: ui(32),
              onTap: () => controller.seekPreviewBy(-15000),
            ),
            SizedBox(width: ui(52)),
            // 正中央：大紫色播放 / 暂停按钮（设计稿 72×72，#8741FF）。
            // previewPlaying 是低频字段，由 PlayerController 状态变化驱动
            // Riverpod state 同步，外层 state 触发本视图重建即可。
            _SoundIconButton(
              asset: state.previewPlaying
                  ? AppAssets.soundPauseCircle
                  : AppAssets.soundPlayCircle,
              size: ui(72),
              onTap: controller.togglePreviewPlayback,
            ),
            SizedBox(width: ui(52)),
            _SoundIconButton(
              asset: AppAssets.soundSeekForward15,
              size: ui(32),
              onTap: () => controller.seekPreviewBy(15000),
            ),
          ],
        ),
        errorMessage: state.errorMessage,
      ),
    );
  }
}

class _RecordingStage extends ConsumerStatefulWidget {
  const _RecordingStage({
    required this.title,
    required this.onBack,
    required this.headerActions,
    required this.body,
  });

  final String title;
  final Future<void> Function() onBack;
  final List<Widget> headerActions;
  final Widget body;

  @override
  ConsumerState<_RecordingStage> createState() => _RecordingStageState();
}

class _RecordingStageState extends ConsumerState<_RecordingStage> {
  BuildContext? _saveDialogContext;
  BuildContext? _shareDialogContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final state = ref.read(recordingSystemControllerProvider);
      if (state.showSaveDialog) {
        _openSaveDialog();
      }
      if (state.showShareDialog) {
        _openShareDialog();
      }
    });
  }

  @override
  void dispose() {
    // dispose 阶段对话框可能已经被 Riverpod / Navigator 收掉了，pop 会抛
    // "looking up a deactivated widget's ancestor" 类异常。每一段都吞掉，
    // 保证 super.dispose 一定能跑到，不会让外层 Stage widget 半个状态退出。
    final saveCtx = _saveDialogContext;
    _saveDialogContext = null;
    if (saveCtx != null) {
      try {
        Navigator.of(saveCtx).pop();
      } catch (_) {}
    }
    final shareCtx = _shareDialogContext;
    _shareDialogContext = null;
    if (shareCtx != null) {
      try {
        Navigator.of(shareCtx).pop();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _openSaveDialog() async {
    if (_saveDialogContext != null) {
      return;
    }
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
      builder: (dialogCtx) {
        _saveDialogContext = dialogCtx;
        return const _SaveRecordingDialog();
      },
    );
    _saveDialogContext = null;
    if (!mounted) {
      return;
    }
    if (ref.read(recordingSystemControllerProvider).showSaveDialog) {
      ref.read(recordingSystemControllerProvider.notifier).closeSaveDialog();
    }
  }

  Future<void> _openShareDialog() async {
    if (_shareDialogContext != null) {
      return;
    }
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
      builder: (dialogCtx) {
        _shareDialogContext = dialogCtx;
        return const _ShareRecordingDialog();
      },
    );
    _shareDialogContext = null;
    if (!mounted) {
      return;
    }
    if (ref.read(recordingSystemControllerProvider).showShareDialog) {
      ref.read(recordingSystemControllerProvider.notifier).closeShareDialog();
    }
  }

  void _closeSaveDialog() {
    final ctx = _saveDialogContext;
    if (ctx == null) {
      return;
    }
    _saveDialogContext = null;
    Navigator.of(ctx).pop();
  }

  void _closeShareDialog() {
    final ctx = _shareDialogContext;
    if (ctx == null) {
      return;
    }
    _shareDialogContext = null;
    Navigator.of(ctx).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RecordingSystemState>(recordingSystemControllerProvider, (
      prev,
      next,
    ) {
      final prevSave = prev?.showSaveDialog ?? false;
      final prevShare = prev?.showShareDialog ?? false;
      if (prevSave != next.showSaveDialog) {
        if (next.showSaveDialog) {
          _openSaveDialog();
        } else {
          _closeSaveDialog();
        }
      }
      if (prevShare != next.showShareDialog) {
        if (next.showShareDialog) {
          _openShareDialog();
        } else {
          _closeShareDialog();
        }
      }
    });
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          Container(
            height: ui(56),
            padding: EdgeInsets.symmetric(horizontal: ui(12)),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1),
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => widget.onBack(),
                  borderRadius: BorderRadius.circular(ui(8)),
                  child: Container(
                    width: ui(32),
                    height: ui(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(8)),
                      border: Border.all(
                        color: const Color(0xFFF3F2F3),
                        width: ui(1),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: ui(18),
                      color: const Color(0xFF1C274C),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: const Color(0xFF0B081A),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ),
                ),
                if (widget.headerActions.isEmpty)
                  SizedBox(width: ui(32))
                else
                  Wrap(spacing: ui(8), children: widget.headerActions),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(25), ui(20), ui(20)),
              child: widget.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _LightHeaderButton extends StatelessWidget {
  const _LightHeaderButton({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconAsset,
              width: ui(16),
              height: ui(16),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 录制 / 试听页的共用骨架。布局保持原样（暗色波形面板、scrubber、
/// 秒表 capsule、底部三段控件），但所有「内容会变」的位置都改成
/// 由调用方传入 [Widget] 的 slot 模式：调用方决定要不要包
/// [AnimatedBuilder] / [StreamBuilder] 做局部重建，本骨架只负责定位。
class _RecordingStageBody extends StatelessWidget {
  const _RecordingStageBody({
    required this.wavePanel,
    required this.scrubberPanel,
    required this.timerCapsule,
    required this.bottomCenter,
    required this.leftPill,
    required this.rightPill,
    required this.errorMessage,
    this.centerControls,
  });

  /// 顶部暗色波形面板：录制中传 [_LiveDarkWavePanel]，试听时传
  /// [_PreviewDarkWavePanel]——内部各自包了 audio_waveforms 组件。
  final Widget wavePanel;

  /// 暗色 scrubber 进度条：包 [AnimatedBuilder] / [StreamBuilder]
  /// 局部跟随 elapsed / position 变化重建。
  final Widget scrubberPanel;

  /// 秒表 capsule（紫色边框、白底 + 时间文字）：同上局部重建。
  final Widget timerCapsule;

  /// 底部居中区域（提示文案 + 可选「试听」按钮等）：同上。
  final Widget bottomCenter;

  /// 左下、右下两枚控制 pill：根据 phase / 时长可用态变化，调用方决定
  /// 是否包 [AnimatedBuilder]。
  final Widget leftPill;
  final Widget rightPill;

  /// 错误 banner 内容；为空 / 空字符串时不显示。
  final String? errorMessage;

  /// 中间「主控件」（录制时为大圆按钮，试听时为 -15 / ▶ / +15 三键）。
  final Widget? centerControls;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;
    final topOffset = hasError ? ui(50) : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < ui(560);
        final waveTop = topOffset + ui(compact ? 0 : 8);
        final scrubberTop = waveTop + ui(compact ? 200 : 208);
        final timerTop = scrubberTop + ui(compact ? 104 : 116);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (hasError)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _ErrorBanner(message: errorMessage!),
              ),
            Positioned(
              left: ui(8),
              right: ui(8),
              top: waveTop,
              height: ui(190),
              child: wavePanel,
            ),
            Positioned(
              left: ui(8),
              right: ui(8),
              top: scrubberTop,
              height: ui(80),
              child: scrubberPanel,
            ),
            Positioned(
              left: 0,
              right: 0,
              top: timerTop,
              child: Center(child: timerCapsule),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: timerTop + ui(74),
              child: Center(child: bottomCenter),
            ),
            Positioned(
              left: ui(22),
              right: ui(22),
              bottom: ui(10),
              child: Row(
                children: <Widget>[
                  leftPill,
                  Expanded(
                    child: Center(
                      child: centerControls ?? const SizedBox.shrink(),
                    ),
                  ),
                  rightPill,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// 暗色波形面板（自绘版）
//
// 替代 audio_waveforms 的 AudioWaveforms / AudioFileWaveforms：内部
// 用 [CustomPainter] 直接画振幅条 + 进度光标，外层视觉（金属边框、暗色
// 渐变底色、12px 圆角）与原版完全一致。两块面板都包了一层
// [RepaintBoundary] —— 重绘只发生在它内部那张 raster 图层里，外层
// stage 不会跟着进 raster 任务，性能开销与 audio_waveforms 持平甚至
// 更轻（少一个平台通道往返）。
// ===========================================================================

/// 暗色波形面板的统一外框。两个具体面板复用这套金属边 / 暗色渐变 /
/// 内圈描边，所以视觉与原 audio_waveforms 版本完全对齐。
class _DarkWaveFrame extends StatelessWidget {
  const _DarkWaveFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(3)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(20)),
        border: Border.all(color: const Color(0xFFC3C3C3), width: ui(3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF353535), Color(0xFF141414)],
          ),
          borderRadius: BorderRadius.circular(ui(16)),
          border: Border.all(color: const Color(0xFF161616), width: ui(6)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ui(10)),
          child: child,
        ),
      ),
    );
  }
}

/// 录制中的暗色波形面板。订阅 [samples]（来自 controller.liveAmplitudes，
/// 由 `record` 包的 onAmplitudeChanged 灌进去），用 [_LiveWavePainter]
/// 把最近 N 个振幅样本画成滚动柱状波形，新样本始终从右往左推进。
class _LiveDarkWavePanel extends StatelessWidget {
  const _LiveDarkWavePanel({required this.samples});

  final ValueListenable<List<double>> samples;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return _DarkWaveFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RepaintBoundary(
            child: ValueListenableBuilder<List<double>>(
              valueListenable: samples,
              builder: (context, snapshot, _) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _LiveWavePainter(
                    samples: snapshot,
                    barWidth: ui(2),
                    spacing: ui(5),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 试听阶段的暗色波形面板。
///
/// 把 [waveform]（录制阶段实时采样得到的振幅快照；或服务端已存录音的
/// seed 占位）画成静态柱状条，并叠一根跟随 [positionMs] / [durationMs]
/// 移动的进度光标——光标左侧的条用紫色亮起，右侧灰色。整片面板支持
/// 拖动 / 点击定位：拖动期间 cursor 用本地手指 ratio 实时跟手，丝滑
/// 不卡（不会每帧都 await 一次 just_audio 的 `seek`）；松手时一次性
/// 把最终 ratio 通过 [onSeekRatio] commit 给 controller。
class _PreviewDarkWavePanel extends StatefulWidget {
  const _PreviewDarkWavePanel({
    required this.waveform,
    required this.positionMs,
    required this.durationMs,
    required this.fallbackDurationMs,
    required this.onSeekRatio,
  });

  final List<double> waveform;
  final ValueListenable<int> positionMs;
  final ValueListenable<int> durationMs;
  final int fallbackDurationMs;
  final ValueChanged<double> onSeekRatio;

  @override
  State<_PreviewDarkWavePanel> createState() => _PreviewDarkWavePanelState();
}

class _PreviewDarkWavePanelState extends State<_PreviewDarkWavePanel> {
  /// 拖拽期间的临时 cursor ratio（0..1）。`null` 表示当前没在拖，
  /// cursor 跟随 [widget.positionMs] / [widget.durationMs]。
  double? _dragRatio;

  double _localToRatio(double dx, double width) {
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return _DarkWaveFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 单击直接 commit seek 到目标位置。
              onTapDown: (details) {
                widget.onSeekRatio(
                  _localToRatio(details.localPosition.dx, size.width),
                );
              },
              // 横向拖拽：每次只刷本地 _dragRatio（局部 setState
              // 触发 cursor 重绘），不调 seek，避免 just_audio 在
              // native 上 await 串行化 seek 让 cursor 卡顿。
              onHorizontalDragStart: (details) {
                setState(() {
                  _dragRatio = _localToRatio(
                    details.localPosition.dx,
                    size.width,
                  );
                });
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragRatio = _localToRatio(
                    details.localPosition.dx,
                    size.width,
                  );
                });
              },
              onHorizontalDragEnd: (_) {
                final ratio = _dragRatio;
                if (ratio != null) {
                  widget.onSeekRatio(ratio);
                }
                setState(() {
                  _dragRatio = null;
                });
              },
              onHorizontalDragCancel: () {
                setState(() {
                  _dragRatio = null;
                });
              },
              child: ValueListenableBuilder<int>(
                valueListenable: widget.positionMs,
                builder: (context, positionValue, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: widget.durationMs,
                    builder: (context, durationValue, _) {
                      final total = durationValue > 0
                          ? durationValue
                          : widget.fallbackDurationMs;
                      // 拖拽中：用本地 _dragRatio；否则用真实播放
                      // position 推算的 ratio。
                      final ratio = _dragRatio ??
                          (total <= 0
                              ? 0.0
                              : (positionValue / total)
                                  .clamp(0.0, 1.0)
                                  .toDouble());
                      return CustomPaint(
                        size: size,
                        painter: _PreviewWavePainter(
                          samples: widget.waveform,
                          progressRatio: ratio,
                          barWidth: ui(2),
                          spacing: ui(5),
                          cursorThickness: ui(2),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Live 录制波形 painter：最近 N 个样本，从左到右线性铺满。
class _LiveWavePainter extends CustomPainter {
  _LiveWavePainter({
    required this.samples,
    required this.barWidth,
    required this.spacing,
  });

  final List<double> samples;
  final double barWidth;
  final double spacing;

  static const _liveColor = Color(0xFFB791FF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = _liveColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    if (samples.isEmpty) {
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        paint..strokeWidth = math.max(barWidth - 1, 1),
      );
      return;
    }

    final maxBars = math.max(1, (size.width / spacing).floor());
    final start = samples.length > maxBars ? samples.length - maxBars : 0;
    final visible = samples.sublist(start);

    // Fill from left to right. Once the panel is full, keep the newest
    // window but preserve chronological order: oldest visible on the left,
    // newest visible on the right.
    final stride = spacing;
    final firstX = stride / 2;
    for (var i = 0; i < visible.length; i++) {
      final amp = visible[i].clamp(0.05, 1.0);
      final halfH = (size.height / 2 - 4) * amp;
      final x = firstX + i * stride;
      if (x < 0) continue;
      canvas.drawLine(
        Offset(x, centerY - halfH),
        Offset(x, centerY + halfH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWavePainter oldDelegate) {
    return !identical(oldDelegate.samples, samples) ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.spacing != spacing;
  }
}

/// 试听波形 painter：静态柱状 + 紫色已播放区 + 灰色未播放区 + 光标线。
class _PreviewWavePainter extends CustomPainter {
  _PreviewWavePainter({
    required this.samples,
    required this.progressRatio,
    required this.barWidth,
    required this.spacing,
    required this.cursorThickness,
  });

  final List<double> samples;
  final double progressRatio;
  final double barWidth;
  final double spacing;
  final double cursorThickness;

  static const _activeColor = Color(0xFFA773FF);
  static const _idleColor = Color(0xFF555555);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final centerY = size.height / 2;

    if (samples.isEmpty) {
      final paint = Paint()
        ..color = _idleColor
        ..strokeWidth = math.max(barWidth - 1, 1)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        paint,
      );
      // Even with no samples, still draw the cursor so the user can see
      // playback is moving.
      final cursorX = (size.width * progressRatio).clamp(0.0, size.width);
      final cursorPaint = Paint()
        ..color = _activeColor
        ..strokeWidth = cursorThickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cursorX, 4),
        Offset(cursorX, size.height - 4),
        cursorPaint,
      );
      return;
    }

    final maxBars = math.max(1, (size.width / spacing).floor());
    final barCount = math.min(samples.length, maxBars);
    final stride = size.width / barCount;
    final maxAmp = samples.fold<double>(
      0.0,
      (acc, v) => math.max(acc, v.abs()),
    );
    final normalizer = maxAmp > 0.05 ? maxAmp : 1.0;
    final cursorX = (size.width * progressRatio).clamp(0.0, size.width);

    final activePaint = Paint()
      ..color = _activeColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final idlePaint = Paint()
      ..color = _idleColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      final sample = _bucketPeak(samples, i, barCount);
      final amp = (sample.abs() / normalizer).clamp(0.05, 1.0);
      final halfH = (size.height / 2 - 4) * amp;
      final x = i * stride + stride / 2;
      final paint = x <= cursorX ? activePaint : idlePaint;
      canvas.drawLine(
        Offset(x, centerY - halfH),
        Offset(x, centerY + halfH),
        paint,
      );
    }

    final cursorPaint = Paint()
      ..color = _activeColor
      ..strokeWidth = cursorThickness
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cursorX, 4),
      Offset(cursorX, size.height - 4),
      cursorPaint,
    );
  }

  double _bucketPeak(List<double> values, int bucket, int bucketCount) {
    final start = (bucket * values.length) ~/ bucketCount;
    final end = math.max(
      start + 1,
      ((bucket + 1) * values.length) ~/ bucketCount,
    );
    var peak = 0.0;
    for (var i = start; i < end && i < values.length; i++) {
      final value = values[i].abs();
      if (value > peak) peak = value;
    }
    return peak;
  }

  @override
  bool shouldRepaint(covariant _PreviewWavePainter oldDelegate) {
    return !identical(oldDelegate.samples, samples) ||
        oldDelegate.progressRatio != progressRatio ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.spacing != spacing ||
        oldDelegate.cursorThickness != cursorThickness;
  }
}

class _DarkScrubberPanel extends StatelessWidget {
  const _DarkScrubberPanel({
    required this.progressRatio,
    required this.startLabel,
    required this.endLabel,
  });

  final double progressRatio;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(3)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(20)),
        border: Border.all(color: const Color(0xFFC3C3C3), width: ui(3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF353535), Color(0xFF141414)],
          ),
          borderRadius: BorderRadius.circular(ui(14)),
          border: Border.all(color: const Color(0xFF161616), width: ui(4)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  left: ui(8),
                  top: ui(6),
                  bottom: ui(6),
                  width: math.max(
                    ui(8),
                    (constraints.maxWidth - ui(16)) *
                        progressRatio.clamp(0.0, 1.0),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFA773FF), Color(0xFF7422FF)],
                      ),
                      borderRadius: BorderRadius.circular(ui(6)),
                    ),
                  ),
                ),
                Positioned(
                  left: ui(10),
                  bottom: ui(2),
                  child: Text(
                    startLabel,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: const Color(0xFF747474),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: ui(10),
                  bottom: ui(2),
                  child: Text(
                    endLabel,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: const Color(0xFF747474),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GraniteTimerCapsule extends StatelessWidget {
  const _GraniteTimerCapsule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(300),
      height: ui(60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF111111), Color(0xFF39283D)],
        ),
        border: Border.all(color: const Color(0xFFC3C3C3), width: ui(3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x44000000),
            blurRadius: ui(4.7),
            offset: Offset(ui(4.7), ui(4.7)),
          ),
        ],
      ),
      child: Text(
        label,
        // 计时器以 33ms 频率刷新，"1"/"7" 比 "0"/"8" 窄，普通字体下
        // Text 居中渲染会让整段文本宽度每次刷新都变化，肉眼看是数字
        // 在水平方向高频左右抖动。`FontFeature.tabularFigures()` 强
        // 制 OpenType "tnum"，每个数字字符占一致宽度（等宽），位置
        // 锁死，整段文本不再因数值变化而抖。
        style: TextStyle(
          fontSize: ui(28),
          color: const Color(0xFFABA1B7),
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w600,
          height: 1.0,
          letterSpacing: 1.5,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 录制 / 试听界面底部两侧的横向胶囊按钮（重录 / 完成 / 继续 / 暂停 …）。
/// 标准尺寸 108×56，资源图本身已经包含了文字与背景，所以这里只是个
/// 等比缩放的 Image + Opacity 状态切换。
class _SoundControlButton extends StatelessWidget {
  const _SoundControlButton({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: ui(108),
          height: ui(56),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// 录制态中央按钮：单个大圆形（idle / recording / paused 三种状态）。
/// 录制过程中并不允许时间跳转，所以这里**不**带 -15/+15 小图标——
/// 那两个按钮只在播放音频的页面出现。
class _RecordTransportControls extends StatelessWidget {
  const _RecordTransportControls({
    required this.centerAsset,
    required this.onCenterTap,
  });

  final String centerAsset;
  final Future<void> Function() onCenterTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onCenterTap(),
      child: SizedBox(
        width: ui(64),
        height: ui(64),
        child: Image.asset(centerAsset, fit: BoxFit.contain),
      ),
    );
  }
}

class _SoundIconButton extends StatelessWidget {
  const _SoundIconButton({required this.asset, required this.onTap, this.size});

  final String asset;
  final Future<void> Function() onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final buttonSize = size ?? ui(44);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(),
      child: SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFFFD7D7)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: ui(18),
            color: const Color(0xFFE85454),
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFFAA3E3E),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 保存录音文件 弹窗 / 分享弹窗
// ===========================================================================

class _SaveRecordingDialog extends ConsumerWidget {
  const _SaveRecordingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingSystemControllerProvider);
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;
    const labels = <String>['原声', '考场', '录音棚', '音乐厅'];
    const thumbs = <String>[
      AppAssets.soundEffectOriginal,
      AppAssets.soundEffectExamHall,
      AppAssets.soundEffectStudio,
      AppAssets.soundEffectConcert,
    ];

    // 关键修复：iPad / iPhone 上键盘弹出时，老实现是 Center 直接居中
    // 在全屏空间，键盘直接盖住"作品名称"输入框，用户看不到自己在输入
    // 什么。把对话框包在一层 viewInsets.bottom 的底部 padding 里，键盘
    // 弹起时整个 Center 区域上移，作品名称输入框始终在键盘上方可见。
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: const Color(0xCC000000),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Center(
          child: SingleChildScrollView(
            // 极端短屏（外接键盘 / 浮窗模式）下兜底：键盘 + 弹窗高度 >
            // 屏幕高度时也能滚动到底部，避免内容被裁掉。
            child: Container(
          width: ui(428),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(24)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFD2C6FF), Colors.white, Colors.white],
              stops: <double>[0, 0.33, 1],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(ui(24), ui(36), ui(24), ui(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    '保存录音文件',
                    style: TextStyle(
                      fontSize: ui(22),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.0,
                    ),
                  ),
                ),
                SizedBox(height: ui(28)),
                Text(
                  '您可选择喜欢的音效',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 14,
                  ),
                ),
                SizedBox(height: ui(12)),
                Row(
                  children: List<Widget>.generate(labels.length, (index) {
                    final active = state.selectedEffectIndex == index;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == labels.length - 1 ? 0 : ui(12),
                        ),
                        child: _EffectThumb(
                          imageAsset: thumbs[index],
                          active: active,
                          onTap: () => controller.selectEffect(index),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: ui(8)),
                Row(
                  children: List<Widget>.generate(labels.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == labels.length - 1 ? 0 : ui(12),
                        ),
                        child: Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: ui(14),
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: ui(20)),
                Text(
                  '作品名称',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 14,
                  ),
                ),
                SizedBox(height: ui(8)),
                _SaveTitleField(
                  initialValue: state.pendingTitle,
                  onChanged: controller.updatePendingTitle,
                ),
                SizedBox(height: ui(24)),
                Row(
                  children: [
                    Expanded(
                      child: _DialogActionButton(
                        label: '取消',
                        primary: false,
                        onTap: controller.closeSaveDialog,
                      ),
                    ),
                    SizedBox(width: ui(16)),
                    Expanded(
                      child: _DialogActionButton(
                        label: '确认',
                        primary: true,
                        onTap: () async {
                          // 严格按这个顺序，否则 iPad 必现框架异常
                          // "This exception was thrown because the
                          // deactivated widget's ancestor was looked up..."：
                          //
                          //   1) await saveCurrentRecording() -> 上传 + 入库
                          //   2) 失败 -> Toast，弹窗保持打开让用户重试
                          //   3) 成功 -> **先** Toast（此时 dialog 还在树上，
                          //      `Overlay.maybeOf(context)` 能拿到 root
                          //      Overlay），**再** closeSaveDialog 同步把
                          //      dialog pop 掉
                          //   4) 切回列表 + 刷新延迟到下一帧执行：dialog
                          //      pop 动画需要至少一帧再拆 viewMode 对应的
                          //      Stage widget，否则父子树同帧 dispose 再次
                          //      触发 deactivated ancestor lookup
                          //
                          // 最外层再裹一层 try-catch 兜底：万一 controller
                          // 内部还有未捕获到的同步 / 异步异常逃出来，也不
                          // 让它通过 Future error 冒泡到 framework，更不让
                          // toast 显示一坨英文 stack。原文走 debugPrint。
                          String? message;
                          try {
                            message = await controller.saveCurrentRecording();
                          } catch (error, stack) {
                            debugPrint(
                              '[recording] save dialog uncaught: '
                              '$error\n$stack',
                            );
                            message = '保存录音失败，请稍后重试';
                          }
                          if (!context.mounted) {
                            return;
                          }
                          if (message != null) {
                            _showMessage(context, message);
                            return;
                          }
                          _showMessage(context, '录音已保存');
                          controller.closeSaveDialog();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.finishSaveAndReturnToList();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EffectThumb extends StatelessWidget {
  const _EffectThumb({
    required this.imageAsset,
    required this.active,
    required this.onTap,
  });

  final String imageAsset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B081A),
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(
              color: active ? const Color(0xFF8741FF) : const Color(0xFFF5F6FA),
              width: ui(active ? 3 : 1),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(imageAsset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _SaveTitleField extends StatefulWidget {
  const _SaveTitleField({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_SaveTitleField> createState() => _SaveTitleFieldState();
}

class _SaveTitleFieldState extends State<_SaveTitleField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _SaveTitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(48),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        // 关键修复：保存录音弹窗一打开就让作品名称输入框拿到焦点。
        // 老实现没有 autofocus，iPad 上键盘不会自动弹起，用户多次点
        // 输入框看不到光标会以为弹窗坏了。同时 textInputAction.done
        // 让虚拟键盘上出现"完成"键，回车直接收键盘。
        autofocus: true,
        textInputAction: TextInputAction.done,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: const Color(0xFF0B081A),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
        decoration: InputDecoration(
          hintText: '请输入文件名称',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFCECED1),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: ui(16),
            vertical: ui(14),
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(8)),
            borderSide: BorderSide(
              color: const Color(0xFFF3F2F3),
              width: ui(1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(8)),
            borderSide: BorderSide(
              color: const Color(0xFFD9C7FF),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: primary ? null : Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: primary
              ? null
              : Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: primary
                  ? const Color(0x59AD80FF)
                  : const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(16),
            color: primary ? Colors.white : const Color(0xFF0B081A),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 12 / 16,
          ),
        ),
      ),
    );
  }
}

class _ShareRecordingDialog extends ConsumerWidget {
  const _ShareRecordingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingSystemControllerProvider);
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Material(
      color: const Color(0xCC000000),
      child: Center(
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(24), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '分享到班级',
                    style: TextStyle(
                      fontSize: ui(18),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: controller.closeShareDialog,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: ui(8)),
              Text(
                '选择需要分享的班级后，系统会逐个发送录音作品。',
                style: TextStyle(
                  fontSize: ui(13),
                  color: const Color(0xFF7C8496),
                  fontFamily: 'PingFang SC',
                ),
              ),
              SizedBox(height: ui(18)),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: ui(280)),
                child: state.shareClasses.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: ui(24)),
                          child: Text(
                            '暂无可分享的班级',
                            style: TextStyle(
                              fontSize: ui(14),
                              color: const Color(0xFF99A0B0),
                              fontFamily: 'PingFang SC',
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: state.shareClasses.length,
                        separatorBuilder: (_, _) => SizedBox(height: ui(8)),
                        itemBuilder: (context, index) {
                          final item = state.shareClasses[index];
                          return InkWell(
                            onTap: () => controller.toggleShareClass(item.id),
                            borderRadius: BorderRadius.circular(ui(14)),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ui(14),
                                vertical: ui(12),
                              ),
                              decoration: BoxDecoration(
                                color: item.selected
                                    ? const Color(0xFFF3EEFF)
                                    : const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(ui(14)),
                                border: Border.all(
                                  color: item.selected
                                      ? const Color(0xFFB18BFF)
                                      : const Color(0xFFE7EBF5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.selected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: item.selected
                                        ? const Color(0xFF8B5CFF)
                                        : const Color(0xFFB5BDCF),
                                  ),
                                  SizedBox(width: ui(10)),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        color: const Color(0xFF0B081A),
                                        fontFamily: 'PingFang SC',
                                        fontWeight: AppFont.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SizedBox(height: ui(20)),
              Row(
                children: [
                  Expanded(
                    child: _DialogActionButton(
                      label: '取消',
                      primary: false,
                      onTap: controller.closeShareDialog,
                    ),
                  ),
                  SizedBox(width: ui(16)),
                  Expanded(
                    child: _DialogActionButton(
                      label: '确认分享',
                      primary: true,
                      onTap: () async {
                        // 与保存对话框同款兜底：所有异常都收成中文 toast，
                        // 不允许 framework / 网络层的英文 toString 直接
                        // 显示给用户。
                        String? message;
                        try {
                          message = await controller.sendShare();
                        } catch (error, stack) {
                          debugPrint(
                            '[recording] share dialog uncaught: '
                            '$error\n$stack',
                          );
                          message = '分享失败，请稍后重试';
                        }
                        if (!context.mounted) {
                          return;
                        }
                        // 与保存对话框同样的 deactivated-context 防护：
                        // 成功 -> 先 toast（dialog 还 mounted，能拿到
                        // root Overlay），再 closeShareDialog；失败 ->
                        // 直接 toast，dialog 保持打开让用户重试。
                        if (message != null) {
                          _showMessage(context, message);
                          return;
                        }
                        _showMessage(context, '分享成功');
                        controller.closeShareDialog();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 录音文件卡的右上角 ··· 操作（保留，未走通用 ItemMenuAction，因为同时含
// 「播放」等录音特有操作；如有需要可后续抽离）。
enum _RecordingItemAction { preview, rename, share, delete }

// ===========================================================================
// 工具方法
// ===========================================================================

int _parseDurationLabel(String raw) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty) {
    return 0;
  }
  final dot = RegExp(r'^(\d+):(\d+)\.(\d+)$').firstMatch(cleaned);
  if (dot != null) {
    final minutes = int.tryParse(dot.group(1)!) ?? 0;
    final seconds = int.tryParse(dot.group(2)!) ?? 0;
    final centiseconds = int.tryParse(dot.group(3)!) ?? 0;
    return minutes * 60000 + seconds * 1000 + centiseconds * 10;
  }
  final parts = cleaned.split(':');
  if (parts.length == 3) {
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    final centiseconds = int.tryParse(parts[2]) ?? 0;
    return minutes * 60000 + seconds * 1000 + centiseconds * 10;
  }
  if (parts.length == 2) {
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return minutes * 60000 + seconds * 1000;
  }
  return 0;
}

String _formatClock(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final centiseconds = ((milliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
  return '$minutes:$seconds:$centiseconds';
}

String _formatSecondsClock(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(1, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

void _showMessage(BuildContext context, String message) {
  AppToast.show(context, message);
}
