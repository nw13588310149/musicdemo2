import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

// 录音系统 v2 测试接口地址（与课件云盘保持一致；切换正式环境时修改此常量即可）
const _kRecordingBase = 'https://api-v2.yyzl0931.com';

final recordingSystemRepositoryProvider = Provider<RecordingSystemRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return RecordingSystemRepository(client: client);
});

class RecordingSystemRepository {
  RecordingSystemRepository({required this.client});

  final ApiClient client;

  // ── Upload ─────────────────────────────────────────────────────────────────

  /// 服务端唯一可用的录音上传端点。
  ///
  /// 历史上这里维护过一份候选列表（`/app/user/fileUpload`、
  /// `/app/common/fileUpload` 作为 fallback），但服务端实际只暴露
  /// `/app/common/v2/fileUpload`，其他两个固定 404。fallback 还会在
  /// 主端点业务失败（HTTP 200 但 code != 0）时继续尝试 fallback，
  /// 把"主端点的真实业务失败 msg"覆盖成"fallback 端点的 404"，
  /// 让上层 toast 显示成无意义的 "Http status error [404]"。
  /// 现在只保留主端点，主端点失败即直接把它的 ApiResponse 透传给
  /// controller，由 `_fallbackMessage` 决定展示策略。
  static const _kUploadEndpoint = '/app/common/v2/fileUpload';

  Future<ApiResponse> uploadRecording({
    required Uint8List bytes,
    required String filename,
  }) async {
    final mediaType = _audioMediaType(filename);
    debugPrint(
      '[recording] uploadRecording start: filename=$filename '
      'bytes=${bytes.length} mime=${mediaType.mimeType}',
    );
    // 显式声明 contentType：iPad/iOS 录音是 .m4a，dio 默认推断不到
    // mime 时会回退到 application/octet-stream，部分网关会拦截
    // "未知二进制"上传导致 400，这里把准确的 audio mime 钉死，让
    // 后端按音频文件入库。
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mediaType,
      ),
    });
    try {
      final resp = await client.postFormData(_kUploadEndpoint, data: form);
      debugPrint(
        '[recording] uploadRecording -> success=${resp.isSuccess} '
        'code=${resp.code} msg="${resp.msg}" data=${resp.data}',
      );
      return resp;
    } catch (error, stack) {
      debugPrint(
        '[recording] uploadRecording threw: $error\n$stack',
      );
      return ApiResponse.failure('上传失败');
    }
  }

  /// 选择上传录音用的 multipart Content-Type。
  ///
  /// - `.m4a` / `.aac` -> `audio/mp4`（iOS `record` 插件 AAC-LC 输出）
  /// - `.webm`         -> `audio/webm`（Web `MediaRecorder` opus）
  /// - `.wav`          -> `audio/wav`
  /// - 其它             -> `application/octet-stream`
  DioMediaType _audioMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) {
      return DioMediaType('audio', 'mp4');
    }
    if (lower.endsWith('.webm')) {
      return DioMediaType('audio', 'webm');
    }
    if (lower.endsWith('.wav')) {
      return DioMediaType('audio', 'wav');
    }
    if (lower.endsWith('.mp3')) {
      return DioMediaType('audio', 'mpeg');
    }
    return DioMediaType('application', 'octet-stream');
  }

  // ── Category ───────────────────────────────────────────────────────────────

  Future<ApiResponse> getCategories() {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingCategoryList',
    );
  }

  Future<ApiResponse> addCategory(String name) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingCategorySave',
      data: <String, dynamic>{'id': 0, 'name': name},
    );
  }

  Future<ApiResponse> renameCategory(int id, String name) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingCategorySave',
      data: <String, dynamic>{'id': id, 'name': name},
    );
  }

  Future<ApiResponse> deleteCategory(int id) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingCategoryDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Folder ─────────────────────────────────────────────────────────────────

  Future<ApiResponse> getFolderList({
    required int categoryId,
    int current = 1,
    int size = 100,
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingFolderList',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'current': current,
        'size': size,
      },
    );
  }

  Future<ApiResponse> addFolder({
    required int categoryId,
    required String name,
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingFolderSave',
      data: <String, dynamic>{'categoryId': categoryId, 'id': 0, 'name': name},
    );
  }

  Future<ApiResponse> renameFolder({
    required int categoryId,
    required int id,
    required String name,
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingFolderSave',
      data: <String, dynamic>{'categoryId': categoryId, 'id': id, 'name': name},
    );
  }

  Future<ApiResponse> deleteFolder(int id) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingFolderDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Recording file ────────────────────────────────────────────────────────

  Future<ApiResponse> getRecordings(
    int categoryId, {
    int folderId = 0,
    String keyword = '',
    int current = 1,
    int size = 1000,
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingList',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'folderId': folderId,
        'keyword': keyword,
        'current': current,
        'size': size,
      },
    );
  }

  /// 新增 / 修改录音作品。后端约定同一个 `recordingSave` 接口：
  /// `id == 0` 时表示新增、`id > 0` 时按 id 更新。请求体形如：
  /// ```json
  /// {
  ///   "categoryId": 2,
  ///   "duration": "01:02:03",
  ///   "filePath": "app/upload/.../xxx.png",
  ///   "folderId": 0,
  ///   "id": 0,
  ///   "name": "作品名称",
  ///   "param1": "string",
  ///   "param2": "string",
  ///   "param3": "string"
  /// }
  /// ```
  Future<ApiResponse> saveRecording({
    required int categoryId,
    required String name,
    required String duration,
    required String filePath,
    int id = 0,
    int folderId = 0,
    String param1 = '',
    String param2 = '',
    String param3 = '',
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingSave',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'duration': duration,
        'filePath': filePath,
        'folderId': folderId,
        'id': id,
        'name': name,
        'param1': param1,
        'param2': param2,
        'param3': param3,
      },
    );
  }

  Future<ApiResponse> deleteRecording(int id) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Share (班级分享，沿用旧接口) ────────────────────────────────────────────

  Future<ApiResponse> getClassList() {
    return client.post('/app/school/v2/chat/classList');
  }

  Future<ApiResponse> shareRecording({
    required String classId,
    required Map<String, dynamic> payload,
  }) {
    return client.post(
      '/app/school/v2/chat/sendMsg',
      data: <String, dynamic>{
        'classId': classId,
        'content': jsonEncode(payload),
        'param1': 'voice',
        'param2': '',
        'param3': '',
        'param4': '',
        'param5': '',
        'type': 3,
      },
    );
  }
}
