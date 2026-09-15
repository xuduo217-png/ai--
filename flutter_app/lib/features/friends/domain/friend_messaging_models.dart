enum MessageSendStatus { sending, sent, failed }

enum MediaTransferStage {
  none,
  draft,
  uploading,
  readyToSend,
  sending,
  sent,
  failed,
}

class FriendshipSummary {
  const FriendshipSummary({
    required this.friendId,
    required this.friendName,
    this.serverConversationId,
    this.friendAvatar,
    this.friendSignature,
    this.remark,
    this.lastChatAt,
  });

  final int friendId;
  final String friendName;
  final String? serverConversationId;
  final String? friendAvatar;
  final String? friendSignature;
  final String? remark;
  final DateTime? lastChatAt;

  String get displayName {
    final value = remark?.trim();
    return value == null || value.isEmpty ? friendName : value;
  }

  FriendshipSummary copyWith({
    String? friendName,
    String? serverConversationId,
    String? friendAvatar,
    String? friendSignature,
    String? remark,
    DateTime? lastChatAt,
  }) {
    return FriendshipSummary(
      friendId: friendId,
      friendName: friendName ?? this.friendName,
      serverConversationId: serverConversationId ?? this.serverConversationId,
      friendAvatar: friendAvatar ?? this.friendAvatar,
      friendSignature: friendSignature ?? this.friendSignature,
      remark: remark ?? this.remark,
      lastChatAt: lastChatAt ?? this.lastChatAt,
    );
  }

  String conversationIdFor(int ownerUserId) {
    final serverValue = serverConversationId?.trim();
    if (serverValue != null && serverValue.isNotEmpty) return serverValue;
    return buildFriendConversationId(ownerUserId, friendId);
  }

  factory FriendshipSummary.fromJson(Map<String, dynamic> json) {
    return FriendshipSummary(
      friendId: _toInt(json['friendId']),
      friendName: _firstNonEmptyString([
        json['friendName'],
        json['username'],
        '用户${_toInt(json['friendId'])}',
      ]),
      serverConversationId: _nullableString(json['conversationId']),
      friendAvatar: _nullableString(json['friendAvatar'] ?? json['avatar']),
      friendSignature: _nullableString(
        json['friendSignature'] ?? json['signature'],
      ),
      remark: _nullableString(json['remark']),
      lastChatAt: parseFriendDateTime(json['lastChatAt']),
    );
  }
}

class FriendMessage {
  const FriendMessage({
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.messageType,
    required this.content,
    required this.sendStatus,
    required this.isRead,
    required this.readSynced,
    required this.createdAt,
    required this.updatedAt,
    this.messageId,
    this.tempMessageId,
    this.deliveryMode,
    this.localFilePath,
    this.localThumbnailPath,
    this.localFileExists = false,
    this.mediaStage = MediaTransferStage.none,
    this.isRevoked = false,
    this.revokedAt,
  });

  final String? messageId;
  final String? tempMessageId;
  final String conversationId;
  final int senderId;
  final int receiverId;
  final String messageType;
  final String content;
  final MessageSendStatus sendStatus;
  final bool isRead;
  final bool readSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? deliveryMode;
  final String? localFilePath;
  final String? localThumbnailPath;
  final bool localFileExists;
  final MediaTransferStage mediaStage;
  final bool isRevoked;
  final DateTime? revokedAt;

  String get localKey =>
      messageId ??
      tempMessageId ??
      '${conversationId}_${senderId}_${createdAt.microsecondsSinceEpoch}';

  bool isIncomingFor(int ownerUserId) => receiverId == ownerUserId;

