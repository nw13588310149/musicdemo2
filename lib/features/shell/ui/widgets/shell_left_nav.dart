import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../state/shell_state.dart';
import '../shell_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 动画常量
// ─────────────────────────────────────────────────────────────────────────────
const _kDuration = Duration(milliseconds: 280);
const _kCurve = Curves.easeInOutCubic;

// ─────────────────────────────────────────────────────────────────────────────
// ShellLeftNav — 持有 AnimationController 以驱动所有子动画
// ─────────────────────────────────────────────────────────────────────────────
class ShellLeftNav extends StatefulWidget {
  const ShellLeftNav({
    required this.state,
    required this.currentRoute,
    required this.onToggleCollapse,
    required this.onNavigate,
    super.key,
  });

  final ShellState state;
  final String currentRoute;
  final VoidCallback onToggleCollapse;
  final ValueChanged<String> onNavigate;

  @override
  State<ShellLeftNav> createState() => _ShellLeftNavState();
}

class _ShellLeftNavState extends State<ShellLeftNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 0.0 = 展开, 1.0 = 折叠
  late final Animation<double> _progress;

  // Logo: 前 40% 完成淡出
  late final Animation<double> _logoOpacity;

  // 文字: 前 55% 完成淡出, 0→100% 完成宽度收缩
  late final Animation<double> _labelOpacity;
  late final Animation<double> _labelWidth; // 1→0

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _kDuration,
      value: widget.state.collapsed ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: _kCurve);

    _logoOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.4, curve: Curves.easeIn),
      ),
    );
    _labelOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.55, curve: Curves.easeIn),
      ),
    );
    _labelWidth = Tween<double>(begin: 1, end: 0).animate(_progress);
  }

  @override
  void didUpdateWidget(ShellLeftNav old) {
    super.didUpdateWidget(old);
    if (old.state.collapsed != widget.state.collapsed) {
      widget.state.collapsed ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _isActive(String navRoute) {
    final current = widget.currentRoute;
    if (navRoute == '/') return current == '/';
    if (current == navRoute) return true;
    return current.startsWith('$navRoute/');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final scale = DashboardScaleScope.of(context);
        final ui = scale.ui;
        final t = _progress.value; // 0=展开, 1=折叠

        // 列表两侧内边距: 展开时 16, 折叠时 8（使 icon 精确居中于 40px 内容宽度）
        final hPad = ui(16.0 - 8.0 * t); // lerp(16, 8, t)

        // 按钮内左边距: 展开 16 → 折叠 0
        final tilePadLeft = ui(16.0 * (1.0 - t));
        // 按钮内右边距: 展开 10 → 折叠 0
        final tilePadRight = ui(10.0 * (1.0 - t));

        return ColoredBox(
          color: Colors.white,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 主体列（logo + 导航列表）──────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: ui(31.5)),

                  // Logo：透明度由动画驱动，高度固定保持空间
                  Opacity(
                    opacity: _logoOpacity.value,
                    child: SizedBox(
                      height: ui(36),
                      child: Center(
                        child: Image.asset(
                          AppAssets.shellLogo,
                          width: ui(132),
                          height: ui(36),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: ui(18)),

                  // 导航列表
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        itemCount: widget.state.navItems.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: ui(4)),
                        itemBuilder: (context, index) {
                          final item = widget.state.navItems[index];
                          return _NavTile(
                            item: item,
                            progress: t,
                            labelOpacity: _labelOpacity.value,
                            labelWidthFactor: _labelWidth.value,
                            tilePadLeft: tilePadLeft,
                            tilePadRight: tilePadRight,
                            active: _isActive(item.route),
                            onTap: () => widget.onNavigate(item.route),
                          );
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: ui(57)),
                ],
              ),

              // ── 缩放切换按钮（右下角）─────────────────────────────────────
              Positioned(
                right: 0,
                bottom: ui(57),
                child: GestureDetector(
                  onTap: widget.onToggleCollapse,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: ui(27),
                    height: ui(36),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(ui(12)),
                        bottomLeft: Radius.circular(ui(12)),
                      ),
                    ),
                    child: Center(
                      child: Transform.rotate(
                        // 展开=0°, 折叠=180°（指向右侧，表示"展开"方向）
                        angle: t * math.pi,
                        child: AppAssetGraphic(
                          AppAssets.leftNavScale,
                          width: ui(21),
                          height: ui(13),
                          fit: BoxFit.contain,
                        ),
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavTile — 单个导航项，接收插值后的动画参数
// ─────────────────────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.progress,
    required this.labelOpacity,
    required this.labelWidthFactor,
    required this.tilePadLeft,
    required this.tilePadRight,
    required this.active,
    required this.onTap,
  });

  final ShellNavItem item;
  final double progress; // 0=展开, 1=折叠
  final double labelOpacity;
  final double labelWidthFactor; // 1→0
  final double tilePadLeft;
  final double tilePadRight;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    // 选中态背景：从「写死的 #202020」改为「PNG 平铺」。
    // - active.png 本身是深色 + 圆角矩形，作为 DecorationImage 平铺即可。
    // - 用 BoxFit.cover：图本身约 3:1 的横向比例，展开态横长矩形天然契合，
    //   折叠态 40×40 也能铺满（cover 会裁掉横向两侧，但图是纯色横块，
    //   裁掉中段同色像素肉眼不可分辨，安全）。
    // - 外层仍保留 borderRadius.circular(12)，把图边缘任何透明 / 半透明
    //   渐变像素裁掉，避免「图自带圆角 + 容器无圆角」时四角露出底色的白。
    final activeBg = active
        ? const DecorationImage(
            image: AssetImage(AppAssets.leftNavActiveBg),
            fit: BoxFit.cover,
          )
        : null;
    // 设计稿：未选中文案 opacity 0.70 + #0B081A；选中项白字
    final textColor = active
        ? Colors.white
        : const Color(0xFF0B081A).withValues(alpha: 0.7);

    final collapsed = progress > 0.5;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        // 命中区固定 48 高（与展开态一致），icon 在里面始终垂直居中。
        child: Container(
          constraints: BoxConstraints(minHeight: ui(48)),
          alignment: collapsed ? Alignment.center : Alignment.centerLeft,
          child: collapsed
              // 折叠态：bg 收成 40×40 正方形，包住 icon；命中区仍是 48 高。
              ? Container(
                  width: ui(40),
                  height: ui(40),
                  decoration: BoxDecoration(
                    image: activeBg,
                    borderRadius: BorderRadius.circular(ui(12)),
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildIcon(context),
                      if (item.badge > 0)
                        Positioned(
                          right: ui(-2),
                          top: ui(1),
                          child: const _BadgeDot(),
                        ),
                    ],
                  ),
                )
              // 展开态：bg 横铺整条 tile，左 16 / 右 10 / 上下 12 内边距。
              : Container(
                  decoration: BoxDecoration(
                    image: activeBg,
                    borderRadius: BorderRadius.circular(ui(12)),
                  ),
                  padding: EdgeInsets.only(
                    left: tilePadLeft,
                    right: tilePadRight,
                    top: ui(12),
                    bottom: ui(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildIcon(context),
                      Expanded(
                        child: ClipRect(
                          child: Align(
                            widthFactor: labelWidthFactor,
                            alignment: Alignment.centerLeft,
                            child: Opacity(
                              opacity: labelOpacity,
                              // 设计稿：inline-flex，图标→文案→角标 按内容自然宽度紧凑排列
                              // 角标紧贴文案（设计稿 4px 间隙），不挤占「智慧校园」
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(width: ui(8)),
                                  Flexible(
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      // PingFang SC 在 iOS / Web (Safari/
                                      // CanvasKit) 上缺少 CoreText 的字面
                                      // 灰度补偿，直接写 FontWeight.w500
                                      // 视觉上比设计稿轻一档，必须走
                                      // AppFont.w500 让平台层把字重统一上浮。
                                      style: TextStyle(
                                        fontSize: ui(15),
                                        height: 1,
                                        fontFamily: 'PingFang SC',
                                        fontWeight: AppFont.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (item.badge > 0) ...[
                                    SizedBox(width: ui(4)),
                                    _NavUnreadCapsule(count: item.badge),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return AppAssetGraphic(
      active ? item.activeIcon : item.icon,
      width: ui(24),
      height: ui(24),
      fit: BoxFit.contain,
      colorFilter: active
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge（智慧校园未读等）：设计稿 #F04545 胶囊 + Manrope 800 数字
// ─────────────────────────────────────────────────────────────────────────────

/// 折叠态：角标圆点（#F04545）
class _BadgeDot extends StatelessWidget {
  const _BadgeDot();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(8),
      height: ui(8),
      decoration: const BoxDecoration(
        color: Color(0xFFF04545),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 展开态：圆角胶囊，宽度按数字内容自适应（"9"/"10+"/"99+" 各不相同）
/// 设计稿"10+"≈22×15：文字 17w + 左右各 2.5px padding 自然撑出
class _NavUnreadCapsule extends StatelessWidget {
  const _NavUnreadCapsule({required this.count});

  final int count;

  String get _label => count > 99 ? '99+' : (count > 9 ? '$count+' : '$count');

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(15),
      padding: EdgeInsets.symmetric(horizontal: ui(2.5)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF04545),
        borderRadius: BorderRadius.circular(ui(20)),
      ),
      child: Text(
        _label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: ui(10),
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
