/// `PushNotificationService` 的 iOS / Android 实现：基于 `getuiflut` 个推
/// SDK（与 1.0 uniPush 同源），把 OS 级远端通知接到 [PushNotificationMessage]
/// 上来。
///
/// 通过 `push_notification_service.dart` 顶部的条件 import 在原生平台
/// （`dart:io` 可用）自动选中。Flutter 桌面（Windows/macOS/Linux）虽然
/// 也走这个文件，但运行时会因 getuiflut 不支持而 fallback 到 no-op，
/// 不会抛异常。
///
/// 需要配套的原生工程配置（见 `android/app/build.gradle` / `Info.plist` /
/// `AppDelegate.swift`）。具体步骤在文末注释里给出，请把 1.0 uniPush
/// 控制台拿到的 GeTui AppID / AppKey / AppSecret 填进去。
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:getuiflut/getuiflut.dart';

import '../storage/app_storage.dart';
import 'push_notification_service.dart';

// =============================================================================
// 个推 SDK 凭证（需要填）
//
// 1.0 工程在 manifest.json 里只能看到 `appid: __UNI__1949195`，这是 DCloud
// uniapp 的 appId；真正的个推 AppID/AppKey/AppSecret 需要去 DCloud UniPush
// 控制台 → "应用配置" → "厂商配置" 拷贝出来，三个值都填到下方常量里。
//
// 如果暂时拿不到，留空也能跑：getuiflut 在 iOS 上会因 startSdk 缺参数静默失败，
// Android 上则需要在 AndroidManifest.xml 的 manifestPlaceholders 里配置
// GETUI_APPID 才能开始上报。
//
// 拿到后请填这里 ↓（**不要**提交到 Git 公共仓库，建议改为从远端 config
// 接口下发）。
// =============================================================================
const String _kGetuiAppId = 'YOUR_GETUI_APP_ID';
const String _kGetuiAppKey = 'YOUR_GETUI_APP_KEY';
const String _kGetuiAppSecret = 'YOUR_GETUI_APP_SECRET';

PushNotificationService createPushNotificationService({
  required AppStorage storage,
}) {
  if (!_isSupportedPlatform()) {
    return _NoopPushNotificationService();
  }
  return _GetuiPushNotificationService(storage: storage);
}

