import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return SchoolRepository(client: client);
});

class SchoolRepository {
  SchoolRepository({required this.client});

  final ApiClient client;

  /// v2: 同一用户可能绑定多所学校，返回的是 `List<Map>`，调用方按首项取用
  /// 即可（旧版 `/app/user/mySchool` 返回单 Map，已停用）。
  ///
  /// 「绑定学校」流程中，`data == []` 表示当前用户尚未绑定任何学校，需要
  /// 进一步调用 [getSchoolJoinList] 拿到「申请审核状态」决定弹窗形态。
  Future<ApiResponse> getSchoolInfo() {
    return client.post('/app/school/v2/user/schoolList');
  }

  /// 「绑定学校」申请审核记录列表。后端返回字段：
  /// ```json
  /// { "code": 0, "data": [{ "status": 0, "rejectReason": "..." }] }
  /// ```
  /// `status`：`0`-待审核 / `1`-通过 / `2`-拒绝。
  ///
  /// 配合 [getSchoolInfo]：当 schoolList 为空时调用本接口区分
  /// 「从未提交」/ 「审核中」/ 「未通过」三种弹窗状态。
  Future<ApiResponse> getSchoolJoinList() {
    return client.post('/app/school/v2/user/schoolJoinList');
  }

  /// 发起一次「学校编码绑定」申请。
  ///
  /// 2.0 走独立的 `/app/school/v2/user/schoolJoin` 端点（与旧版实名认证
  /// `/app/user/submitCertification` 分离），绑定弹窗只需上送 `schoolCode`
  /// （由学校管理员分发的入学码），其它字段（idcard / role 等）走老的实
  /// 名认证页面再补。提交成功后下一次 [getSchoolJoinList] 将返回
  /// `status=0`（待审核）。
  Future<ApiResponse> submitSchoolBinding(String schoolCode) {
    return client.post(
      '/app/school/v2/user/schoolJoin',
      data: <String, dynamic>{'schoolCode': schoolCode},
    );
  }

  Future<ApiResponse> getLearningProgress() {
    return client.post(
      '/app/user/schoolHomeLearningProgress',
      data: const <String, dynamic>{'province': '甘肃省'},
    );
  }

  Future<ApiResponse> getLatestInfo() {
    return client.post(
      '/app/user/homeLatestInfo',
      data: const <String, dynamic>{'province': '甘肃省'},
    );
  }

  /// 课表-左侧时间列表（节次 + 起止时间）。
  ///
  /// 入参：
  /// ```json
  /// { "classId": "1798658711795392514" }
  /// ```
  ///
  /// 不同班级可能采用不同的作息表（中学 / 小学 / 艺考特训等）；不传或空字符
  /// 时按全校默认配置返回。`classId` 雪花 long → String。
  ///
  /// 通常返回结构：
  /// ```json
  /// {
  ///   "data": [
  ///     {"lineNum": 1, "startTime": "08:00", "endTime": "08:40"},
  ///     ...
  ///   ]
  /// }
  /// ```
  ///
  /// 用于课表网格左侧时间冻结列。
  Future<ApiResponse> schoolTimeConfigList({String? classId}) {
    final body = <String, dynamic>{};
    if (classId != null && classId.isNotEmpty) {
      body['classId'] = classId;
    }
    return client.post('/app/school/v2/user/schoolTimeConfigList', data: body);
  }

  /// 科目下拉列表。`classId` 雪花 long → String；为空时返回全部科目，
  /// 传入班级 id 后返回该班级可选科目。
  Future<ApiResponse> subjectList({String? classId}) {
    final body = <String, dynamic>{};
    if (classId != null && classId.isNotEmpty) {
      body['classId'] = classId;
    }
    return client.post('/app/school/v2/user/subjectList', data: body);
  }
}
