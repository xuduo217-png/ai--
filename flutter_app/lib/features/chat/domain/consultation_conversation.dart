import 'chat_models.dart';

class ConsultationConversationPage {
  const ConsultationConversationPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<ConsultationConversation> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
}

class ConsultationConversation {
  const ConsultationConversation({
    required this.conversationId,
    required this.userId,
    required this.doctorId,
    required this.doctorName,
    required this.doctorAvatarUrl,
    required this.status,
    required this.paymentRequired,
    required this.isTemporary,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.serviceStartAt,
    this.serviceEndAt,
    this.lastMessage,
  });

  final String conversationId;
  final int userId;
  final int doctorId;
  final String doctorName;
  final String doctorAvatarUrl;
  final ChatSessionStatus status;
  final bool paymentRequired;
  final bool isTemporary;
  final int? orderId;
  final DateTime? serviceStartAt;
  final DateTime? serviceEndAt;
  final ConsultationConversationLastMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get sortTime => lastMessage?.createdAt ?? updatedAt;

  ConsultationConversation copyWith({
    ConsultationConversationLastMessage? lastMessage,
    int? unreadCount,
    ChatSessionStatus? status,
    DateTime? serviceEndAt,
    bool? paymentRequired,
  }) {
    return ConsultationConversation(
      conversationId: conversationId,
      userId: userId,
      doctorId: doctorId,
      doctorName: doctorName,
      doctorAvatarUrl: doctorAvatarUrl,
      status: status ?? this.status,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      isTemporary: isTemporary,
      orderId: orderId,
      serviceStartAt: serviceStartAt,
      serviceEndAt: serviceEndAt ?? this.serviceEndAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ConsultationConversation.fromJson(Map<String, dynamic> json) {
    final createdAt = _dateTime(json['createdAt']) ?? DateTime.now();
    return ConsultationConversation(
      conversationId: '${json['conversationId'] ?? ''}',
      userId: _int(json['userId']),
      doctorId: _int(json['doctorId']),
      doctorName: '${json['doctorName'] ?? ''}',
      doctorAvatarUrl: '${json['doctorAvatar'] ?? ''}',
      status: ChatSessionStatus.fromWire(json['status']),
      paymentRequired: json['paymentRequired'] == true,
      isTemporary: json['isTemporary'] == true,
      orderId: json['orderId'] == null ? null : _int(json['orderId']),
      serviceStartAt: _dateTime(json['serviceStartAt']),
      serviceEndAt: _dateTime(json['serviceEndAt']),
      lastMessage: json['lastMessage'] is Map
          ? ConsultationConversationLastMessage.fromJson(
              Map<String, dynamic>.from(json['lastMessage'] as Map),
            )
          : null,
      unreadCount: _int(json['unreadCount']),
      createdAt: createdAt,
      updatedAt: _dateTime(json['updatedAt']) ?? createdAt,
    );
  }
}

class ConsultationConversationLastMessage {
  const ConsultationConversationLastMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.type,
    required this.isAutoReply,
    required this.createdAt,
    this.senderId,
    this.receiverId,
  });

  final int id;
  final String conversationId;
  final int? senderId;
  final int? receiverId;
  final String content;
  final ChatMessageType type;
  final bool isAutoReply;
  final DateTime createdAt;

  String get preview => switch (type) {
    ChatMessageType.image => '[图片]',
    ChatMessageType.video => '[视频]',
    ChatMessageType.aiConsultation => '[AI 问诊]',
    ChatMessageType.paymentSuccess => '[支付成功]',
    ChatMessageType.paymentPrompt => '[待购买服务]',
    _ => content.trim().isEmpty ? '暂无消息' : content,
  };

  factory ConsultationConversationLastMessage.fromMessage(ChatMessage message) {
    return ConsultationConversationLastMessage(
      id: message.id,
      conversationId: message.conversationId,
      senderId: message.senderId,
      receiverId: message.receiverId,
      content: message.content,
      type: message.type,
      isAutoReply: message.isAutoReply,
      createdAt: message.createdAt,
    );
  }

  factory ConsultationConversationLastMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConsultationConversationLastMessage(
      id: _int(json['id']),
      conversationId: '${json['conversationId'] ?? ''}',
      senderId: json['senderId'] == null ? null : _int(json['senderId']),
      receiverId: json['receiverId'] == null ? null : _int(json['receiverId']),
      content: '${json['content'] ?? ''}',
      type: ChatMessageType.fromWire(json['type']),
      isAutoReply: json['isAutoReply'] == true,
      createdAt: _dateTime(json['createdAt']) ?? DateTime.now(),
    );
  }
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

DateTime? _dateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}
