import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../data/shell_repository.dart';
import '../../state/shell_controller.dart';
import '../../state/shell_state.dart';
import '../shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class ShellTopBar extends StatelessWidget {
  ShellTopBar({
    required this.state,
    required this.onNavigate,
    required this.onLogout,
    required this.onMarkAllRead,
    required this.onLoadProvinces,
    required this.onUpdateProvince,
    super.key,
  });

  final ShellState state;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;
  final Future<void> Function() onMarkAllRead;
  final Future<List<String>> Function() onLoadProvinces;
  final Future<String?> Function(String province) onUpdateProvince;

  /// 用户菜单触发按钮的位置 anchor，供自定义 popover 定位使用。
  final GlobalKey _userMenuKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < ui(720);
        final showUserName = constraints.maxWidth >= ui(560);
        final gap = compact ? ui(8) : ui(16);

        return SizedBox(
          height: ui(40),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ui(324)),
                    child: _buildSearchBox(context),
                  ),
                ),
              ),
              SizedBox(width: gap),
              // 帮助 / 通知 / 设置 三个图标统一 40×40：图标自身带留白，
              // 与外层 _buildToolButton 的 40×40 命中区一致，视觉上由图标
              // 本体的内边距充当点击热区与背景的间距。
              _buildToolButton(
                context: context,
                child: AppAssetGraphic(
                  AppAssets.shellV2Help,
                  width: ui(40),
                  height: ui(40),
                  fit: BoxFit.contain,
                ),
                onTap: () => _showToast(context, '帮助功能即将上线'),
              ),
              SizedBox(width: gap),
              _buildNotice(context),
              SizedBox(width: gap),
              _buildToolButton(
                context: context,
                child: AppAssetGraphic(
                  AppAssets.shellV2Setting,
                  width: ui(40),
                  height: ui(40),
                  fit: BoxFit.contain,
                ),
                onTap: () => onNavigate(RoutePaths.info),
              ),
              SizedBox(width: gap),
              _buildUserMenu(context, showUserName: showUserName),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    return const _TopSearchBox();
  }

  Widget _buildToolButton({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
  }) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: SizedBox(
          width: ui(40),
          height: ui(40),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context, {required bool showUserName}) {
    final ui = DashboardScaleScope.of(context).ui;
    final displayName = state.user.displayName.trim().isEmpty
        ? '用户'
        : state.user.displayName.trim();

    return GestureDetector(
      key: _userMenuKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _openUserMenu(context),
      child: SizedBox(
        height: ui(40),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(context),
            if (showUserName) ...[
              SizedBox(width: ui(6)),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ui(96)),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(16),
                    height: 1,
                    color: const Color(0xFF1A1A1A),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
              ),
            ],
            SizedBox(width: ui(2)),
            AppAssetGraphic(
              AppAssets.leftNavBottom,
              width: ui(14),
              height: ui(14),
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUserMenu(BuildContext context) async {
    final triggerBox =
        _userMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (triggerBox == null) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    // 提前抓取当前页面的 DashboardScaleScope，再透传到 root overlay 子树里，
    // 避免菜单 builder 的 context 找不到 scope 而触发 `scope != null` 断言。
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final menuWidth = ui(180);
    final menuHeight = ui(212);

    // 与 1.0 `placement="bottom-end"` 对齐：弹出在按钮右下方。
    final triggerSize = triggerBox.size;
    final bottomRight = triggerBox.localToGlobal(
      triggerSize.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final overlaySize = overlayBox.size;
    var dx = bottomRight.dx - menuWidth;
    var dy = bottomRight.dy + ui(8);
    if (dx < ui(8)) {
      dx = ui(8);
    }
    if (dx + menuWidth > overlaySize.width - ui(8)) {
      dx = overlaySize.width - menuWidth - ui(8);
    }
    if (dy + menuHeight > overlaySize.height - ui(8)) {
      dy = overlaySize.height - menuHeight - ui(8);
    }

    final action = await showMenu<_UserMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(dx, dy, dx + menuWidth, dy + menuHeight),
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      constraints: BoxConstraints.tightFor(width: menuWidth),
      items: <PopupMenuEntry<_UserMenuAction>>[
        PopupMenuItem<_UserMenuAction>(
          padding: EdgeInsets.zero,
          enabled: false,
          child: DashboardScaleScope(
            data: scale,
            child: Builder(
              builder: (panelCtx) => _UserMenuPanel(
                width: menuWidth,
                province: state.user.province,
                onSelect: (value) => Navigator.of(panelCtx).pop(value),
              ),
            ),
          ),
        ),
      ],
    );

    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case _UserMenuAction.region:
        await _handleRegion(context);
        break;
      case _UserMenuAction.profile:
        onNavigate(RoutePaths.info);
        break;
      case _UserMenuAction.logout:
        await _handleLogout(context);
        break;
    }
  }

  Future<void> _handleRegion(BuildContext context) async {
    final provinces = await onLoadProvinces();
    if (!context.mounted) return;
    if (provinces.isEmpty) {
      _showToast(context, '加载省份失败，请稍后重试');
      return;
    }
    final selected = await showOptionsDialog(
      context: context,
      title: '选择地区',
      options: provinces,
      selected: state.user.province.isEmpty ? null : state.user.province,
    );
    if (selected == null || !context.mounted) return;
    final err = await onUpdateProvince(selected);
    if (!context.mounted) return;
    _showToast(context, err ?? '修改成功！');
  }

  Future<void> _handleLogout(BuildContext context) async {
    await onLogout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RoutePaths.login,
        (route) => false,
      );
    }
  }

  Widget _buildAvatar(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fallback = Container(
      width: ui(36),
      height: ui(36),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFE7ECFA), Color(0xFFD9E1F6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: ui(20),
        color: const Color(0xFF7E879C),
      ),
    );
    final avatarWidget = state.user.avatarUrl.isNotEmpty
        ? Image.network(
            state.user.avatarUrl,
            width: ui(36),
            height: ui(36),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : fallback;

    return Container(
      width: ui(40),
      height: ui(40),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: ClipOval(
        child: SizedBox(width: ui(36), height: ui(36), child: avatarWidget),
      ),
    );
  }

  Widget _buildNotice(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final unread = state.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildToolButton(
          context: context,
          // 与帮助 / 设置三个图标统一 40×40，让按钮本体留白由图标资源自带。
          child: AppAssetGraphic(
            AppAssets.shellV2Notice,
            width: ui(40),
            height: ui(40),
            fit: BoxFit.contain,
          ),
          onTap: () => _showNoticeDialog(context),
        ),
        if (unread > 0)
          Positioned(
            right: ui(-6),
            top: ui(-4),
            child: Container(
              height: ui(14),
              constraints: BoxConstraints(minWidth: ui(22)),
              padding: EdgeInsets.symmetric(horizontal: ui(4)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF04545),
                borderRadius: BorderRadius.circular(ui(20)),
              ),
              child: Text(
                unread > 99 ? '99+' : (unread > 9 ? '$unread+' : '$unread'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(9),
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showNoticeDialog(BuildContext context) async {
    // 右侧抽屉样式（与视频中心 / 班级分享等抽屉一致的滑入动效），
    // 替代原 1.0 居中 Dialog 列表样式。
    final scale = DashboardScaleScope.maybeOf(context);
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      barrierDismissible: true,
      barrierLabel: '关闭通知',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget panel = _NoticeDrawer(
          items: state.noticeItems,
          onMarkAllRead: () async {
            Navigator.of(dialogContext).pop();
            await onMarkAllRead();
          },
          onClose: () => Navigator.of(dialogContext).pop(),
        );
        if (scale != null) {
          panel = DashboardScaleScope(data: scale, child: panel);
        }
        return panel;
      },
      transitionBuilder: (context, animation, secondary, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  void _showToast(BuildContext context, String message) {
    AppToast.show(context, message);
  }
}

// ─────────────────────── 用户菜单（自定义弹层） ───────────────────────

enum _UserMenuAction { region, profile, logout }

class _UserMenuPanel extends StatelessWidget {
  const _UserMenuPanel({
    required this.width,
    required this.province,
    required this.onSelect,
  });

  final double width;
  final String province;
  final ValueChanged<_UserMenuAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final regionText = province.trim().isEmpty ? '未设置' : province.trim();
    // Figma：white bg + 1px #F3F2F3 border + 16px radius + 0 2 8 rgba(0,0,0,.12) shadow
    // 内边距 16，三行间距 16；行高度 44，左侧 36 圆形占位 + 20 图标。
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1F000000), // rgba(0,0,0,0.12)
            blurRadius: ui(8),
            offset: Offset(0, ui(2)),
          ),
        ],
      ),
      padding: EdgeInsets.all(ui(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UserMenuRow(
            iconAsset: AppAssets.homeUserMenuRegion,
            label: '所在地区',
            sublabel: regionText,
            onTap: () => onSelect(_UserMenuAction.region),
          ),
          SizedBox(height: ui(24)),
          _UserMenuRow(
            iconAsset: AppAssets.homeUserMenuProfile,
            label: '资料修改',
            onTap: () => onSelect(_UserMenuAction.profile),
          ),
          SizedBox(height: ui(24)),
          _UserMenuRow(
            iconAsset: AppAssets.homeUserMenuLogout,
            label: '退出登录',
            onTap: () => onSelect(_UserMenuAction.logout),
          ),
        ],
      ),
    );
  }
}

