import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final myNotesRepositoryProvider = Provider<MyNotesRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return MyNotesRepository(client: client);
});

class MyNotesRepository {
  MyNotesRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getCategories() {
    // 返回结构：data: List<{ id, name, count, createTime, userId }>。
    // `count` 字段已经聚合了该分类下的笔记数，前端直接展示即可。
    return client.post('/app/user/noteCategoryList');
  }

  Future<ApiResponse> getNotes({
    required int categoryId,
    int current = 1,
    int size = 200,
  }) {
    return client.post(
      '/app/user/noteList',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'current': current,
        'size': size,
      },
    );
  }

  Future<ApiResponse> addCategory(String name) {
    return client.post(
      '/app/user/noteCategorySave',
      data: <String, dynamic>{'id': 0, 'name': name},
    );
  }

  /// 重命名笔记分类。复用与「新增分类」相同的 `noteCategorySave` 接口：
  /// 后端约定 `id == 0` 表示新增、`id > 0` 表示按 id 更新分类名。
  Future<ApiResponse> updateCategory({required int id, required String name}) {
    return client.post(
      '/app/user/noteCategorySave',
      data: <String, dynamic>{'id': id, 'name': name},
    );
  }

  Future<ApiResponse> deleteCategory(int id) {
    return client.post(
      '/app/user/noteCategoryDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> deleteNote(int id) {
    return client.post(
      '/app/user/noteDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> updateNote({
    required int id,
    required int categoryId,
    required int paperType,
    required String title,
    required String imageUrl,
    String param2 = 'string',
    String param3 = 'string',
    String param4 = 'string',
    String param5 = 'string',
  }) {
    return client.post(
      '/app/user/noteUpdate',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'id': id,
        'paperType': paperType,
        'param1': imageUrl,
        'param2': param2,
        'param3': param3,
        'param4': param4,
        'param5': param5,
        'title': title,
      },
    );
  }

  Future<ApiResponse> uploadNoteImage({
    required Uint8List bytes,
    required String filename,
  }) {
    return client.postFormData(
      '/app/common/v2/fileUpload',
      data: FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
  }

  Future<ApiResponse> saveNote({
    required int categoryId,
    required int paperType,
    required String title,
    required String imageUrl,
  }) {
    return client.post(
      '/app/user/noteSave',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'paperType': paperType,
        'param1': imageUrl,
        'param2': 'string',
        'param3': 'string',
        'param4': 'string',
        'param5': 'string',
        'title': title,
      },
    );
  }
}