bool _isSupportedPlatform() {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS || Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

class _GetuiPushNotificationService implements PushNotificationService {
  _GetuiPushNotificationService({required AppStorage storage})
    : _storage = storage;

  final AppStorage _storage;
  final StreamController<String> _cidController =
      StreamController<String>.broadcast();
  final StreamController<PushNotificationMessage> _msgController =
      StreamController<PushNotificationMessage>.broadcast();

  String? _clientId;
  bool _initialized = false;

  @override
  String? get clientId => _clientId;

  @override
  Stream<String> get clientIdStream => _cidController.stream;

  @override
  Stream<PushNotificationMessage> get notifications => _msgController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      Getuiflut().addEventHandler(
        // 所有平台：CID 到达回调，立即落盘 + 广播。AuthController 登录成功
        // 后会读 [AppStorage.pushId] 调 `/reportCid`，所以 CID 来得比登录
        // 晚也没关系，下次重新登录或 _reportCidIfNeeded 会兜底重试。
        onReceiveClientId: (String message) async {
          if (message.isEmpty) return;
          _clientId = message;
          await _storage.savePushId(message);
          if (!_cidController.isClosed) {
            _cidController.add(message);
          }
        },
        onReceiveOnlineState: (String online) async {},
        // 透传消息（iOS / Android 都会触发，多用于自定义业务字段）。
        onReceivePayload: (Map<String, dynamic> message) async {
          _emit(message, fromClick: false);
        },
        onSetTagResult: (Map<String, dynamic> message) async {},
        onAliasResult: (Map<String, dynamic> message) async {},
        onQueryTagResult: (Map<String, dynamic> message) async {},
        onRegisterDeviceToken: (String message) async {},
        // Android 通知到达 / 点击。
        onNotificationMessageArrived: (Map<String, dynamic> msg) async {
          _emit(msg, fromClick: false);
        },
        onNotificationMessageClicked: (Map<String, dynamic> msg) async {
          _emit(msg, fromClick: true);
        },
        // iOS 透传消息（应用前台）。
        onTransmitUserMessageReceive: (Map<String, dynamic> msg) async {
          _emit(msg, fromClick: false);
        },
        // iOS 通知点击响应（应用从通知拉起）。
        onReceiveNotificationResponse: (Map<String, dynamic> message) async {
          _emit(message, fromClick: true);
        },
        onAppLinkPayload: (String message) async {},
        onPushModeResult: (Map<String, dynamic> message) async {},
        // iOS 前台展示通知前的回调：在这里返回时 SDK 已决定弹不弹横幅。
        onWillPresentNotification: (Map<String, dynamic> message) async {
          _emit(message, fromClick: false);
        },
        onOpenSettingsForNotification: (Map<String, dynamic> message) async {},
        onGrantAuthorization: (String granted) async {},
        onLiveActivityResult: (Map<String, dynamic> message) async {},
        onRegisterPushToStartTokenResult: (Map<String, dynamic> message) async {
        },
      );

      if (Platform.isIOS) {
        // iOS：必须 startSdk 才会向 APNs 注册并拉到 deviceToken。
        // 注意：startSdk 内部会触发系统申请通知权限弹窗，不要在用户没看到
        // 任何 UI 时立刻调，建议在登录页或首页 initState 之后调。
        //
        // getuiflut 当前版本 startSdk 没有声明 Future 返回，因此不 await，
        // SDK 会在后台异步完成 APNs / GeTui 握手并通过事件回调上报 CID。
        Getuiflut().startSdk(
          appId: _kGetuiAppId,
          appKey: _kGetuiAppKey,
          appSecret: _kGetuiAppSecret,
        );
      } else if (Platform.isAndroid) {
        // Android：appId 由 `android/app/build.gradle` 的 manifestPlaceholders
        // `GETUI_APPID` 注入，这里只需要拉起 SDK。`initGetuiSdk` 当前以
        // getter 形式暴露（且返回 void），按官方 demo 直接访问即可。
        Getuiflut().initGetuiSdk;
      }
    } catch (_) {
      // 凭证缺失或 SDK 初始化失败：保持 no-op，不影响业务流程。
    }
  }

  void _emit(Map<String, dynamic> msg, {required bool fromClick}) {
    if (_msgController.isClosed) return;
    final title = (msg['title'] ?? msg['gtTitle'] ?? '').toString();
    final body = (msg['content'] ??
            msg['payload'] ??
            msg['gtContent'] ??
            msg['body'] ??
            '')
        .toString();
    // 个推透传字段可能在 payload / data 里以 JSON 字符串形式存在；
    // 这里仅做浅层装箱，业务层再二次解析。
    Map<String, dynamic> data;
    final raw = msg['payload'] ?? msg['data'] ?? msg;
    if (raw is Map) {
      data = raw.map((k, v) => MapEntry(k.toString(), v));
    } else {
      data = <String, dynamic>{'raw': raw};
    }
    _msgController.add(
      PushNotificationMessage(
        title: title,
        body: body,
        payload: data,
        fromClick: fromClick,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _cidController.close();
    await _msgController.close();
  }
}

class _NoopPushNotificationService implements PushNotificationService {
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
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {
    await _cidController.close();
    await _msgController.close();
  }
}

// =============================================================================
// 原生工程配置清单（一次性，不会改动 Dart 代码）
//
// ---------- Android ----------
// 1. `android/build.gradle` 在 `allprojects.repositories` 里加：
//      maven { url "https://mvn.getui.com/nexus/content/repositories/releases/" }
// 2. `android/app/build.gradle` 在 `android.defaultConfig` 里加：
//      manifestPlaceholders = [
//        GETUI_APPID: "你的个推 AppID"   // 与 _kGetuiAppId 同一个值
//      ]
//    `dependencies` 里加：
//      implementation 'com.getui:gtsdk:3.3.12.0'
//      implementation 'com.getui:gtc:3.2.18.0'
// 3. `AndroidManifest.xml` 的 <application> 节点内追加（GeTui 自动声明
//    `PushService` / `GTIntentService`，无需手动写组件，只要 manifestPlaceholders
//    把 `GETUI_APPID` 填上即可）。
// 4. 厂商通道（华为 / 小米 / OPPO / vivo / 魅族 / Honor / 谷歌 FCM）：
//    若需 APP 杀死后仍能收推送，按个推官网指引在 `AndroidManifest` 中加各厂商
//    appId/appKey 的 meta-data。1.0 uniPush 配置过的厂商通道，2.0 可以照搬。
//
// ---------- iOS ----------
// 1. Xcode → Runner → Signing & Capabilities → "+ Capability" → 添加：
//      - Push Notifications
//      - Background Modes：勾选 `Remote notifications`
// 2. 把 1.0 在 Apple Developer 上申请的 APNs 证书 / Auth Key 上传到个推控制台
//    （uniPush 用过的同一份即可）。
// 3. `ios/Runner/AppDelegate.swift` 在 `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`
//    保持系统默认实现即可（GetuiflutPlugin 已通过 method-swizzling 截获回调）。
// 4. 若启用 UIScene（iOS 13+ 的 SceneDelegate），需要在 SceneDelegate.swift
//    `scene(_:willConnectTo:options:)` 调用：
//      [GetuiflutPlugin handleSceneWillConnectWithOptions:connectionOptions];
//
// ---------- HarmonyOS / 桌面 / Web ----------
// - 桌面 / Web：本服务自动 fallback 为 no-op，无需配置。
// - HarmonyOS：需要 OpenHarmony 定制版 Flutter 工具链 + module.json5 元数据，
//   参考 getuiflut 官方文档第 2.3 节。
// =============================================================================
