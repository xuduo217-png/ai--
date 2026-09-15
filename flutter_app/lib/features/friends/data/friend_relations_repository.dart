import '../../../core/network/api_client.dart';
import '../domain/friend_messaging_models.dart';
import '../domain/friend_relation_models.dart';

abstract interface class FriendRelationsRepositoryGateway {
  Future<SearchUserResult> searchUserByPhone({required String phone});

  Future<SendFriendRequestResult> sendFriendRequest({
    required int receiverId,
    required String message,
  });

  Future<FriendPage<FriendRequest>> loadFriendRequests({
    required FriendRequestStatus status,
    required int page,
    required int pageSize,
  });

  Future<void> acceptFriendRequest({required int requestId});
  Future<void> rejectFriendRequest({required int requestId});

  Future<FriendPage<FriendshipSummary>> loadFriends({
    required int page,
    required int pageSize,
  });

  Future<FriendRelationshipSummary> loadRelationshipSummary({
    required int targetUserId,
  });

  Future<void> updateFriendRemark({
    required int friendId,
    required String remark,
  });

  Future<void> deleteFriend({required int friendId});

  Future<void> blockFriendChat({required int blockedUserId});
  Future<void> unblockFriendChat({required int blockedUserId});

  Future<FriendPage<FriendChatBlock>> loadFriendChatBlocks({
    required int page,
    required int pageSize,
  });
}

class FriendRelationsRepository implements FriendRelationsRepositoryGateway {
  const FriendRelationsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<SearchUserResult> searchUserByPhone({required String phone}) async {
    final response = await _apiClient.post(
      '/friends/search-by-phone',
      body: <String, Object?>{'phone': phone},
      authenticated: true,
    );
    return SearchUserResult.fromJson(_asMap(response, 'user search result'));
  }

  @override
  Future<SendFriendRequestResult> sendFriendRequest({
    required int receiverId,
    required String message,
  }) async {
    final response = await _apiClient.post(
      '/friends/request',
      body: <String, Object?>{'receiverId': receiverId, 'message': message},
      authenticated: true,
      allowBusinessFailure: true,
    );
    return SendFriendRequestResult.fromJson(
      _asMap(response, 'friend request result'),
    );
  }

  @override
  Future<FriendPage<FriendRequest>> loadFriendRequests({
    required FriendRequestStatus status,
    required int page,
    required int pageSize,
  }) async {
    final response = await _apiClient.get(
      '/friends/requests',
      queryParameters: <String, Object?>{
        'status': status.name,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return _parsePage(response, FriendRequest.fromJson);
  }

  @override
  Future<void> acceptFriendRequest({required int requestId}) async {
    await _apiClient.post(
      '/friends/requests/$requestId/accept',
      body: const <String, Object?>{},
      authenticated: true,
    );
  }

  @override
  Future<void> rejectFriendRequest({required int requestId}) async {
    await _apiClient.post(
      '/friends/requests/$requestId/reject',
      body: const <String, Object?>{},
      authenticated: true,
    );
  }

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
  Future<FriendRelationshipSummary> loadRelationshipSummary({
    required int targetUserId,
  }) async {
    final response = await _apiClient.get(
      '/friends/relationship/$targetUserId',
    );
    return FriendRelationshipSummary.fromJson(
      _asMap(response, 'friend relationship summary'),
    );
  }

  @override
  Future<void> updateFriendRemark({
    required int friendId,
    required String remark,
  }) async {
    await _apiClient.put(
      '/friends/$friendId/remark',
      body: <String, Object?>{'remark': remark},
    );
  }

  @override
  Future<void> deleteFriend({required int friendId}) async {
    await _apiClient.delete('/friends/$friendId');
  }

  @override
  Future<void> blockFriendChat({required int blockedUserId}) async {
    await _apiClient.post(
      '/friends/chat-blocks',
      body: <String, Object?>{'blockedUserId': blockedUserId},
      authenticated: true,
    );
  }

  @override
  Future<void> unblockFriendChat({required int blockedUserId}) async {
    await _apiClient.delete('/friends/chat-blocks/$blockedUserId');
  }

  @override
  Future<FriendPage<FriendChatBlock>> loadFriendChatBlocks({
    required int page,
    required int pageSize,
  }) async {
    final response = await _apiClient.get(
      '/friends/chat-blocks',
      queryParameters: <String, Object?>{'page': page, 'pageSize': pageSize},
    );
    return _parsePage(response, FriendChatBlock.fromJson);
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
  if (value is Map) return Map<String, Object?>.from(value);
  throw FormatException('$name must be a JSON object.');
}

int _asInt(Object? value, String name) {
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null) return parsed;
  throw FormatException('$name must be an integer.');
}
