import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../../features/shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// Available actions for the shared item action menu (the popup used by
/// the cloud disk's left sidebar and other lists).
///
/// To extend the menu with new entries, add a value here AND update
/// [_actionMeta] to provide a label, icon and (optionally) a danger flag.
enum ItemMenuAction { rename, share, copy, delete }

class _ActionMeta {
  const _ActionMeta({
    required this.label,
    required this.icon,
    this.danger = false,
  });
  final String label;
  final String icon;
  final bool danger;
}

const Map<ItemMenuAction, _ActionMeta> _actionMeta =
    <ItemMenuAction, _ActionMeta>{
      ItemMenuAction.rename: _ActionMeta(
        label: '重命名',
        icon: AppAssets.coursewareActionRename,
      ),
      ItemMenuAction.share: _ActionMeta(
        label: '分享',
        icon: AppAssets.coursewareActionShare,
      ),
      ItemMenuAction.copy: _ActionMeta(
        label: '复制',
        icon: AppAssets.coursewareActionCopy,
      ),
      ItemMenuAction.delete: _ActionMeta(
        label: '删除',
        icon: AppAssets.coursewareActionDelete,
        danger: true,
      ),
    };

/// Default action set for list/sidebar item menus: rename / share / copy / delete.
const List<ItemMenuAction> kDefaultItemMenuActions = <ItemMenuAction>[
  ItemMenuAction.rename,
  ItemMenuAction.share,
  ItemMenuAction.copy,
  ItemMenuAction.delete,
];

/// Shows the shared list-item action menu anchored to the trigger widget.
///
/// [triggerKey] must be attached to the widget that opened the menu (typically
/// the ⋯ button); it's used to compute the popup anchor so the menu appears
/// at the click point and shifts inward when there isn't enough room.
///
/// [actions] controls which entries appear, in order. Pass any subset of
/// [ItemMenuAction]; e.g. `[ItemMenuAction.rename, ItemMenuAction.delete]`
/// for cloud-disk style category cards, or omit it to use the full default
/// (rename / share / copy / delete).
///
/// Returns the selected action, or `null` if the user dismissed the menu.
Future<ItemMenuAction?> showItemActionMenu({
  required BuildContext context,
  required GlobalKey triggerKey,
  List<ItemMenuAction> actions = kDefaultItemMenuActions,
}) {
  if (actions.isEmpty) {
    return Future<ItemMenuAction?>.value(null);
  }
  final triggerCtx = triggerKey.currentContext;
  if (triggerCtx == null) {
    return Future<ItemMenuAction?>.value(null);
  }
  final renderBox = triggerCtx.findRenderObject() as RenderBox;
  final overlayBox =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()
          as RenderBox;

  final origin = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = renderBox.size;
  final scale = DashboardScaleScope.of(context);
  final menuWidth = scale.ui(142);
  // Approximate height: 8 top pad + 36*N rows + (1 divider + 5 gap) if delete
  // is not the only entry + 8 bottom pad. Used only to nudge the menu up when
  // there isn't enough room below the trigger; rendering remains intrinsic.
  final hasDelete = actions.contains(ItemMenuAction.delete);
  final nonDeleteCount = actions
      .where((a) => a != ItemMenuAction.delete)
      .length;
  final approxMenuHeight = scale.ui(
    16 + nonDeleteCount * 36 + (hasDelete ? (nonDeleteCount > 0 ? 42 : 36) : 0),
  );

  // Anchor so the trigger center maps roughly to the menu's top-left corner;
  // flip horizontally / vertically when out of bounds.
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

  return showMenu<ItemMenuAction>(
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
    items: <PopupMenuEntry<ItemMenuAction>>[
      PopupMenuItem<ItemMenuAction>(
        enabled: false,
        padding: EdgeInsets.zero,
        // Re-inject DashboardScaleScope: the popup is hosted in a separate
        // overlay and ancestors aren't reachable inside `child`.
        child: DashboardScaleScope(
          data: scale,
          child: Builder(
            builder: (panelCtx) => _ItemActionMenuPanel(
              actions: actions,
              onSelected: (action) => Navigator.of(panelCtx).pop(action),
            ),
          ),
        ),
      ),
    ],
  );
}

/// 142px-wide menu panel: white / 12 radius / 1.11px light border /
/// soft three-layer shadow. Matches the cloud-disk left-sidebar popup style.
class _ItemActionMenuPanel extends StatelessWidget {
  const _ItemActionMenuPanel({required this.actions, required this.onSelected});

  final List<ItemMenuAction> actions;
  final ValueChanged<ItemMenuAction> onSelected;

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
        children: _buildRows(ui),
      ),
    );
  }

  List<Widget> _buildRows(double Function(double) ui) {
    final children = <Widget>[];
    final hasDelete = actions.contains(ItemMenuAction.delete);
    final regular = actions.where((a) => a != ItemMenuAction.delete).toList();

    children.add(SizedBox(height: ui(8)));
    for (var i = 0; i < regular.length; i++) {
      final action = regular[i];
      final meta = _actionMeta[action]!;
      children.add(
        _ItemActionMenuRow(
          label: meta.label,
          icon: meta.icon,
          danger: meta.danger,
          onTap: () => onSelected(action),
        ),
      );
      if (i != regular.length - 1) {
        children.add(SizedBox(height: ui(2)));
      }
    }
    if (hasDelete) {
      if (regular.isNotEmpty) {
        children
          ..add(SizedBox(height: ui(2)))
          ..add(
            Container(
              margin: EdgeInsets.symmetric(horizontal: ui(8)),
              height: ui(1),
              color: const Color(0xFFF3F4F6),
            ),
          )
          ..add(SizedBox(height: ui(3)));
      }
      final meta = _actionMeta[ItemMenuAction.delete]!;
      children.add(
        _ItemActionMenuRow(
          label: meta.label,
          icon: meta.icon,
          danger: meta.danger,
          onTap: () => onSelected(ItemMenuAction.delete),
        ),
      );
    }
    children.add(SizedBox(height: ui(8)));
    return children;
  }
}

class _ItemActionMenuRow extends StatelessWidget {
  const _ItemActionMenuRow({
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
