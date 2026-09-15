import 'dart:convert';

enum ChatMessageType {
  text,
  image,
  video,
  system,
  aiConsultation,
  autoReply,
  paymentSuccess,
  paymentPrompt;

  String get wireValue => switch (this) {
    ChatMessageType.text => 'TEXT',
    ChatMessageType.image => 'IMAGE',
    ChatMessageType.video => 'VIDEO',
    ChatMessageType.system => 'SYSTEM',
    ChatMessageType.aiConsultation => 'AI_CONSULTATION',
    ChatMessageType.autoReply => 'AUTO_REPLY',
    ChatMessageType.paymentSuccess => 'PAYMENT_SUCCESS',
    ChatMessageType.paymentPrompt => 'PAYMENT_PROMPT',
  };

  static ChatMessageType fromWire(Object? value) {
    return ChatMessageType.values.firstWhere(
      (type) => type.wireValue == '$value'.toUpperCase(),
      orElse: () => ChatMessageType.text,
    );
  }
}

enum ChatSessionStatus {
  free,
  paid,
  expired;

  static ChatSessionStatus fromWire(Object? value) {
    return switch ('$value'.toUpperCase()) {
      'PAID' => ChatSessionStatus.paid,
      'EXPIRED' => ChatSessionStatus.expired,
      _ => ChatSessionStatus.free,
    };
  }
}

class ChatTarget {
  const ChatTarget({
    required this.doctorId,
    required this.name,
    required this.avatarUrl,
  });

  final int doctorId;
  final String name;
  final String avatarUrl;
}

class ChatPackage {
  const ChatPackage({
    required this.id,
    required this.name,
    required this.duration,
    required this.price,
    required this.isActive,
    this.durationDays,
    this.description,
  });

  final int id;
  final String name;
  final int duration;
  final int? durationDays;
  final double price;
  final String? description;
  final bool isActive;

  int get displayDays => durationDays ?? (duration / 60 / 24).ceil();

  factory ChatPackage.fromJson(Map<String, dynamic> json) {
    return ChatPackage(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}',
      duration: _toInt(json['duration']),
      durationDays: json['durationDays'] == null
          ? null
          : _toInt(json['durationDays']),
      price: _toDouble(json['price']),
      description: _optionalString(json['description']),
      isActive: json['isActive'] != false,
    );
  }
}

enum ChatPackageOrderStatus {
  pending,
  paid,
  cancelled,
  expired,
  unknown;

  static ChatPackageOrderStatus fromWire(Object? value) {
    return switch ('$value'.toUpperCase()) {
      'PENDING' => ChatPackageOrderStatus.pending,
      'PAID' => ChatPackageOrderStatus.paid,
      'CANCELLED' => ChatPackageOrderStatus.cancelled,
      'EXPIRED' => ChatPackageOrderStatus.expired,
      _ => ChatPackageOrderStatus.unknown,
    };
  }
}

enum ChatPackagePaymentStatus {
  pending,
  processing,
  success,
  failed,
  closed,
  unknown;

  bool get paid => this == ChatPackagePaymentStatus.success;
  bool get terminal => const {
    ChatPackagePaymentStatus.success,
    ChatPackagePaymentStatus.failed,
    ChatPackagePaymentStatus.closed,
  }.contains(this);

  static ChatPackagePaymentStatus fromWire(Object? value) {
    return switch ('$value'.toLowerCase()) {
      'pending' => ChatPackagePaymentStatus.pending,
      'processing' => ChatPackagePaymentStatus.processing,
      'success' => ChatPackagePaymentStatus.success,
      'failed' => ChatPackagePaymentStatus.failed,
      'closed' => ChatPackagePaymentStatus.closed,
      _ => ChatPackagePaymentStatus.unknown,
    };
  }
}

class ChatPackagePayment {
  const ChatPackagePayment({
    required this.orderId,
    required this.orderStatus,
    required this.paymentNo,
    this.alipayOrderString,
  });

  final int orderId;
  final ChatPackageOrderStatus orderStatus;
  final String paymentNo;
  final String? alipayOrderString;

  bool get paid => orderStatus == ChatPackageOrderStatus.paid;
}

class ChatSession {
  const ChatSession({
    required this.conversationId,
    required this.userId,
    required this.doctorId,
    required this.status,
    this.autoReplyCount,
    this.maxFreeReplies,
    this.paymentRequired = false,
    this.serviceStartAt,
    this.serviceEndAt,
    this.remainingSeconds,
    this.availablePackages = const [],
  });

