enum AiChatMessageType { user, ai }

enum AiChatMessageStatus { sending, sent, failed }

class AiChatSession {
  const AiChatSession({required this.id, required this.title, this.sortTime});

  final String id;
  final String title;
  final DateTime? sortTime;
}

class AiChatAttachment {
  const AiChatAttachment({
    required this.name,
    required this.url,
    this.size = 0,
  });

  final String name;
  final String url;
  final int size;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'fileName': name,
      'url': url,
      'fileUrl': url,
      'size': size,
    };
  }
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.type,
    required this.text,
    this.status = AiChatMessageStatus.sent,
    this.reasoning = '',
    this.reasoningExpanded = false,
    this.streaming = false,
    this.reasoningStreaming = false,
    this.attachments = const [],
    this.sortTime,
  });

  final String id;
  final AiChatMessageType type;
  final String text;
  final AiChatMessageStatus status;
  final String reasoning;
  final bool reasoningExpanded;
  final bool streaming;
  final bool reasoningStreaming;
  final List<AiChatAttachment> attachments;
  final DateTime? sortTime;

  AiChatMessage copyWith({
    String? id,
    AiChatMessageType? type,
    String? text,
    AiChatMessageStatus? status,
    String? reasoning,
    bool? reasoningExpanded,
    bool? streaming,
    bool? reasoningStreaming,
    List<AiChatAttachment>? attachments,
    DateTime? sortTime,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      status: status ?? this.status,
      reasoning: reasoning ?? this.reasoning,
      reasoningExpanded: reasoningExpanded ?? this.reasoningExpanded,
      streaming: streaming ?? this.streaming,
      reasoningStreaming: reasoningStreaming ?? this.reasoningStreaming,
      attachments: attachments ?? this.attachments,
      sortTime: sortTime ?? this.sortTime,
    );
  }
}

class AiChatSessionGroup {
  const AiChatSessionGroup({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;
  final String label;
  final List<AiChatSession> items;
}

class AiChatState {
  const AiChatState({
    this.sidebarCollapsed = false,
    this.isDeepThinking = false,
    this.isWebSearching = false,
    this.sessionsLoading = false,
    this.messagesLoading = false,
    this.sending = false,
    this.waitingAssistant = false,
    this.uploadingAttachment = false,
    this.isNewConversation = true,
    this.activeSessionId,
    this.sessions = const [],
    this.messages = const [],
    this.pendingAttachments = const [],
  });

  final bool sidebarCollapsed;
  final bool isDeepThinking;
  final bool isWebSearching;
  final bool sessionsLoading;
  final bool messagesLoading;
  final bool sending;
  final bool waitingAssistant;
  final bool uploadingAttachment;
  final bool isNewConversation;
  final String? activeSessionId;
  final List<AiChatSession> sessions;
  final List<AiChatMessage> messages;
  final List<AiChatAttachment> pendingAttachments;

  String get effectiveChatModel {
    return isDeepThinking ? 'deepseek-reasoner' : 'deepseek-chat';
  }

  AiChatState copyWith({
    bool? sidebarCollapsed,
    bool? isDeepThinking,
    bool? isWebSearching,
    bool? sessionsLoading,
    bool? messagesLoading,
    bool? sending,
    bool? waitingAssistant,
    bool? uploadingAttachment,
    bool? isNewConversation,
    String? activeSessionId,
    bool clearActiveSessionId = false,
    List<AiChatSession>? sessions,
    List<AiChatMessage>? messages,
    List<AiChatAttachment>? pendingAttachments,
  }) {
    return AiChatState(
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      isDeepThinking: isDeepThinking ?? this.isDeepThinking,
      isWebSearching: isWebSearching ?? this.isWebSearching,
      sessionsLoading: sessionsLoading ?? this.sessionsLoading,
      messagesLoading: messagesLoading ?? this.messagesLoading,
      sending: sending ?? this.sending,
      waitingAssistant: waitingAssistant ?? this.waitingAssistant,
      uploadingAttachment: uploadingAttachment ?? this.uploadingAttachment,
      isNewConversation: isNewConversation ?? this.isNewConversation,
      activeSessionId: clearActiveSessionId
          ? null
          : (activeSessionId ?? this.activeSessionId),
      sessions: sessions ?? this.sessions,
      messages: messages ?? this.messages,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    );
  }
}

List<AiChatSessionGroup> groupSessionsByTime(List<AiChatSession> sessions) {
  if (sessions.isEmpty) {
    return const [];
  }

  final sorted = [...sessions]
    ..sort((a, b) {
      final at = a.sortTime?.millisecondsSinceEpoch ?? 0;
      final bt = b.sortTime?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final todayStart = startOfToday.millisecondsSinceEpoch;
  final withinSevenDays = todayStart - 7 * 86400000;
  final withinThirtyDays = todayStart - 30 * 86400000;

  final today = <AiChatSession>[];
  final week = <AiChatSession>[];
  final month = <AiChatSession>[];
  final older = <AiChatSession>[];

  for (final session in sorted) {
    final time = session.sortTime?.millisecondsSinceEpoch ?? 0;
    if (time == 0) {
      older.add(session);
      continue;
    }
    if (time >= todayStart) {
      today.add(session);
    } else if (time >= withinSevenDays) {
      week.add(session);
    } else if (time >= withinThirtyDays) {
      month.add(session);
    } else {
      older.add(session);
    }
  }

  final groups = <AiChatSessionGroup>[];
  if (today.isNotEmpty) {
    groups.add(AiChatSessionGroup(key: 'today', label: '今天', items: today));
  }
  if (week.isNotEmpty) {
    groups.add(AiChatSessionGroup(key: 'week', label: '7天内', items: week));
  }
  if (month.isNotEmpty) {
    groups.add(AiChatSessionGroup(key: 'month', label: '30天内', items: month));
  }
  if (older.isNotEmpty) {
    groups.add(AiChatSessionGroup(key: 'older', label: '更早', items: older));
  }
  return groups;
}
