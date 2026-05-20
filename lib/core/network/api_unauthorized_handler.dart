import 'package:flutter/material.dart';

import '../../app/router/app_navigator.dart';
import '../../app/router/route_paths.dart';
import '../storage/app_storage.dart';
import '../widgets/app_toast.dart';

/// 业务 `code == 401` 或 HTTP 401：未登录 / 登录失效的全局处理。
///
/// 同一时刻多个接口并发返回 401 时，只提示一次「账号未登录」并只跳转一次登录页。
class ApiUnauthorizedHandler {
  ApiUnauthorizedHandler._();

  static final ApiUnauthorizedHandler instance = ApiUnauthorizedHandler._();

  static const String defaultMessage = '账号未登录';

  VoidCallback? _onSessionCleared;
  bool _handling = false;

  void bindSessionCleared(VoidCallback? callback) {
    _onSessionCleared = callback;
  }

  /// 登录成功后调用，允许后续再次触发 401 处理。
  void reset() {
    _handling = false;
  }

  Future<void> handle({
    required AppStorage storage,
    String? message,
  }) async {
    if (_handling) {
      return;
    }
    _handling = true;

    try {
      await storage.clearToken();
      await storage.clearSchoolId();
      await storage.clearMobile();
      _onSessionCleared?.call();

      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }

      final routeName = ModalRoute.of(context)?.settings.name;
      final onAuthPage = routeName == RoutePaths.login ||
          routeName == RoutePaths.register ||
          routeName == RoutePaths.forget;

      if (!onAuthPage) {
        AppToast.show(
          context,
          (message == null || message.trim().isEmpty)
              ? defaultMessage
              : message.trim(),
          type: AppToastType.error,
        );
        Navigator.of(context).pushNamedAndRemoveUntil(
          RoutePaths.login,
          (route) => false,
        );
      }
    } finally {
      // 吞掉同一轮并发 401；登录成功后会 [reset]。
      Future<void>.delayed(const Duration(seconds: 2), () {
        _handling = false;
      });
    }
  }
}
