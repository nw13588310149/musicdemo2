import '../constants/app_constants.dart';

/// 全局文件 URL 解析器。
///
/// 后端文件接口（`/app/common/v2/fileUpload`）返回的是相对路径，例如：
/// `app/upload/1788178798952914945/2026-05-01/2050084458168000513.png`。
/// 实际加载这些文件需要拼上一个独立的「文件服务器域名」，该域名通过
/// `/app/common/v2/configList` 接口在登录后获取，并写入 [AppStorage] 与
/// [MediaUrl.fileBaseUrl]。
///
/// - 在 `main()` 启动时，从持久化存储读取上次的 fileBaseUrl 注入此处；
/// - 登录 / 注册 / 游客登录成功后，AuthController 会调用 configList，命中
///   后再次调用 [setFileBaseUrl] 更新；
/// - 所有需要把"相对文件 path"变成"完整 URL"的位置（图片、音频、HTTP
///   预览…）都应使用 [resolve]，而不是直接拼 `AppConstants.apiBaseUrl`。
class MediaUrl {
  MediaUrl._();

  static String _fileBaseUrl = '';

  /// 当前生效的文件服务器域名；为空时回退到 [AppConstants.apiBaseUrl]。
  static String get fileBaseUrl =>
      _fileBaseUrl.isNotEmpty ? _fileBaseUrl : AppConstants.apiBaseUrl;

  /// 是否已经收到过 configList 的回包（用于调试/避免重复刷新等）。
  static bool get hasFileBaseUrl => _fileBaseUrl.isNotEmpty;

  /// 同步设置文件服务器域名（来自 `configList` 或 `AppStorage`）。空字符串
  /// 会清空覆盖，回退到 `apiBaseUrl`。
  static void setFileBaseUrl(String url) {
    _fileBaseUrl = url.trim();
  }

  /// 把后端返回的相对路径补齐为完整 URL：
  /// - 已经是 `http(s)://` 直接原样返回；
  /// - `//host/...` 视为 `https://host/...`；
  /// - 其它（包括 `app/upload/...`、`/app/upload/...`）拼到 [fileBaseUrl] 上。
  static String resolve(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    final normalized = value.startsWith('/') ? value : '/$value';
    return '${fileBaseUrl.replaceFirst(RegExp(r'/$'), '')}$normalized';
  }
}
