import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

abstract final class ShellLayoutSpec {
  static const designWidth = 1024.0;
  static const designHeight = 768.0;
  static const legacyWidth = 1180.0;
  static const sidebarWidth = 178.0;
  static const collapsedSidebarWidth = 56.0;
  static const navRailWidth = 146.0;
  static const contentWidth = 970.0;
  static const shellGap = 16.0;
  static const topInset = 16.0;
  static const topBarHeight = 40.0;
  static const pageGap = 16.0;
  static const bottomInset = 0.0;
  static const floatingRight = 16.0;
  static const floatingBottom = 18.0;
  static const floatingExpandedBottom = 160.0;
  static const panelRadius = 16.0;
  static const smallRadius = 12.0;
}

class DashboardScaleData {
  const DashboardScaleData({
    required this.viewportScale,
    required this.availableSize,
  });

  final double viewportScale;
  final Size availableSize;

  // 缩放策略已关闭：UI 尺寸直接按当前设计值渲染，由各页面自行适配。
  double ui(num legacyPx) => legacyPx.toDouble();

  EdgeInsets insets(num left, num top, [num? right, num? bottom]) {
    return EdgeInsets.fromLTRB(
      ui(left),
      ui(top),
      ui(right ?? left),
      ui(bottom ?? top),
    );
  }

  BorderRadius radius(num legacyPx) => BorderRadius.circular(ui(legacyPx));
}

class DashboardScaleScope extends InheritedWidget {
  const DashboardScaleScope({
    required this.data,
    required super.child,
    super.key,
  });

  final DashboardScaleData data;

  static DashboardScaleData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DashboardScaleScope>();
    assert(scope != null, 'DashboardScaleScope not found in widget tree.');
    return scope!.data;
  }

  static DashboardScaleData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DashboardScaleScope>()
        ?.data;
  }

  static DashboardScaleData fromSize(Size size) {
    final viewportScale = math.min(
      size.width / ShellLayoutSpec.designWidth,
      size.height / ShellLayoutSpec.designHeight,
    );
    return DashboardScaleData(
      viewportScale: viewportScale.isFinite && viewportScale > 0
          ? viewportScale
          : 1,
      availableSize: size,
    );
  }

  @override
  bool updateShouldNotify(DashboardScaleScope oldWidget) {
    return oldWidget.data.viewportScale != data.viewportScale ||
        oldWidget.data.availableSize != data.availableSize;
  }
}

class ShellDesignCanvas extends StatelessWidget {
  const ShellDesignCanvas({
    required this.child,
    this.backgroundColor = const Color(0xFFEFF3FC),
    super.key,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: ShellLayoutSpec.designWidth,
          height: ShellLayoutSpec.designHeight,
          child: ColoredBox(color: backgroundColor, child: child),
        ),
      ),
    );
  }
}

class ShellPageSurface extends StatelessWidget {
  const ShellPageSurface({
    required this.child,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.color = Colors.white,
    this.gradient,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.alignment,
    super.key,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        border: border,
        borderRadius:
            borderRadius ??
            BorderRadius.circular(scale.ui(ShellLayoutSpec.panelRadius)),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}

class ShellSectionTitleBar extends StatelessWidget {
  const ShellSectionTitleBar({
    required this.title,
    required this.onMoreTap,
    this.width = double.infinity,
    this.moreLabel = '\u66f4\u591a',
    super.key,
  });

  final String title;
  final VoidCallback onMoreTap;
  final double width;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return SizedBox(
      width: width,
      height: ui(30),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(20),
                color: Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          GestureDetector(
            onTap: onMoreTap,
            child: Container(
              width: ui(58),
              height: ui(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  ui(ShellLayoutSpec.smallRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    moreLabel,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: Color(0xFF788698),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: ui(2)),
                  AppAssetGraphic(
                    AppAssets.shellV2MoreArrow,
                    width: ui(10),
                    height: ui(10),
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
