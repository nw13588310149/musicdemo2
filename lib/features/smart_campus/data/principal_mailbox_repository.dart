import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';

/// 智慧校园「校长信箱 + 意见反馈」相关接口的 Repository。学生 / 任课老师 /
/// 班主任 / 管理员四端共用同一个页面（[PrincipalMailboxView]），因此把
/// 「校长信箱」与「意见反馈」两组接口聚合在同一仓库中。
///
/// **校长信箱**（`POST /app/school/v2/user/*`）：
///   - `principalMailboxList`    我提交的校长信箱列表（按 status 过滤）
///   - `principalMailboxSubmit`  提交校长信箱
///
/// **意见反馈**（`POST /app/user/*`，与学校上下文无关）：
///   - `feedbackList`            我提交的意见反馈列表（分页）
///   - `feedbackSave`            提交意见反馈
///
/// 请求头 `app-token` / `schoolId` 由 [ApiClient] 统一注入；校长信箱列表
/// 接口无须单独传 `schoolId`，校长信箱提交接口按 Swagger 仍要求 body 带
/// `schoolId`，这里从 [AppStorage] 读取后自动塞入，调用方只需传业务字段。
/// 意见反馈接口与学校无关，仅需 token 即可。
final principalMailboxRepositoryProvider = Provider<PrincipalMailboxRepository>(
  (ref) {
    final client = ref.watch(apiClientProvider);
    final storage = ref.watch(appStorageProvider);
    return PrincipalMailboxRepository(client: client, storage: storage);
  },
);

class PrincipalMailboxRepository {
  PrincipalMailboxRepository({required this.client, required this.storage});

  final ApiClient client;
  final AppStorage storage;

  static const _base = '/app/school/v2/user';
  static const _userBase = '/app/user';

  /// 「我提交的校长信箱」列表。
  ///
  /// `status` 状态：
  /// - 0 已发送
  /// - 1 已回复
  /// - 2 已关闭
  Future<ApiResponse> principalMailboxList({
    int current = 1,
    int size = 10,
    int status = 0,
  }) {
    return client.post(
      '$_base/principalMailboxList',
      data: <String, dynamic>{
        'current': current,
        'size': size,
        'status': status,
      },
    );
  }

  /// 提交一封新的校长信。
  ///
  /// - [content]      正文内容（必填）
  /// - [msgType]      消息类型，例：举报 / 建议 / 其他
  /// - [isAnonymous]  是否匿名：0 否 / 1 是
  /// - [attachments]  附件 URL，多个用英文逗号分隔；无附件传空串
  /// - [schoolId]     学校 id；不传则从 [AppStorage] 自动取值
  Future<ApiResponse> principalMailboxSubmit({
    required String content,
    required String msgType,
    int isAnonymous = 0,
    String attachments = '',
    int? schoolId,
  }) {
    final sid = schoolId ?? int.tryParse(storage.schoolId) ?? 0;
    return client.post(
      '$_base/principalMailboxSubmit',
      data: <String, dynamic>{
        'attachments': attachments,
        'content': content,
        'isAnonymous': isAnonymous,
        'msgType': msgType,
        'schoolId': sid,
      },
    );
  }

  // ============== 意见反馈 ==============

  /// 「我提交的意见反馈」列表（分页）。返回数据通常为 `{records, total, ...}`
  /// 结构，由调用方按 `_asList` 规则容错解析。
  Future<ApiResponse> feedbackList({int current = 1, int size = 10}) {
    return client.post(
      '$_userBase/feedbackList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 提交一条意见反馈。仅 `content` 必填。
  Future<ApiResponse> feedbackSave({required String content}) {
    return client.post(
      '$_userBase/feedbackSave',
      data: <String, dynamic>{'content': content},
    );
  }
}
