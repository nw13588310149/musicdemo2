import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final studyCatalogRepositoryProvider = Provider<StudyCatalogRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return StudyCatalogRepository(client: client);
});

class StudyCatalogRepository {
  StudyCatalogRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getMenuList(int type) {
    return client.post(
      '/app/common/menuList',
      data: <String, dynamic>{'type': type},
    );
  }

  Future<ApiResponse> getTextbookList({
    required int type,
    required String firstMenu,
    required String secondMenu,
    required bool schoolMode,
    int size = 1000,
  }) {
    return client.post(
      schoolMode ? '/app/user/schoolTextbookList' : '/app/user/textbookList',
      data: <String, dynamic>{
        'current': 1,
        'firstMenu': firstMenu,
        'province': '甘肃',
        'secondMenu': secondMenu,
        'size': size,
        'type': type,
      },
    );
  }

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }
}
