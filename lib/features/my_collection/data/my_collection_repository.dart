import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final myCollectionRepositoryProvider = Provider<MyCollectionRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return MyCollectionRepository(client: client);
});

class MyCollectionRepository {
  MyCollectionRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getCategories() {
    return client.post('/app/user/customFavoriteCategoryList');
  }

  Future<ApiResponse> getItems({required int type}) {
    return client.post(
      '/app/user/favoriteList',
      data: <String, dynamic>{'current': 1, 'size': 1000, 'type': type},
    );
  }

  Future<ApiResponse> removeFavorite({
    required int targetId,
    required int type,
  }) {
    return client.post(
      '/app/user/favoriteSave',
      data: <String, dynamic>{
        'favorite': 0,
        'targetId': targetId,
        'type': type,
      },
    );
  }

  Future<ApiResponse> getClassList() {
    return client.post('/app/school/v2/chat/classList');
  }

  Future<ApiResponse> shareToClass({
    required int classId,
    required int type,
    required Map<String, dynamic> payload,
  }) {
    return client.post(
      '/app/school/v2/chat/sendMsg',
      data: <String, dynamic>{
        'classId': classId,
        'content': jsonEncode(payload),
        'param1': type == 6 ? 'video' : 'book',
        'param2': '',
        'param3': '',
        'param4': '',
        'param5': '',
        'type': 3,
      },
    );
  }
}
