import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

/// 智慧校园「群聊」相关接口的 Repository。
///
/// 全部为 `POST /app/school/v2/chat/*`，对应 Swagger 中的
/// **v2 智慧校园-群聊 (App School V 2 Chat Controller)** 一组：
///   - `classList`             群聊列表（即「我的班级群」）
///   - `classDetail`           群聊详情（成员数 / 群公告 / 免打扰 ...）
///   - `msgList`               查看某个群最新消息列表（按 id 降序，分页）
///   - `sendMsg`               发送消息（type=1 文本 / 2 图片 / 3 富内容）
///   - `syncMsg`               同步消息（首次进入或重连后批量补齐）
///   - `deleteMsg`             撤回消息
///   - `updateAnnouncement`    设置群公告
///   - `updateDoNotDisturb`    设置消息免打扰
///
/// 请求头 `app-token` / `schoolId` 由 [ApiClient] 统一注入；调用方只需传
/// 业务字段。所有方法返回 [ApiResponse]，由调用方按 `isSuccess` + `data`
/// 处理。
///
/// 雪花长 id（`classId` / `msgId` / `userId`）一律以**字符串**形式传输，
/// 否则在 web 端经 JS number(53bit) 转换会丢精度。
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ChatRepository(client: client);
});

class ChatRepository {
  ChatRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/chat';

  // ============== 群聊列表 / 详情 ==============

  /// 群聊列表（我加入的所有群 / 班级）。空 body 即可。
  Future<ApiResponse> classList() {
    return client.post('$_base/classList');
  }

  /// 群聊详情：成员、公告、免打扰开关、是否可管理等。
  Future<ApiResponse> classDetail({required String classId}) {
    return client.post(
      '$_base/classDetail',
      data: <String, dynamic>{'classId': classId},
    );
  }

  // ============== 消息列表 / 发送 / 同步 / 撤回 ==============

  /// 查看某个群最新消息列表（按 id 降序，分页）。
  ///
  /// 严格对齐 swagger `MsgListReq`：
  /// ```json
  /// { "classId": 0, "offsetMsgId": 0, "size": 20 }
  /// ```
  /// - [classId]：群 / 班级雪花 id（字符串传输，避免 web 端精度丢失）。
  /// - [offsetMsgId]：从哪条消息「之前」开始拉。**首次进入聊天传 `'0'`**
  ///   表示拉最新一页；之后用户上滑要"加载更多旧消息"时，把当前列表里
  ///   最老一条消息的 `msgId` 传进来即可。
  /// - [size]：每页消息条数，默认 20。
  Future<ApiResponse> msgList({
    required String classId,
    String offsetMsgId = '0',
    int size = 20,
  }) {
    return client.post(
      '$_base/msgList',
      data: <String, dynamic>{
        'classId': classId,
        'offsetMsgId': offsetMsgId,
        'size': size,
      },
    );
  }

  /// 发送一条消息。
  ///
  /// - `type==1`：文本消息，`content` 为正文；
  /// - `type==2`：图片消息，`content` 为图片 URL；
  /// - `type==3`：富内容（课件/视频/资讯/课程/录音 等），`content` 为
  ///   JSON 字符串，`param1` 决定子类型（'kj' / 'video' / 'news' /
  ///   'book' / 'voice' / 'file' ...）。
  ///
  /// 返回 `data` 通常为新消息的 `msgId`（数字）或一个含 `msgId/createTime`
  /// 的对象，调用方据此把发送中的本地消息「敲定」。
  Future<ApiResponse> sendMsg({
    required String classId,
    required int type,
    required String content,
    String param1 = '',
    String param2 = '',
    String param3 = '',
    String param4 = '',
    String param5 = '',
  }) {
    return client.post(
      '$_base/sendMsg',
      data: <String, dynamic>{
        'classId': classId,
        'type': type,
        'content': content,
        'param1': param1,
        'param2': param2,
        'param3': param3,
        'param4': param4,
        'param5': param5,
      },
    );
  }

  /// 同步消息（不要轮询）：登录 / 重连 / 切回前台时调用一次，把
  /// 服务端缓存的离线消息批量拉下来。`offsetMsgId` 传 `0` 表示首次同步。
  Future<ApiResponse> syncMsg({
    String offsetMsgId = '0',
    int size = 20,
  }) {
    return client.post(
      '$_base/syncMsg',
      data: <String, dynamic>{
        'offsetMsgId': offsetMsgId,
        'size': size,
      },
    );
  }

  /// 撤回消息（仅自己发的 / 班主任 / 管理员可用，权限由后端校验）。
  Future<ApiResponse> deleteMsg({required String msgId}) {
    return client.post(
      '$_base/deleteMsg',
      data: <String, dynamic>{'msgId': msgId},
    );
  }

  // ============== 文件上传 ==============

  /// 上传语音文件（用于群聊语音消息），返回 `data` 为可访问的 URL 字符串。
  ///
  /// 使用与录音系统相同的上传端点 `/app/common/v2/fileUpload`。
  Future<ApiResponse> uploadVoice({
    required Uint8List bytes,
    required String filename,
  }) {
    final lower = filename.toLowerCase();
    final DioMediaType mime;
    if (lower.endsWith('.webm')) {
      mime = DioMediaType('audio', 'webm');
    } else if (lower.endsWith('.wav')) {
      mime = DioMediaType('audio', 'wav');
    } else {
      mime = DioMediaType('audio', 'mp4'); // .m4a / .aac
    }
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mime,
      ),
    });
    return client.postFormData('/app/common/v2/fileUpload', data: form);
  }

  // ============== 群设置 ==============

  /// 设置群公告（仅群管理员 / 班主任）。`announcement` 为最新公告全文。
  Future<ApiResponse> updateAnnouncement({
    required String classId,
    required String announcement,
  }) {
    return client.post(
      '$_base/updateAnnouncement',
      data: <String, dynamic>{
        'classId': classId,
        'announcement': announcement,
      },
    );
  }

  /// 设置消息免打扰开关。`doNotDisturb` true=开启免打扰 / false=取消。
  Future<ApiResponse> updateDoNotDisturb({
    required String classId,
    required bool doNotDisturb,
  }) {
    return client.post(
      '$_base/updateDoNotDisturb',
      data: <String, dynamic>{
        'classId': classId,
        'doNotDisturb': doNotDisturb,
      },
    );
  }
}
