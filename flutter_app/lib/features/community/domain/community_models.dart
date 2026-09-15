enum CommunityFeedType {
  following('following', '关注'),
  recommend('recommend', '推荐');

  const CommunityFeedType(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

enum CommunityConnectionType {
  followers('粉丝列表'),
  following('关注列表');

  const CommunityConnectionType(this.title);

  final String title;
}

typedef CommunityLoginRequest = Future<bool> Function(String message);

class CommunityUser {
  const CommunityUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
    required this.coverImageUrl,
    required this.verified,
    this.createdAt,
  });

  factory CommunityUser.fromJson(Map<String, Object?> json) {
    final id = _int(json['id']);
    final username = _text(json['username']);
    final nickname = _firstText([
      json['nickname'],
      json['username'],
      json['phone'],
      id > 0 ? '用户$id' : null,
    ]);
    return CommunityUser(
      id: id,
      username: username,
      nickname: nickname.isEmpty ? '匿名用户' : nickname,
      avatarUrl: _text(json['avatar'] ?? json['avatarUrl']),
      bio: _text(json['bio']),
      coverImageUrl: _text(json['coverImage'] ?? json['coverImageUrl']),
      verified: _bool(json['verified']),
      createdAt: _date(json['createdAt']),
    );
  }

  final int id;
  final String username;
  final String nickname;
  final String avatarUrl;
  final String bio;
  final String coverImageUrl;
  final bool verified;
  final DateTime? createdAt;

  CommunityUser copyWith({String? bio, String? coverImageUrl}) {
    return CommunityUser(
      id: id,
      username: username,
      nickname: nickname,
      avatarUrl: avatarUrl,
      bio: bio ?? this.bio,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      verified: verified,
      createdAt: createdAt,
    );
  }
}

class CommunityRelationship {
  const CommunityRelationship({
    required this.isSelf,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isMutualFollow,
  });

  const CommunityRelationship.empty()
    : isSelf = false,
      isFollowing = false,
      isFollowedBy = false,
      isMutualFollow = false;

  factory CommunityRelationship.fromJson(Map<String, Object?> json) {
    return CommunityRelationship(
      isSelf: _bool(json['isSelf']),
      isFollowing: _bool(json['isFollowing']),
      isFollowedBy: _bool(json['isFollowedBy']),
      isMutualFollow: _bool(json['isMutualFollow']),
    );
  }

  final bool isSelf;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isMutualFollow;
}

class CommunityProfileStats {
  const CommunityProfileStats({
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
  });

  factory CommunityProfileStats.fromJson(Map<String, Object?> json) {
    return CommunityProfileStats(
      postCount: _int(json['postCount']),
      followerCount: _int(json['followerCount']),
      followingCount: _int(json['followingCount']),
    );
  }

  final int postCount;
  final int followerCount;
  final int followingCount;

