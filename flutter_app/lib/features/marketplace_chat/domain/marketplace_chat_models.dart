import '../../friends/domain/friend_messaging_models.dart';

class MarketplacePeer {
  const MarketplacePeer({
    required this.id,
    required this.nickname,
    this.username,
    this.avatar,
  });

  final int id;
  final String nickname;
  final String? username;
  final String? avatar;

  factory MarketplacePeer.fromJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    return MarketplacePeer(
      id: id,
      nickname: _text(json['nickname']).isEmpty
          ? (_text(json['username']).isEmpty
                ? '用户$id'
                : _text(json['username']))
          : _text(json['nickname']),
      username: _nullableText(json['username']),
      avatar: _nullableText(json['avatar']),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'nickname': nickname,
    'username': username,
    'avatar': avatar,
  };
}

class MarketplaceProductSnapshot {
  const MarketplaceProductSnapshot({
    required this.id,
    required this.name,
    required this.isActive,
    required this.isSold,
    this.image,
    this.price,
  });

  final int id;
  final String name;
  final String? image;
  final double? price;
  final bool isActive;
  final bool isSold;

  factory MarketplaceProductSnapshot.fromJson(Map<String, dynamic> json) {
    return MarketplaceProductSnapshot(
      id: _int(json['id']),
      name: _text(json['name']).isEmpty ? '商品已不可见' : _text(json['name']),
      image: _nullableText(json['image']),
      price: _nullableDouble(json['price']),
      isActive: _bool(json['isActive']),
      isSold: _bool(json['isSold']),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'price': price,
    'isActive': isActive,
    'isSold': isSold,
  };
}

class MarketplaceConversation {
  const MarketplaceConversation({
    required this.conversationId,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.role,
    required this.peer,
    required this.product,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
  });

  final String conversationId;
  final int productId;
  final int buyerId;
  final int sellerId;
  final String role;
  final MarketplacePeer peer;
  final MarketplaceProductSnapshot product;
  final MarketplaceLastMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get sortTime => lastMessage?.createdAt ?? updatedAt;

  MarketplaceConversation copyWith({
    MarketplaceLastMessage? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return MarketplaceConversation(
      conversationId: conversationId,
      productId: productId,
      buyerId: buyerId,
      sellerId: sellerId,
      role: role,
      peer: peer,
      product: product,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MarketplaceConversation.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return MarketplaceConversation(
      conversationId: _text(json['conversationId']),
      productId: _int(json['productId']),
      buyerId: _int(json['buyerId']),
      sellerId: _int(json['sellerId']),
      role: _text(json['role']),
      peer: MarketplacePeer.fromJson(_map(json['peer'])),
      product: MarketplaceProductSnapshot.fromJson(_map(json['product'])),
      lastMessage: json['lastMessage'] is Map
          ? MarketplaceLastMessage.fromJson(_map(json['lastMessage']))
          : null,
      unreadCount: _int(json['unreadCount']),
      createdAt: parseFriendDateTime(json['createdAt']) ?? now,
      updatedAt: parseFriendDateTime(json['updatedAt']) ?? now,
    );
  }

  Map<String, Object?> toJson() => {
    'conversationId': conversationId,
    'productId': productId,
    'buyerId': buyerId,
    'sellerId': sellerId,
    'role': role,
    'peer': peer.toJson(),
    'product': product.toJson(),
    'lastMessage': lastMessage?.toJson(),
    'unreadCount': unreadCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class MarketplaceLastMessage {
  const MarketplaceLastMessage({
    required this.messageId,
    required this.messageType,
    required this.content,
    required this.senderId,
    required this.createdAt,
  });

  final String messageId;
  final String messageType;
  final String content;
  final int senderId;
  final DateTime createdAt;

  factory MarketplaceLastMessage.fromJson(Map<String, dynamic> json) {
    return MarketplaceLastMessage(
      messageId: _text(json['messageId']),
      messageType: _text(json['messageType']),
      content: _text(json['content']),
      senderId: _int(json['senderId']),
      createdAt:
          parseFriendDateTime(json['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  factory MarketplaceLastMessage.fromMessage(FriendMessage message) {
    return MarketplaceLastMessage(
      messageId: message.messageId ?? message.tempMessageId ?? message.localKey,
      messageType: message.messageType,
      content: message.content,
      senderId: message.senderId,
      createdAt: message.createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'messageId': messageId,
    'messageType': messageType,
    'content': content,
    'senderId': senderId,
    'createdAt': createdAt.toIso8601String(),
  };
}

class MarketplacePage<T> {
  const MarketplacePage({
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

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

String _text(Object? value) => value == null ? '' : '$value'.trim();

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty || text == 'null' ? null : text;
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;

double? _nullableDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(_text(value));

bool _bool(Object? value) => switch (value) {
  true || 1 || '1' || 'true' => true,
  _ => false,
};
