import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';

final shellRepositoryProvider = Provider<ShellRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(appStorageProvider);
  return ShellRepository(storage: storage, client: client);
});

class ShellRepository {
  ShellRepository({required this.storage, required this.client});

  final AppStorage storage;
  final ApiClient client;

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }

  /// v2: 同一用户可能绑定多所学校，返回的是 `List<Map>`，调用方按首项取用
  /// 即可（旧版 `/app/user/mySchool` 返回单 Map，已停用）。
  Future<ApiResponse> getSchoolInfo() {
    return client.post('/app/school/v2/user/schoolList');
  }

  Future<ApiResponse> getUnreadCount() {
    return client.post('/app/msg/getUnReadMsgCount');
  }

  Future<ApiResponse> getMessageList() {
    return client.post(
      '/app/msg/list',
      data: const <String, dynamic>{'current': 1, 'size': 10},
    );
  }

  Future<ApiResponse> markRead(List<int> ids) {
    return client.post(
      '/app/msg/updateRead',
      data: <String, dynamic>{'ids': ids},
    );
  }

  Future<ApiResponse> logout() {
    return client.post('/app/user/logout');
  }

  /// 省份地区列表（对齐 1.0 `getCity`）。
  Future<ApiResponse> provinceCityList() => client.post(
    '/app/common/provinceCityList',
    data: const <String, dynamic>{},
  );

  /// 仅更新「所在地区」字段，对应 1.0 顶部下拉中的省份切换。
  Future<ApiResponse> updateProvince(String province) => client.post(
    '/app/user/userinfoUpdate',
    data: <String, dynamic>{'province': province},
  );

  // ── 顶部搜索（对齐 1.0 TopNav.vue `sear`）────────────────────────────────
  // 1.0 的顶部搜索把同一个 keyword 同时丢给四个不同列表接口，分别命中：
  //   - 课程（textbookList，data 中包含 type=1/2/3/4/5/9 等不同子类）
  //   - 视频（videoTutorialList，前端会强制把 type 视作 6）
  //   - 录音（recordingList，前端把 type 视作 'ly'）
  //   - 笔记（noteList，前端把 type 视作 'note'）
  // 后续点击结果时按 type 跳转不同详情页。这里把四个接口收敛在 shell 仓库
  // 里，避免顶部搜索去耦合到各业务模块自己的 repository（它们的入参语义
  // 各不相同）。
  Map<String, dynamic> _searchBody(String keyword, String province) {
    return <String, dynamic>{
      'current': 1,
      'firstMenu': '',
      'keyword': keyword,
      // 1.0 实际写死了 "甘肃"，这里改成跟随用户当前 province，未设置时回落
      // 到 "甘肃" 以保持后端老接口的兼容。
      'province': province.isEmpty ? '甘肃' : province,
      'secondMenu': '',
      'size': 100,
      'type': '',
    };
  }

  Future<ApiResponse> searchTextbookList({
    required String keyword,
    required String province,
  }) {
    return client.post(
      '/app/user/textbookList',
      data: _searchBody(keyword, province),
    );
  }

  Future<ApiResponse> searchVideoList({
    required String keyword,
    required String province,
  }) {
    return client.post(
      '/app/user/videoTutorialList',
      data: _searchBody(keyword, province),
    );
  }

  Future<ApiResponse> searchRecordingList({
    required String keyword,
    required String province,
  }) {
    return client.post(
      '/app/user/recordingList',
      data: _searchBody(keyword, province),
    );
  }

  Future<ApiResponse> searchNoteList({
    required String keyword,
    required String province,
  }) {
    return client.post(
      '/app/user/noteList',
      data: _searchBody(keyword, province),
    );
  }
}
