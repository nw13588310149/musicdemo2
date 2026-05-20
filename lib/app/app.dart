import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config_repository.dart';
import '../core/network/chat_socket_service.dart';
import '../core/permissions/first_launch_permission_host.dart';
import '../core/providers/app_providers.dart' show appStorageProvider, bindApiUnauthorizedSessionCleanup;
import '../core/push/push_notification_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/keyboard_dismisser.dart';
import '../features/auth/data/auth_repository.dart';
import 'router/app_navigator.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<String>? _cidSubscription;

  @override
  void initState() {
    super.initState();
    bindApiUnauthorizedSessionCleanup(ref);
    // 已经登录过的用户冷启动时，异步刷新一次文件服务器配置；游客 token
    // （如 "youke"）也走相同路径，确保拿到最新的 fileBaseUrl。
    final storage = ref.read(appStorageProvider);
    if (storage.token.isNotEmpty) {
      final repo = ref.read(appConfigRepositoryProvider);
      unawaited(repo.refreshFileBaseUrl());
      // 同步建立全局 WebSocket 长连接：承担 AI 助手 + 系统事件 + 群聊推送。
      // 游客 token（"youke"）也尝试连接，由后端按需放行/拒绝。
      ref.read(chatSocketServiceProvider).connect();
    }
    // GeTui CID 是异步回调拿到的：登录早于 CID 到达 / CID 在运行时
    // 变更（极少见但官方支持）时，下面这个监听负责把最新 CID 上报到
    // `/app/user/reportCid`。AuthController 的 `_reportCidIfNeeded` 只
    // 处理"登录时已经有 CID"的快路径，慢路径靠这里兜底。
    _cidSubscription = ref
        .read(pushNotificationServiceProvider)
        .clientIdStream
        .listen((cid) async {
          if (cid.isEmpty) return;
          final token = ref.read(appStorageProvider).token;
          if (token.isEmpty) return; // 未登录时不上报；登录后会自动重试。
          final authRepo = ref.read(authRepositoryProvider);
          try {
            await authRepo.reportCid(cid);
          } catch (_) {
            // 接口失败不影响业务；下次 CID 到达 / 重新登录会再试一次。
          }
        });
  }

  @override
  void dispose() {
    unawaited(_cidSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(appStorageProvider);
    final initialRoute = storage.token.isEmpty
        ? RoutePaths.login
        : RoutePaths.home;

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: '音乐之路',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      // 本地化：强制 zh-CN，并注入 Material / Cupertino / Widgets 三套
      // LocalizationsDelegates。修复 iPadOS 输入框长按 / Live Text 弹出的
      // 系统编辑菜单（Scan Text、Copy、Paste 等）显示英文的问题。
      // supportedLocales 列了 zh-CN 和 en-US 两条：前者命中后所有 Cupertino
      // 文案走中文；保留 en 是为了在系统语言为英文且用户清掉本地缓存时
      // 仍有兜底，不至于回退到 ARB 缺失的 Locale 报错。
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      // 全局文本行为：
      // 1. 锁定 textScaler = 1.0：禁用 iOS/Android 系统的 "Display & Text Size"
      //    缩放，保证 Web 与平板上同一个 fontSize 渲染出相同的逻辑像素，
      //    避免 iPad 上文字"莫名偏小"。
      // 2. DefaultTextHeightBehavior：让首/末行不再应用 height leading，
      //    与 CSS/Figma 行为一致，解决全局"文字偏下、上下间距偏宽"。
      // 3. [GlobalKeyboardFocusSentinel]：监听 FocusManager，焦点离开
      //    EditableText 时再发一次 `TextInput.hide` + Web 端 blur，治掉
      //    iPadOS 浮动小键盘"输入框失焦后还赖在屏幕上"的顽固 bug。
      // 4. 根级 [_TapOutsideToDismissKeyboard]：点击非可交互空白区域自动
      //    收起软键盘，解决 iPad/iOS 上多行 TextField（Return 键变换行）
      //    + 没有"收起键盘"按钮时无法关闭键盘的问题。
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
          child: DefaultTextHeightBehavior(
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            child: FirstLaunchPermissionHost(
              child: GlobalKeyboardFocusSentinel(
                child: _TapOutsideToDismissKeyboard(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 应用根级"点外面收键盘"包装。
///
/// 实现原理：
/// - 用 [GestureDetector] 监听 `onTap`，配合 `HitTestBehavior.translucent`
///   让自己加入命中测试但不挡住下层；
/// - 子树内的按钮 / TextField 自带 GestureDetector / Listener，会在手势
///   竞技场中胜出，所以正常点按交互不会被打断；
/// - 只有真正"点到没有任何手势消费者的空白区域"时，根级 `onTap` 才会
///   触发，调用 `FocusManager.instance.primaryFocus?.unfocus()` 收起软
///   键盘。
///
/// 用 `unfocus(disposition: UnfocusDisposition.scope)` 而不是默认的
/// `previouslyFocusedChild`，避免焦点回到链路中的某个父 FocusScope 时
/// 部分 TextField 仍维持 IME 连接、键盘不下去。
class _TapOutsideToDismissKeyboard extends StatelessWidget {
  const _TapOutsideToDismissKeyboard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // 不能用 onTapDown：那会立刻触发，干扰按钮的 splash / 按下态。
      // onTap 只在确认是"轻点"且没人抢走手势时才回调。
      onTap: () {
        final focus = FocusManager.instance.primaryFocus;
        if (focus == null || !focus.hasFocus) return;
        focus.unfocus(disposition: UnfocusDisposition.scope);
        // 双保险：iPadOS 浮动小键盘有时不响应 unfocus 触发的 IME hide，
        // 这里再显式调一次平台原生 / 浏览器层的收键盘逻辑。
        dismissPlatformKeyboard();
      },
      child: child,
    );
  }
}