  FriendMessage copyWith({
    String? messageId,
    String? tempMessageId,
    String? content,
    MessageSendStatus? sendStatus,
    bool? isRead,
    bool? readSynced,
    DateTime? updatedAt,
    String? localFilePath,
    String? localThumbnailPath,
    bool? localFileExists,
    MediaTransferStage? mediaStage,
    bool? isRevoked,
    DateTime? revokedAt,
  }) {
    return FriendMessage(
      messageId: messageId ?? this.messageId,
      tempMessageId: tempMessageId ?? this.tempMessageId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      messageType: messageType,
      content: content ?? this.content,
      sendStatus: sendStatus ?? this.sendStatus,
      isRead: isRead ?? this.isRead,
      readSynced: readSynced ?? this.readSynced,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryMode: deliveryMode,
      localFilePath: localFilePath ?? this.localFilePath,
      localThumbnailPath: localThumbnailPath ?? this.localThumbnailPath,
      localFileExists: localFileExists ?? this.localFileExists,
      mediaStage: mediaStage ?? this.mediaStage,
      isRevoked: isRevoked ?? this.isRevoked,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }

  factory FriendMessage.fromJson(Map<String, dynamic> json) {
    final senderId = _toInt(json['senderId']);
    final receiverId = _toInt(json['receiverId']);
    final conversationId = _nullableString(json['conversationId']);
    final createdAt =
        parseFriendDateTime(json['createdAt']) ?? DateTime.now().toUtc();
    final updatedAt = parseFriendDateTime(json['updatedAt']) ?? createdAt;
    final rawMessageId = json['messageId'] ?? json['id'];

    return FriendMessage(
      messageId: _nullableString(rawMessageId),
      tempMessageId: _nullableString(json['tempMessageId']),
      conversationId:
          conversationId ?? buildFriendConversationId(senderId, receiverId),
      senderId: senderId,
      receiverId: receiverId,
      messageType: _nullableString(json['messageType']) ?? 'text',
      content: '${json['content'] ?? ''}',
      sendStatus: MessageSendStatus.sent,
      isRead: _toBool(json['isRead']),
      readSynced: true,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deliveryMode: _nullableString(json['deliveryMode']),
      mediaStage:
          const {'image', 'video', 'voice'}.contains(json['messageType'])
          ? MediaTransferStage.sent
          : MediaTransferStage.none,
      isRevoked: _toBool(json['isRevoked']),
      revokedAt: parseFriendDateTime(json['revokedAt']),
    );
  }
}

class FriendConversation {
  const FriendConversation({
    required this.conversationId,
    required this.friendId,
    required this.friendName,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.hidden,
    this.friendAvatar,
    this.friendSignature,
    this.lastMessage,
    this.lastMessageType,
  });

  final String conversationId;
  final int friendId;
  final String friendName;
  final String? friendAvatar;
  final String? friendSignature;
  final String? lastMessage;
  final String? lastMessageType;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool hidden;
}

class FriendPage<T> {
  const FriendPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class FriendMessageAck {
  const FriendMessageAck({
    required this.tempMessageId,
    required this.success,
    this.messageId,
    this.message,
    this.errorMessage,
  });

  final String tempMessageId;
  final bool success;
  final String? messageId;
  final FriendMessage? message;
  final String? errorMessage;
}

class FriendReadReceipt {
  const FriendReadReceipt({
    required this.messageId,
    required this.conversationId,
    required this.readerId,
  });

  final String messageId;
  final String conversationId;
  final int readerId;
}

class FriendshipDeletedEvent {
  const FriendshipDeletedEvent({
    required this.friendId,
    required this.deletedByUserId,
  });

  final int friendId;
  final int deletedByUserId;
}

class SessionRevokedEvent {
  const SessionRevokedEvent({this.reason});

  final String? reason;
}

String buildFriendConversationId(int firstUserId, int secondUserId) {
  final smaller = firstUserId < secondUserId ? firstUserId : secondUserId;
  final larger = firstUserId < secondUserId ? secondUserId : firstUserId;
  return '${smaller}_$larger';
}

DateTime? parseFriendDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is num) {
    final milliseconds = value.abs() < 100000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds.toInt(),
      isUtc: true,
    );
  }
  return DateTime.tryParse('$value')?.toUtc();
}

int _toInt(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  _ => int.tryParse('$value') ?? 0,
};

bool _toBool(Object? value) => switch (value) {
  true => true,
  1 => true,
  final String text => text == '1' || text.toLowerCase() == 'true',
  _ => false,
};

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

String _firstNonEmptyString(List<Object?> values) {
  for (final value in values) {
    final text = _nullableString(value);
    if (text != null) return text;
  }
  return '';
}
