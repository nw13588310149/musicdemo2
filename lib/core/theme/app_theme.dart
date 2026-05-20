import 'package:flutter/material.dart';

import 'app_font.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF00C9A4);

  /// 业务视觉主题色（紫）。与设计稿一致，用于所有需要"主题色"的非 Material
  /// 控件（计时器、播放器、按钮等已分别硬编码同值）。这里作为公共常量统一
  /// 来源，方便后续整体调色。
  static const Color brandColor = Color(0xFF8741FF);

  // 全局默认字族回退链：iOS 上 Skia/Impeller 直接绘制 Apple 系统 "PingFang SC"
  // 时字面率偏细（CoreText 内置了视觉补偿，Flutter 没有），所以这里强制把
  // pubspec 中自带的 PingFang SC OTF 排在第一位 fallback——当主字族 Harmony
  // 没有相应字形（或上层显式指定了一个不存在的字族）时，先命中我们打包进来
  // 的 OTF 文件，避免落到系统 PingFang 上看起来"飘"。
  static const List<String> _fontFamilyFallback = <String>[
    'PingFang SC',
  ];

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Harmony',
      fontFamilyFallback: _fontFamilyFallback,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        primary: _primaryColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF171A20),
        centerTitle: true,
        // 字重过 [AppFont.weight] 走一遍：iOS 上自动 +1 档抵消 Skia/Impeller
        // 渲染中文偏细的视觉差。
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: AppFont.w500,
          color: const Color(0xFF171A20),
        ),
      ),
      // 全局 loading 着色：所有未显式指定 color 的 CircularProgressIndicator /
      // LinearProgressIndicator 均使用品牌紫 brandColor。
      // 注：依然允许业务方在调用点用 `valueColor: AlwaysStoppedAnimation(...)`
      // 或 `color: ...` 单独覆盖（例如夜色背景下的白色 loading）。
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandColor,
        circularTrackColor: Color(0x1A8741FF),
        linearTrackColor: Color(0x1A8741FF),
      ),
      // RefreshIndicator 在当前 Flutter SDK 上没有 RefreshIndicatorThemeData
      // 这一通道（直接读 ColorScheme.primary / canvasColor），因此「下拉刷新
      // 统一品牌紫」改用 `AppRefreshIndicator` 包装组件实现，业务页面直接用
      // 它即可，不再依赖 ThemeData。详见 lib/core/widgets/app_refresh_indicator.dart。
      // 全局输入框光标 / 文本选区配色：所有未显式指定 cursorColor 的
      // TextField / TextFormField 都会走品牌紫；选区色与选区把手保持同色系。
      // 备注：cursorHeight 不在 ThemeData 暴露，需要在调用点单独设置。
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: brandColor,
        selectionColor: brandColor.withValues(alpha: 0.22),
        selectionHandleColor: brandColor,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(45)),
          backgroundColor: const WidgetStatePropertyAll(_primaryColor),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );

    // 让 Theme.of(context).textTheme 走一次字重补偿。注意：业务里直接
    // `TextStyle(...)` 创建的样式不会被这里覆盖，需要在调用点把
    // `FontWeight.wXXX` 改成 `AppFont.wXXX`。
    return base.copyWith(
      textTheme: bumpTextThemeWeights(base.textTheme),
      primaryTextTheme: bumpTextThemeWeights(base.primaryTextTheme),
    );
  }
}
