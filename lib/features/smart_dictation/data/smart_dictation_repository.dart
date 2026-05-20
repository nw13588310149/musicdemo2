import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final smartDictationRepositoryProvider = Provider<SmartDictationRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return SmartDictationRepository(client: client);
});

class SmartDictationRepository {
  SmartDictationRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getSmartDictationList({required int type}) {
    return client.post(
      '/app/user/smartDictationList',
      data: <String, dynamic>{'type': type},
    );
  }

  Future<ApiResponse> saveSmartDictationRecord({
    required int smartDictationId,
    required int stars,
  }) {
    return client.post(
      '/app/user/smartDictationRecordSave',
      data: <String, dynamic>{
        'smartDictationId': smartDictationId,
        'stars': stars,
      },
    );
  }

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }
}
