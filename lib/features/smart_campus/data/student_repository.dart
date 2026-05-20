import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

/// 智慧校园 **学生端** `POST /app/school/v2/student/*`。
///
/// 与 [TeacherRepository] 中任课老师调用的 `teacher/...` 路径不同；
/// 学生「我的作业」使用本类中的 `student/...` 接口。
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return StudentRepository(client: client);
});

class StudentRepository {
  StudentRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/student';

  /// 我的作业列表（分页）。
  ///
  /// - [status]：`0` 待提交、`1` 已提交、`2` 已评分；不传则不限状态（全部）。
  Future<ApiResponse> studentHomeworkList({
    int current = 1,
    int size = 10,
    int? status,
  }) {
    final body = <String, dynamic>{'current': current, 'size': size};
    if (status != null) body['status'] = status;
    return client.post('$_base/studentHomeworkList', data: body);
  }

  /// 作业详情。`id` 须传列表项的 **`homeworkStudentId`**（学生作业记录 id），勿用作业 `id`。
  Future<ApiResponse> studentHomeworkDetail({required String id}) {
    return client.post(
      '$_base/studentHomeworkDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 提交作业。`id` 为 **`homeworkStudentId`**；`studentParam1`～`3` 预留给附件路径、
  /// 文件名、提交类型等扩展（与上传通道对齐）。
  Future<ApiResponse> studentHomeworkSubmit({
    required String id,
    required String description,
    String studentParam1 = '',
    String studentParam2 = '',
    String studentParam3 = '',
  }) {
    return client.post(
      '$_base/studentHomeworkSubmit',
      data: <String, dynamic>{
        'id': id,
        'description': description,
        'studentParam1': studentParam1,
        'studentParam2': studentParam2,
        'studentParam3': studentParam3,
      },
    );
  }
}