  final String conversationId;
  final int userId;
  final int doctorId;
  final ChatSessionStatus status;
  final int? autoReplyCount;
  final int? maxFreeReplies;
  final bool paymentRequired;
  final DateTime? serviceStartAt;
  final DateTime? serviceEndAt;
  final int? remainingSeconds;
  final List<ChatPackage> availablePackages;

  ChatSession copyWith({
    ChatSessionStatus? status,
    DateTime? serviceStartAt,
    DateTime? serviceEndAt,
    bool? paymentRequired,
  }) {
    return ChatSession(
      conversationId: conversationId,
      userId: userId,
      doctorId: doctorId,
      status: status ?? this.status,
      autoReplyCount: autoReplyCount,
      maxFreeReplies: maxFreeReplies,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      serviceStartAt: serviceStartAt ?? this.serviceStartAt,
      serviceEndAt: serviceEndAt ?? this.serviceEndAt,
      remainingSeconds: remainingSeconds,
      availablePackages: availablePackages,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      conversationId: '${json['conversationId'] ?? ''}',
      userId: _toInt(json['userId']),
      doctorId: _toInt(json['doctorId']),
      status: ChatSessionStatus.fromWire(json['status']),
      autoReplyCount: json['autoReplyCount'] == null
          ? null
          : _toInt(json['autoReplyCount']),
      maxFreeReplies: json['maxFreeReplies'] == null
          ? null
          : _toInt(json['maxFreeReplies']),
      paymentRequired: json['paymentRequired'] == true,
      serviceStartAt: _toDateTime(json['serviceStartAt']),
      serviceEndAt: _toDateTime(json['serviceEndAt']),
      remainingSeconds: json['remainingSeconds'] == null
          ? null
          : _toInt(json['remainingSeconds']),
      availablePackages: _mapList(
        json['availablePackages'],
        ChatPackage.fromJson,
      ),
    );
  }
}

class ChatSessionExtension {
  const ChatSessionExtension({
    required this.extensionId,
    required this.conversationId,
    required this.extensionMinutes,
    required this.serviceEndAt,
    required this.status,
    this.userId,
    this.doctorId,
    this.orderId,
    this.previousServiceEndAt,
    this.extendedAt,
  });

  final int extensionId;
  final String conversationId;
  final int extensionMinutes;
  final DateTime serviceEndAt;
  final ChatSessionStatus status;
  final int? userId;
  final int? doctorId;
  final int? orderId;
  final DateTime? previousServiceEndAt;
  final DateTime? extendedAt;

  factory ChatSessionExtension.fromJson(Map<String, dynamic> json) {
    final endAt = _toDateTime(json['serviceEndAt']);
    if (endAt == null) {
      throw const FormatException('会话延长响应缺少 serviceEndAt');
    }
    return ChatSessionExtension(
      extensionId: _toInt(json['extensionId']),
      conversationId: '${json['conversationId'] ?? ''}',
      extensionMinutes: _toInt(json['extensionMinutes']),
      serviceEndAt: endAt,
      status: ChatSessionStatus.fromWire(json['status']),
      userId: json['userId'] == null ? null : _toInt(json['userId']),
      doctorId: json['doctorId'] == null ? null : _toInt(json['doctorId']),
      orderId: json['orderId'] == null ? null : _toInt(json['orderId']),
      previousServiceEndAt: _toDateTime(json['previousServiceEndAt']),
      extendedAt: _toDateTime(json['extendedAt']),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.isAutoReply,
    required this.isRead,
    required this.createdAt,
    this.senderName,
    this.senderType,
    this.receiverType,
    this.packages = const [],
    this.orderId,
    this.localMediaPath,
    this.pending = false,
    this.failed = false,
    this.isRevoked = false,
    this.revokedAt,
  });

  final int id;
  final String conversationId;
  final int? senderId;
  final String? senderName;
  final String? senderType;
  final int receiverId;
  final String? receiverType;
  final String content;
  final ChatMessageType type;
  final bool isAutoReply;
  final bool isRead;
  final DateTime createdAt;
  final List<ChatPackage> packages;
  final int? orderId;
  final String? localMediaPath;
  final bool pending;
  final bool failed;
  final bool isRevoked;
  final DateTime? revokedAt;

  bool get isSystem =>
      type == ChatMessageType.system ||
      type == ChatMessageType.aiConsultation ||
      type == ChatMessageType.autoReply;

  ChatMediaContent? get mediaContent {
    if (type != ChatMessageType.image && type != ChatMessageType.video) {
      return null;
    }
    return ChatMediaContent.parse(content);
  }

