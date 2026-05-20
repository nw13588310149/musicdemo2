/// 推送通知服务（移动端 OS 级消息弹窗）。
///
/// 1.0 通过 uniPush（DCloud 包装的个推 GeTui v2）做 iOS / 安卓应用级推送，
/// 把 CID（个推 clientId）上报到 `/app/user/reportCid`，后端推送时按 CID
/// 找设备。2.0 在 Flutter 端复用同一套个推后端配置：
///
///   - 移动端：`getuiflut` 插件（getui.com 官方维护）
///   - Web / 桌面：no-op 兜底（浏览器 Notification API 与 OS 系统通知差异
///     较大，这里不做模拟；如需 web 内通知请走业务层 toast）
///
/// 与 1.0 保持一致的行为：
///   - 收到 `onReceiveClientId` 回调后把 CID 写入 [AppStorage.savePushId]，
///     Auth 流程会通过 `/app/user/reportCid` 接口上报；
///   - `onNotificationMessageArrived` / `onNotificationMessageClicked` /
///     `onReceivePayload` 收到的远端通知统一封装成 [PushNotificationMessage]
///     并通过 [notifications] 流广播，业务层（路由跳转、徽章清零等）订阅。
///
/// 注意：本服务在应用根 [ProviderScope] 生命周期内活着。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'push_notification_service_stub.dart'
    if (dart.library.io) 'push_notification_service_io.dart';

/// 一条推送通知（送达 / 点击）。
class PushNotificationMessage {
  const PushNotificationMessage({
    required this.title,
    required this.body,
    required this.payload,
    required this.fromClick,
  });

  /// 通知标题（远端可空）。
  final String title;

  /// 通知正文。
  final String body;

  /// 透传数据：服务端在推送时通过个推 transmission / payload 下发的 JSON。
  /// 通常包含 `type` / `bizId` / `classId` 等业务字段，用于点击后路由。
  final Map<String, dynamic> payload;

  /// `true` 表示这是用户点击通知触发的（点击进 App 的场景）；
  /// `false` 表示前台到达（仅做角标 / Toast，不做路由跳转）。
  final bool fromClick;
}

/// 公共接口；具体实现按平台条件加载。
abstract class PushNotificationService {
  /// 拉起底层 SDK（注册 deviceToken、申请通知权限、设置事件回调）。
  /// 同步幂等：重复调用直接返回。
  Future<void> initialize();

  /// 当前 CID（即个推 clientId / pushId）。初始化完成或下次回调到达后才会非空。
  String? get clientId;

  /// CID 变更广播。AuthController 登录成功后用它做 `/reportCid` 兜底重试。
  Stream<String> get clientIdStream;

  /// 远端通知（送达 / 点击）广播。
  Stream<PushNotificationMessage> get notifications;

  /// 释放底层资源（一般跟随 Provider 生命周期）。
  Future<void> dispose();
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final storage = ref.watch(appStorageProvider);
  final service = createPushNotificationService(storage: storage);
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
