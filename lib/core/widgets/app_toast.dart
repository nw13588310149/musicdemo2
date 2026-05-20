import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

enum AppToastType { success, error }

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// 全局轻提示。
  ///
  /// `type` 不传时根据 [message] 文本自动判定成功 / 失败：
  /// - 含「失败 / 错误 / 无效 / 失效 / 无法 / 不支持 / 尚未 / 不可用」→ 失败
  /// - 含「成功 / 完成」→ 成功
  /// - 含「已...」状态确认（已发布 / 已删除 / 已通过 等）→ 成功
  /// - 其余（请..、暂无.. 等）兜底为失败样式
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
    AppToastType? type,
  }) {
    final text = message.trim();
    if (text.isEmpty) {
      return;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    final size = MediaQuery.maybeSizeOf(context) ?? const Size(1440, 900);
    final scale = math.min(size.width / 1440, size.height / 900);
    double ui(num value) => value * (scale.isFinite && scale > 0 ? scale : 1);

    final resolved = type ?? _autoDetectType(text);

    _timer?.cancel();
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: ui(72),
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, ui(10) * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: _buildBody(text, resolved, ui),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    _timer = Timer(duration, () {
      _entry?.remove();
      _entry = null;
    });
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    show(context, message, duration: duration, type: AppToastType.success);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    show(context, message, duration: duration, type: AppToastType.error);
  }

  static AppToastType _autoDetectType(String text) {
    const errorKeywords = <String>[
      '失败',
      '错误',
      '无效',
      '失效',
      '无法',
      '不支持',
      '尚未',
      '不可用',
      '重试',
      '再试',
    ];
    for (final kw in errorKeywords) {
      if (text.contains(kw)) return AppToastType.error;
    }
    if (text.contains('成功') || text.contains('完成')) {
      return AppToastType.success;
    }
    if (text.contains('已')) return AppToastType.success;
    return AppToastType.error;
  }

  static Widget _buildBody(
    String text,
    AppToastType type,
    double Function(num) ui,
  ) {
    final isSuccess = type == AppToastType.success;
    final bgAsset = isSuccess
        ? 'assets/images/home/successBG.png'
        : 'assets/images/home/errorBG.png';
    final iconAsset = isSuccess
        ? 'assets/images/home/success.png'
        : 'assets/images/home/error.png';

    return Container(
      width: ui(340),
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        image: DecorationImage(
          image: AssetImage(bgAsset),
          fit: BoxFit.fill,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            iconAsset,
            width: ui(24),
            height: ui(24),
            fit: BoxFit.contain,
          ),
          SizedBox(width: ui(8)),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
