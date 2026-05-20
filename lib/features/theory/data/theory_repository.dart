import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final theoryRepositoryProvider = Provider<TheoryRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return TheoryRepository(client: client);
});

class TheoryRepository {
  TheoryRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getDetail(int id) {
    return client.post(
      '/app/user/textbookDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }

  Future<ApiResponse> saveStudyRecord(int textbookId) {
    return client.post(
      '/app/user/textbookRecordSave',
      data: <String, dynamic>{'textbookId': textbookId},
    );
  }

  Future<ApiResponse> getClassList() {
    return client.post('/app/school/v2/chat/classList');
  }

  /// 收藏 / 取消收藏教材，与 musicPlay / 1.0 完全一致。
  Future<ApiResponse> setFavorite({
    required int targetId,
    required int type,
    required bool favorite,
  }) {
    return client.post(
      '/app/user/favoriteSave',
      data: <String, dynamic>{
        'favorite': favorite ? 1 : 0,
        'targetId': targetId,
        'type': type,
      },
    );
  }

  Future<ApiResponse> sendMsg({
    required String classId,
    required String content,
    String param1 = 'book',
    String param2 = '',
    String param3 = '',
    String param4 = '',
    String param5 = '',
    int type = 3,
  }) {
    return client.post(
      '/app/school/v2/chat/sendMsg',
      data: <String, dynamic>{
        'classId': classId,
        'content': content,
        'param1': param1,
        'param2': param2,
        'param3': param3,
        'param4': param4,
        'param5': param5,
        'type': type,
      },
    );
  }
}
