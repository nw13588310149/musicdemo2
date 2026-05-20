import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final quizPracticeRepositoryProvider = Provider<QuizPracticeRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return QuizPracticeRepository(client: client);
});

class QuizPracticeRepository {
  QuizPracticeRepository({required this.client});

  final ApiClient client;

  /// 刷题数据汇总：返回顺序练习/随机练习/考前密卷/错题集 4 类的统计数据。
  Future<ApiResponse> getSummary() {
    return client.post('/app/user/questionPracticeSummary');
  }

  /// 创建一组练习（status==null 时初始化）。size 默认 150 与 1.0 一致。
  Future<ApiResponse> createPractice({
    required String practiceType,
    int size = 150,
  }) {
    return client.post(
      '/app/user/questionPracticeCreate',
      data: <String, dynamic>{
        'practiceType': practiceType,
        'size': size.toString(),
      },
    );
  }

  /// 根据 practiceId 拉取该轮练习的全部题目。
  Future<ApiResponse> getItemList({required int practiceId}) {
    return client.post(
      '/app/user/questionPracticeItemList',
      data: <String, dynamic>{'practiceId': practiceId},
    );
  }

  /// 上报答题结果。status: 1=正确, 2=错误。
  Future<ApiResponse> reportAnswer({
    required int questionPracticeItemId,
    required int answer,
    required int status,
  }) {
    return client.post(
      '/app/user/questionPracticeItemReport',
      data: <String, dynamic>{
        'answer': answer,
        'questionPracticeItemId': questionPracticeItemId,
        'status': status,
      },
    );
  }
}