class _UserMenuRow extends StatelessWidget {
  const _UserMenuRow({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.sublabel,
  });

  /// 行图标（PNG 资源路径）。
  final String iconAsset;
  final String label;

  /// 副标题（仅「所在地区」用于显示当前省份）。null 时不渲染第二行。
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasSub = sublabel != null && sublabel!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        height: ui(44),
        child: Row(
          children: [
            Image.asset(
              iconAsset,
              width: ui(36),
              height: ui(36),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: hasSub
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: ui(16),
                      color: Colors.black,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.2,
                    ),
                  ),
                  if (hasSub) ...[
                    SizedBox(height: ui(4)),
                    Text(
                      sublabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: const Color(0xFF8741FF),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── 通知抽屉（右侧滑入） ───────────────────────

class _NoticeDrawer extends StatelessWidget {
  const _NoticeDrawer({
    required this.items,
    required this.onMarkAllRead,
    required this.onClose,
  });

  final List<ShellNoticeItem> items;
  final Future<void> Function() onMarkAllRead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        elevation: 32,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: SizedBox(
          width: ui(420),
          height: double.infinity,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(12), ui(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NoticeDrawerHeader(
                    count: items.length,
                    onMarkAllRead: items.isEmpty ? null : onMarkAllRead,
                    onClose: onClose,
                  ),
                  SizedBox(height: ui(16)),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF3F2F3),
                  ),
                  SizedBox(height: ui(12)),
                  Expanded(
                    child: items.isEmpty
                        ? const _NoticeEmpty()
                        : ListView.separated(
                            padding: EdgeInsets.only(right: ui(8)),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => SizedBox(height: ui(8)),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _NoticeRow(item: item);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeDrawerHeader extends StatelessWidget {
  const _NoticeDrawerHeader({
    required this.count,
    required this.onMarkAllRead,
    required this.onClose,
  });

  final int count;
  final Future<void> Function()? onMarkAllRead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: const Color(0xFF8741FF),
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(6)),
        Text(
          '通知($count)',
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.2,
          ),
        ),
        const Spacer(),
        if (onMarkAllRead != null)
          InkWell(
            onTap: onMarkAllRead,
            borderRadius: BorderRadius.circular(ui(6)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui(8),
                vertical: ui(6),
              ),
              child: Text(
                '批量已读',
                style: TextStyle(
                  color: const Color(0xFF8741FF),
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
            ),
          ),
        SizedBox(width: ui(2)),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(ui(20)),
          child: Padding(
            padding: EdgeInsets.all(ui(4)),
            child: Icon(
              Icons.close_rounded,
              size: ui(20),
              color: const Color(0xFF6D6B75),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.item});

  final ShellNoticeItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 1.0 通知接口的 targetType 图标素材尚未补齐（assets/images/shell/msg{1-4}.png
    // 未入库），先隐藏前导图标，仅保留文本 + 时间。素材到位后恢复 _NoticeRow 的
    // leading Image.asset 即可。
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui(12),
        vertical: ui(12),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(14),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.45,
            ),
          ),
          SizedBox(height: ui(6)),
          Text(
            item.createTime,
            style: TextStyle(
              color: const Color(0xFFB6B5BB),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeEmpty extends StatelessWidget {
  const _NoticeEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: ui(48),
            color: const Color(0xFFCECED1),
          ),
          SizedBox(height: ui(12)),
          Text(
            '暂无通知',
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

// ─────────────────────── 顶部全局搜索（对齐 1.0 TopNav.vue）───────────────────
//
// 行为对齐：
//   1) 用户在输入框输入关键字 → 300ms 防抖后并行命中四个 1.0 列表接口；
//   2) 输入框获得焦点且查询非空时，浮层下拉显示 4 个 tab（课程/视频/录音/笔记），
//      tab 标题尾部带计数；
//   3) 点击列表项 → 按 1.0 `goDetail` 的分发规则路由到对应详情页：
//        type 1/3       → /musicPlay              {id}
//        type 4/5       → /musicPlay              {id, type:2}
//        type 2         → /theory                 {id}
//        type 6         → /video-tutorial         {openVideoId}
//        type 9         → /consultationDetail     {id}
//        type 'ly'      → /recording              {id: categoryId}
//        type 'note'    → /noteDetail             {id, title, type, param1, sId}
//
// 视觉上沿用顶部 v2 设计（白底、12px 圆角、40px 高）；下拉浮层使用 Overlay
// 居中弹出在输入框下方 8px，右下方阴影 + 1px 浅边框，与个人菜单风格一致。

enum _SearchTab { text, video, ly, note }

extension _SearchTabExt on _SearchTab {
  String get label {
    switch (this) {
      case _SearchTab.text:
        return '课程';
      case _SearchTab.video:
        return '视频';
      case _SearchTab.ly:
        return '录音';
      case _SearchTab.note:
        return '笔记';
    }
  }
}

class _SearchItem {
  const _SearchItem({
    required this.id,
    required this.title,
    required this.type,
    this.categoryId,
    this.paperType,
    this.param1,
  });

  /// 后端原始 id（雪花长整型，必须以字符串形式承载，避免 53bit 精度丢失）。
  final String id;
  final String title;

  /// 1.0 `goDetail` 的分发字段：可能是数字（1/2/3/4/5/6/9）或字符串（'ly'/'note'）。
  final dynamic type;

  /// 录音 / 笔记列表项额外字段：
  ///   - 录音：`categoryId` 用作跳 /recording 的 id。
  ///   - 笔记：`categoryId` 是分类 id，`paperType`/`param1` 用于详情页。
  final String? categoryId;
  final dynamic paperType;
  final String? param1;
}

class _TopSearchBox extends ConsumerStatefulWidget {
  const _TopSearchBox();

  @override
  ConsumerState<_TopSearchBox> createState() => _TopSearchBoxState();
}

class _TopSearchBoxState extends ConsumerState<_TopSearchBox> {
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final GlobalKey _fieldKey = GlobalKey();

  Timer? _debounce;

  /// 当前已发出（或正在响应中）的 keyword，用于丢弃过期请求结果。
  String _pendingKeyword = '';

  String _query = '';
  _SearchTab _activeTab = _SearchTab.text;
  bool _loading = false;
  Map<_SearchTab, List<_SearchItem>> _results = const {
    _SearchTab.text: <_SearchItem>[],
    _SearchTab.video: <_SearchItem>[],
    _SearchTab.ly: <_SearchItem>[],
    _SearchTab.note: <_SearchItem>[],
  };

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.dispose();
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      if (_query.trim().isNotEmpty && !_overlayController.isShowing) {
        _overlayController.show();
      }
    } else {
      // 失焦时延迟一帧再关浮层，避免 ListView 项的点击事件还没派发就被销毁。
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        if (!_focusNode.hasFocus && _overlayController.isShowing) {
          _overlayController.hide();
        }
      });
    }
  }

  void _handleTextChange() {
    final value = _controller.text;
    if (value == _query) return;
    setState(() => _query = value);

    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      // 清空时立即重置结果 & 收起浮层。
      _pendingKeyword = '';
      setState(() {
        _loading = false;
        _results = const {
          _SearchTab.text: <_SearchItem>[],
          _SearchTab.video: <_SearchItem>[],
          _SearchTab.ly: <_SearchItem>[],
          _SearchTab.note: <_SearchItem>[],
        };
      });
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
      return;
    }

    if (!_overlayController.isShowing && _focusNode.hasFocus) {
      _overlayController.show();
    }
    _debounce = Timer(_debounceDuration, () => _performSearch(trimmed));
  }

  Future<void> _performSearch(String keyword) async {
    _pendingKeyword = keyword;
    setState(() => _loading = true);

    final repo = ref.read(shellRepositoryProvider);
    final province = ref.read(shellControllerProvider).user.province;

    try {
      final responses = await Future.wait([
        repo.searchTextbookList(keyword: keyword, province: province),
        repo.searchVideoList(keyword: keyword, province: province),
        repo.searchRecordingList(keyword: keyword, province: province),
        repo.searchNoteList(keyword: keyword, province: province),
      ]);
      // 过期请求兜底：在 await 期间用户可能继续打字，老 keyword 的结果应被丢弃。
      if (!mounted || _pendingKeyword != keyword) {
        return;
      }
      setState(() {
        _loading = false;
        _results = {
          _SearchTab.text: _parseList(
            responses[0].data,
            forcedType: null, // 课程接口自带 type 字段，按原值分发。
          ),
          _SearchTab.video: _parseList(responses[1].data, forcedType: 6),
          _SearchTab.ly: _parseList(responses[2].data, forcedType: 'ly'),
          _SearchTab.note: _parseList(responses[3].data, forcedType: 'note'),
        };
      });
    } catch (_) {
      if (!mounted || _pendingKeyword != keyword) return;
      setState(() {
        _loading = false;
        _results = const {
          _SearchTab.text: <_SearchItem>[],
          _SearchTab.video: <_SearchItem>[],
          _SearchTab.ly: <_SearchItem>[],
          _SearchTab.note: <_SearchItem>[],
        };
      });
    }
  }

  List<_SearchItem> _parseList(dynamic raw, {dynamic forcedType}) {
    if (raw is! List) return const <_SearchItem>[];
    final items = <_SearchItem>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.map((key, value) => MapEntry(key.toString(), value));
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final title =
          (map['title']?.toString().trim().isNotEmpty ?? false)
          ? map['title'].toString()
          : (map['name']?.toString() ?? '');
      final type = forcedType ?? map['type'];
      final categoryId = map['categoryId']?.toString();
      items.add(
        _SearchItem(
          id: id,
          title: title,
          type: type,
          categoryId: categoryId,
          paperType: map['paperType'],
          param1: map['param1']?.toString(),
        ),
      );
    }
    return items;
  }

  void _handleItemTap(_SearchItem item) {
    final navigator = Navigator.of(context);
    _focusNode.unfocus();
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    final dynamic type = item.type;
    if (type is int) {
      switch (type) {
        case 1:
        case 3:
          navigator.pushNamed(
            RoutePaths.musicPlay,
            arguments: <String, dynamic>{'id': item.id},
          );
          return;
        case 2:
          navigator.pushNamed(
            RoutePaths.theory,
            arguments: <String, dynamic>{'id': item.id},
          );
          return;
        case 4:
        case 5:
          navigator.pushNamed(
            RoutePaths.musicPlay,
            arguments: <String, dynamic>{'id': item.id, 'type': 2},
          );
          return;
        case 6:
          navigator.pushNamed(
            RoutePaths.videoTutorial,
            arguments: <String, dynamic>{'openVideoId': item.id},
          );
          return;
        case 9:
          navigator.pushNamed(
            RoutePaths.consultationDetail,
            arguments: <String, dynamic>{'id': item.id},
          );
          return;
      }
    }
    if (type == 'ly') {
      final cid = item.categoryId ?? item.id;
      navigator.pushNamed(
        RoutePaths.recording,
        arguments: <String, dynamic>{'id': cid},
      );
      return;
    }
    if (type == 'note') {
      navigator.pushNamed(
        RoutePaths.noteDetail,
        arguments: <String, dynamic>{
          'id': item.categoryId ?? '',
          'title': item.title,
          'type': item.paperType,
          'param1': item.param1 ?? '',
          'sId': item.id,
        },
      );
      return;
    }
  }

  void _handleClear() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal.targetsRootOverlay(
        controller: _overlayController,
        overlayChildBuilder: (overlayContext) =>
            _buildOverlay(overlayContext, scale),
        child: _buildField(context),
      ),
    );
  }

