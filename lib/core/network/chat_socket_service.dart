import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../providers/app_providers.dart';
import '../storage/app_storage.dart';

/// 全局长连接服务。承担三类下行事件：
///
/// 1. AI 助手（流式增量片段 / 整包响应 / 思考过程）；
/// 2. 系统事件（被踢、token 失效、登录超时）；
/// 3. 群聊推送（新消息 / 撤回 / 公告更新）。
///
/// 行为对齐 1.0 `utils/wsClient.js`：
/// * 仅在本地存在 `token` 时连接；连接成功后发送 `{type:1000, token}`；
/// * 每 60s 上行心跳 `{type:100}`；
/// * 非主动断开时 5s 自动重连；
/// * 全部事件以广播 `Stream<ChatSocketEvent>` 暴露，业务侧按 `type` 过滤。
///
/// 与 1.0 的差异：
/// * 1.0 群聊走 HTTP `syncMsg` 轮询；2.0 增加 [ChatSocketEventType.chatNewMessage]
///   等事件，由后端在 WS 上推。客户端遇到 `chatNewMessage` 后既可以
///   直接合并 payload（若服务端带上完整消息体），也可以触发一次
///   `syncMsg` 作为兜底。
///
/// 注意：本服务在应用整个生命周期内活着，Provider 默认不会被销毁；
/// 想强制断开请显式调 [disconnect]。
final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  final storage = ref.watch(appStorageProvider);
  final service = ChatSocketService(storage: storage);
  ref.onDispose(service.dispose);
  return service;
});

/// 事件类型。`stream`/`full`/`message` 三个值与 1.0 兼容，旧的
/// `AiChatSocketEventType` 通过 typedef 指向同一个枚举。
enum ChatSocketEventType {
  /// 任意原始下行帧 —— 不做语义判定，订阅方可自行解析。
  message,

  /// AI 助手流式增量字符片段（type=0 / 10004 / 10013 或匹配的 type=1 / 10014 增量）。
  stream,

  /// AI 助手整包响应（type=1 / 10005 / 10014 或带 `role=assistant` 的 envelope）。
  full,

  /// 群聊新消息。payload 可能直接带完整消息体；若只是个信号位，
  /// 业务侧应触发一次 `syncMsg` 兜底拉取。
  chatNewMessage,

  /// 群聊消息撤回。
  chatMessageDeleted,

  /// 群公告更新。
  chatAnnouncementUpdated,

  /// 被踢下线（type=10003）。
  kicked,

  /// token 失效（type=10000）。
  tokenError,

  /// 登录超时（type=10002）。
  loginTimeout,
}

/// 旧名称别名 —— `features/ai_chat` 模块沿用此名，避免大面积改 import。
typedef AiChatSocketEventType = ChatSocketEventType;

class ChatSocketEvent {
  const ChatSocketEvent({required this.type, required this.payload});

  final ChatSocketEventType type;
  final Map<String, dynamic> payload;
}

/// 旧名称别名。
typedef AiChatSocketEvent = ChatSocketEvent;

class ChatSocketService {
  ChatSocketService({required AppStorage storage}) : _storage = storage;

  final AppStorage _storage;
  final StreamController<ChatSocketEvent> _events =
      StreamController<ChatSocketEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _intentionallyClosed = false;
  bool _connecting = false;

  /// 全部下行事件流。订阅方按 [ChatSocketEvent.type] 过滤即可。
  Stream<ChatSocketEvent> get events => _events.stream;

  /// 当前底层 socket 是否已就绪（不是 100% 等价于"在线"，仅做粗略可视化）。
  bool get isConnected => _channel != null;

