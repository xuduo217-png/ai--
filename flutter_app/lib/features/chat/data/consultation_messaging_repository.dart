import '../../../core/network/api_client.dart';
import '../domain/consultation_conversation.dart';

abstract interface class ConsultationMessagingRepositoryGateway {
  Future<ConsultationConversationPage> loadConversations({
    int page = 1,
    int pageSize = 100,
  });
  Future<int> loadUnreadCount();
  Future<void> markConversationRead(String conversationId);
}

class ConsultationMessagingRepository
    implements ConsultationMessagingRepositoryGateway {
  const ConsultationMessagingRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<ConsultationConversationPage> loadConversations({
    int page = 1,
    int pageSize = 100,
  }) async {
    final payload = await _apiClient.get(
      '/chat/conversations',
      queryParameters: {'page': page, 'limit': pageSize},
    );
    final root = _map(payload);
    final items = root['data'] is List ? root['data'] as List : const [];
    final pagination = root['pagination'] is Map
        ? _map(root['pagination'])
        : root;
    final total = _int(pagination['total']);
    final resolvedPageSize = _int(
      pagination['pageSize'] ?? pagination['limit'],
    );
    final safePageSize = resolvedPageSize > 0 ? resolvedPageSize : pageSize;
    final totalPages = _int(pagination['totalPages']);
    return ConsultationConversationPage(
      items: items
          .map((item) => ConsultationConversation.fromJson(_map(item)))
          .toList(growable: false),
      page: _int(pagination['page']) > 0 ? _int(pagination['page']) : page,
      pageSize: safePageSize,
      total: total,
      totalPages: totalPages > 0 || total == 0
          ? totalPages
          : (total / safePageSize).ceil(),
    );
  }

  @override
  Future<int> loadUnreadCount() async {
    final payload = await _apiClient.get('/chat/unread-count');
    if (payload is num) return payload.toInt();
    if (payload is Map) {
      final value = payload['count'];
      return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    }
    return int.tryParse('$payload') ?? 0;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    final encodedId = Uri.encodeComponent(conversationId);
    await _apiClient.put('/chat/conversations/$encodedId/read');
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
