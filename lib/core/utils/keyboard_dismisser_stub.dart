/// 非 Web 平台占位实现：原生 iOS / Android 在 `dismissPlatformKeyboard`
/// 里走 `SystemChannels.textInput.invokeMethod('TextInput.hide')` 已经够
/// 用，不需要额外的 DOM 失焦动作，所以这里是空 no-op。
void blurActiveElement() {}
