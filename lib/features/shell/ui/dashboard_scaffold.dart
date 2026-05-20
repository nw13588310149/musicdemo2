import 'package:flutter/material.dart';

import 'shell_layout.dart';

class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({
    required this.sidebar,
    required this.topBar,
    required this.child,
    super.key,
    this.floatingChild,
    this.overlayChild,
    this.sidebarWidth = 178,
    this.backgroundColor = const Color(0xFFEFF3FC),
    this.contentPadding = const EdgeInsets.all(16),
    this.contentGap = 16,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget sidebar;
  final Widget topBar;
  final Widget child;
  final Widget? floatingChild;

  /// 全屏模态遮罩，盖在所有内容（含侧栏 / 顶栏 / 浮层）之上。
  ///
  /// 当前用于「绑定学校」强制弹窗（[SchoolBindingOverlay]）：只要传入
  /// 非空 widget，就铺满 SafeArea 内的整页区域并 stretch 拦截所有手势，
  /// 调用方负责实现拦截 / 模糊 / 内容渲染。`null` 时无任何影响。
  final Widget? overlayChild;
  final double sidebarWidth;
  final Color backgroundColor;
  final EdgeInsets contentPadding;
  final double contentGap;

  /// 透传给底层 [Scaffold.resizeToAvoidBottomInset]。
  ///
  /// 默认 true，弹出软键盘时整个 body 会相应收缩，方便像 AI 助手等输入页
  /// 把光标贴在键盘上方。但对于"播放器/视频"这类不依赖输入的页面，
  /// 业务希望键盘弹出时整页保持不动（Scaffold 不收缩），所以由路由层在
  /// 这些页面把这个参数置为 false，避免播放条被键盘整体顶起来。
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = DashboardScaleScope.fromSize(constraints.biggest);
        final scaledSidebarWidth = scale.ui(sidebarWidth);
        final scaledContentPadding = EdgeInsets.fromLTRB(
          scale.ui(contentPadding.left),
          scale.ui(contentPadding.top),
          scale.ui(contentPadding.right),
          scale.ui(contentPadding.bottom),
        );

        return DashboardScaleScope(
          data: scale,
          child: Scaffold(
            backgroundColor: backgroundColor,
            // 让背景延伸到底部系统手势条/导航条之下，避免在平板上出现灰色留白条。
            // 顶部仍保留 SafeArea，避免状态栏遮挡 topBar；底部由 contentPadding
            // 提供 16px 的视觉外间距，正常机型下不会与系统手势条冲突。
            extendBody: true,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            body: ColoredBox(
              color: backgroundColor,
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          width: scaledSidebarWidth,
                          child: sidebar,
                        ),
                        Expanded(
                          child: Padding(
                            padding: scaledContentPadding,
                            child: Column(
                              children: [
                                topBar,
                                SizedBox(height: scale.ui(contentGap)),
                                Expanded(child: child),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (floatingChild != null)
                      Positioned(
                        right: scale.ui(16),
                        bottom: scale.ui(18),
                        child: floatingChild!,
                      ),
                    // overlayChild 放在 Stack 最后，确保 z-order 在所有
                    // 业务内容（含 floatingChild）之上，且 Positioned.fill
                    // 能拦截所有手势——绑定学校弹窗依赖这点做「不可关闭」。
                    if (overlayChild != null)
                      Positioned.fill(child: overlayChild!),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
