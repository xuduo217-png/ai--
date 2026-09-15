import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/community_models.dart';

class CommunityFeedController extends ChangeNotifier {
  CommunityFeedController({
    required CommunityGateway gateway,
    required this.authenticated,
    CommunityFeedType initialType = CommunityFeedType.recommend,
  }) : _gateway = gateway,
       _type = initialType;

  final CommunityGateway _gateway;
  final bool authenticated;

  CommunityFeedType _type;
  CommunityFeedType get type => _type;

  List<CommunityPost> _posts = const [];
  List<CommunityPost> get posts => _posts;

  bool _loading = false;
  bool get loading => _loading;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  String? _error;
  String? get error => _error;

  int _page = 1;
  int _totalPages = 1;
  bool get hasMore => _page < _totalPages;

  Future<void> load({bool refresh = false}) async {
    if (_loading || _refreshing || _loadingMore) return;
    if (_type == CommunityFeedType.following && !authenticated) {
      _posts = const [];
      _page = 1;
      _totalPages = 0;
      _error = null;
      notifyListeners();
      return;
    }
    if (!refresh && _posts.isNotEmpty) return;
    if (refresh) {
      _refreshing = true;
    } else {
      _loading = true;
    }
    _error = null;
    notifyListeners();
    try {
      final result = await _gateway.loadCommunityPosts(
        authenticated: authenticated,
        type: _type,
      );
      _posts = result.items;
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object catch (error) {
      _error = '$error';
      if (_posts.isEmpty) _totalPages = 0;
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> selectType(CommunityFeedType value) async {
    if (_type == value) return;
    _type = value;
    _posts = const [];
    _page = 1;
    _totalPages = 1;
    _error = null;
    notifyListeners();
    await load();
  }

  Future<void> loadMore() async {
    if (_loading || _refreshing || _loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final result = await _gateway.loadCommunityPosts(
        authenticated: authenticated,
        type: _type,
        page: _page + 1,
      );
      final ids = _posts.map((post) => post.id).toSet();
      _posts = [..._posts, ...result.items.where((post) => ids.add(post.id))];
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object catch (error) {
      _error = '$error';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(int postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final previous = _posts[index];
    final next = previous.copyWith(
      isLiked: !previous.isLiked,
      likeCount: previous.isLiked
          ? (previous.likeCount - 1).clamp(0, 1 << 31)
          : previous.likeCount + 1,
    );
    _posts = [..._posts]..[index] = next;
    notifyListeners();
    try {
      if (previous.isLiked) {
        await _gateway.unlikeCommunityPost(postId);
      } else {
        await _gateway.likeCommunityPost(postId);
      }
    } on Object catch (error) {
      _posts = [..._posts]..[index] = previous;
      _error = '$error';
      notifyListeners();
      rethrow;
    }
  }
}

class CommunitySearchController extends ChangeNotifier {
  CommunitySearchController({
    required CommunityGateway gateway,
    required this.authenticated,
  }) : _gateway = gateway;

  final CommunityGateway _gateway;
  final bool authenticated;

  List<CommunityTag> _tags = const [];
  List<CommunityTag> get tags => _tags;

  List<CommunityPost> _posts = const [];
  List<CommunityPost> get posts => _posts;

  CommunityTag? _selectedTag;
  CommunityTag? get selectedTag => _selectedTag;

  String _keyword = '';
  String get keyword => _keyword;

  bool _loadingTags = false;
  bool get loadingTags => _loadingTags;

  bool _loadingPosts = false;
  bool get loadingPosts => _loadingPosts;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  String? _error;
  String? get error => _error;

  int _page = 1;
  int _totalPages = 1;
  bool get hasMore => _page < _totalPages;

  int _tagRequestId = 0;
  int _postRequestId = 0;

  Future<void> loadHotTags() => searchTags('');

  Future<void> searchTags(String value) async {
    final normalized = value.trim();
    final requestId = ++_tagRequestId;
    _keyword = normalized;
    _selectedTag = null;
    _posts = const [];
    _page = 1;
    _totalPages = 1;
    _loadingTags = true;
    _loadingPosts = false;
    _error = null;
    ++_postRequestId;
    notifyListeners();
    try {
      final result = normalized.isEmpty
          ? await _gateway.loadCommunityHotTags()
          : await _gateway.searchCommunityTags(normalized);
      if (requestId != _tagRequestId) return;
      _tags = result;
    } on Object catch (error) {
      if (requestId != _tagRequestId) return;
      _tags = const [];
      _error = '$error';
    } finally {
      if (requestId == _tagRequestId) {
        _loadingTags = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchAndSelectFirst(String value) async {
    await searchTags(value);
    if (_tags.isEmpty) return;
    final normalized = value.trim().replaceFirst(RegExp(r'^#'), '');
    final match = _tags.firstWhere(
      (tag) => tag.name.replaceFirst(RegExp(r'^#'), '') == normalized,
      orElse: () => _tags.first,
    );
    await selectTag(match);
  }

  Future<void> selectTag(CommunityTag tag) async {
    final requestId = ++_postRequestId;
    _selectedTag = tag;
    _posts = const [];
    _page = 1;
    _totalPages = 1;
    _loadingPosts = true;
    _loadingMore = false;
    _error = null;
    notifyListeners();
    try {
      final result = await _gateway.loadCommunityPosts(
        authenticated: authenticated,
        type: CommunityFeedType.recommend,
        tag: tag.name,
      );
      if (requestId != _postRequestId) return;
      _posts = result.items;
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object catch (error) {
      if (requestId != _postRequestId) return;
      _error = '$error';
      _totalPages = 0;
    } finally {
      if (requestId == _postRequestId) {
        _loadingPosts = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final tag = _selectedTag;
    if (tag == null || _loadingPosts || _loadingMore || !hasMore) return;
    final requestId = _postRequestId;
    _loadingMore = true;
    notifyListeners();
    try {
      final result = await _gateway.loadCommunityPosts(
        authenticated: authenticated,
        type: CommunityFeedType.recommend,
        page: _page + 1,
        tag: tag.name,
      );
      if (requestId != _postRequestId) return;
      final ids = _posts.map((post) => post.id).toSet();
      _posts = [..._posts, ...result.items.where((post) => ids.add(post.id))];
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object catch (error) {
      if (requestId == _postRequestId) _error = '$error';
    } finally {
      if (requestId == _postRequestId) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    final tag = _selectedTag;
    if (tag != null) {
      await selectTag(tag);
      return;
    }
    await searchTags(_keyword);
  }

  Future<void> toggleLike(int postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final previous = _posts[index];
    _posts = [..._posts]
      ..[index] = previous.copyWith(
        isLiked: !previous.isLiked,
        likeCount: previous.isLiked
            ? (previous.likeCount - 1).clamp(0, 1 << 31)
            : previous.likeCount + 1,
      );
    notifyListeners();
    try {
      if (previous.isLiked) {
        await _gateway.unlikeCommunityPost(postId);
      } else {
        await _gateway.likeCommunityPost(postId);
      }
    } on Object {
      _posts = [..._posts]..[index] = previous;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    ++_tagRequestId;
    ++_postRequestId;
    super.dispose();
  }
}

class CommunityPostDetailController extends ChangeNotifier {
  CommunityPostDetailController({
    required CommunityGateway gateway,
    required this.postId,
    required this.authenticated,
  }) : _gateway = gateway;

  final CommunityGateway _gateway;
  final int postId;
  final bool authenticated;

  CommunityPost? _post;
  CommunityPost? get post => _post;

  List<CommunityComment> _comments = const [];
  List<CommunityComment> get comments => _comments;

  bool _loading = false;
  bool get loading => _loading;

  bool _working = false;
  bool get working => _working;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  String? _error;
  String? get error => _error;

  int _commentPage = 1;
  int _commentTotalPages = 1;
  int _commentTotal = 0;
  int get commentTotal => _commentTotal;
  bool get hasMoreComments => _commentPage < _commentTotalPages;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        _gateway.loadCommunityPost(postId, authenticated: authenticated),
        _gateway.loadCommunityComments(postId, authenticated: authenticated),
      ]);
      _post = values[0] as CommunityPost;
      final page = values[1] as CommunityPage<CommunityComment>;
      _comments = page.items;
      _commentPage = page.page;
      _commentTotalPages = page.totalPages;
      _commentTotal = page.total;
    } on Object catch (error) {
      _error = '$error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  Future<void> togglePostLike() async {
    final previous = _post;
    if (previous == null || _working) return;
    _post = previous.copyWith(
      isLiked: !previous.isLiked,
      likeCount: previous.isLiked
          ? (previous.likeCount - 1).clamp(0, 1 << 31)
          : previous.likeCount + 1,
    );
    _working = true;
    notifyListeners();
    try {
      if (previous.isLiked) {
        await _gateway.unlikeCommunityPost(postId);
      } else {
        await _gateway.likeCommunityPost(postId);
      }
    } on Object {
      _post = previous;
      rethrow;
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> toggleCommentLike(int commentId) async {
    if (_working) return;
    final target = _findComment(_comments, commentId);
    if (target == null) return;
    final nextLiked = !target.isLiked;
    _comments = _updateComment(
      _comments,
      commentId,
      (comment) => comment.copyWith(
        isLiked: nextLiked,
        likeCount: nextLiked
            ? comment.likeCount + 1
            : (comment.likeCount - 1).clamp(0, 1 << 31),
      ),
    );
    _working = true;
    notifyListeners();
    try {
      if (nextLiked) {
        await _gateway.likeCommunityComment(commentId);
      } else {
        await _gateway.unlikeCommunityComment(commentId);
      }
    } on Object {
      _comments = _updateComment(_comments, commentId, (_) => target);
      rethrow;
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> createComment(String content, {int? parentId}) async {
    final normalized = content.trim();
    if (normalized.isEmpty || _working) return;
    _working = true;
    notifyListeners();
    try {
      await _gateway.createCommunityComment(
        postId,
        content: normalized,
        parentId: parentId,
      );
      final page = await _gateway.loadCommunityComments(
        postId,
        authenticated: true,
      );
      _comments = page.items;
      _commentPage = page.page;
      _commentTotalPages = page.totalPages;
      _commentTotal = page.total;
      _post = _post?.copyWith(commentCount: (_post?.commentCount ?? 0) + 1);
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreComments() async {
    if (_loadingMore || _working || !hasMoreComments) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _gateway.loadCommunityComments(
        postId,
        authenticated: authenticated,
        page: _commentPage + 1,
      );
      final ids = _comments.map((comment) => comment.id).toSet();
      _comments = [
        ..._comments,
        ...page.items.where((comment) => ids.add(comment.id)),
      ];
      _commentPage = page.page;
      _commentTotalPages = page.totalPages;
      _commentTotal = page.total;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}

class CommunityProfileController extends ChangeNotifier {
  CommunityProfileController({
    required CommunityGateway gateway,
    required this.userId,
    required this.authenticated,
  }) : _gateway = gateway;

  final CommunityGateway _gateway;
  final int userId;
  final bool authenticated;

  CommunityProfile? _profile;
  CommunityProfile? get profile => _profile;

  List<CommunityPost> _posts = const [];
  List<CommunityPost> get posts => _posts;

  bool _loading = false;
  bool get loading => _loading;

  bool _working = false;
  bool get working => _working;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _gateway.loadCommunityProfile(userId, authenticated: authenticated),
        _gateway.loadCommunityUserPosts(userId, authenticated: authenticated),
      ]);
      _profile = results[0] as CommunityProfile;
      _posts = results[1] as List<CommunityPost>;
    } on Object catch (error) {
      _error = '$error';
      _profile = null;
      _posts = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> toggleFollow() async {
    final previous = _profile;
    if (previous == null || previous.relationship.isSelf || _working) return;
    _working = true;
    notifyListeners();
    try {
      final relationship = previous.relationship.isFollowing
          ? await _gateway.unfollowCommunityUser(userId)
          : await _gateway.followCommunityUser(userId);
      final delta =
          previous.relationship.isFollowing == relationship.isFollowing
          ? 0
          : relationship.isFollowing
          ? 1
          : -1;
      _profile = previous.copyWith(
        relationship: relationship,
        stats: previous.stats.copyWith(
          followerCount: (previous.stats.followerCount + delta).clamp(
            0,
            1 << 31,
          ),
        ),
      );
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> togglePostLike(int postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final previous = _posts[index];
    final next = previous.copyWith(
      isLiked: !previous.isLiked,
      likeCount: previous.isLiked
          ? (previous.likeCount - 1).clamp(0, 1 << 31)
          : previous.likeCount + 1,
    );
    _posts = [..._posts]..[index] = next;
    notifyListeners();
    try {
      if (previous.isLiked) {
        await _gateway.unlikeCommunityPost(postId);
      } else {
        await _gateway.likeCommunityPost(postId);
      }
    } on Object {
      _posts = [..._posts]..[index] = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePost(int postId) async {
    if (_working) return;
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    _working = true;
    notifyListeners();
    try {
      await _gateway.deleteCommunityPost(postId);
      _posts = [..._posts]..removeAt(index);
      final currentProfile = _profile;
      if (currentProfile != null) {
        _profile = currentProfile.copyWith(
          stats: currentProfile.stats.copyWith(
            postCount: (currentProfile.stats.postCount - 1).clamp(0, 1 << 31),
          ),
        );
      }
    } finally {
      _working = false;
      notifyListeners();
    }
  }
}

class CommunityBlacklistController extends ChangeNotifier {
  CommunityBlacklistController({required CommunityGateway gateway})
    : _gateway = gateway;

  final CommunityGateway _gateway;

  List<CommunityBlockItem> _items = const [];
  List<CommunityBlockItem> get items => _items;

  bool _loading = false;
  bool get loading => _loading;

  int? _pendingUserId;
  int? get pendingUserId => _pendingUserId;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _gateway.loadCommunityBlockedUsers();
    } on Object catch (error) {
      _error = '$error';
      if (_items.isEmpty) _items = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> unblock(CommunityBlockItem item) async {
    if (_pendingUserId != null) return;
    _pendingUserId = item.blockedUserId;
    notifyListeners();
    try {
      await _gateway.unblockCommunityUser(item.blockedUserId);
      _items = _items
          .where((current) => current.blockedUserId != item.blockedUserId)
          .toList(growable: false);
    } finally {
      _pendingUserId = null;
      notifyListeners();
    }
  }
}

class CommunityConnectionsController extends ChangeNotifier {
  CommunityConnectionsController({
    required CommunityGateway gateway,
    required this.userId,
    required this.type,
    required this.authenticated,
    required this.currentUserId,
  }) : _gateway = gateway;

  final CommunityGateway _gateway;
  final int userId;
  final CommunityConnectionType type;
  final bool authenticated;
  final int? currentUserId;

  List<CommunityRelationUser> _items = const [];
  List<CommunityRelationUser> get items => _items;

  bool _loading = false;
  bool get loading => _loading;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  int? _pendingUserId;
  int? get pendingUserId => _pendingUserId;

  String _keyword = '';
  String get keyword => _keyword;

  String? _error;
  String? get error => _error;

  int _page = 1;
  int _totalPages = 1;
  bool get hasMore => _page < _totalPages;

  Future<void> load({bool refresh = false, String? keyword}) async {
    if (_loading || _refreshing || _loadingMore) return;
    if (keyword != null) _keyword = keyword.trim();
    if (refresh) {
      _refreshing = true;
    } else {
      _loading = true;
    }
    _error = null;
    notifyListeners();
    try {
      final page = await _gateway.loadCommunityConnections(
        userId: userId,
        type: type,
        authenticated: authenticated,
        keyword: _keyword,
      );
      _items = page.items;
      _page = page.page;
      _totalPages = page.totalPages;
    } on Object catch (error) {
      _error = '$error';
      _items = const [];
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> search(String keyword) => load(refresh: true, keyword: keyword);

  Future<void> loadMore() async {
    if (_loading || _refreshing || _loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final result = await _gateway.loadCommunityConnections(
        userId: userId,
        type: type,
        authenticated: authenticated,
        page: _page + 1,
        keyword: _keyword,
      );
      final ids = _items.map((item) => item.user.id).toSet();
      _items = [
        ..._items,
        ...result.items.where((item) => ids.add(item.user.id)),
      ];
      _page = result.page;
      _totalPages = result.totalPages;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(CommunityRelationUser item) async {
    if (item.relationship.isSelf || _pendingUserId != null) return;
    _pendingUserId = item.user.id;
    notifyListeners();
    try {
      final relationship = item.relationship.isFollowing
          ? await _gateway.unfollowCommunityUser(item.user.id)
          : await _gateway.followCommunityUser(item.user.id);
      final remove =
          type == CommunityConnectionType.following &&
          currentUserId == userId &&
          !relationship.isFollowing;
      _items = remove
          ? _items.where((current) => current.user.id != item.user.id).toList()
          : [
              for (final current in _items)
                if (current.user.id == item.user.id)
                  current.copyWith(relationship: relationship)
                else
                  current,
            ];
    } finally {
      _pendingUserId = null;
      notifyListeners();
    }
  }
}

CommunityComment? _findComment(List<CommunityComment> items, int id) {
  for (final item in items) {
    if (item.id == id) return item;
    final nested = _findComment(item.replies, id);
    if (nested != null) return nested;
  }
  return null;
}

List<CommunityComment> _updateComment(
  List<CommunityComment> items,
  int id,
  CommunityComment Function(CommunityComment comment) update,
) {
  return [
    for (final item in items)
      if (item.id == id)
        update(item)
      else if (item.replies.isNotEmpty)
        CommunityComment(
          id: item.id,
          userId: item.userId,
          postId: item.postId,
          content: item.content,
          parentId: item.parentId,
          likeCount: item.likeCount,
          isLiked: item.isLiked,
          author: item.author,
          replies: _updateComment(item.replies, id, update),
          createdAt: item.createdAt,
        )
      else
        item,
  ];
}
