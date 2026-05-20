import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

/// 首次安装 / 冷启动时批量申请的原生权限清单与请求逻辑。
///
/// iOS 会在用户授权前读取 [Info.plist] 中的 UsageDescription；
/// Android 需在 [AndroidManifest.xml] 声明并在运行时申请（API 33+ 媒体权限拆分）。
class AppPermissionService {
  const AppPermissionService();

  /// 当前应用依赖的系统权限（Web 为空）。
  static List<Permission> get essentialPermissions {
    if (kIsWeb) return const [];
    if (Platform.isIOS) {
      return const [
        Permission.microphone,
        Permission.camera,
        Permission.photos,
        Permission.notification,
      ];
    }
    if (Platform.isAndroid) {
      return const [
        Permission.microphone,
        Permission.camera,
        Permission.photos,
        Permission.audio,
        Permission.videos,
        Permission.notification,
        Permission.storage,
      ];
    }
    return const [];
  }

  /// 逐项请求尚未授予的权限。已永久拒绝的项跳过（用户可在系统设置中开启）。
  Future<void> requestEssentialPermissions() async {
    for (final permission in essentialPermissions) {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) continue;
      if (status.isPermanentlyDenied) continue;
      await permission.request();
      // iOS 连续弹多个系统授权框时略作间隔，避免第二个弹窗被吞掉。
      if (Platform.isIOS) {
        await Future<void>.delayed(const Duration(milliseconds: 320));
      }
    }
  }

  /// 打开系统「应用设置」页（用户此前点了「不允许」后的兜底入口）。
  Future<bool> openSystemSettings() => openAppSettings();
}
