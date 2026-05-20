import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kFieldBorder = Color(0xFFF5F6FA);
const Color _kPanelBorder = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kPurple = Color(0xFF8741FF);

/// 在 [anchorContext] 所代表的触发器**下方 4px** 锚定打开一个全局通用样式
/// 的下拉弹层（[PopupSelectorPanel]），返回用户选中的值或 `null`（点击蒙层
/// 关闭）。所有自定义触发器（pill / icon / 异形 chip）只要调用这一个助手，
/// 就能拿到统一的弹层视觉与交互。
///
/// - [width]：弹层宽度。`null` 时使用触发器的实际宽度；触发器很窄（如 36
///   高紫边胶囊）时通常需要显式指定一个更宽的值（推荐 ≥ 120）。
/// - [maxWidth] / [minWidth]：可选的宽度区间，覆盖默认的 [width]。
/// - 弹层会自动 dismiss（点击 barrier / 选中 / 调用 `Navigator.pop`）。
Future<T?> showAppPopupSelector<T>({
  required BuildContext anchorContext,
  required List<T> items,
  required T? value,
  required String Function(T) itemLabel,
  double? width,
  double? minWidth,
  double? maxWidth,
}) async {
  final renderBox = anchorContext.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;
  final overlayBox =
      Overlay.of(anchorContext, rootOverlay: true).context.findRenderObject()
          as RenderBox?;
  if (overlayBox == null) return null;
  final origin = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = renderBox.size;
  final scale = DashboardScaleScope.of(anchorContext);
  final effectiveWidth = width ?? size.width;

  return showMenu<T>(
    context: anchorContext,
    elevation: 0,
    color: Colors.transparent,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    constraints: BoxConstraints(
      minWidth: minWidth ?? effectiveWidth,
      maxWidth: maxWidth ?? effectiveWidth,
    ),
    position: RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + size.height + scale.ui(4),
      overlayBox.size.width - origin.dx - size.width,
      overlayBox.size.height - origin.dy - size.height,
    ),
    items: <PopupMenuEntry<T>>[
      PopupMenuItem<T>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: DashboardScaleScope(
          data: scale,
          child: Builder(
            builder: (panelCtx) => PopupSelectorPanel<T>(
              items: items,
              value: value,
              itemLabel: itemLabel,
              onSelected: (v) => Navigator.of(panelCtx).pop(v),
            ),
          ),
        ),
      ),
    ],
  );
}

/// 项目内统一的「下拉选择」控件。
///
/// 字段：48 高白底 + 1px `#F5F6FA` 边的按钮，14/400 黑字 + 18px chevron；
/// 弹层：锚定在字段下方 4px 处，同字段宽度，白底 12 圆角 + 1px `#F3F2F3` 边
/// + 多层柔和阴影；每行 40 高，命中项使用 `#8741FF` 紫色文字 + 紫色 check。
///
/// 与请假申请、授课课表「申请小课」等表单使用同一份实现，保证视觉与交互
/// 一致。提取自 `student_leave_management_view._PopupSelectorField`。
///
/// 用法：
/// ```dart
/// PopupSelectorField<String>(
///   value: _type,
///   items: const ['病假', '事假', '其他'],
///   itemLabel: (s) => s,
///   onChanged: (v) => setState(() => _type = v),
/// )
/// ```
class PopupSelectorField<T> extends StatefulWidget {
  const PopupSelectorField({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  State<PopupSelectorField<T>> createState() => _PopupSelectorFieldState<T>();
}

class _PopupSelectorFieldState<T> extends State<PopupSelectorField<T>> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    final fieldCtx = _fieldKey.currentContext;
    if (fieldCtx == null) return;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<T>(
      anchorContext: fieldCtx,
      items: widget.items,
      value: widget.value,
      itemLabel: widget.itemLabel,
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      onTap: _openMenu,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kFieldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.itemLabel(widget.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(18),
                color: _kTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全局通用「下拉弹层」面板。
///
/// 视觉：白底 12 圆角 + 1px `#F3F2F3` 边 + 多层柔和阴影；上下各 6px 边距；
/// 每行 40 高、14/400 黑字；命中项使用 `#8741FF` 紫色 14/500 + 右侧紫色
/// check。所有调起此面板的下拉控件（请假申请、班级筛选、查寝状态等）共用
/// 同一份实现。
///
/// 多数情况下应使用 [showAppPopupSelector] 助手，它会负责锚定到触发器下方
/// 4px、传递 `DashboardScaleScope` 并管理弹出/关闭。仅在需要自定义嵌入位置
/// 时直接使用本组件。
class PopupSelectorPanel<T> extends StatelessWidget {
  const PopupSelectorPanel({
    super.key,
    required this.items,
    required this.value,
    required this.itemLabel,
    required this.onSelected,
  });

  final List<T> items;
  final T? value;
  final String Function(T) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kPanelBorder, width: 1),
        boxShadow: [
          const BoxShadow(color: Color(0x050B081A), blurRadius: 1),
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
          SizedBox(height: ui(6)),
          for (final item in items)
            _PopupSelectorRow<T>(
              label: itemLabel(item),
              selected: item == value,
              onTap: () => onSelected(item),
            ),
          SizedBox(height: ui(6)),
        ],
      ),
    );
  }
}

class _PopupSelectorRow<T> extends StatelessWidget {
  const _PopupSelectorRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(14)),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: selected ? _kPurple : _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: selected ? AppFont.w500 : AppFont.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: ui(16), color: _kPurple),
          ],
        ),
      ),
    );
  }
}
