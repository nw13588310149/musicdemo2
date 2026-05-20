import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final dictationRepositoryProvider = Provider<DictationRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return DictationRepository(client: client);
});

class DictationRepository {
  DictationRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getMenuList() {
    return client.post(
      '/app/common/menuList',
      data: const <String, dynamic>{'type': 3},
    );
  }

  Future<ApiResponse> getTextbookList({
    required String firstMenu,
    required String secondMenu,
    bool schoolMode = false,
  }) {
    return client.post(
      schoolMode ? '/app/user/schoolTextbookList' : '/app/user/textbookList',
      data: <String, dynamic>{
        'current': 1,
        'firstMenu': firstMenu,
        'province': '甘肃',
        'secondMenu': secondMenu,
        'size': 1000,
        'type': 3,
      },
    );
  }

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }
}
