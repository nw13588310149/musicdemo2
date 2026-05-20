import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/widgets/app_toast.dart';
import '../../recording_system/state/recording_system_controller.dart';
import '../state/school_binding_controller.dart';
import '../state/shell_controller.dart';
import '../state/shell_state.dart';
import 'dashboard_scaffold.dart';
import 'shell_layout.dart';
import 'widgets/school_binding_overlay.dart';
import 'widgets/shell_left_nav.dart';
import 'widgets/shell_top_bar.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({
    required this.currentRoute,
    required this.child,
    super.key,
  });

  final String currentRoute;
  final Widget child;

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  /// 「未开通 / 已过期」自动跳转 personalCenter 仅在每个 ShellScaffold
  /// 实例内触发一次，避免 myInfo 30s 轮询导致重复弹 toast / 重复跳转。
  /// 实际限流由 [build] 中的 post-frame 调度兜底 —— 跳转后老实例会被销
  /// 毁，新实例（personalCenter）路由本身在豁免清单里，不会再次触发。
  bool _vipRedirectScheduled = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shellControllerProvider);
    final controller = ref.read(shellControllerProvider.notifier);
    // 观察「绑定学校」遮罩状态：未绑定时 DashboardScaffold 渲染 overlayChild
    // 强制盖在所有内容之上。read notifier 只是为了在 ShellScaffold 挂载
    // 时把 SchoolBindingController 实例化（构造里会自动开启 5s 轮询）。
    final bindingState = ref.watch(schoolBindingControllerProvider);
    ref.read(schoolBindingControllerProvider.notifier);

    // 学校绑定遮罩优先：一旦遮罩生效，所有点击都被它兜住，VIP 校验暂停。
    // 等绑定完成、遮罩消失，下一帧 build 会按需触发 VIP 跳转。
    if (!bindingState.shouldShowOverlay) {
      _maybeScheduleVipRedirect(state);
    }

    return DashboardScaffold(
      sidebarWidth: state.collapsed
          ? ShellLayoutSpec.collapsedSidebarWidth
          : ShellLayoutSpec.sidebarWidth,
      overlayChild: bindingState.shouldShowOverlay
          ? const SchoolBindingOverlay()
          : null,
      // 应用户要求：在带音频播放器的页面，弹出底部钢琴键盘时不要让播放器
      // 跟着上推。Scaffold 默认会因 viewInsets 把 body 收缩——这里对播放
      // 类路由把 resizeToAvoidBottomInset 关掉，整个 body 保持原高度，
      // 钢琴/小键盘自然以"覆盖层"的姿态浮在播放区域之上。
      // 其它路由（AI 聊天、注册表单等）保持默认的 resize=true，避免输入框
      // 被键盘挡住。
      resizeToAvoidBottomInset: !_routeLocksLayoutForKeyboard(
        widget.currentRoute,
      ),
      sidebar: RepaintBoundary(
        child: ShellLeftNav(
          state: state,
          currentRoute: widget.currentRoute,
          onToggleCollapse: controller.toggleCollapse,
          onNavigate: (route) => _navigate(context, ref, route),
        ),
      ),
      topBar: ShellTopBar(
        state: state,
        onNavigate: (route) => _navigate(context, ref, route),
        onLogout: controller.logout,
        onMarkAllRead: controller.markAllNoticeRead,
        onLoadProvinces: controller.loadProvinces,
        onUpdateProvince: controller.updateProvince,
      ),
      child: RepaintBoundary(child: widget.child),
    );
  }

  /// 路由白名单：键盘弹起时这些页面整页保持不动（Scaffold 不 resize）。
  /// 当前都是"页面里塞了播放器 + 钢琴键盘"的入口，且页内本身没有需要避让
  /// 系统软键盘的输入框（评论 / 分享 dialog 由各自的 dialog 自行处理布局）：
  ///   - `/musicPlay`：通用音频播放页（听写、节奏、和弦…）；
  ///   - `/answerEnd2`：试题模块"听写 / 视唱 / 乐理"的播放变体；
  /// 其它路由（AI 聊天、注册表单、个人资料等）保持默认 resize=true。
  bool _routeLocksLayoutForKeyboard(String route) {
    return route == RoutePaths.musicPlay || route == RoutePaths.answerEnd2;
  }

  /// 当用户已加载且 VIP 失效时，把非豁免页面强制踢回个人中心，并 toast
  /// 提示「请先开通会员」。借助 `_vipRedirectScheduled` 一次性标记避免
  /// 一次 build 中重复 schedule；老实例跳转后会被销毁，所以无需手动复位。
  void _maybeScheduleVipRedirect(ShellState state) {
    if (_vipRedirectScheduled) {
      return;
    }
    if (ShellController.isRouteAllowedWithoutVip(widget.currentRoute)) {
      return;
    }
    // user.id 为空说明 myInfo 还没回包，先不要乱判 VIP。
    if (state.user.id.isEmpty) {
      return;
    }
    if (state.user.isVipActive) {
      return;
    }
    _vipRedirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      AppToast.show(context, '请先开通会员');
      Navigator.of(
        context,
      ).pushReplacementNamed(RoutePaths.personalCenter);
    });
  }

  void _navigate(BuildContext context, WidgetRef ref, String route) {
    if (route == widget.currentRoute) {
      // 录音系统的导航项再次点击时，直接调用 controller 把视图归位到列表
      // 首页（同时停掉在跑的录音 / 试听）。其他模块再点同一项保持原有"啥
      // 也不做"的行为，避免影响它们的页内 UI 状态。
      if (route == RoutePaths.recording) {
        ref
            .read(recordingSystemControllerProvider.notifier)
            .enterListHome();
      }
      return;
    }
    // VIP 拦截：未开通 / 已过期的用户点击非豁免左侧导航或顶部菜单时，只
    // toast 提示而不真正跳转。学校绑定遮罩生效期间走另一条主线（遮罩自
    // 己吞点击），此处不会被触达。
    final shellState = ref.read(shellControllerProvider);
    if (shellState.user.id.isNotEmpty &&
        !shellState.user.isVipActive &&
        !ShellController.isRouteAllowedWithoutVip(route)) {
      AppToast.show(context, '请先开通会员');
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }
}
