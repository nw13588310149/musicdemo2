import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../constants/app_constants.dart';
import '../storage/app_storage.dart';
import 'api_response.dart';
import 'api_unauthorized_handler.dart';
import 'media_url.dart';

class ApiClient {
  static const Set<String> _unauthorizedIgnoredPaths = <String>{
    '/app/user/mobileLogin',
    '/app/user/register',
    '/app/user/resetPassword',
    '/app/user/sendSmsCode',
  };

  ApiClient({required AppStorage storage})
    : _storage = storage,
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
          contentType: Headers.jsonContentType,
        ),
      );

  final AppStorage _storage;
  final Dio _dio;

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        options: _buildOptions(headers: headers, timeout: timeout),
      );
      return _finalizeResponse(
        path,
        _normalizeForPath(path, _toApiResponse(response.data)),
      );
    } on DioException catch (error) {
      return _finalizeResponse(path, _fromDioException(path, error));
    } catch (_) {
      return ApiResponse.failure('网络异常，请稍后重试');
    }
  }

  Future<ApiResponse> post(
    String path, {
    Object? data,
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        options: _buildOptions(headers: headers, timeout: timeout),
      );
      return _finalizeResponse(
        path,
        _normalizeForPath(path, _toApiResponse(response.data)),
      );
    } on DioException catch (error) {
      return _finalizeResponse(path, _fromDioException(path, error));
    } catch (_) {
      return ApiResponse.failure('网络异常，请稍后重试');
    }
  }

  Future<ApiResponse> postFormData(
    String path, {
    required FormData data,
    void Function(int sent, int total)? onSendProgress,
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    try {
      // 对齐 1.0（axios + FormData）：不手动设置 Content-Type，
      // 让 Dio/浏览器自动生成带 boundary 的 multipart/form-data。
      final mergedHeaders =
          <String, dynamic>{
            'app-token': _storage.token,
            'schoolId': _storage.schoolId,
            ...?headers,
          }..removeWhere(
            (key, _) => key.toLowerCase() == Headers.contentTypeHeader,
          );
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        onSendProgress: onSendProgress,
        options: Options(
          headers: mergedHeaders,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
      return _finalizeResponse(path, _toApiResponse(response.data));
    } on DioException catch (error) {
      return _finalizeResponse(path, _fromDioException(path, error));
    } catch (_) {
      return ApiResponse.failure('网络异常，请稍后重试');
    }
  }

  Future<Uint8List> getBytes(
    String url, {
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: _buildOptions(
        headers: headers,
        timeout: timeout,
      ).copyWith(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Empty response bytes');
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> updateToken(String token) async {
    await _storage.saveToken(token);
  }

  Options _buildOptions({Map<String, dynamic>? headers, Duration? timeout}) {
    final mergedHeaders = <String, dynamic>{
      'app-token': _storage.token,
      'schoolId': _storage.schoolId,
      ...?headers,
    };
    final hasContentType = mergedHeaders.keys.any(
      (key) => key.toLowerCase() == Headers.contentTypeHeader,
    );
    if (!hasContentType) {
      mergedHeaders[Headers.contentTypeHeader] = Headers.jsonContentType;
    }

    return Options(
      headers: mergedHeaders,
      sendTimeout: timeout,
      receiveTimeout: timeout,
    );
  }

  ApiResponse _toApiResponse(dynamic body) {
    if (body is Map<String, dynamic>) {
      return ApiResponse.fromJson(body);
    }
    // dio 默认会按响应的 Content-Type 解析：服务端如果给上传接口返
    // 回的是 `text/plain` / `text/html`（部分网关上传场景遇到），
    // dio 拿到的就是原始 JSON 字符串而不是 Map。这里再走一次 String
    // -> jsonDecode 兜底，保证 `{code, msg, data}` 这类标准响应不会
    // 因为 Content-Type 一栏的差异而被误判成"接口数据格式错误"。
    if (body is String) {
      final trimmed = body.trim();
      if (trimmed.isNotEmpty) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            return ApiResponse.fromJson(decoded);
          }
          if (decoded is Map) {
            return ApiResponse.fromJson(
              decoded.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            );
          }
        } catch (error) {
          debugPrint('[api] _toApiResponse: not JSON string -> $error');
        }
      }
    }
    if (body is Map) {
      return ApiResponse.fromJson(
        body.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    debugPrint(
      '[api] _toApiResponse: unsupported body type=${body.runtimeType}',
    );
    return ApiResponse.failure('接口数据格式错误');
  }

  /// 针对个别接口做返回数据的规范化。目前只处理 `/app/user/myInfo`：
  /// 后端有时会把 `headUrl` 写成相对路径（如 `app/upload/.../xxx.png`），
  /// 这里统一拼成完整 URL，避免上层每个消费方都去 import [MediaUrl]。
  /// 直接修改 `data['user']` 这个 Map 是安全的——它来自 dio 解析出的
  /// JSON，仅由本次响应使用，没有任何共享引用。
  ApiResponse _normalizeForPath(String path, ApiResponse response) {
    if (!response.isSuccess) {
      return response;
    }
    if (path == '/app/user/myInfo') {
      _normalizeMyInfoData(response.data);
    }
    return response;
  }

  void _normalizeMyInfoData(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return;
    }
    // 兼容两种返回形态：data.user.headUrl（标准）和 data.headUrl（兜底）。
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      _resolveStringField(user, 'headUrl');
    }
    _resolveStringField(data, 'headUrl');
  }

  void _resolveStringField(Map<String, dynamic> map, String key) {
    final raw = map[key];
    if (raw is! String) {
      return;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return;
    }
    map[key] = MediaUrl.resolve(trimmed);
  }

  bool _shouldHandleUnauthorized(String path) {
    return !_unauthorizedIgnoredPaths.contains(path);
  }

  ApiResponse _finalizeResponse(String path, ApiResponse response) {
    if (response.code != 401 || !_shouldHandleUnauthorized(path)) {
      return response;
    }
    final toastMsg = response.msg.trim().isEmpty
        ? ApiUnauthorizedHandler.defaultMessage
        : response.msg;
    unawaited(
      ApiUnauthorizedHandler.instance.handle(
        storage: _storage,
        message: toastMsg,
      ),
    );
    return ApiResponse.failure(toastMsg, code: 401);
  }

  ApiResponse _fromDioException(String path, DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final parsed = ApiResponse.fromJson(data);
      if (parsed.code == 401 || statusCode == 401) {
        return _finalizeResponse(path, parsed);
      }
    }
    if (statusCode == 401) {
      return _finalizeResponse(
        path,
        ApiResponse.failure(
          _extractDioMessage(error),
          code: 401,
        ),
      );
    }
    return ApiResponse.failure(_extractDioMessage(error));
  }

  String _extractDioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['msg'] != null) {
      return data['msg'].toString();
    }
    if (data is Map && data['msg'] != null) {
      return data['msg'].toString();
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    return '请求失败，请稍后重试';
  }
}
