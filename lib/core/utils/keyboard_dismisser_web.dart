import 'package:web/web.dart' as web;

/// Web 端：把 `document.activeElement` 主动 blur 掉。
///
/// Flutter Web 在 iPad Safari 上用一个隐藏 `<input>` / `<textarea>`
/// 中转 IME，光靠 `FocusNode.unfocus()` 触发的 `TextInput.hide` 经常
/// 收不掉系统的浮动小键盘。直接 blur active element 等价于浏览器
/// 自身的「点击空白让 input 失焦」，这一步 Safari 才会真的把键盘收回。
void blurActiveElement() {
  final el = web.document.activeElement;
  if (el == null) {
    return;
  }
  // 浏览器里 `document.activeElement` 只可能是支持 focus 的元素
  // （input / textarea / contenteditable / button / 带 tabindex 的
  //  元素…），全部都继承自 HTMLElement，所以这里直接 cast 是安全的；
  // 没有 `.blur()` 方法的元素根本不会出现在 activeElement 上。
  (el as web.HTMLElement).blur();
}
