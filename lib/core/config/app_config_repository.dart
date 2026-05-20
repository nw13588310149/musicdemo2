import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/media_url.dart';
import '../providers/app_providers.dart';
import '../storage/app_storage.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(appStorageProvider);
  return AppConfigRepository(client: client, storage: storage);
});

/// 负责拉取后端「全局配置」并把其中的「文件服务器域名」同步到
/// [MediaUrl] 与 [AppStorage]。
///
/// 接口：`POST /app/common/v2/configList`
///
/// 实际响应（已确认）：
/// ```json
/// {
///   "code": 0,
///   "msg": "ok",
///   "data": { "fileServerUrl": "https://img.yyzl0931.com/" }
/// }
/// ```
class AppConfigRepository {
  AppConfigRepository({required this.client, required AppStorage storage})
    : _storage = storage;

  final ApiClient client;
  final AppStorage _storage;

  /// 主要 key（与后端确认）以及若干兜底别名，按优先级查找。
  static const _fileBaseUrlKeys = <String>[
    'fileServerUrl',
    'fileServer',
    'fileUrl',
    'fileDomain',
    'fileBaseUrl',
    'fileHost',
  ];

  /// 调用 configList 接口，把文件服务器域名写入 storage / MediaUrl。
  ///
  /// 返回拿到的域名（成功）或空字符串（失败/无法解析）。
  Future<String> refreshFileBaseUrl() async {
    final response = await client.post(
      '/app/common/v2/configList',
      data: const <String, dynamic>{},
    );
    if (!response.isSuccess) {
      if (kDebugMode) {
        debugPrint('[AppConfig] configList failed: ${response.msg}');
      }
      return '';
    }

    final base = _extractFileBaseUrl(response.data);
    if (base.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[AppConfig] configList ok but no fileServerUrl '
          'recognised in: ${response.data}',
        );
      }
      return '';
    }

    await _storage.saveFileBaseUrl(base);
    MediaUrl.setFileBaseUrl(base);
    if (kDebugMode) {
      debugPrint('[AppConfig] file base url => $base');
    }
    return base;
  }

  /// 启动时从持久化里恢复上次的 fileBaseUrl。
  void hydrateFromStorage() {
    final cached = _storage.fileBaseUrl;
    if (cached.isNotEmpty) {
      MediaUrl.setFileBaseUrl(cached);
    }
  }

  /// 从 configList 的 `data` 字段中抽出文件服务器域名。
  ///
  /// 主格式：`data` 直接是 Map，含 `fileServerUrl` 字段。
  /// 兼容：`data` 为 List<Map>，每项可能形如 `{ key: 'fileServerUrl', value: '...' }`
  /// 或本身就含 `fileServerUrl` 字段。
  String _extractFileBaseUrl(dynamic data) {
    if (data is Map) {
      // 1) 直接 data.fileServerUrl
      for (final key in _fileBaseUrlKeys) {
        final raw = data[key]?.toString();
        if (raw != null && raw.trim().isNotEmpty) {
          return _normaliseUrl(raw);
        }
      }
      // 2) {key: 'fileServerUrl', value: '...'}
      final keyField = data['key']?.toString();
      if (keyField != null && _fileBaseUrlKeys.contains(keyField)) {
        final raw = data['value']?.toString();
        if (raw != null && raw.trim().isNotEmpty) {
          return _normaliseUrl(raw);
        }
      }
    } else if (data is Iterable) {
      for (final item in data) {
        final v = _extractFileBaseUrl(item);
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }

  String _normaliseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    return 'https://$trimmed';
  }
}
