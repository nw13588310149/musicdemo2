import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ConsultationRepository(client: client);
});

class ConsultationRepository {
  ConsultationRepository({required this.client});

  final ApiClient client;

  /// 资讯列表：1.0 走 textbookList + type:9。
  Future<ApiResponse> getList({
    int page = 1,
    int size = 1000,
    String province = '',
    String firstMenu = '',
    String secondMenu = '',
    int type = 9,
  }) {
    return client.post(
      '/app/user/textbookList',
      data: <String, dynamic>{
        'current': page,
        'size': size,
        'province': province,
        'firstMenu': firstMenu,
        'secondMenu': secondMenu,
        'type': type,
      },
    );
  }

  /// 资讯详情。
  Future<ApiResponse> getDetail(int id) {
    return client.post(
      '/app/user/textbookDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 我的班级群（用于分享课件抽屉）。
  Future<ApiResponse> getClassList() {
    return client.post('/app/school/v2/chat/classList');
  }

  /// 发送消息（分享）。1.0 中 type=3、param1='news'、content 为 JSON。
  ///
  /// classId 后端是 19 位 snowflake id（字符串），不能转成 Web 上的 int，
  /// 否则精度会丢失末位。
  Future<ApiResponse> sendMsg({
    required String classId,
    required String content,
    String param1 = 'news',
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
