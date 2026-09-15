import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/community/data/community_repository.dart';
import 'package:pet_hospital_flutter/features/community/domain/community_models.dart';

void main() {
  test('社区仓库遵循帖子、资料、关系、评论和内容治理 contract', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test/server-api',
      client: MockClient((request) async {
        requests.add(request);
        final payload = switch ((request.method, request.url.path)) {
          ('GET', '/server-api/community/posts') => {
            'code': 0,
            'data': [_postJson],
            'pagination': {
              'total': 11,
              'page': 2,
              'limit': 10,
              'totalPages': 2,
            },
          },
          ('GET', '/server-api/community/posts/7') => {
            'code': 0,
            'data': _postJson,
          },
          ('POST', '/server-api/community/posts') => {
            'code': 0,
            'data': _postJson,
          },
          ('GET', '/server-api/community/users/8/profile') => {
            'code': 0,
            'data': _profileJson,
          },
          ('POST', '/server-api/community/users/8/follow') => {
            'code': 0,
            'data': _followingRelationship,
          },
          ('GET', '/server-api/community/posts/7/comments') => {
            'code': 0,
            'data': [_commentJson],
            'pagination': {'total': 1, 'page': 1, 'limit': 20, 'totalPages': 1},
          },
          ('POST', '/server-api/community/posts/7/comments') => {
            'code': 0,
            'data': _commentJson,
          },
          ('POST', '/server-api/moderation/reports') => {
            'code': 0,
            'data': {'id': 18},
          },
          ('POST', '/server-api/moderation/blocks') => {
            'code': 0,
            'data': {'id': 19},
          },
          ('GET', '/server-api/moderation/blocks') => {
            'success': true,
            'data': [_blockJson],
          },
          ('DELETE', '/server-api/moderation/blocks/8') => {'success': true},
          ('GET', '/server-api/community/tags/hot') => {
            'code': 0,
            'data': [
              {'id': 1, 'name': '#萌宠', 'usageCount': 16},
            ],
          },
          ('GET', '/server-api/community/tags/search') => {
            'code': 0,
            'data': [
              {'id': 1, 'name': '#萌宠', 'usageCount': 16},
            ],
          },
          _ => throw StateError(
            'Unexpected request: ${request.method} ${request.url}',
          ),
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      tokenProvider: () async => 'community-token',
    );
    final repository = CommunityRepository(client);

    final page = await repository.loadCommunityPosts(
      authenticated: false,
      type: CommunityFeedType.recommend,
      page: 2,
      tag: '萌宠',
    );
    final detail = await repository.loadCommunityPost(7, authenticated: true);
    final created = await repository.createCommunityPost(
      const CommunityPostDraft(
        content: ' 今天也要快乐养宠 ',
        images: ['/uploads/community/cat.jpg'],
        tags: ['#萌宠'],
      ),
    );
    final profile = await repository.loadCommunityProfile(
      8,
      authenticated: false,
    );
    final relationship = await repository.followCommunityUser(8);
    final comments = await repository.loadCommunityComments(
      7,
      authenticated: true,
    );
    await repository.createCommunityComment(7, content: ' 好可爱 ', parentId: 3);
    await repository.reportCommunityContent(
      targetType: 'POST',
      targetId: 7,
      reason: 'SPAM',
      description: '重复广告',
    );
    await repository.blockCommunityUser(8, reason: '不再查看');
    final hotTags = await repository.loadCommunityHotTags();
    final searchedTags = await repository.searchCommunityTags(' 萌宠 ');
    final blocks = await repository.loadCommunityBlockedUsers();
    await repository.unblockCommunityUser(8);

    expect(page.items.single.author.nickname, '小顾');
    expect(page.page, 2);
    expect(page.totalPages, 2);
    expect(detail.videoUrl, isEmpty);
    expect(created.images.single, '/uploads/community/cat.jpg');
    expect(profile.stats.followerCount, 12);
    expect(relationship.isFollowing, isTrue);
    expect(comments.items.single.content, '好可爱');
    expect(hotTags.single.name, '#萌宠');
    expect(searchedTags.single.usageCount, 16);
    expect(blocks.single.blockedUser.nickname, '小顾');
    expect(blocks.single.blockedAt, DateTime(2026, 7, 28, 16));

    expect(requests[0].url.queryParameters, {
      'type': 'recommend',
      'page': '2',
      'limit': '10',
      'tag': '萌宠',
    });
    expect(requests[0].headers['authorization'], isNull);
    expect(requests[1].headers['authorization'], 'Bearer community-token');
    expect(jsonDecode(requests[2].body), {
      'content': '今天也要快乐养宠',
      'images': ['/uploads/community/cat.jpg'],
      'tags': ['#萌宠'],
    });
    expect(requests[3].headers['authorization'], isNull);
    expect(jsonDecode(requests[6].body), {'content': '好可爱', 'parentId': 3});
    expect(jsonDecode(requests[7].body), {
      'targetType': 'POST',
      'targetId': '7',
      'reason': 'SPAM',
      'description': '重复广告',
    });
    expect(jsonDecode(requests[8].body), {
      'blockedUserId': 8,
      'reason': '不再查看',
    });
    expect(requests[9].headers['authorization'], 'Bearer community-token');
    expect(requests[10].headers['authorization'], 'Bearer community-token');
    expect(requests[10].url.queryParameters, {'keyword': '萌宠'});
    expect(requests[11].headers['authorization'], 'Bearer community-token');
    expect(requests[12].method, 'DELETE');
  });

  test('帖子草稿校验内容与数量限制并允许图片视频混合发布', () {
    expect(const CommunityPostDraft(content: '').validate(), '请输入帖子内容');
    expect(
      CommunityPostDraft(
        content: '内容',
        images: List.filled(10, '/image.jpg'),
      ).validate(),
      '最多只能上传 9 张图片',
    );
    const mixedMediaDraft = CommunityPostDraft(
      content: '内容',
      images: ['/image.jpg'],
      videoUrl: '/video.mp4',
    );
    expect(mixedMediaDraft.validate(), isNull);
    expect(mixedMediaDraft.toJson(), {
      'content': '内容',
      'images': ['/image.jpg'],
      'video': '/video.mp4',
    });
    expect(const CommunityPostDraft(content: '内容').validate(), isNull);
  });
}

const _followingRelationship = {
  'isSelf': false,
  'isFollowing': true,
  'isFollowedBy': false,
  'isMutualFollow': false,
};

const _blockJson = {
  'id': 19,
  'blockedUserId': 8,
  'reason': '不再查看',
  'blockedAt': '2026-07-28T08:00:00.000Z',
  'blockedUser': {
    'id': 8,
    'username': 'xiaogu',
    'nickname': '小顾',
    'avatar': '/uploads/avatar.jpg',
  },
};

const _profileJson = {
  'user': {
    'id': 8,
    'username': 'xiaogu',
    'nickname': '小顾',
    'avatar': '/uploads/avatar.jpg',
    'bio': '和布丁一起生活',
    'coverImage': '/uploads/cover.jpg',
  },
  'stats': {'postCount': 3, 'followerCount': 12, 'followingCount': 6},
  'relationship': _followingRelationship,
};

const _postJson = {
  'id': 7,
  'userId': 8,
  'content': '今天也要快乐养宠',
  'images': ['/uploads/community/cat.jpg'],
  'video': '',
  'videoCover': '',
  'tags': ['#萌宠'],
  'likeCount': 18,
  'commentCount': 1,
  'viewCount': 120,
  'isPinned': false,
  'isFeatured': true,
  'isLiked': false,
  'status': 'PUBLISHED',
  'createdAt': '2026-07-25T08:00:00.000Z',
  'user': {
    'id': 8,
    'username': 'xiaogu',
    'nickname': '小顾',
    'avatar': '/uploads/avatar.jpg',
    'verified': true,
  },
};

const _commentJson = {
  'id': 3,
  'postId': 7,
  'userId': 9,
  'content': '好可爱',
  'parentId': null,
  'likeCount': 2,
  'isLiked': false,
  'createdAt': '2026-07-25T09:00:00.000Z',
  'user': {'id': 9, 'nickname': '布丁妈妈', 'avatar': ''},
  'replies': <Object?>[],
};
