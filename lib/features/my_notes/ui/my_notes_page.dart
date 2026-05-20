import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/my_notes_controller.dart';
import '../state/my_notes_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class MyNotesPage extends ConsumerStatefulWidget {
  const MyNotesPage({super.key});

  @override
  ConsumerState<MyNotesPage> createState() => _MyNotesPageState();
}

class _MyNotesPageState extends ConsumerState<MyNotesPage> {
  final GlobalKey _canvasBoundaryKey = GlobalKey();
  List<Offset> _activeStroke = const <Offset>[];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myNotesControllerProvider);
    return switch (state.view) {
      MyNotesView.list => _NotesListView(
        state: state,
        onCreate: _handleCreate,
        onAddCategory: _showAddCategoryDialog,
        onCategoryAction: _handleCategoryAction,
        onNoteAction: _handleNoteAction,
      ),
      MyNotesView.template => _NoteTemplateView(
        selectedType: state.paperType,
        onBack: _backToList,
        onSelected: (type) {
          ref.read(myNotesControllerProvider.notifier).chooseTemplate(type);
        },
      ),
      MyNotesView.editor => _NoteEditorView(
        boundaryKey: _canvasBoundaryKey,
        state: state,
        activeStroke: _activeStroke,
        onBack: _backToList,
        onColorSelected: (color) {
          ref.read(myNotesControllerProvider.notifier).setSelectedColor(color);
        },
        onStrokeWidthChanged: (value) {
          ref.read(myNotesControllerProvider.notifier).setStrokeWidth(value);
        },
        onUndo: () {
          ref.read(myNotesControllerProvider.notifier).undoStroke();
        },
        onClear: () {
          ref.read(myNotesControllerProvider.notifier).clearCanvas();
        },
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onPanCancel: _handlePanCancel,
        onSave: _saveEditorImage,
      ),
    };
  }

  Future<void> _handleCreate() async {
    final controller = ref.read(myNotesControllerProvider.notifier);
    // 先做一次"是否存在可写入分类"的校验，避免让用户白填一次标题：
    // 没有可写分类时直接提示并退出，不弹出输入框。
    final validationError = controller.validateCanCreateNote();
    if (validationError != null) {
      if (mounted) {
        _showMessage(validationError);
      }
      return;
    }
    // 先弹出"新建笔记"标题输入框（按 Figma 设计稿），确认后再带着
    // 标题进入"选择笔记样式"页面。
    final title = await _showCreateNoteTitleDialog(context);
    if (!mounted || title == null || title.isEmpty) {
      return;
    }
    final message = controller.beginCreateNote(title: title);
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  void _backToList() {
    setState(() => _activeStroke = const <Offset>[]);
    ref.read(myNotesControllerProvider.notifier).backToList();
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await showTextInputDialog(
      context: context,
      title: '新建笔记分类',
      hintText: '请输入笔记分类名称',
      confirmLabel: '确认',
    );
    if (!mounted || result == null) {
      return;
    }
    final message = await ref
        .read(myNotesControllerProvider.notifier)
        .addCategory(result);
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  /// Left-nav category menu — supports 重命名 + 删除.
  /// 重命名复用 `noteCategorySave`（id > 0 即更新）；删除走 `noteCategoryDelete`。
  Future<void> _handleCategoryAction(
    NoteCategoryItem item,
    _NoteMenuAction action,
  ) async {
    final controller = ref.read(myNotesControllerProvider.notifier);
    switch (action) {
      case _NoteMenuAction.rename:
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
        final message = await controller.renameCategory(item.id, nextName);
        if (mounted) {
          _showMessage(message ?? '分类名称已更新');
        }
        break;
      case _NoteMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除分类',
          content: '删除“${item.name}”后，该分类下的笔记也会一并移除。',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteCategory(item.id);
        if (mounted) {
          _showMessage(message ?? '分类已删除');
        }
        break;
    }
  }

  /// Note card menu — supports 重命名 + 删除.
  Future<void> _handleNoteAction(NoteEntry item, _NoteMenuAction action) async {
    final controller = ref.read(myNotesControllerProvider.notifier);
    switch (action) {
      case _NoteMenuAction.rename:
        final nextTitle = await showTextInputDialog(
          context: context,
          title: '重命名笔记',
          hintText: '请输入新的笔记名称',
          initialValue: item.title,
          confirmLabel: '保存',
        );
        if (nextTitle == null || nextTitle.isEmpty || nextTitle == item.title) {
          return;
        }
        final message = await controller.renameNote(item, nextTitle);
        if (mounted) {
          _showMessage(message ?? '笔记名称已更新');
        }
        break;
      case _NoteMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除笔记',
          content: '确定删除“${item.title}”吗？此操作不可恢复。',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteNote(item.id);
        if (mounted) {
          _showMessage(message ?? '笔记已删除');
        }
        break;
    }
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() => _activeStroke = <Offset>[details.localPosition]);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _activeStroke = <Offset>[..._activeStroke, details.localPosition];
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_activeStroke.length >= 2) {
      ref.read(myNotesControllerProvider.notifier).addStroke(_activeStroke);
    }
    setState(() => _activeStroke = const <Offset>[]);
  }

  /// 多指落下时（≥2 根手指）由 [_NoteEditorView] 主动调用：丢弃此前
  /// 单指开启的半截笔画，把绘制权让给 [InteractiveViewer] 的缩放手势，
  /// 避免 iPad 上"两指捏合 = 顺手画一道"。
  void _handlePanCancel() {
    if (_activeStroke.isEmpty) {
      return;
    }
    setState(() => _activeStroke = const <Offset>[]);
  }

  Future<void> _saveEditorImage() async {
    try {
      final boundary =
          _canvasBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        _showMessage('画布还未准备好，请稍后重试');
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 2.2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showMessage('笔记导出失败，请稍后重试');
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final message = await ref
          .read(myNotesControllerProvider.notifier)
          .saveCurrentNote(bytes);
      if (message != null && mounted) {
        _showMessage(message);
        return;
      }
      if (mounted) {
        _showMessage('笔记已保存');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('保存失败，请稍后重试');
      }
    }
  }

  void _showMessage(String message) {
    AppToast.show(context, message);
  }
}

