import '../../../core/network/api_client.dart';
import '../../friends/domain/friend_messaging_models.dart';
import '../domain/marketplace_chat_models.dart';

abstract interface class MarketplaceChatRepositoryGateway {
  Future<MarketplaceConversation> openConversation(int productId);
  Future<MarketplaceConversation> loadConversation(String conversationId);
  Future<MarketplacePage<MarketplaceConversation>> loadConversations({
    int page = 1,
    int pageSize = 50,
  });
  Future<MarketplacePage<FriendMessage>> loadMessages({
    required String conversationId,
    required int page,
    int pageSize = 50,
  });
  Future<int> loadUnreadCount();
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  });
  Future<void> markConversationRead(String conversationId);
  Future<void> reportMessage(String messageId, {String? description});
  Future<void> blockUser(int userId);
}

abstract interface class MarketplaceMessageRecallGateway {
  Future<FriendMessage> revokeMessage(String messageId);
}

class MarketplaceChatRepository
    implements
        MarketplaceChatRepositoryGateway,
        MarketplaceMessageRecallGateway {
  const MarketplaceChatRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<MarketplaceConversation> openConversation(int productId) async {
    final payload = await _apiClient.post(
      '/marketplace-chat/conversations',
      authenticated: true,
      body: {'productId': productId},
    );
    return MarketplaceConversation.fromJson(_map(_unwrapBusinessData(payload)));
  }

  @override
  Future<MarketplaceConversation> loadConversation(
    String conversationId,
  ) async {
    final payload = await _apiClient.get(
      '/marketplace-chat/conversations/$conversationId',
    );
    return MarketplaceConversation.fromJson(_map(_unwrapBusinessData(payload)));
  }

  @override
  Future<MarketplacePage<MarketplaceConversation>> loadConversations({
    int page = 1,
    int pageSize = 50,
  }) async {
    final payload = await _apiClient.get(
      '/marketplace-chat/conversations',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return _page(payload, MarketplaceConversation.fromJson);
  }

  @override
  Future<MarketplacePage<FriendMessage>> loadMessages({
    required String conversationId,
    required int page,
    int pageSize = 50,
  }) async {
    final payload = await _apiClient.get(
      '/marketplace-chat/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return _page(payload, FriendMessage.fromJson);
  }

  @override
  Future<int> loadUnreadCount() async {
    final payload = _map(
      _unwrapBusinessData(
        await _apiClient.get('/marketplace-chat/unread-count'),
      ),
    );
    return _int(payload['count']);
  }

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {
    await _apiClient.post(
      '/marketplace-chat/messages/read',
      authenticated: true,
      body: {'messageId': messageId, 'conversationId': conversationId},
    );
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    await _apiClient.post(
      '/marketplace-chat/conversations/$conversationId/read',
      authenticated: true,
    );
  }

  @override
  Future<FriendMessage> revokeMessage(String messageId) async {
    final payload = await _apiClient.post(
      '/marketplace-chat/messages/$messageId/revoke',
      authenticated: true,
    );
    final envelope = _map(payload);
    final data = _map(envelope['data']);
    return FriendMessage.fromJson(
      _map(data['message'] ?? envelope['message'] ?? data),
    );
  }

  @override
  Future<void> reportMessage(String messageId, {String? description}) async {
    await _apiClient.post(
      '/moderation/reports',
      authenticated: true,
      body: {
        'targetType': 'MARKETPLACE_MESSAGE',
        'targetId': messageId,
        'reason': 'OTHER',
        if (description?.trim().isNotEmpty == true)
          'description': description!.trim(),
      },
    );
  }

  @override
  Future<void> blockUser(int userId) async {
    await _apiClient.post(
      '/moderation/blocks',
      authenticated: true,
      body: {'blockedUserId': userId, 'reason': '商城聊天'},
    );
  }
}

MarketplacePage<T> _page<T>(
  Object? payload,
  T Function(Map<String, dynamic>) parser,
) {
  final root = _map(payload);
  final rawItems = root['data'] is List ? root['data'] as List : const [];
  final pagination = _map(root['pagination']).isNotEmpty
      ? _map(root['pagination'])
      : root;
  final page = _int(pagination['page']);
  final pageSize = _int(pagination['pageSize']);
  final total = _int(pagination['total']);
  return MarketplacePage(
    items: rawItems.map((item) => parser(_map(item))).toList(growable: false),
    page: page == 0 ? 1 : page,
    pageSize: pageSize == 0 ? 50 : pageSize,
    total: total,
    totalPages: _int(pagination['totalPages']) == 0 && total > 0
        ? (total / (pageSize == 0 ? 50 : pageSize)).ceil()
        : _int(pagination['totalPages']),
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

Object? _unwrapBusinessData(Object? value) {
  final payload = _map(value);
  return payload['success'] == true && payload.containsKey('data')
      ? payload['data']
      : value;
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
