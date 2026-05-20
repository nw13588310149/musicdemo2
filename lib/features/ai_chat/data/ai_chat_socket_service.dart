/// 兼容入口：旧版 AI 聊天专属 WS 客户端已并入 [ChatSocketService]（全局
/// 长连接，统一承担 AI 助手 + 系统事件 + 群聊推送）。本文件只做以下两件事：
///
/// 1. 通过 `export` 暴露 [ChatSocketService] / [ChatSocketEvent]，让旧代码
///    继续从这里 import；
/// 2. 用 typedef + Provider 重定向把 [AiChatSocketService] / [aiChatSocketServiceProvider]
///    指向新的全局实现，避免大面积 import 改造。
///
/// 新写代码请直接 `import 'package:.../core/network/chat_socket_service.dart';`。
library;

import '../../../core/network/chat_socket_service.dart';

export '../../../core/network/chat_socket_service.dart';

/// 旧类名：完整指向新版 [ChatSocketService]，可继续作为构造函数参数类型。
typedef AiChatSocketService = ChatSocketService;

/// 旧 provider 别名：仍可 `ref.watch(aiChatSocketServiceProvider)`，
/// 拿到的是全局唯一的 [ChatSocketService] 单例。
final aiChatSocketServiceProvider = chatSocketServiceProvider;
