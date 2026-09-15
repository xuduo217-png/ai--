import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/activity/data/activity_repository.dart';
import 'package:pet_hospital_flutter/features/activity/domain/activity_models.dart';

void main() {
  test('活动仓库遵循列表、详情、评论、报名、投票和选手 contract', () async {
    final requests = <http.Request>[];
    final apiClient = ApiClient(
      baseUrl: 'https://example.test/server-api',
      client: MockClient((request) async {
        requests.add(request);
        final payload = switch ((request.method, request.url.path)) {
          ('GET', '/server-api/activities/app') => {
            'code': 0,
            'data': [_activityJson],
            'pagination': {
              'total': 1,
              'page': 1,
              'pageSize': 10,
              'totalPages': 1,
            },
          },
          ('GET', '/server-api/activities/app/7') => {
            'code': 0,
            'data': _activityJson,
          },
          ('GET', '/server-api/activities/app/7/comments') => {
            'code': 0,
            'data': [_commentJson],
            'pagination': {
              'total': 1,
              'page': 1,
              'pageSize': 20,
              'totalPages': 1,
            },
          },
          ('POST', '/server-api/activities/app/7/comments') => {
            'code': 0,
            'data': {'message': '评论成功', 'data': _commentJson},
          },
          ('POST', '/server-api/activities/app/7/register') => {
            'code': 0,
            'data': {
              'success': true,
              'message': '报名成功',
              'data': {'registrationId': 3},
            },
          },
          ('POST', '/server-api/activities/app/7/vote') => {
            'code': 0,
            'data': {
              'success': true,
              'message': '投票成功',
              'data': {'optionId': 11},
            },
          },
          ('POST', '/server-api/activities/app/7/vote-options') => {
            'code': 0,
            'data': {
              'success': true,
              'message': '报名成功',
              'data': _voteOptionJson,
            },
          },
          ('DELETE', '/server-api/activities/app/7/vote-options/11') => {
            'code': 0,
            'data': {'success': true, 'message': '删除成功'},
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
      tokenProvider: () async => 'activity-token',
    );
    final repository = ActivityRepository(apiClient);

    final page = await repository.loadActivities(
      authenticated: false,
      status: ActivityStatus.ongoing,
      keyword: '萌宠',
    );
    final detail = await repository.loadActivityDetail(7, authenticated: true);
    final comments = await repository.loadActivityComments(
      7,
      authenticated: false,
    );
    final createdComment = await repository.createActivityComment(
      7,
      content: ' 加油 ',
    );
    final register = await repository.registerActivity(7, phone: '13800138000');
    final vote = await repository.voteActivity(7, optionId: 11);
    final option = await repository.createActivityVoteOption(
      7,
      const ActivityVoteOptionDraft(
        title: '布丁',
        description: '活泼可爱',
        imageUrl: '/uploads/cat.jpg',
        videoUrl: '',
        videoCoverUrl: '',
      ),
    );
    final deleted = await repository.deleteActivityVoteOption(7, 11);

    expect(page.items.single.title, '萌宠人气大赛');
    expect(
      page.items.single.coverImageUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/activity.jpg',
    );
    expect(detail.activityType, ActivityType.online);
    expect(detail.voteOptions.single.ownerUserId, 8);
    expect(comments.items.single.user?.nickname, '小顾');
    expect(createdComment.content, '支持布丁');
    expect(register.success, isTrue);
    expect(vote.message, '投票成功');
    expect(option.data?.title, '布丁');
    expect(deleted.message, '删除成功');

    expect(requests.first.url.queryParameters, {
      'status': 'ONGOING',
      'keyword': '萌宠',
      'page': '1',
      'pageSize': '10',
    });
    expect(requests.first.headers['authorization'], isNull);
    expect(requests[1].headers['authorization'], 'Bearer activity-token');
    expect(requests[2].headers['authorization'], isNull);
    expect(jsonDecode(requests[3].body), {'content': '加油'});
    expect(jsonDecode(requests[5].body), {'optionId': 11});
    expect(jsonDecode(requests[6].body), {
      'title': '布丁',
      'description': '活泼可爱',
      'image': '/uploads/cat.jpg',
      'video': '',
      'videoCover': '',
    });
    expect(requests[7].method, 'DELETE');
    expect(requests[7].headers['authorization'], 'Bearer activity-token');
  });
}

const _voteOptionJson = {
  'id': 11,
  'activityId': 7,
  'image': '/uploads/cat.jpg',
  'video': '',
  'videoCover': '',
  'title': '布丁',
  'description': '活泼可爱',
  'voteCount': 18,
  'sortOrder': 1,
  'ownerUserId': 8,
};

const _activityJson = {
  'id': 7,
  'title': '萌宠人气大赛',
  'startTime': 1784937600,
  'endTime': 1787529600,
  'location': '',
  'summary': '选出最受欢迎的萌宠',
  'description': '<p>每人每天可投一票</p>',
  'coverImage': '/uploads/activity.jpg',
  'hospitalId': 2,
  'hospitalName': '谷德宠物医院',
  'registrationCount': 18,
  'status': 'ONGOING',
  'activityType': 'ONLINE',
  'isRegistered': false,
  'canRegister': true,
  'createdAt': 1784937600000,
  'updatedAt': 1784937600000,
  'voteOptions': [_voteOptionJson],
};

const _commentJson = {
  'id': 21,
  'activityId': 7,
  'userId': 8,
  'content': '支持布丁',
  'likeCount': 0,
  'createdAt': '2026-07-25T08:00:00.000Z',
  'user': {'id': 8, 'nickname': '小顾', 'avatar': '/uploads/avatar.jpg'},
  'replies': <Object>[],
};
