import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

// 校园课件测试接口地址（后续改为生产地址时修改此常量即可）
const _kCoursewareBase = 'https://api-v2.yyzl0931.com';

final cloudDriveRepositoryProvider = Provider<CloudDriveRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return CloudDriveRepository(client: client);
});

class CloudDriveRepository {
  CloudDriveRepository({required this.client});

  final ApiClient client;

  // ── Upload ────────────────────────────────────────────────────────────────

  // 候选上传端点（按优先级排列，首个成功即返回）
  static const _kUploadCandidates = <String>[
    '/app/common/v2/fileUpload',
    '/app/user/fileUpload',
    '/app/common/fileUpload',
  ];

  /// 不带进度回调的上传（内部复用）
  Future<ApiResponse> uploadFile({
    required Uint8List bytes,
    required String filename,
  }) => uploadFileWithProgress(bytes: bytes, filename: filename);

  /// 带上传进度回调的上传。[onSendProgress] 在主端点成功前持续回调 (0.0–1.0)。
  Future<ApiResponse> uploadFileWithProgress({
    required Uint8List bytes,
    required String filename,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _uploadMultipartWithProgress(
      createFile: () async =>
          MultipartFile.fromBytes(bytes, filename: filename),
      onSendProgress: onSendProgress,
    );
  }

  Future<ApiResponse> uploadFilePathWithProgress({
    required String filePath,
    required String filename,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _uploadMultipartWithProgress(
      createFile: () => MultipartFile.fromFile(filePath, filename: filename),
      onSendProgress: onSendProgress,
    );
  }

  Future<ApiResponse> _uploadMultipartWithProgress({
    required Future<MultipartFile> Function() createFile,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    ApiResponse last = ApiResponse.failure('上传失败');
    for (var i = 0; i < _kUploadCandidates.length; i++) {
      final path = _kUploadCandidates[i];
      // FormData 是流，每次必须重新创建
      final form = FormData.fromMap(<String, dynamic>{
        'file': await createFile(),
      });
      // 只有第一个候选端点传递进度回调，避免重试时回调乱序
      final resp = await client.postFormData(
        path,
        data: form,
        onSendProgress: i == 0 ? onSendProgress : null,
      );
      last = resp;
      if (resp.isSuccess) {
        return resp;
      }
    }
    return last;
  }

  // ── Category ──────────────────────────────────────────────────────────────

  Future<ApiResponse> getCategoryList() {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareCategoryList',
    );
  }

  /// 云盘用量（已用 / 总量等，具体字段由后端约定，解析见 controller）。
  Future<ApiResponse> getCoursewareUsage() {
    return client.post('/app/courseware/v2/usage');
  }

  Future<ApiResponse> addCategory(String name) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareCategorySave',
      data: <String, dynamic>{'id': 0, 'name': name},
    );
  }

  Future<ApiResponse> renameCategory(int id, String name) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareCategorySave',
      data: <String, dynamic>{'id': id, 'name': name},
    );
  }

  Future<ApiResponse> deleteCategory(int id) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareCategoryDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Folder ────────────────────────────────────────────────────────────────

  Future<ApiResponse> getFolderList({
    required int categoryId,
    int current = 1,
    int size = 100,
  }) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareFolderList',
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
      '$_kCoursewareBase/app/courseware/v2/coursewareFolderSave',
      data: <String, dynamic>{'categoryId': categoryId, 'id': 0, 'name': name},
    );
  }

  Future<ApiResponse> renameFolder({
    required int categoryId,
    required int id,
    required String name,
  }) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareFolderSave',
      data: <String, dynamic>{'categoryId': categoryId, 'id': id, 'name': name},
    );
  }

  Future<ApiResponse> deleteFolder(int id) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareFolderDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Courseware file ───────────────────────────────────────────────────────

  Future<ApiResponse> getCoursewareList({
    int categoryId = 0,
    int folderId = 0,
    String keyword = '',
    int current = 1,
    int size = 1000,
  }) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareList',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'folderId': folderId,
        'keyword': keyword,
        'current': current,
        'size': size,
      },
    );
  }

  Future<ApiResponse> addCourseware({
    required int categoryId,
    required String title,
    int folderId = 0,
    String filePath = '',
    String param1 = '',
    String param2 = '',
    String param3 = '',
    String param4 = '',
    String param5 = '',
  }) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareSave',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'folderId': folderId,
        'filePath': filePath,
        'title': title,
        'param1': param1,
        'param2': param2,
        'param3': param3,
        'param4': param4,
        'param5': param5,
      },
    );
  }

  Future<ApiResponse> updateCoursewareTitle(int id, String title) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareUpdateTitle',
      data: <String, dynamic>{'id': id, 'title': title},
    );
  }

  Future<ApiResponse> deleteCourseware(int id) {
    return client.post(
      '$_kCoursewareBase/app/courseware/v2/coursewareDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Share (班级分享) ────────────────────────────────────────────────────────

  Future<ApiResponse> getClassList() {
    return client.post('/app/school/v2/chat/classList');
  }

  Future<ApiResponse> sendShareMessage({
    required String classId,
    required String content,
  }) {
    return client.post(
      '/app/school/v2/chat/sendMsg',
      data: <String, dynamic>{
        'classId': classId,
        'content': content,
        'param1': 'kj',
        'param2': '',
        'param3': '',
        'param4': '',
        'param5': '',
        'type': 3,
      },
    );
  }
}