class _NotesListView extends ConsumerWidget {
  const _NotesListView({
    required this.state,
    required this.onCreate,
    required this.onAddCategory,
    required this.onCategoryAction,
    required this.onNoteAction,
  });

  final MyNotesState state;
  final Future<void> Function() onCreate;
  final Future<void> Function() onAddCategory;
  final Future<void> Function(NoteCategoryItem item, _NoteMenuAction action)
  onCategoryAction;
  final Future<void> Function(NoteEntry item, _NoteMenuAction action)
  onNoteAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final controller = ref.read(myNotesControllerProvider.notifier);

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left nav (matches courseware layout) ──────────────────────
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
              child: _NotesSidebar(
                state: state,
                onSelectCategory: controller.selectCategory,
                onAddCategory: onAddCategory,
                onCategoryAction: onCategoryAction,
              ),
            ),
            // ── Right content (tabs + grid) ───────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(ui(16)),
                  ),
                ),
                child: _NotesContentArea(
                  state: state,
                  onSelectFilter: controller.selectFilter,
                  onOpenNote: controller.openExistingNote,
                  onCreate: onCreate,
                  onNoteAction: onNoteAction,
                ),
              ),
            ),
          ],
        ),
        if (state.busy)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0x22000000),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Left nav (sidebar)
// ──────────────────────────────────────────────────────────────────────────

class _NotesSidebar extends StatelessWidget {
  const _NotesSidebar({
    required this.state,
    required this.onSelectCategory,
    required this.onAddCategory,
    required this.onCategoryAction,
  });

  final MyNotesState state;
  final ValueChanged<int> onSelectCategory;
  final Future<void> Function() onAddCategory;
  final Future<void> Function(NoteCategoryItem item, _NoteMenuAction action)
  onCategoryAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(8), ui(8), ui(8), ui(10)),
      child: Column(
        children: [
          Expanded(
            // 刚进入页面正在拉取数据时，侧栏保持空白；不展示 loading 转圈，
            // 也不闪一下"暂无分类"占位。加载完成确实无数据时才显示占位。
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
                    separatorBuilder: (context, index) =>
                        SizedBox(height: ui(8)),
                    itemBuilder: (context, index) {
                      final item = state.categories[index];
                      return _NoteCategoryCard(
                        item: item,
                        selected: item.id == state.selectedCategoryId,
                        onTap: () => onSelectCategory(item.id),
                        onAction: (action) => onCategoryAction(item, action),
                      );
                    },
                  ),
          ),
          SizedBox(height: ui(12)),
          _NotesAddCategoryCard(onTap: onAddCategory),
        ],
      ),
    );
  }
}

class _NoteCategoryCard extends StatefulWidget {
  const _NoteCategoryCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final NoteCategoryItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_NoteMenuAction> onAction;

