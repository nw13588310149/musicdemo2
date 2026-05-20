/// 题目富文本相关的纯函数工具：
///
/// - [stripHtmlToText]：去掉所有标签 / 解码 HTML 实体，得到纯文本
///   兜底（用于 `Text` 渲染、判空、HtmlWidget 失败时回退）。
/// - [htmlHasMedia] / [htmlHasInlineRich]：判断 HTML 是否含图片 /
///   上下标 / 加粗等结构，用于决定渲染管线（直接 `Text` 还是
///   `HtmlWidget`）。
///
/// 抽到独立文件、做成"在数据进入 Riverpod state 时算一次"的策略，
/// 是为了：
/// 1. 避免每次 build / 每次切题在 UI 层重复 strip / decode；
/// 2. 让 strip 后的字符串变成 `QuizQuestion` 的不可变属性，跨题
///    切换时不会有"上一题 strip 结果还没来得及更新"的中间态。
library;

const Map<String, String> _namedEntities = <String, String>{
  'nbsp': '\u00A0',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'ldquo': '\u201C', // “
  'rdquo': '\u201D', // ”
  'lsquo': '\u2018', // ‘
  'rsquo': '\u2019', // ’
  'sbquo': '\u201A',
  'bdquo': '\u201E',
  'laquo': '\u00AB', // «
  'raquo': '\u00BB', // »
  'hellip': '\u2026', // …
  'mdash': '\u2014', // —
  'ndash': '\u2013', // –
  'middot': '\u00B7', // ·
  'bull': '\u2022', // •
  'times': '\u00D7', // ×
  'divide': '\u00F7', // ÷
  'plusmn': '\u00B1', // ±
  'deg': '\u00B0', // °
  'micro': '\u00B5', // µ
  'permil': '\u2030', // ‰
  'copy': '\u00A9', // ©
  'reg': '\u00AE', // ®
  'trade': '\u2122', // ™
  'sect': '\u00A7', // §
  'para': '\u00B6', // ¶
  'iquest': '\u00BF',
  'iexcl': '\u00A1',
  'larr': '\u2190',
  'rarr': '\u2192',
  'uarr': '\u2191',
  'darr': '\u2193',
  'harr': '\u2194',
  'sup2': '\u00B2',
  'sup3': '\u00B3',
  'frac12': '\u00BD',
  'frac14': '\u00BC',
  'frac34': '\u00BE',
};

final RegExp _entityRegExp = RegExp(
  r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z][a-zA-Z0-9]+);',
);
final RegExp _brRegExp = RegExp(r'<br\s*/?>', caseSensitive: false);
final RegExp _blockEndRegExp = RegExp(
  r'</(p|div|li|tr|h[1-6])>',
  caseSensitive: false,
);
final RegExp _tagRegExp = RegExp(r'<[^>]+>');

/// 含媒体（图片 / 表格 / 视频 / 音频 / iframe / svg）。
/// 触发后必须走 HtmlWidget，否则就丢内容。
final RegExp _mediaRegExp = RegExp(
  r'<(img|svg|video|audio|iframe|table)\b',
  caseSensitive: false,
);

/// 含 inline 富文本（上下标 / 加粗 / 斜体 / 下划线 / 删除线 /
/// 行内代码 / 强制换行）。触发后走 HtmlWidget 才能保留视觉。
final RegExp _inlineRichRegExp = RegExp(
  r'<(sup|sub|strong|b|em|i|u|s|del|mark|code|br)\b',
  caseSensitive: false,
);

/// 把后端富文本 HTML 抠成纯文本，已包含：
/// - `<br>` / `</p>` / `</div>` 等块级结束标签 → `\n`；
/// - 其余标签全部剥掉；
/// - HTML 实体（`&ldquo;` `&hellip;` 以及数字实体 `&#xABCD;`）解码。
String stripHtmlToText(String html) {
  if (html.isEmpty) return '';
  final stripped = html
      .replaceAll(_brRegExp, '\n')
      .replaceAll(_blockEndRegExp, '\n')
      .replaceAll(_tagRegExp, '');
  return decodeHtmlEntities(stripped).trim();
}

bool htmlHasMedia(String html) {
  if (html.isEmpty) return false;
  return _mediaRegExp.hasMatch(html);
}

bool htmlHasInlineRich(String html) {
  if (html.isEmpty) return false;
  return _inlineRichRegExp.hasMatch(html);
}

/// 解码 HTML 实体（命名 + 数字），不会动任何标签结构。供 inline
/// span 解析等需要"保留 tag、只解码实体"的场景使用。
String decodeHtmlEntities(String input) {
  if (input.isEmpty || !input.contains('&')) return input;
  return input.replaceAllMapped(_entityRegExp, (m) {
    final body = m.group(1)!;
    if (body.startsWith('#x') || body.startsWith('#X')) {
      final cp = int.tryParse(body.substring(2), radix: 16);
      if (cp != null && cp >= 0 && cp <= 0x10FFFF) {
        return String.fromCharCode(cp);
      }
    } else if (body.startsWith('#')) {
      final cp = int.tryParse(body.substring(1));
      if (cp != null && cp >= 0 && cp <= 0x10FFFF) {
        return String.fromCharCode(cp);
      }
    } else {
      final v = _namedEntities[body];
      if (v != null) return v;
    }
    return m.group(0)!;
  });
}