  /// 触发一次连接。若已有底层 socket 在跑，会先关掉再重连，确保用最新
  /// token 走 `{type:1000}` 握手。可在以下时机调用：
  /// * App 启动且本地存在 token；
  /// * 登录 / 重新登录成功；
  /// * 切换学校等需要换 token 的场景。
  void connect() {
    if (_disposed) {
      return;
    }
    final token = _storage.token;
    if (token.isEmpty) {
      // 没有 token（首次进入 / 刚 logout）：什么都不做，等待登录后再 connect。
      return;
    }
    if (_connecting) {
      return;
    }

    _intentionallyClosed = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeChannel();

    _connecting = true;
    try {
      final channel = WebSocketChannel.connect(_wsUri());
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleRawMessage,
        onError: (_) => _handleClosed(),
        onDone: _handleClosed,
        cancelOnError: true,
      );
      channel.sink.add(
        jsonEncode(<String, dynamic>{'type': 1000, 'token': token}),
      );
      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  /// 主动断开并不再自动重连。退出登录、切换账号时调用。
  void disconnect() {
    _intentionallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _closeChannel();
  }

  /// 等价于 disconnect + connect，保证用最新 token 走一次握手。
  void reconnect() {
    disconnect();
    _intentionallyClosed = false;
    connect();
  }

  void dispose() {
    _disposed = true;
    disconnect();
    unawaited(_events.close());
  }

  Uri _wsUri() {
    final base = AppConstants.apiBaseUrl.trim();
    if (base.startsWith('https://')) {
      return Uri.parse(
        'wss://${base.substring('https://'.length).replaceFirst(RegExp(r'/$'), '')}/websocket',
      );
    }
    if (base.startsWith('http://')) {
      return Uri.parse(
        'ws://${base.substring('http://'.length).replaceFirst(RegExp(r'/$'), '')}/websocket',
      );
    }
    return Uri.parse('$base/websocket');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      try {
        _channel?.sink.add(jsonEncode(<String, dynamic>{'type': 100}));
      } catch (_) {
        _handleClosed();
      }
    });
  }

  void _handleRawMessage(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(text);
      final map = _toMap(decoded);
      if (map == null) {
        return;
      }

      // 始终先以 message 维度广播一次，方便排查 / 调试 / 自定义解析。
      _emit(ChatSocketEventType.message, map);

      final normalizedType = _normalizeWsType(map);

      // AI 助手 —— 流式增量。
      if (normalizedType == 0 ||
          normalizedType == 10004 ||
          normalizedType == 10013 ||
          _isLikelyChatGptStreamChunk(map, normalizedType)) {
        _emit(ChatSocketEventType.stream, map);
        return;
      }

      // AI 助手 —— 整包响应。
      if (normalizedType == 1 ||
          normalizedType == 10005 ||
          normalizedType == 10014 ||
          _isAssistantFullPayload(map, normalizedType)) {
        _emit(ChatSocketEventType.full, map);
        return;
      }

      // 系统事件。
      if (normalizedType == 10003) {
        _emit(ChatSocketEventType.kicked, map);
        return;
      }
      if (normalizedType == 10000) {
        _emit(ChatSocketEventType.tokenError, map);
        return;
      }
      if (normalizedType == 10002) {
        _emit(ChatSocketEventType.loginTimeout, map);
        return;
      }

      // 群聊推送 —— 后端约定 type 号待最终确认；这里同时容忍语义判定。
      //
      // 约定（推荐让后端就近选用 2001 / 2002 / 2003）：
      //   2001：新消息
      //   2002：消息撤回
      //   2003：公告变更
      //
      // 兜底语义判定：若帧里带 classId + (content/msgId)，无 type 也按
      // chatNewMessage 处理。
      if (_isChatPushType(normalizedType, 2001) ||
          _looksLikeChatNewMessage(map, normalizedType)) {
        _emit(ChatSocketEventType.chatNewMessage, map);
        return;
      }
      if (_isChatPushType(normalizedType, 2002) ||
          _looksLikeChatMessageDeleted(map, normalizedType)) {
        _emit(ChatSocketEventType.chatMessageDeleted, map);
        return;
      }
      if (_isChatPushType(normalizedType, 2003) ||
          _looksLikeChatAnnouncementChanged(map, normalizedType)) {
        _emit(ChatSocketEventType.chatAnnouncementUpdated, map);
        return;
      }
    } catch (_) {
      return;
    }
  }

  void _emit(ChatSocketEventType type, Map<String, dynamic> payload) {
    if (!_events.isClosed) {
      _events.add(ChatSocketEvent(type: type, payload: payload));
    }
  }

  int? _normalizeWsType(Map<String, dynamic> json) {
    final value = json['type'] ?? json['msgType'] ?? json['messageType'];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  bool _isLikelyChatGptStreamChunk(Map<String, dynamic> json, int? type) {
    if (type != 1 && type != 10014) {
      return false;
    }
    final hasStringContent = json['content'] is String;
    if (!hasStringContent) {
      return false;
    }

    // 流式增量帧典型形态：type ∈ {1, 10014}，content 为字符串。
    //
    // 历史教训：
    // 1) 旧版要求 `sessionId == null && role == null`，但服务端在「新建会话
    //    首条回复」上每片都带 sessionId，结果首轮整帧被误判到 full 分支后立刻
    //    `_finishAiStream`，后续增量被丢弃 → 表现为「没有打字效果」。
    // 2) 改成「必须带 replyId」之后，仍然有部分场景（首条回复、断线重连后的
    //    第一片、deepseek 流的中段恢复包）服务端不下发 replyId，分片再次落入
    //    full 分支，又出现「结束时一次渲染」。
    //
    // 因此这里采用最宽松、最符合 web 1.0 实际行为的规则：
    // - type == 1：DeepSeek/小艺同学常规流式增量 type，**只要 content 是字符串
    //   就当作流式分片**，不管 replyId 是否存在；
    // - type == 10014：协议里同时承担「流式分片」与「最终 envelope」两种语义，
    //   为了避免把 envelope 全量帧也当成 delta 累加，这里仍要求带 replyId。
    if (type == 1) {
      return true;
    }
    return json['replyId'] != null;
  }

  bool _isAssistantFullPayload(Map<String, dynamic> json, int? type) {
    if (type != null) {
      return false;
    }
    return (json['role'] == 'assistant' || json['role'] == 'ai') &&
        json['content'] != null &&
        (json['sessionId'] != null || json['chatSessionId'] != null);
  }

  bool _isChatPushType(int? actualType, int expectedType) =>
      actualType != null && actualType == expectedType;

  /// 兜底：若服务端只下发 classId + 内容字段而无明确 type，按新消息处理。
  bool _looksLikeChatNewMessage(Map<String, dynamic> json, int? type) {
    if (type != null && type < 2000) {
      // 已经被其它分支处理过。
      return false;
    }
    final hasClass = json['classId'] != null || json['cId'] != null;
    if (!hasClass) return false;
    final hasContent =
        json['content'] != null ||
        json['msgId'] != null ||
        json['id'] != null ||
        json['contentType'] != null;
    return hasContent;
  }

  bool _looksLikeChatMessageDeleted(Map<String, dynamic> json, int? type) {
    if (type != null && type < 2000) {
      return false;
    }
    final eventField = (json['event'] ?? json['action'] ?? '')
        .toString()
        .toLowerCase();
    return eventField.contains('delete') || eventField.contains('recall');
  }

  bool _looksLikeChatAnnouncementChanged(
    Map<String, dynamic> json,
    int? type,
  ) {
    if (type != null && type < 2000) {
      return false;
    }
    final eventField = (json['event'] ?? json['action'] ?? '')
        .toString()
        .toLowerCase();
    return eventField.contains('announcement') ||
        json['announcement'] != null && json['classId'] != null;
  }

  void _handleClosed() {
    if (_disposed || _intentionallyClosed) {
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _closeChannel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionallyClosed || _reconnectTimer != null) {
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      // 重连前再次校验 token，避免登出后还在静默重连。
      if (_storage.token.isEmpty) {
        return;
      }
      connect();
    });
  }

  void _closeChannel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {
      // Ignore socket close errors.
    }
    _channel = null;
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, data) => MapEntry('$key', data));
    }
    return null;
  }
}
