import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final videoTutorialRepositoryProvider = Provider<VideoTutorialRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return VideoTutorialRepository(client: client);
});

class VideoTutorialRepository {
  VideoTutorialRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getBannerList() {
    return client.post(
      '/app/user/bannerList',
      data: const <String, dynamic>{'contentType': 1},
    );
  }

  Future<ApiResponse> getMenuList() {
    return client.post(
      '/app/common/menuList',
      data: const <String, dynamic>{'type': 6},
    );
  }

  Future<ApiResponse> getVideoList({
    required int current,
    required int size,
    String? firstMenu,
    String? secondMenu,
  }) {
    return client.post(
      '/app/user/videoTutorialList',
      data: <String, dynamic>{
        'current': current,
        'size': size,
        'firstMenu': firstMenu,
        'secondMenu': secondMenu,
      },
    );
  }

  Future<ApiResponse> getVideoDetail(String id) {
    return client.post(
      '/app/user/videoTutorialDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> toggleFavorite({
    required String targetId,
    required bool favorite,
  }) {
    return client.post(
      '/app/user/favoriteSave',
      data: <String, dynamic>{
        'favorite': favorite,
        'targetId': targetId,
        'type': 6,
      },
    );
  }

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }

  Future<ApiResponse> getClassList() {
    return client.post(
      '/app/school/v2/chat/classList',
      data: const <String, dynamic>{},
    );
  }

  Future<ApiResponse> shareVideo({
    required String classId,
    required String content,
  }) {
    return client.post(
      '/app/school/v2/chat/sendMsg',
      data: <String, dynamic>{
        'classId': classId,
        'content': content,
        'param1': 'video',
        'param2': '',
        'param3': '',
        'param4': '',
        'param5': '',
        'type': 3,
      },
    );
  }
}
