import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 字重补偿（CJK 专用）。
///
/// iOS 上 Skia/Impeller 直接绘制 PingFang / HarmonyOS Sans 等中文字体时，
/// 缺少 Apple CoreText 的 stem-darkening / 灰度补偿，相同字重的轮廓比原生
/// UIKit 看起来轻一档。通过把 [FontWeight] 在 iOS 上整体上浮一档
/// （w400 → w500、w500 → w600 …）把视觉权重对回设计稿。
///
/// ## 使用范围
/// - 中文为主的文本（PingFang SC / Harmony）：用 [AppFont.w400] 等常量
///   替代 [FontWeight.w400]，例如：
///
///   ```dart
///   TextStyle(fontFamily: 'PingFang SC', fontWeight: AppFont.w400)
///   ```
///
/// - 纯西文字族（Manrope / Barlow / Inter / Roboto）：继续直接用原生
///   [FontWeight]，否则会被错误加粗。
///
/// ## 边界
/// - 已经是 [FontWeight.w900] 时不再上浮。
/// - 项目仅打包 PingFang SC 的 w100 ~ w600 OTF，调用点不要写 w700+，
///   否则即便补偿后也无对应字面，会回退到系统字体。
class AppFont {
  AppFont._();

  /// 当前设备是否需要做 CJK 字重补偿。
  ///
  /// 用 [defaultTargetPlatform] 判断而不是 `dart:io` 的 `Platform.isIOS`，
  /// 这样 Flutter Web 在 iOS Safari/CanvasKit 下也会被识别为 iOS（同样
  /// 缺少 CoreText 灰度补偿，需要补偿）。
  static bool get needsBump =>
      defaultTargetPlatform == TargetPlatform.iOS;

  /// 返回平台对齐后的字重。已是 [FontWeight.w900] 时原样返回。
  static FontWeight weight(FontWeight w) {
    if (!needsBump) return w;
    final i = FontWeight.values.indexOf(w);
    if (i < 0 || i >= FontWeight.values.length - 1) return w;
    return FontWeight.values[i + 1];
  }

  /// CJK 调用点常用字重别名。
  static FontWeight get w300 => weight(FontWeight.w300);
  static FontWeight get w400 => weight(FontWeight.w400);
  static FontWeight get w500 => weight(FontWeight.w500);
  static FontWeight get w600 => weight(FontWeight.w600);
}

/// 把 [TextTheme] 中所有已设定 `fontWeight` 的字段统一上浮一档。
///
/// 仅影响走 `Theme.of(context).textTheme.xxx` 的文字。业务代码里直接
/// `TextStyle(...)` 的位置不受影响，需要在调用点替换 [FontWeight] 常量
/// 为 [AppFont] 提供的版本。
TextTheme bumpTextThemeWeights(TextTheme src) {
  TextStyle? bump(TextStyle? s) {
    final w = s?.fontWeight;
    if (s == null || w == null) return s;
    return s.copyWith(fontWeight: AppFont.weight(w));
  }

  return src.copyWith(
    displayLarge: bump(src.displayLarge),
    displayMedium: bump(src.displayMedium),
    displaySmall: bump(src.displaySmall),
    headlineLarge: bump(src.headlineLarge),
    headlineMedium: bump(src.headlineMedium),
    headlineSmall: bump(src.headlineSmall),
    titleLarge: bump(src.titleLarge),
    titleMedium: bump(src.titleMedium),
    titleSmall: bump(src.titleSmall),
    bodyLarge: bump(src.bodyLarge),
    bodyMedium: bump(src.bodyMedium),
    bodySmall: bump(src.bodySmall),
    labelLarge: bump(src.labelLarge),
    labelMedium: bump(src.labelMedium),
    labelSmall: bump(src.labelSmall),
  );
}
