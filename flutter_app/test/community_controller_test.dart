import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/community/domain/community_models.dart';
import 'package:pet_hospital_flutter/features/community/presentation/community_controller.dart';

void main() {
  test('推荐流加载、去重分页并完成乐观点赞', () async {
    final gateway = _FakeCommunityGateway();
    final controller = CommunityFeedController(
      gateway: gateway,
      authenticated: true,
    );

    await controller.load();
    expect(controller.posts.map((post) => post.id), [1, 2]);
    expect(controller.hasMore, isTrue);

    await controller.loadMore();
    expect(controller.posts.map((post) => post.id), [1, 2, 3]);
    expect(controller.hasMore, isFalse);

    final operation = controller.toggleLike(1);
    expect(controller.posts.first.isLiked, isTrue);
    expect(controller.posts.first.likeCount, 6);
    gateway.likeCompleter.complete();
    await operation;
    expect(gateway.likedPostId, 1);
  });

  test('点赞接口失败时恢复帖子原状态', () async {
    final gateway = _FakeCommunityGateway(failLike: true);
    final controller = CommunityFeedController(
      gateway: gateway,
      authenticated: true,
    );
    await controller.load();

    await expectLater(controller.toggleLike(1), throwsStateError);

    expect(controller.posts.first.isLiked, isFalse);
    expect(controller.posts.first.likeCount, 5);
    expect(controller.error, contains('点赞失败'));
  });

  test('游客关注流不请求鉴权接口并展示空态数据', () async {
    final gateway = _FakeCommunityGateway();
    final controller = CommunityFeedController(
      gateway: gateway,
      authenticated: false,
    );
    await controller.load();
    await controller.selectType(CommunityFeedType.following);

    expect(controller.posts, isEmpty);
    expect(gateway.loadCount, 1);
  });

  test('社区搜索加载热议话题并按选中标签筛选帖子', () async {
    final gateway = _FakeCommunityGateway();
    final controller = CommunitySearchController(
      gateway: gateway,
      authenticated: false,
    );

    await controller.loadHotTags();
    expect(controller.tags.single.name, '#萌宠');

    await controller.searchAndSelectFirst('萌宠');
    expect(gateway.searchedKeyword, '萌宠');
    expect(gateway.loadedTag, '#萌宠');
    expect(controller.selectedTag?.name, '#萌宠');
    expect(controller.posts.map((post) => post.id), [1, 2]);
  });

  test('社区个人主页删除帖子后同步移除列表并更新数量', () async {
    final gateway = _FakeCommunityGateway();
    final controller = CommunityProfileController(
      gateway: gateway,
      userId: 8,
      authenticated: true,
    );

    await controller.load();
    expect(controller.posts, hasLength(2));
    expect(controller.profile?.stats.postCount, 2);

    await controller.deletePost(1);

    expect(gateway.deletedPostId, 1);
    expect(controller.posts.map((post) => post.id), [2]);
    expect(controller.profile?.stats.postCount, 1);
  });

  test('社区黑名单解除屏蔽后立即移除对应用户', () async {
    final gateway = _FakeCommunityGateway();
    final controller = CommunityBlacklistController(gateway: gateway);

    await controller.load();
    expect(controller.items.single.blockedUser.nickname, '小顾');

    await controller.unblock(controller.items.single);

    expect(gateway.unblockedUserId, 8);
    expect(controller.items, isEmpty);
    expect(controller.pendingUserId, isNull);
  });
}

class _FakeCommunityGateway implements CommunityGateway {
  _FakeCommunityGateway({this.failLike = false});

  final bool failLike;
  final Completer<void> likeCompleter = Completer<void>();
  int loadCount = 0;
  int? likedPostId;
  String searchedKeyword = '';
  String loadedTag = '';
  int? deletedPostId;
  int? unblockedUserId;

  @override
  Future<CommunityPage<CommunityPost>> loadCommunityPosts({
    required bool authenticated,
    required CommunityFeedType type,
    int page = 1,
    int pageSize = 10,
    String tag = '',
  }) async {
    loadCount += 1;
    loadedTag = tag;
    if (page == 1) {
      return CommunityPage(
        items: [_post(1), _post(2)],
        total: 3,
        page: 1,
        pageSize: 2,
        totalPages: 2,
      );
    }
    return CommunityPage(
      items: [_post(2), _post(3)],
      total: 3,
      page: 2,
      pageSize: 2,
      totalPages: 2,
    );
  }

  @override
  Future<void> likeCommunityPost(int postId) async {
    likedPostId = postId;
    if (failLike) throw StateError('点赞失败');
    await likeCompleter.future;
  }

  @override
  Future<List<CommunityTag>> loadCommunityHotTags() async {
    return const [CommunityTag(id: 1, name: '#萌宠', usageCount: 16)];
  }

  @override
  Future<List<CommunityTag>> searchCommunityTags(String keyword) async {
    searchedKeyword = keyword;
    return const [CommunityTag(id: 1, name: '#萌宠', usageCount: 16)];
  }

  @override
  Future<CommunityProfile> loadCommunityProfile(
    int userId, {
    required bool authenticated,
  }) async {
    return CommunityProfile(
      user: _post(1).author,
      stats: const CommunityProfileStats(
        postCount: 2,
        followerCount: 0,
        followingCount: 0,
      ),
      relationship: const CommunityRelationship(
        isSelf: true,
        isFollowing: false,
        isFollowedBy: false,
        isMutualFollow: false,
      ),
    );
  }

  @override
  Future<List<CommunityPost>> loadCommunityUserPosts(
    int userId, {
    required bool authenticated,
  }) async => [_post(1), _post(2)];

  @override
  Future<void> deleteCommunityPost(int postId) async {
    deletedPostId = postId;
  }

  @override
  Future<List<CommunityBlockItem>> loadCommunityBlockedUsers() async {
    return [
      CommunityBlockItem(
        id: 1,
        blockedUserId: 8,
        reason: '不再查看',
        blockedAt: DateTime(2026, 7, 28),
        blockedUser: _post(1).author,
      ),
    ];
  }

  @override
  Future<void> unblockCommunityUser(int userId) async {
    unblockedUserId = userId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommunityPost _post(int id) {
  return CommunityPost(
    id: id,
    userId: 8,
    author: const CommunityUser(
      id: 8,
      username: 'xiaogu',
      nickname: '小顾',
      avatarUrl: '',
      bio: '',
      coverImageUrl: '',
      verified: false,
    ),
    content: '第 $id 条宠物日常',
    images: const [],
    videoUrl: '',
    videoCoverUrl: '',
    tags: const ['#萌宠'],
    likeCount: 5,
    commentCount: 0,
    viewCount: 10,
    isPinned: false,
    isFeatured: false,
    isLiked: false,
    status: 'PUBLISHED',
  );
}
