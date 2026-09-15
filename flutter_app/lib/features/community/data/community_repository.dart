import '../../../core/network/api_client.dart';
import '../domain/community_models.dart';

class CommunityRepository implements CommunityGateway {
  const CommunityRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CommunityPage<CommunityPost>> loadCommunityPosts({
    required bool authenticated,
    required CommunityFeedType type,
    int page = 1,
    int pageSize = 10,
    String tag = '',
  }) async {
    final response = await _apiClient.get(
      '/community/posts',
      authenticated: authenticated,
      queryParameters: {
        'type': type.wireValue,
        'page': page,
        'limit': pageSize,
        if (tag.trim().isNotEmpty) 'tag': tag.trim(),
      },
    );
    return _page(
      response,
      CommunityPost.fromJson,
      fallbackPage: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<CommunityPost> loadCommunityPost(
    int postId, {
    required bool authenticated,
  }) async {
    return CommunityPost.fromJson(
      _map(
        await _apiClient.get(
          '/community/posts/$postId',
          authenticated: authenticated,
        ),
      ),
    );
  }

  @override
  Future<CommunityPost> createCommunityPost(CommunityPostDraft draft) async {
    return CommunityPost.fromJson(
      _map(
        await _apiClient.post(
          '/community/posts',
          authenticated: true,
          body: draft.toJson(),
        ),
      ),
    );
  }

  @override
  Future<CommunityPost> updateCommunityPost(
    int postId,
    CommunityPostDraft draft,
  ) async {
    return CommunityPost.fromJson(
      _map(
        await _apiClient.put('/community/posts/$postId', body: draft.toJson()),
      ),
    );
  }

  @override
  Future<void> deleteCommunityPost(int postId) async {
    await _apiClient.delete('/community/posts/$postId');
  }

  @override
  Future<List<CommunityPost>> loadCommunityUserPosts(
    int userId, {
    required bool authenticated,
  }) async {
    final response = await _apiClient.get(
      '/community/posts/user/$userId',
      authenticated: authenticated,
    );
    final payload = response is Map
        ? _list(_map(response)['data'])
        : _list(response);
    return payload
        .whereType<Map>()
        .map((item) => CommunityPost.fromJson(_map(item)))
        .toList(growable: false);
  }

  @override
  Future<CommunityProfile> loadCommunityProfile(
    int userId, {
    required bool authenticated,
  }) async {
    return CommunityProfile.fromJson(
      _map(
        await _apiClient.get(
          '/community/users/$userId/profile',
          authenticated: authenticated,
        ),
      ),
    );
  }

  @override
  Future<CommunityProfile> updateCommunityProfile({
    required String bio,
    String coverImageUrl = '',
  }) async {
    return CommunityProfile.fromJson(
      _map(
        await _apiClient.put(
          '/community/profile',
          body: {
            'bio': bio.trim(),
            if (coverImageUrl.trim().isNotEmpty)
              'coverImage': coverImageUrl.trim(),
          },
        ),
      ),
    );
  }

  @override
  Future<CommunityRelationship> followCommunityUser(int userId) async {
    return CommunityRelationship.fromJson(
      _map(
        await _apiClient.post(
          '/community/users/$userId/follow',
          authenticated: true,
        ),
      ),
    );
  }

  @override
  Future<CommunityRelationship> unfollowCommunityUser(int userId) async {
    return CommunityRelationship.fromJson(
      _map(await _apiClient.delete('/community/users/$userId/follow')),
    );
  }

  @override
  Future<CommunityPage<CommunityRelationUser>> loadCommunityConnections({
    required int userId,
    required CommunityConnectionType type,
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
    String keyword = '',
  }) async {
    final segment = type == CommunityConnectionType.followers
        ? 'followers'
        : 'followings';
    final response = await _apiClient.get(
      '/community/users/$userId/$segment',
      authenticated: authenticated,
      queryParameters: {
        'page': page,
        'limit': pageSize,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      },
    );
    return _page(
      response,
      CommunityRelationUser.fromJson,
      fallbackPage: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> likeCommunityPost(int postId) async {
    await _apiClient.post('/community/posts/$postId/like', authenticated: true);
  }

  @override
  Future<void> unlikeCommunityPost(int postId) async {
    await _apiClient.delete('/community/posts/$postId/like');
  }

  @override
  Future<CommunityPage<CommunityComment>> loadCommunityComments(
    int postId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/community/posts/$postId/comments',
      authenticated: authenticated,
      queryParameters: {'page': page, 'limit': pageSize},
    );
    return _page(
      response,
      CommunityComment.fromJson,
      fallbackPage: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<CommunityComment> createCommunityComment(
    int postId, {
    required String content,
    int? parentId,
  }) async {
    return CommunityComment.fromJson(
      _map(
        await _apiClient.post(
          '/community/posts/$postId/comments',
          authenticated: true,
          body: {'content': content.trim(), 'parentId': ?parentId},
        ),
      ),
    );
  }

  @override
  Future<void> deleteCommunityComment(int commentId) async {
    await _apiClient.delete('/community/comments/$commentId');
  }

  @override
  Future<void> likeCommunityComment(int commentId) async {
    await _apiClient.post(
      '/community/comments/$commentId/like',
      authenticated: true,
    );
  }

  @override
  Future<void> unlikeCommunityComment(int commentId) async {
    await _apiClient.delete('/community/comments/$commentId/like');
  }

  @override
  Future<List<CommunityTag>> loadCommunityHotTags() async {
    final response = await _apiClient.get(
      '/community/tags/hot',
      authenticated: true,
    );
    return _list(response)
        .whereType<Map>()
        .map((item) => CommunityTag.fromJson(_map(item)))
        .toList(growable: false);
  }

  @override
  Future<List<CommunityTag>> searchCommunityTags(String keyword) async {
    final response = await _apiClient.get(
      '/community/tags/search',
      authenticated: true,
      queryParameters: {'keyword': keyword.trim()},
    );
    return _list(response)
        .whereType<Map>()
        .map((item) => CommunityTag.fromJson(_map(item)))
        .toList(growable: false);
  }

  @override
  Future<CommunityMediaUpload> uploadCommunityImage({
    required String filePath,
    String? filename,
    String category = 'community-post',
  }) async {
    final response = _map(
      await _apiClient.uploadFile(
        '/upload/image',
        filePath: filePath,
        filename: filename,
        fields: {'category': category},
      ),
    );
    final url = _text(response['url']);
    if (url.isEmpty) {
      throw const ApiException('上传成功，但服务器未返回图片地址');
    }
    return CommunityMediaUpload(url: url);
  }

  @override
  Future<CommunityMediaUpload> uploadCommunityVideo({
    required String filePath,
    String? filename,
  }) async {
    final response = _map(
      await _apiClient.uploadVideo(
        '/upload/file',
        filePath: filePath,
        filename: filename,
        fields: const {'category': 'community-post'},
      ),
    );
    final url = _text(response['url']);
    if (url.isEmpty) {
      throw const ApiException('上传成功，但服务器未返回视频地址');
    }
    return CommunityMediaUpload(
      url: url,
      thumbnailUrl: _text(response['thumbnail'] ?? response['videoCover']),
    );
  }

  @override
  Future<void> reportCommunityContent({
    required String targetType,
    required int targetId,
    required String reason,
    String description = '',
  }) async {
    await _apiClient.post(
      '/moderation/reports',
      authenticated: true,
      body: {
        'targetType': targetType,
        'targetId': '$targetId',
        'reason': reason,
        if (description.trim().isNotEmpty) 'description': description.trim(),
      },
    );
  }

  @override
  Future<void> blockCommunityUser(int userId, {String reason = ''}) async {
    await _apiClient.post(
      '/moderation/blocks',
      authenticated: true,
      body: {
        'blockedUserId': userId,
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  @override
  Future<List<CommunityBlockItem>> loadCommunityBlockedUsers() async {
    final response = await _apiClient.get('/moderation/blocks');
    final payload = response is List
        ? _list(response)
        : _list(_map(response)['data']);
    return payload
        .whereType<Map>()
        .map((item) => CommunityBlockItem.fromJson(_map(item)))
        .toList(growable: false);
  }

  @override
  Future<void> unblockCommunityUser(int userId) async {
    await _apiClient.delete('/moderation/blocks/$userId');
  }
}

CommunityPage<T> _page<T>(
  Object? response,
  T Function(Map<String, Object?> json) mapper, {
  required int fallbackPage,
  required int pageSize,
}) {
  final envelope = _map(response);
  final rawItems = response is List ? _list(response) : _list(envelope['data']);
  final items = rawItems
      .whereType<Map>()
      .map((item) => mapper(_map(item)))
      .toList(growable: false);
  final pagination = _map(envelope['pagination'] ?? envelope['meta']);
  final page = _int(pagination['page'], fallbackPage);
  final effectivePageSize = _int(
    pagination['pageSize'] ?? pagination['limit'],
    pageSize,
  );
  final total = _int(pagination['total'], items.length);
  final explicitTotalPages = _int(pagination['totalPages'], 0);
  final totalPages = explicitTotalPages > 0
      ? explicitTotalPages
      : total == 0
      ? 0
      : (total / effectivePageSize).ceil();
  return CommunityPage<T>(
    items: items,
    total: total,
    page: page,
    pageSize: effectivePageSize,
    totalPages: totalPages,
  );
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _list(Object? value) {
  return value is List ? value.cast<Object?>() : const <Object?>[];
}

int _int(Object? value, int fallback) {
  return switch (value) {
    final int current => current,
    final num current => current.toInt(),
    _ => int.tryParse('$value') ?? fallback,
  };
}

String _text(Object? value) => value == null ? '' : '$value'.trim();
