import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 项目内统一的下拉刷新组件。
///
/// 设计目标：和视频中心页 (video_tutorial_page.dart) 视觉一致 —— 白底圆形
/// 卡片 + 品牌紫 (`AppTheme.brandColor`) 旋转条。
///
/// 背景：原生 [RefreshIndicator] 在当前 Flutter SDK 版本里没有
/// `RefreshIndicatorThemeData` 这一通道，没显式传 `color` 时会回退到
/// `Theme.of(context).colorScheme.primary`。本项目主题色是绿色
/// (`_primaryColor = 0xFF00C9A4`)，因此 dictation / sightSinging /
/// musicTheory / answerQuestions / voice / instrumental 等页面早期直接
/// 用了 `RefreshIndicator(...)`，下拉时 loading 是绿色，与设计稿不符。
///
/// 业务方使用方式与原生 [RefreshIndicator] 完全一致，只是把类名换成
/// [AppRefreshIndicator] —— 默认即品牌紫，无需再单独传 `color` /
/// `backgroundColor`。如需特殊覆盖（例如深色背景需白色 loading），
/// 在调用点显式传 `color: ...` / `backgroundColor: ...` 即可。
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
    this.strokeWidth = RefreshProgressIndicator.defaultStrokeWidth,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.elevation = 2.0,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double displacement;
  final double edgeOffset;
  final ScrollNotificationPredicate notificationPredicate;
  final String? semanticsLabel;
  final String? semanticsValue;
  final double strokeWidth;
  final RefreshIndicatorTriggerMode triggerMode;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? AppTheme.brandColor,
      backgroundColor: backgroundColor ?? Colors.white,
      displacement: displacement,
      edgeOffset: edgeOffset,
      notificationPredicate: notificationPredicate,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      strokeWidth: strokeWidth,
      triggerMode: triggerMode,
      elevation: elevation,
      child: child,
    );
  }
}
