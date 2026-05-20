import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/network/media_url.dart';
import 'core/providers/app_providers.dart';
import 'core/push/push_notification_service.dart';
import 'core/storage/app_storage.dart';
import 'features/music_companion/audio/music_companion_audio_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 80 << 20;
  MediaKit.ensureInitialized();
  // 后台预热 SoLoud 钢琴池，避免首次进入音乐伴侣时 iOS 在手势链里 await 加载失败。
  unawaited(warmupMusicCompanionPianoAudio());
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // 与 iOS Info.plist / Android sensorLandscape 一致；请勿在其他页面恢复 portrait。
  // 沉浸式：隐藏系统状态栏和导航栏。
  // - Android：immersiveSticky 模式下用户从屏幕边缘下拉时系统栏会临时显示，几秒后自动隐藏。
  // - iOS：状态栏由 Info.plist + RootFlutterViewController 控制；这里调用是无副作用的兜底。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final storage = await AppStorage.create();
  final cid = Uri.base.queryParameters['cid'];
  if (cid != null && cid.isNotEmpty) {
    await storage.savePushId(cid);
  }
  // 启动时立即把上次缓存的「文件服务器域名」注入 MediaUrl，让首屏就能正常
  // 解析图片/音频路径，登录后再通过 configList 异步刷新。
  final cachedFileBase = storage.fileBaseUrl;
  if (cachedFileBase.isNotEmpty) {
    MediaUrl.setFileBaseUrl(cachedFileBase);
  }

  // 创建一个根容器：既用来把 storage 注入 [appStorageProvider]，又能在
  // [runApp] 之前预读 [pushNotificationServiceProvider] 把 GeTui SDK 的初始化
  // 跑起来。原生平台异步申请通知权限 / 注册 deviceToken 期间不会阻塞 UI，
  // Web 上则走 stub no-op 直接返回。
  final container = ProviderContainer(
    overrides: [appStorageProvider.overrideWithValue(storage)],
  );
  unawaited(container.read(pushNotificationServiceProvider).initialize());

  runApp(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
}