  CommunityProfileStats copyWith({
    int? postCount,
    int? followerCount,
    int? followingCount,
  }) {
    return CommunityProfileStats(
      postCount: postCount ?? this.postCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}

class CommunityProfile {
  const CommunityProfile({
    required this.user,
    required this.stats,
    required this.relationship,
  });

  factory CommunityProfile.fromJson(Map<String, Object?> json) {
    return CommunityProfile(
      user: CommunityUser.fromJson(_map(json['user'])),
      stats: CommunityProfileStats.fromJson(_map(json['stats'])),
      relationship: CommunityRelationship.fromJson(_map(json['relationship'])),
    );
  }

  final CommunityUser user;
  final CommunityProfileStats stats;
  final CommunityRelationship relationship;

  CommunityProfile copyWith({
    CommunityUser? user,
    CommunityProfileStats? stats,
    CommunityRelationship? relationship,
  }) {
    return CommunityProfile(
      user: user ?? this.user,
      stats: stats ?? this.stats,
      relationship: relationship ?? this.relationship,
    );
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.userId,
    required this.author,
    required this.content,
    required this.images,
    required this.videoUrl,
    required this.videoCoverUrl,
    required this.tags,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.isPinned,
    required this.isFeatured,
    required this.isLiked,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory CommunityPost.fromJson(Map<String, Object?> json) {
    final userJson = _map(json['user']);
    final userId = _int(json['userId'] ?? userJson['id']);
    final mergedUser = <String, Object?>{...json, ...userJson, 'id': userId};
    return CommunityPost(
      id: _int(json['id']),
      userId: userId,
      author: CommunityUser.fromJson(mergedUser),
      content: _text(json['content']),
      images: _list(
        json['images'],
      ).map(_text).where((value) => value.isNotEmpty).toList(growable: false),
      videoUrl: _text(json['video'] ?? json['videoUrl']),
      videoCoverUrl: _text(json['videoCover'] ?? json['videoCoverUrl']),
      tags: _list(
        json['tags'],
      ).map(_text).where((value) => value.isNotEmpty).toList(growable: false),
      likeCount: _int(json['likeCount']),
      commentCount: _int(json['commentCount']),
      viewCount: _int(json['viewCount']),
      isPinned: _bool(json['isPinned']),
      isFeatured: _bool(json['isFeatured']),
      isLiked: _bool(json['isLiked']),
      status: _text(json['status']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  final int id;
  final int userId;
  final CommunityUser author;
  final String content;
  final List<String> images;
  final String videoUrl;
  final String videoCoverUrl;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool isPinned;
  final bool isFeatured;
  final bool isLiked;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get coverUrl {
    if (images.isNotEmpty) return images.first;
    return videoCoverUrl;
  }

  CommunityPost copyWith({int? likeCount, int? commentCount, bool? isLiked}) {
    return CommunityPost(
      id: id,
      userId: userId,
      author: author,
      content: content,
      images: images,
      videoUrl: videoUrl,
      videoCoverUrl: videoCoverUrl,
      tags: tags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount,
      isPinned: isPinned,
      isFeatured: isFeatured,
      isLiked: isLiked ?? this.isLiked,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.userId,
    required this.postId,
    required this.content,
    required this.parentId,
    required this.likeCount,
    required this.isLiked,
    required this.author,
    required this.replies,
    this.createdAt,
  });

  factory CommunityComment.fromJson(Map<String, Object?> json) {
    final userJson = _map(json['user']);
    final userId = _int(json['userId'] ?? userJson['id']);
    return CommunityComment(
      id: _int(json['id']),
      userId: userId,
      postId: _int(json['postId']),
      content: _text(json['content']),
      parentId: _nullableInt(json['parentId']),
      likeCount: _int(json['likeCount']),
      isLiked: _bool(json['isLiked']),
      author: CommunityUser.fromJson({...userJson, 'id': userId}),
      replies: _list(json['replies'])
          .whereType<Map>()
          .map((item) => CommunityComment.fromJson(_map(item)))
          .toList(growable: false),
      createdAt: _date(json['createdAt']),
    );
  }

  final int id;
  final int userId;
  final int postId;
  final String content;
  final int? parentId;
  final int likeCount;
  final bool isLiked;
  final CommunityUser author;
  final List<CommunityComment> replies;
  final DateTime? createdAt;

  CommunityComment copyWith({int? likeCount, bool? isLiked}) {
    return CommunityComment(
      id: id,
      userId: userId,
      postId: postId,
      content: content,
      parentId: parentId,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      author: author,
      replies: replies,
      createdAt: createdAt,
    );
  }
}

class CommunityRelationUser {
  const CommunityRelationUser({
    required this.user,
    required this.relationship,
    this.followedAt,
  });

  factory CommunityRelationUser.fromJson(Map<String, Object?> json) {
    return CommunityRelationUser(
      user: CommunityUser.fromJson(json),
      relationship: CommunityRelationship.fromJson(_map(json['relationship'])),
      followedAt: _date(json['followedAt']),
    );
  }

  final CommunityUser user;
  final CommunityRelationship relationship;
  final DateTime? followedAt;

  CommunityRelationUser copyWith({CommunityRelationship? relationship}) {
    return CommunityRelationUser(
      user: user,
      relationship: relationship ?? this.relationship,
      followedAt: followedAt,
    );
  }
}

class CommunityBlockItem {
  const CommunityBlockItem({
    required this.id,
    required this.blockedUserId,
    required this.reason,
    required this.blockedAt,
    required this.blockedUser,
  });

  factory CommunityBlockItem.fromJson(Map<String, Object?> json) {
    final blockedUserId = _int(json['blockedUserId']);
    final userJson = _map(json['blockedUser']);
    return CommunityBlockItem(
      id: _int(json['id']),
      blockedUserId: blockedUserId,
      reason: _text(json['reason']),
      blockedAt: _date(json['blockedAt'] ?? json['createdAt']),
      blockedUser: CommunityUser.fromJson({
        ...userJson,
        'id': _int(userJson['id']) > 0 ? userJson['id'] : blockedUserId,
      }),
    );
  }

  final int id;
  final int blockedUserId;
  final String reason;
  final DateTime? blockedAt;
  final CommunityUser blockedUser;
}

class CommunityTag {
  const CommunityTag({
    required this.id,
    required this.name,
    required this.usageCount,
  });

  factory CommunityTag.fromJson(Map<String, Object?> json) {
    return CommunityTag(
      id: _int(json['id']),
      name: _text(json['name']),
      usageCount: _int(json['usageCount']),
    );
  }

  final int id;
  final String name;
  final int usageCount;
}

class CommunityPage<T> {
  const CommunityPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class CommunityPostDraft {
  const CommunityPostDraft({
    required this.content,
    this.images = const [],
    this.videoUrl = '',
    this.videoCoverUrl = '',
    this.tags = const [],
  });

  final String content;
  final List<String> images;
  final String videoUrl;
  final String videoCoverUrl;
  final List<String> tags;

  String? validate() {
    final normalized = content.trim();
    if (normalized.isEmpty) return '请输入帖子内容';
    if (normalized.length > 10000) return '内容不能超过 10000 字';
    if (images.length > 9) return '最多只能上传 9 张图片';
    if (tags.length > 10) return '最多只能选择 10 个标签';
    return null;
  }

  Map<String, Object?> toJson() => {
    'content': content.trim(),
    if (images.isNotEmpty) 'images': images,
    if (videoUrl.isNotEmpty) 'video': videoUrl,
    if (videoCoverUrl.isNotEmpty) 'videoCover': videoCoverUrl,
    if (tags.isNotEmpty) 'tags': tags,
  };
}

class CommunityMediaUpload {
  const CommunityMediaUpload({required this.url, this.thumbnailUrl = ''});

  final String url;
  final String thumbnailUrl;
}

abstract interface class CommunityGateway {
  Future<CommunityPage<CommunityPost>> loadCommunityPosts({
    required bool authenticated,
    required CommunityFeedType type,
    int page = 1,
    int pageSize = 10,
    String tag = '',
  });

  Future<CommunityPost> loadCommunityPost(
    int postId, {
    required bool authenticated,
  });

  Future<CommunityPost> createCommunityPost(CommunityPostDraft draft);
  Future<CommunityPost> updateCommunityPost(
    int postId,
    CommunityPostDraft draft,
  );
  Future<void> deleteCommunityPost(int postId);
  Future<List<CommunityPost>> loadCommunityUserPosts(
    int userId, {
    required bool authenticated,
  });

  Future<CommunityProfile> loadCommunityProfile(
    int userId, {
    required bool authenticated,
  });

  Future<CommunityProfile> updateCommunityProfile({
    required String bio,
    String coverImageUrl = '',
  });

  Future<CommunityRelationship> followCommunityUser(int userId);
  Future<CommunityRelationship> unfollowCommunityUser(int userId);

  Future<CommunityPage<CommunityRelationUser>> loadCommunityConnections({
    required int userId,
    required CommunityConnectionType type,
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
    String keyword = '',
  });

  Future<void> likeCommunityPost(int postId);
  Future<void> unlikeCommunityPost(int postId);
  Future<CommunityPage<CommunityComment>> loadCommunityComments(
    int postId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
  });

  Future<CommunityComment> createCommunityComment(
    int postId, {
    required String content,
    int? parentId,
  });

  Future<void> deleteCommunityComment(int commentId);
  Future<void> likeCommunityComment(int commentId);
  Future<void> unlikeCommunityComment(int commentId);
  Future<List<CommunityTag>> loadCommunityHotTags();
  Future<List<CommunityTag>> searchCommunityTags(String keyword);
  Future<CommunityMediaUpload> uploadCommunityImage({
    required String filePath,
    String? filename,
    String category = 'community-post',
  });

  Future<CommunityMediaUpload> uploadCommunityVideo({
    required String filePath,
    String? filename,
  });

  Future<void> reportCommunityContent({
    required String targetType,
    required int targetId,
    required String reason,
    String description = '',
  });

  Future<void> blockCommunityUser(int userId, {String reason = ''});
  Future<List<CommunityBlockItem>> loadCommunityBlockedUsers();
  Future<void> unblockCommunityUser(int userId);
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _list(Object? value) {
  return value is List ? value.cast<Object?>() : const <Object?>[];
}

int _int(Object? value) {
  return switch (value) {
    final int current => current,
    final num current => current.toInt(),
    _ => int.tryParse('$value') ?? 0,
  };
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  final parsed = _int(value);
  return parsed > 0 ? parsed : null;
}

bool _bool(Object? value) {
  return value == true || value == 1 || value == '1' || value == 'true';
}

String _text(Object? value) {
  if (value == null || value == 'null') return '';
  return '$value'.trim();
}

String _firstText(List<Object?> values) {
  for (final value in values) {
    final normalized = _text(value);
    if (normalized.isNotEmpty) return normalized;
  }
  return '';
}

DateTime? _date(Object? value) {
  final normalized = _text(value);
  return normalized.isEmpty ? null : DateTime.tryParse(normalized)?.toLocal();
}