  Widget _buildField(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      key: _fieldKey,
      height: ui(40),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isEmpty) return;
          _debounce?.cancel();
          _performSearch(trimmed);
        },
        style: TextStyle(
          fontSize: ui(14),
          color: const Color(0xFF1A1A1A),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
        decoration: InputDecoration(
          isCollapsed: false,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          hintText: '搜索',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFD1D1D1),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: ui(14), right: ui(8)),
            child: AppAssetGraphic(
              AppAssets.shellV2Search,
              width: ui(16),
              height: ui(16),
              fit: BoxFit.contain,
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: ui(38)),
          suffixIcon: _query.isEmpty
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleClear,
                  child: Padding(
                    padding: EdgeInsets.only(right: ui(10)),
                    child: Icon(
                      Icons.cancel,
                      size: ui(16),
                      color: const Color(0xFFC6C6C6),
                    ),
                  ),
                ),
          suffixIconConstraints: BoxConstraints(minWidth: ui(28)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFE5DFFE),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext overlayContext, DashboardScaleData scale) {
    final ui = scale.ui;
    final fieldBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldWidth = fieldBox?.size.width ?? ui(324);
    // 浮层最小宽度：保证 4 个 tab 文字不挤；最多撑到 420 让结果更易读。
    final panelWidth = fieldWidth.clamp(ui(320), ui(420));

    return Stack(
      children: [
        // 透明遮罩：点击浮层外区域时关闭浮层。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              _focusNode.unfocus();
              if (_overlayController.isShowing) {
                _overlayController.hide();
              }
            },
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: Offset(0, ui(8)),
          child: DashboardScaleScope(
            data: scale,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: panelWidth,
                child: _SearchDropdownPanel(
                  loading: _loading,
                  query: _query,
                  activeTab: _activeTab,
                  results: _results,
                  onTabChanged: (tab) {
                    setState(() => _activeTab = tab);
                  },
                  onItemTap: _handleItemTap,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchDropdownPanel extends StatelessWidget {
  const _SearchDropdownPanel({
    required this.loading,
    required this.query,
    required this.activeTab,
    required this.results,
    required this.onTabChanged,
    required this.onItemTap,
  });

  final bool loading;
  final String query;
  final _SearchTab activeTab;
  final Map<_SearchTab, List<_SearchItem>> results;
  final ValueChanged<_SearchTab> onTabChanged;
  final ValueChanged<_SearchItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final list = results[activeTab] ?? const <_SearchItem>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1F000000),
            blurRadius: ui(16),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchTabBar(
            activeTab: activeTab,
            results: results,
            onTabChanged: onTabChanged,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(ui(12), ui(10), ui(12), ui(12)),
            child: SizedBox(
              height: ui(360),
              child: _buildBody(context, list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<_SearchItem> list) {
    final ui = DashboardScaleScope.of(context).ui;
    if (loading) {
      return Center(
        child: SizedBox(
          width: ui(28),
          height: ui(28),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: ui(40),
              color: const Color(0xFFCECED1),
            ),
            SizedBox(height: ui(8)),
            Text(
              '暂无结果',
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFFB6B5BB),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFF3F3F3), width: ui(1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(4)),
        itemCount: list.length,
        separatorBuilder: (_, _) => Container(
          height: ui(1),
          color: const Color(0xFFF3F3F3),
        ),
        itemBuilder: (context, index) {
          final item = list[index];
          return _SearchResultRow(
            index: index,
            item: item,
            onTap: () => onItemTap(item),
          );
        },
      ),
    );
  }
}

class _SearchTabBar extends StatelessWidget {
  const _SearchTabBar({
    required this.activeTab,
    required this.results,
    required this.onTabChanged,
  });

  final _SearchTab activeTab;
  final Map<_SearchTab, List<_SearchItem>> results;
  final ValueChanged<_SearchTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1),
        ),
      ),
      child: Row(
        children: _SearchTab.values.map((tab) {
          final count = results[tab]?.length ?? 0;
          final selected = tab == activeTab;
          return Expanded(
            child: InkWell(
              onTap: () => onTabChanged(tab),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: ui(13),
                          fontFamily: 'PingFang SC',
                          fontWeight: selected
                              ? AppFont.w500
                              : AppFont.w400,
                          color: selected
                              ? const Color(0xFF8741FF)
                              : const Color(0xFF6D6B75),
                          height: 1.2,
                        ),
                        children: [
                          TextSpan(text: tab.label),
                          TextSpan(text: '($count)'),
                        ],
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      bottom: ui(0),
                      child: Container(
                        width: ui(28),
                        height: ui(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8741FF),
                          borderRadius: BorderRadius.circular(ui(3)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final _SearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: ui(44),
        child: Row(
          children: [
            Container(
              width: ui(20),
              height: ui(20),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF8741FF),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(12),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ),
            SizedBox(width: ui(10)),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(13),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
