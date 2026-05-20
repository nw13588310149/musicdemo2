/// `PushNotificationService` 在不支持的平台（Flutter Web / 桌面）上的兜底
/// 实现 —— 全部方法 no-op，初始化即返回，clientIdStream 永远不发事件。
///
/// 通过 `push_notification_service.dart` 顶部的条件 import 在 web 环境
/// （没有 `dart:io`）自动被选中。
library;

import 'dart:async';

import '../storage/app_storage.dart';
import 'push_notification_service.dart';

PushNotificationService createPushNotificationService({
  required AppStorage storage,
}) {
  return _StubPushNotificationService();
}

class _StubPushNotificationService implements PushNotificationService {
  final StreamController<String> _cidController =
      StreamController<String>.broadcast();
  final StreamController<PushNotificationMessage> _msgController =
      StreamController<PushNotificationMessage>.broadcast();

  @override
  String? get clientId => null;

  @override
  Stream<String> get clientIdStream => _cidController.stream;

  @override
  Stream<PushNotificationMessage> get notifications => _msgController.stream;

  @override
  Future<void> initialize() async {
    // Web / 桌面：不接入 GeTui，让 ChatSocketService 单挑系统消息即可。
  }

  @override
  Future<void> dispose() async {
    await _cidController.close();
    await _msgController.close();
  }
}