  @override
  State<_NoteCategoryCard> createState() => _NoteCategoryCardState();
}

class _NoteCategoryCardState extends State<_NoteCategoryCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    // 默认分类（id == 0，名为"笔记"）不允许重命名 / 删除，因此不弹菜单。
    if (widget.item.id <= 0) {
      return;
    }
    final action = await _showNoteActionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
      includeRename: true,
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
        padding: EdgeInsets.fromLTRB(ui(10), ui(12), ui(8), ui(12)),
        decoration: BoxDecoration(
          // Selected: lavender card #EEEAFF with 8 radius.
          // Non-selected: white card with 16 radius.
          color: selected ? const Color(0xFFEEEAFF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(selected ? 8 : 16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 36×36 note glyph：未选中走 note/9.png（无填色描线版本），
            // 选中走 note/4.png（彩色实心版本）。两张图都是 self-contained。
            Image.asset(
              selected
                  ? 'assets/images/note/4.png'
                  : 'assets/images/note/9.png',
              width: ui(36),
              height: ui(36),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(10)),
            // Single-line "name（count）" label per spec.
            Expanded(
              child: Text(
                '${item.name}（${item.count}）',
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
            if (item.id > 0)
              GestureDetector(
                key: _menuTriggerKey,
                behavior: HitTestBehavior.opaque,
                onTap: _openActionMenu,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ui(2)),
                  child: Image.asset(
                    AppAssets.cloudActionMore,
                    width: ui(24),
                    height: ui(24),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotesAddCategoryCard extends StatelessWidget {
  const _NotesAddCategoryCard({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(60),
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          color: const Color(0xFFF5F6FA),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 20×20 grey circle with white plus glyph (matches CSS spec).
            Container(
              width: ui(20),
              height: ui(20),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFB6B5BB),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: ui(14), color: Colors.white),
            ),
            SizedBox(width: ui(6)),
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

// ──────────────────────────────────────────────────────────────────────────
//  Right content (tabs + grid + FAB)
// ──────────────────────────────────────────────────────────────────────────

class _NotesContentArea extends StatelessWidget {
  const _NotesContentArea({
    required this.state,
    required this.onSelectFilter,
    required this.onOpenNote,
    required this.onCreate,
    required this.onNoteAction,
  });

  final MyNotesState state;
  final ValueChanged<MyNotesFilter> onSelectFilter;
  final ValueChanged<NoteEntry> onOpenNote;
  final Future<void> Function() onCreate;
  final Future<void> Function(NoteEntry item, _NoteMenuAction action)
  onNoteAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(20), ui(18), ui(20), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotesTabBar(active: state.activeFilter, onChanged: onSelectFilter),
          SizedBox(height: ui(16)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.visibleNotes.isEmpty
                      ? const _EmptyPanel()
                      : GridView.builder(
                          padding: EdgeInsets.only(bottom: ui(64)),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: ui(190),
                                mainAxisSpacing: ui(20),
                                crossAxisSpacing: ui(23),
                                childAspectRatio: 1.0,
                              ),
                          itemCount: state.visibleNotes.length,
                          itemBuilder: (context, index) {
                            final item = state.visibleNotes[index];
                            return _NoteCard(
                              item: item,
                              onOpen: () => onOpenNote(item),
                              onAction: (action) => onNoteAction(item, action),
                            );
                          },
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: ui(8),
                  child: _NotesFloatingCreateButton(onTap: onCreate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped tab bar that replaces the previous title/search/sort/refresh
/// row. Spec: outer #F5F6FA pill (8 radius, 1px outline #F3F2F3, 4px padding,
/// 16px gap), active item white with shadow + 6 radius.
///
class _NotesTabBar extends StatelessWidget {
  const _NotesTabBar({required this.active, required this.onChanged});

  static const List<MyNotesFilter> _visibleFilters = <MyNotesFilter>[
    MyNotesFilter.all,
    MyNotesFilter.recent,
    MyNotesFilter.favorite,
    MyNotesFilter.unarchived,
  ];

  final MyNotesFilter active;
  final ValueChanged<MyNotesFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _visibleFilters.length; i++) ...[
            _NotesTabItem(
              label: _visibleFilters[i].label,
              active: _visibleFilters[i] == active,
              onTap: () => onChanged(_visibleFilters[i]),
            ),
            if (i != _visibleFilters.length - 1) SizedBox(width: ui(16)),
          ],
        ],
      ),
    );
  }
}

class _NotesTabItem extends StatelessWidget {
  const _NotesTabItem({
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
    // No AnimatedContainer / Material / InkWell: per spec, the tab switch
    // should not animate and the chip should not show any tap feedback.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x59B5B5B5),
                    blurRadius: ui(20),
                    offset: Offset(0, ui(8)),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(14),
            height: 1,
            color: active ? const Color(0xFF0B081A) : const Color(0xFF6D6B75),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
          ),
        ),
      ),
    );
  }
}

class _NotesFloatingCreateButton extends StatelessWidget {
  const _NotesFloatingCreateButton({required this.onTap});

  final Future<void> Function() onTap;

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
            // 16×16 purple star glyph per spec.
            Image.asset(
              'assets/images/note/3.png',
              width: ui(16),
              height: ui(16),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(8)),
            Text(
              '新建笔记',
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

class _NoteTemplateView extends StatefulWidget {
  const _NoteTemplateView({
    required this.selectedType,
    required this.onBack,
    required this.onSelected,
  });

  final NotePaperType selectedType;
  final VoidCallback onBack;
  final ValueChanged<NotePaperType> onSelected;

  @override
  State<_NoteTemplateView> createState() => _NoteTemplateViewState();
}

class _NoteTemplateViewState extends State<_NoteTemplateView> {
  late NotePaperType _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.selectedType;
  }

  @override
  void didUpdateWidget(covariant _NoteTemplateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      _pending = widget.selectedType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            Positioned(
              left: ui(20),
              top: ui(20),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onBack,
                child: Image.asset(
                  'assets/images/note/5.png',
                  width: ui(32),
                  height: ui(32),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: ui(25),
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '请选择您的笔记样式',
                  style: TextStyle(
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    color: const Color(0xFF0B081A),
                  ),
                ),
              ),
            ),
            Positioned(
              top: ui(131),
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TemplatePreviewCard(
                      type: NotePaperType.staff,
                      selected: _pending == NotePaperType.staff,
                      onTap: () =>
                          setState(() => _pending = NotePaperType.staff),
                    ),
                    SizedBox(width: ui(16)),
                    _TemplatePreviewCard(
                      type: NotePaperType.notebook,
                      selected: _pending == NotePaperType.notebook,
                      onTap: () =>
                          setState(() => _pending = NotePaperType.notebook),
                    ),
                    SizedBox(width: ui(16)),
                    _TemplatePreviewCard(
                      type: NotePaperType.blank,
                      selected: _pending == NotePaperType.blank,
                      onTap: () =>
                          setState(() => _pending = NotePaperType.blank),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: ui(614),
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSelected(_pending),
                  child: Container(
                    width: ui(350),
                    height: ui(52),
                    padding: EdgeInsets.all(ui(10)),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '下一步',
                          style: TextStyle(
                            fontSize: ui(16),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            color: Colors.white,
                            height: 28 / 16,
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        Image.asset(
                          'assets/images/note/8.png',
                          width: ui(20),
                          height: ui(20),
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatePreviewCard extends StatelessWidget {
  const _TemplatePreviewCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final NotePaperType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final asset = selected
        ? 'assets/images/note/6.png'
        : 'assets/images/note/7.png';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: ui(300),
        height: ui(400),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ui(16)),
                child: Image.asset(asset, fit: BoxFit.fill),
              ),
            ),
            Positioned(
              top: ui(14),
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  type.label,
                  style: TextStyle(
                    fontSize: ui(18),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    color: const Color(0xFF0B081A),
                    height: 24 / 18,
                  ),
                ),
              ),
            ),
            Positioned(
              left: ui(8),
              top: ui(52),
              width: ui(284),
              height: ui(340),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui(12)),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _NotePaperPainter(type: type),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteEditorView extends StatefulWidget {
  const _NoteEditorView({
    required this.boundaryKey,
    required this.state,
    required this.activeStroke,
    required this.onBack,
    required this.onColorSelected,
    required this.onStrokeWidthChanged,
    required this.onUndo,
    required this.onClear,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    required this.onSave,
  });

  final GlobalKey boundaryKey;
  final MyNotesState state;
  final List<Offset> activeStroke;
  final VoidCallback onBack;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  /// 多指落下时由 [_NoteEditorViewState] 主动调用：让父级丢弃半截笔画，
  /// 把绘制权让给 [InteractiveViewer] 接管的缩放手势。
  final VoidCallback onPanCancel;
  final Future<void> Function() onSave;

  @override
  State<_NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<_NoteEditorView> {
  /// 当前在画布命中区域内按下的指针数。等于 1 时按"绘制"处理；≥ 2 时
  /// 主动废弃笔画并把 2 指捏合 / 平移交给 [InteractiveViewer]。
  int _pointerCount = 0;

  /// 缩放视图自带的状态控制器。仅用来在面板里读取/重置 transform，
  /// 后续如果想加"恢复 100%"按钮直接 `.reset()` 即可。
  late final TransformationController _viewerController =
      TransformationController();

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount += 1;
    if (_pointerCount >= 2) {
      // 第二根手指落下：立刻让父级清掉单指刚刚记录到一半的笔画——
      // [GestureDetector] 自身的 pan 会在 [InteractiveViewer] 的 scale
      // 赢下手势竞技场后被 cancel（不会再发 onPanEnd），不在这里清就会
      // 留下一个半截 stroke。
      widget.onPanCancel();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerCount > 0) {
      _pointerCount -= 1;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pointerCount > 0) {
      _pointerCount -= 1;
    }
  }

  /// 单指态才转发给父级；多指态直接吞掉，避免在 InteractiveViewer 还没
  /// 抢下手势之前的过渡帧里继续往笔画里塞点。
  void _handlePanStart(DragStartDetails details) {
    if (_pointerCount >= 2) {
      return;
    }
    widget.onPanStart(details);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_pointerCount >= 2) {
      return;
    }
    widget.onPanUpdate(details);
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_pointerCount >= 2) {
      return;
    }
    widget.onPanEnd(details);
  }

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final state = widget.state;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.fromLTRB(ui(18), ui(16), ui(18), ui(18)),
      child: Column(
        children: [
          SizedBox(
            height: ui(44),
            child: Row(
              children: [
                _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: widget.onBack,
                ),
                const Spacer(),
                Text(
                  state.draftTitle,
                  style: TextStyle(
                    fontSize: ui(20),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF16141F),
                  ),
                ),
                const Spacer(),
                _SecondaryActionButton(
                  label: '保存',
                  icon: Icons.save_outlined,
                  busy: state.busy,
                  onPressed: state.busy ? null : widget.onSave,
                ),
              ],
            ),
          ),
          SizedBox(height: ui(16)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  // Listener 负责"指头数量统计"，InteractiveViewer 负责
                  // "≥2 指捏合时的缩放/平移"。两层都包在 RepaintBoundary 外面：
                  //   - InteractiveViewer 只是给 child 套了一层 Transform，
                  //     缩放发生时 RepaintBoundary 内部的渲染坐标系不变，
                  //     `boundary.toImage()` 仍然能拿到"未缩放"的整张画布，
                  //     不会因为用户当前正放大着就只导出可见部分。
                  //   - Listener 在最外层，能可靠收到用户所有指头的按下/抬起，
                  //     不受 InteractiveViewer 内部手势竞技场的影响。
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    child: InteractiveViewer(
                      transformationController: _viewerController,
                      // 单指拖动是"绘画"，绝不能被 InteractiveViewer 当成
                      // 平移；2 指捏合走 scale 分支，scaleEnabled = true 即可。
                      panEnabled: false,
                      scaleEnabled: true,
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: RepaintBoundary(
                        key: widget.boundaryKey,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(ui(18)),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(
                                  painter: _NotePaperPainter(
                                    type: state.paperType,
                                  ),
                                ),
                                _buildOptionalRemoteImage(
                                  state.editorBackgroundImageUrl,
                                  fit: BoxFit.cover,
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  // 这三个回调里都先做 _pointerCount 检查，
                                  // 多指态下直接吞掉，避免 scale 还没赢之前的
                                  // 过渡帧里继续往笔画里塞点。
                                  onPanStart: _handlePanStart,
                                  onPanUpdate: _handlePanUpdate,
                                  onPanEnd: _handlePanEnd,
                                  child: CustomPaint(
                                    painter: _StrokePainter(
                                      strokes: state.strokes,
                                      activeStroke: widget.activeStroke,
                                      activeColor: state.selectedColor,
                                      activeWidth: state.strokeWidth,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: ui(0),
                  right: ui(0),
                  bottom: ui(22),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(16),
                        vertical: ui(10),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ui(16)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x14000000),
                            blurRadius: ui(18),
                            offset: Offset(0, ui(8)),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: state.strokes.isEmpty
                                ? null
                                : widget.onUndo,
                            icon: const Icon(Icons.undo_rounded),
                          ),
                          Container(
                            width: 1,
                            height: ui(22),
                            color: const Color(0xFFEAEAF2),
                          ),
                          SizedBox(width: ui(12)),
                          ..._editorColors.map((color) {
                            final active = color == state.selectedColor;
                            return GestureDetector(
                              onTap: () => widget.onColorSelected(color),
                              child: Container(
                                width: ui(22),
                                height: ui(22),
                                margin: EdgeInsets.only(right: ui(10)),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: active
                                        ? const Color(0xFF16141F)
                                        : Colors.white,
                                    width: active ? 2 : 1,
                                  ),
                                ),
                              ),
                            );
                          }),
                          SizedBox(width: ui(4)),
                          Container(
                            width: ui(44),
                            height: ui(34),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(ui(10)),
                            ),
                            child: Text(
                              '${state.strokeWidth.round()}',
                              style: TextStyle(
                                fontSize: ui(14),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2A2A2A),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: ui(110),
                            child: Slider(
                              value: state.strokeWidth,
                              min: 2,
                              max: 32,
                              activeColor: const Color(0xFF8B5CFF),
                              inactiveColor: const Color(0xFFE8EAF4),
                              onChanged: widget.onStrokeWidthChanged,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: ui(22),
                            color: const Color(0xFFEAEAF2),
                          ),
                          SizedBox(width: ui(8)),
                          TextButton.icon(
                            onPressed: widget.onClear,
                            icon: const Icon(Icons.auto_fix_off_outlined),
                            label: const Text('清空画布'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1F1A32),
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ──────────────────────────────────────────────────────────────────────────
//  Note card — purple gradient header + lined paper + folded-corner cover.
//  Layout maps the design CSS (170×170) to scaled `ui()` units. Sizes are
//  expressed as ratios of the card's actual width so the whole composition
//  re-flows at any grid extent.
// ──────────────────────────────────────────────────────────────────────────

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.item,
    required this.onOpen,
    required this.onAction,
  });

  final NoteEntry item;
  final VoidCallback onOpen;
  final ValueChanged<_NoteMenuAction> onAction;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    final action = await _showNoteActionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
      includeRename: true,
    );
    if (action != null) {
      widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final item = widget.item;
    return GestureDetector(
      onTap: widget.onOpen,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 卡片以 170×170 设计稿为基准，所有 design 值按当前宽度等比缩放。
          final w = constraints.maxWidth;
          double k(double design) => design / 170 * w;

          // 整张卡片的视觉（圆角、紫色顶部、横线、折角、阴影）都内置在
          // bg.png 里；这里不再叠真实笔记预览图、灰底、条纹、紫渐变条。
          // 不再使用 ClipRRect 以保留 bg 自身的圆角阴影。
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/sound/bg.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              // 标题
              Positioned(
                left: k(14),
                top: k(15),
                right: k(40),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
              ),
              // ⋯ 菜单触发器（右上角）— note/1.png
              Positioned(
                right: k(8),
                top: k(8),
                child: GestureDetector(
                  key: _menuTriggerKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _openActionMenu,
                  child: Padding(
                    padding: EdgeInsets.all(k(3)),
                    child: Image.asset(
                      'assets/images/note/1.png',
                      width: k(20),
                      height: k(20),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // 黄色日期图标（note/2.png）
              Positioned(
                left: k(13),
                top: k(132),
                child: Image.asset(
                  'assets/images/note/2.png',
                  width: k(20),
                  height: k(18),
                  fit: BoxFit.contain,
                ),
              ),
              // 日期文本
              Positioned(
                left: k(40),
                top: k(133),
                child: Text(
                  item.dateLabel.replaceAll('-', '.'),
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFFA59DB4),
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Action menu (rename / delete) — mirrors the courseware menu visuals.
// ──────────────────────────────────────────────────────────────────────────

enum _NoteMenuAction { rename, delete }

/// Pops up a menu anchored to [triggerKey]'s widget. When [includeRename]
/// is false, only a single "删除" row is shown (used by the left-nav category
/// list since the backend has no rename endpoint for note categories).
Future<_NoteMenuAction?> _showNoteActionMenu({
  required BuildContext context,
  required GlobalKey triggerKey,
  required bool includeRename,
}) {
  final triggerCtx = triggerKey.currentContext;
  if (triggerCtx == null) {
    return Future<_NoteMenuAction?>.value(null);
  }
  final renderBox = triggerCtx.findRenderObject() as RenderBox;
  final overlayBox =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()
          as RenderBox;

  final origin = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = renderBox.size;
  final scale = DashboardScaleScope.of(context);
  final menuWidth = scale.ui(142);
  // Approximate height: 8 + 36*(1 or 2) + (2+1+3) divider + 8.
  final approxMenuHeight = scale.ui(includeRename ? 100 : 56);

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

  return showMenu<_NoteMenuAction>(
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
    items: <PopupMenuEntry<_NoteMenuAction>>[
      PopupMenuItem<_NoteMenuAction>(
        enabled: false,
        padding: EdgeInsets.zero,
        // The popup is hosted in a separate Overlay, so the trigger's
        // ancestors (including DashboardScaleScope) are NOT available
        // inside `child`. Re-provide the captured `scale` here so the
        // menu panel and its rows can resolve `ui()` values, then use a
        // Builder so `panelCtx` actually depends on the new scope.
        child: DashboardScaleScope(
          data: scale,
          child: Builder(
            builder: (panelCtx) => _NoteActionMenuPanel(
              includeRename: includeRename,
              onSelected: (action) => Navigator.of(panelCtx).pop(action),
            ),
          ),
        ),
      ),
    ],
  );
}

class _NoteActionMenuPanel extends StatelessWidget {
  const _NoteActionMenuPanel({
    required this.includeRename,
    required this.onSelected,
  });

  final bool includeRename;
  final ValueChanged<_NoteMenuAction> onSelected;

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
          if (includeRename) ...[
            _NoteActionMenuRow(
              label: '重命名',
              icon: AppAssets.coursewareActionRename,
              onTap: () => onSelected(_NoteMenuAction.rename),
            ),
            SizedBox(height: ui(2)),
            Container(
              margin: EdgeInsets.symmetric(horizontal: ui(8)),
              height: ui(1),
              color: const Color(0xFFF3F4F6),
            ),
            SizedBox(height: ui(3)),
          ],
          _NoteActionMenuRow(
            label: '删除',
            icon: AppAssets.coursewareActionDelete,
            danger: true,
            onTap: () => onSelected(_NoteMenuAction.delete),
          ),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _NoteActionMenuRow extends StatelessWidget {
  const _NoteActionMenuRow({
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

/// Empty-state placeholder shown when the active category has no notes.
/// Per spec: a 300×300 illustration (`assets/images/404/kj.png`) + the
/// single line "暂无笔记". No description text, no inline CTA — users
/// rely on the floating "新建笔记" FAB at the bottom-right to create one.
class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/404/kj.png',
            width: ui(200),
            height: ui(200),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(0)),
          Text(
            '暂无笔记',
            style: TextStyle(
              fontSize: ui(16),
              color: const Color(0xFF8A91A5),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// "新建笔记" 标题输入弹窗，按 Figma 设计稿 1:1 实现：
/// - 容器 420×275，圆角 24，背景 `linear-gradient(180deg, #D2C6FF 0%,
///   white 35%, white 100%)`
/// - 顶部装饰使用 `assets/images/courseware/1.png`（与"上传课件"弹窗
///   同源），按设计放在右上角并被容器圆角裁剪
/// - 居中标题"新建笔记" 24/w500 #0B081A
/// - 输入框 380×48，圆角 8，1px `#F5F6FA` 描边；占位 14/#B6B5BB
/// - 底部"取消 / 确认"复用 [AppDialogActionBar]（视觉与 spec 完全一致）
Future<String?> _showCreateNoteTitleDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final scale = DashboardScaleScope.of(dialogContext);
      final u = scale.ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: u(32),
          vertical: u(24),
        ),
        child: Container(
          width: u(420),
          height: u(275),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFD2C6FF), Colors.white, Colors.white],
              stops: <double>[0, 0.35, 1],
            ),
            borderRadius: BorderRadius.circular(u(24)),
          ),
          child: Stack(
            children: [
              // 顶部装饰图：宽度铺满弹窗、高度 169，借助容器圆角自然裁剪。
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SizedBox(
                  height: u(169),
                  child: Image.asset(
                    AppAssets.coursewareUploadHeader,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // 标题"新建笔记"：水平居中（spec left:162 ↔ 容器宽 420 居中）
              Positioned(
                left: 0,
                right: 0,
                top: u(50),
                child: Center(
                  child: Text(
                    '新建笔记',
                    style: TextStyle(
                      fontSize: u(24),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      color: const Color(0xFF0B081A),
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              // 输入框：380×48，圆角 8，1px #F5F6FA 描边；spec 内边距 16/14
              Positioned(
                left: u(20),
                right: u(20),
                top: u(116),
                child: SizedBox(
                  height: u(48),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 30,
                    cursorColor: const Color(0xFF8741FF),
                    cursorWidth: 1.5,
                    cursorHeight: u(16),
                    style: TextStyle(
                      fontSize: u(14),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 20 / 14,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '请输入笔记标题',
                      counterText: '',
                      hintStyle: TextStyle(
                        fontSize: u(14),
                        color: const Color(0xFFB6B5BB),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 20 / 14,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: u(16),
                        vertical: u(14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(u(8)),
                        borderSide: BorderSide(
                          color: const Color(0xFFF5F6FA),
                          width: u(1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(u(8)),
                        borderSide: BorderSide(
                          color: const Color(0xFFD9C7FF),
                          width: u(1),
                        ),
                      ),
                    ),
                    onSubmitted: (value) =>
                        Navigator.of(dialogContext).pop(value.trim()),
                  ),
                ),
              ),
              // 底部按钮组：高度 45、宽度 182、间距 16，复用公共 ActionBar。
              Positioned(
                left: u(20),
                right: u(20),
                top: u(194),
                child: AppDialogActionBar(
                  cancelLabel: '取消',
                  confirmLabel: '确认',
                  onCancel: () => Navigator.of(dialogContext).pop(),
                  onConfirm: () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  controller.dispose();
  return result;
}

Widget _buildOptionalRemoteImage(String? rawUrl, {BoxFit fit = BoxFit.cover}) {
  final resolvedUrl = _resolveRemoteUrl(rawUrl);
  if (resolvedUrl == null) {
    return const SizedBox.shrink();
  }
  return Image.network(
    resolvedUrl,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    loadingBuilder: (context, child, loadingProgress) => child,
  );
}

String? _resolveRemoteUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'string') {
    return null;
  }
  final resolved = MediaUrl.resolve(value);
  return resolved.isEmpty ? null : resolved;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: ui(40),
        height: ui(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFE7EAF4)),
        ),
        child: Icon(icon, size: ui(22), color: const Color(0xFF19152A)),
      ),
    );
  }
}

/// 次操作按钮（白底带描边，例如笔记详情右上角的"保存"）。
class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final foreground = onPressed == null
        ? const Color(0xFFB9BCCB)
        : const Color(0xFF1B1730);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          height: ui(40),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: const Color(0xFFE6EAF5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: ui(16),
                  height: ui(16),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: ui(18), color: foreground),
              SizedBox(width: ui(6)),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: ui(14),
                  fontWeight: FontWeight.w500,
                  color: foreground,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter({
    required this.strokes,
    required this.activeStroke,
    required this.activeColor,
    required this.activeWidth,
  });

  final List<NoteStroke> strokes;
  final List<Offset> activeStroke;
  final Color activeColor;
  final double activeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width);
    }
    if (activeStroke.length >= 2) {
      _drawStroke(canvas, activeStroke, activeColor, activeWidth);
    }
  }

  void _drawStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midPoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midPoint.dx,
        midPoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeWidth != activeWidth;
  }
}

class _NotePaperPainter extends CustomPainter {
  const _NotePaperPainter({required this.type});

  final NotePaperType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD6DCE9)
      ..strokeWidth = 1;

    switch (type) {
      case NotePaperType.blank:
        _drawDots(canvas, size, paint);
        break;
      case NotePaperType.notebook:
        _drawNotebook(canvas, size, paint);
        break;
      case NotePaperType.staff:
        _drawStaff(canvas, size, paint);
        break;
    }
  }

  void _drawDots(Canvas canvas, Size size, Paint paint) {
    final dotPaint = Paint()..color = const Color(0xFFE9EDF7);
    for (double y = 26; y < size.height; y += 28) {
      for (double x = 20; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  void _drawNotebook(Canvas canvas, Size size, Paint paint) {
    for (double y = 42; y < size.height; y += 34) {
      canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), paint);
    }
  }

  void _drawStaff(Canvas canvas, Size size, Paint paint) {
    double startY = 36;
    while (startY < size.height - 20) {
      for (var i = 0; i < 5; i++) {
        final y = startY + i * 9;
        canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
      }
      startY += 66;
    }
  }

  @override
  bool shouldRepaint(covariant _NotePaperPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

const List<Color> _editorColors = <Color>[
  Color(0xFF2A2A2A),
  Color(0xFFFF5A36),
  Color(0xFFFFA040),
  Color(0xFF5CCB6A),
  Color(0xFF4B9EF8),
  Color(0xFF8B5CFF),
];
