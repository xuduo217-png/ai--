import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';

abstract interface class FriendsRepositoryGateway {
  Future<FriendPage<FriendshipSummary>> loadFriends({
    required int page,
    required int pageSize,
  });

  Future<FriendPage<FriendMessage>> loadMessageHistory({
    required int friendId,
    required int page,
    required int pageSize,
  });

  Future<int> loadUnreadCount();

  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  });
}

abstract interface class FriendsMessageRecallGateway {
  Future<FriendMessage> revokeMessage({required String messageId});
}

class FriendsRepository
    implements FriendsRepositoryGateway, FriendsMessageRecallGateway {
  const FriendsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<FriendPage<FriendshipSummary>> loadFriends({
    required int page,
    required int pageSize,
  }) async {
    final response = await _apiClient.get(
      '/friends',
      queryParameters: <String, Object?>{'page': page, 'pageSize': pageSize},
    );
    return _parsePage(response, FriendshipSummary.fromJson);
  }

  @override
  Future<FriendPage<FriendMessage>> loadMessageHistory({
    required int friendId,
    required int page,
    required int pageSize,
  }) async {
    final response = await _apiClient.get(
      '/friends/messages/$friendId/history',
      queryParameters: <String, Object?>{'page': page, 'pageSize': pageSize},
    );
    return _parsePage(response, FriendMessage.fromJson);
  }

  @override
  Future<int> loadUnreadCount() async {
    final response = await _apiClient.get('/friends/messages/unread-count');
    final data = _asMap(response, 'unread count');
    return _asInt(data['count'], 'count');
  }

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {
    await _apiClient.post(
      '/friends/messages/read',
      body: <String, Object?>{
        'messageId': messageId,
        'conversationId': conversationId,
      },
      authenticated: true,
    );
  }

  @override
  Future<FriendMessage> revokeMessage({required String messageId}) async {
    final response = await _apiClient.post(
      '/friends/messages/$messageId/revoke',
      authenticated: true,
    );
    final envelope = _asMap(response, 'revoke message response');
    final data = envelope['data'] is Map
        ? Map<String, Object?>.from(envelope['data']! as Map)
        : envelope;
    return FriendMessage.fromJson(_asMap(data['message'] ?? data, 'message'));
  }
}

FriendPage<T> _parsePage<T>(
  Object? response,
  T Function(Map<String, Object?> json) fromJson,
) {
  final envelope = _asMap(response, 'paginated response');
  final rawItems = envelope['data'];
  if (rawItems is! List<Object?>) {
    throw const FormatException('Paginated response data must be a list.');
  }

  final pagination = envelope['pagination'] is Map
      ? Map<String, Object?>.from(envelope['pagination']! as Map)
      : envelope;
  final page = _asInt(pagination['page'], 'page');
  final pageSize = _asInt(pagination['pageSize'], 'pageSize');
  final total = _asInt(pagination['total'], 'total');
  final totalPages = pagination['totalPages'] == null
      ? (total == 0 ? 0 : (total / pageSize).ceil())
      : _asInt(pagination['totalPages'], 'totalPages');

  return FriendPage<T>(
    items: rawItems
        .map((item) => fromJson(_asMap(item, 'page item')))
        .toList(growable: false),
    page: page,
    pageSize: pageSize,
    total: total,
    totalPages: totalPages,
  );
}

Map<String, Object?> _asMap(Object? value, String name) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$name must be a JSON object.');
}

int _asInt(Object? value, String name) {
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null) return parsed;
  throw FormatException('$name must be an integer.');
}
