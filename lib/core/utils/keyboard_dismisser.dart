import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'keyboard_dismisser_stub.dart'
    if (dart.library.html) 'keyboard_dismisser_web.dart'
    as platform;

/// 强制收起 iOS / iPadOS 「迷你浮动键盘」、Android 软键盘以及 Web
/// 浏览器键盘的工具方法。
///
/// ## 背景
/// iPadOS 17+ 上系统提供一种紧凑的浮动小键盘（屏幕中下方那块带「完成 /
/// 麦克风 / 空格」的小窗）。Flutter 调用 `FocusNode.unfocus()` 时通常
/// 会顺带触发 `TextInput.hide` 把传统底部键盘收掉，但浮动小键盘**经常
/// 拒绝响应**这一信号——这是 Flutter / WebView / Safari 多端共有的体验
/// bug。表现为：用户点别处或路由跳走后，文本框已经失去焦点，但小键盘
/// 还停在屏幕上挡住内容。
///
/// ## 实现思路
/// 1. **原生平台**：再调一次 `SystemChannels.textInput.invokeMethod
///    ('TextInput.hide')`。这是 idempotent 的，重复调用没有副作用，但
///    部分 iOS 版本上的浮动键盘只接收第二次显式 hide。
/// 2. **Web 平台**：除了 channel 调用外，还需直接 `blur()` 当前
///    `document.activeElement`。Flutter Web 的 `EditableText` 用一个
///    隐藏 `<input>` / `<textarea>` 中转 IME，它失焦才能让 Safari 把
///    iPad 浮动键盘真正收掉。
///
/// ## 调用入口
/// - 应用根 [_TapOutsideToDismissKeyboard]（点空白处）
/// - 全局 [FocusManager] 监听器（焦点离开任意 [EditableText] 时）
/// - 业务代码内手动场景，例如对话框 / Drawer 关闭、`Navigator.pop` 前等
void dismissPlatformKeyboard() {
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  if (kIsWeb) {
    platform.blurActiveElement();
  }
}

/// 给应用根包装的「焦点哨兵」：监听 [FocusManager.primaryFocus] 的变化，
/// 当焦点离开 [EditableText] 后台一帧内强制再次收起键盘。
///
/// 仅监听-不修改焦点。子树内任何已经在用 `FocusScope` / `unfocus` 的位置
/// 都不会被它干扰，只是在「焦点真的从输入框移走」时多按一次系统 hide
/// 按钮，治掉 iPad 浮动小键盘的顽固症。
class GlobalKeyboardFocusSentinel extends StatefulWidget {
  const GlobalKeyboardFocusSentinel({super.key, required this.child});

  final Widget child;

  @override
  State<GlobalKeyboardFocusSentinel> createState() =>
      _GlobalKeyboardFocusSentinelState();
}

class _GlobalKeyboardFocusSentinelState
    extends State<GlobalKeyboardFocusSentinel> {
  bool _previousWasTextInput = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleFocusChanged() {
    final focus = FocusManager.instance.primaryFocus;
    final isTextInput = _isEditableTextFocus(focus);
    if (_previousWasTextInput && !isTextInput) {
      // 焦点刚从一个文本输入框离开。直接同步调用即可：FocusManager 的
      // notifyListeners 已经在 build 帧之外触发，这里再去 hide 一次是
      // 安全的（不会再次进入 build / setState）。
      dismissPlatformKeyboard();
    }
    _previousWasTextInput = isTextInput;
  }

  /// 判断当前 primary focus 是不是一个文本输入控件。
  /// [EditableText] 是 `TextField` / `TextFormField` / `CupertinoTextField`
  /// 共享的底层 widget，所有走 IME 的输入都会经过它。
  bool _isEditableTextFocus(FocusNode? focus) {
    if (focus == null || !focus.hasFocus) {
      return false;
    }
    final ctx = focus.context;
    if (ctx == null) {
      return false;
    }
    if (ctx.widget is EditableText) {
      return true;
    }
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
