import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuthDesignCanvas extends StatelessWidget {
  const AuthDesignCanvas({
    required this.builder,
    this.backgroundColor = const Color(0xFFF2ECFF),
    super.key,
  });

  static const Size designSize = Size(1180, 820);

  final Widget Function(double scale) builder;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // 注意：登录 / 注册 / 忘记密码 这三个页面共用本 Canvas，并且页面里
    // 都包含 TextField。当 Scaffold 默认 `resizeToAvoidBottomInset: true`
    // 时，键盘弹出会压缩 body 高度，导致下面 LayoutBuilder 拿到的
    // `constraints.maxHeight` 缩水 → `scale` 变小 → 整张设计稿被等比
    // 缩小（背景图随之缩放）。
    //
    // 修复：把 `viewInsets.bottom`（键盘高度）加回去再算 scale，
    // 让缩放系数始终按"键盘未弹起时"的可用高度计算。即使外层 Scaffold
    // 没有显式设 `resizeToAvoidBottomInset: false`，这里也能兜住。
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullHeight = constraints.maxHeight + keyboardInset;
          final scale = math.min(
            constraints.maxWidth / designSize.width,
            fullHeight / designSize.height,
          );

          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: designSize.width * scale,
              height: designSize.height * scale,
              child: RepaintBoundary(child: builder(scale)),
            ),
          );
        },
      ),
    );
  }
}