  ChatMessage copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    String? localMediaPath,
    bool clearLocalMediaPath = false,
    bool? pending,
    bool? failed,
    ChatMessageType? type,
    bool? isRevoked,
    DateTime? revokedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderType: senderType,
      receiverId: receiverId,
      receiverType: receiverType,
      content: content ?? this.content,
      type: type ?? this.type,
      isAutoReply: isAutoReply,
      isRead: isRead,
      createdAt: createdAt ?? this.createdAt,
      packages: packages,
      orderId: orderId,
      localMediaPath: clearLocalMediaPath
          ? null
          : (localMediaPath ?? this.localMediaPath),
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
      isRevoked: isRevoked ?? this.isRevoked,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _toInt(json['id']),
      conversationId: '${json['conversationId'] ?? ''}',
      senderId: json['senderId'] == null ? null : _toInt(json['senderId']),
      senderName: _optionalString(json['senderName']),
      senderType: _optionalString(json['senderType']),
      receiverId: _toInt(json['receiverId']),
      receiverType: _optionalString(json['receiverType']),
      content: '${json['content'] ?? ''}',
      type: ChatMessageType.fromWire(json['type']),
      isAutoReply: json['isAutoReply'] == true,
      isRead: json['isRead'] == true,
      createdAt: _toDateTime(json['createdAt']) ?? DateTime.now(),
      packages: _mapList(json['packages'], ChatPackage.fromJson),
      orderId: json['orderId'] == null ? null : _toInt(json['orderId']),
      isRevoked: json['isRevoked'] == true || json['isRevoked'] == 1,
      revokedAt: _toDateTime(json['revokedAt']),
    );
  }
}

class ChatMediaContent {
  const ChatMediaContent({
    required this.url,
    this.thumbnail,
    this.width,
    this.height,
    this.duration,
    this.size,
    this.fileName,
    this.mimeType,
  });

  final String url;
  final String? thumbnail;
  final int? width;
  final int? height;
  final int? duration;
  final int? size;
  final String? fileName;
  final String? mimeType;

  String toMessageContent() => jsonEncode({
    'url': url,
    if (thumbnail != null) 'thumbnail': thumbnail,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (duration != null) 'duration': duration,
    if (size != null) 'size': size,
    if (fileName != null) 'fileName': fileName,
    if (mimeType != null) 'mimeType': mimeType,
  });

  static ChatMediaContent parse(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final json = Map<String, dynamic>.from(decoded);
        return ChatMediaContent(
          url: '${json['url'] ?? ''}',
          thumbnail: _optionalString(json['thumbnail']),
          width: json['width'] == null ? null : _toInt(json['width']),
          height: json['height'] == null ? null : _toInt(json['height']),
          duration: json['duration'] == null ? null : _toInt(json['duration']),
          size: json['size'] == null ? null : _toInt(json['size']),
          fileName: _optionalString(json['fileName']),
          mimeType: _optionalString(json['mimeType']),
        );
      }
    } on FormatException {
      // 兼容历史版本直接保存 URL 的媒体消息。
    }
    return ChatMediaContent(url: content);
  }
}

class ChatBootstrap {
  const ChatBootstrap({
    required this.session,
    required this.canSend,
    required this.messages,
    required this.doctorOnline,
    required this.availablePackages,
  });

  final ChatSession? session;
  final bool canSend;
  final List<ChatMessage> messages;
  final bool doctorOnline;
  final List<ChatPackage> availablePackages;
}

class ChatUploadResult {
  const ChatUploadResult({
    required this.url,
    this.thumbnail,
    this.width,
    this.height,
    this.size,
    this.originalName,
  });

  final String url;
  final String? thumbnail;
  final int? width;
  final int? height;
  final int? size;
  final String? originalName;

  factory ChatUploadResult.fromJson(Map<String, dynamic> json) {
    return ChatUploadResult(
      url: '${json['url'] ?? ''}',
      thumbnail: _optionalString(json['thumbnail']),
      width: json['width'] == null ? null : _toInt(json['width']),
      height: json['height'] == null ? null : _toInt(json['height']),
      size: json['size'] == null ? null : _toInt(json['size']),
      originalName: _optionalString(json['originalName']),
    );
  }
}

int _toInt(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  _ => int.tryParse('$value') ?? 0,
};

double _toDouble(Object? value) => switch (value) {
  final double number => number,
  final num number => number.toDouble(),
  _ => double.tryParse('$value') ?? 0,
};

String? _optionalString(Object? value) {
  final result = value == null ? '' : '$value'.trim();
  return result.isEmpty ? null : result;
}

DateTime? _toDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
