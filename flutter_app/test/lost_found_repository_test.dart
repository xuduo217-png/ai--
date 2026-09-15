import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/lost_found/data/lost_found_repository.dart';
import 'package:pet_hospital_flutter/features/lost_found/domain/lost_found_models.dart';

void main() {
  test('走失领养仓库遵循列表、发布、评论和 moderation contract', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test/server-api',
      client: MockClient((request) async {
        requests.add(request);
        final payload = switch ((request.method, request.url.path)) {
          ('GET', '/server-api/lost-found') => {
            'code': 0,
            'data': [_recordJson],
            'pagination': {
              'total': 11,
              'page': 2,
              'pageSize': 10,
              'totalPages': 2,
            },
          },
          ('POST', '/server-api/lost-found') => {
            'code': 0,
            'data': _recordJson,
          },
          ('GET', '/server-api/lost-found/7/comments') => {
            'code': 0,
            'data': [_commentJson],
            'pagination': {'total': 1, 'page': 1, 'limit': 10, 'totalPages': 1},
          },
          ('POST', '/server-api/lost-found/7/comments') => {
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
      tokenProvider: () async => 'lost-found-token',
    );
    final repository = LostFoundRepository(client);
    const draft = LostFoundDraft(
      petId: 3,
      recordType: LostFoundRecordType.lost,
      contactName: '小顾',
      contactPhone: '13800138000',
      description: '昨晚在公园东门附近走失，戴着蓝色项圈。',
      images: ['/uploads/lost-found/one.jpg'],
    );

    final page = await repository.loadLostFoundRecords(
      authenticated: false,
      recordType: LostFoundRecordType.lost,
      page: 2,
    );
    final created = await repository.createLostFoundRecord(draft);
    final comments = await repository.loadLostFoundComments(
      7,
      authenticated: true,
    );
    await repository.createLostFoundComment(
      7,
      content: '我在东门附近见过',
      parentId: 5,
    );
    await repository.reportLostFoundContent(
      targetType: 'LOST_FOUND_RECORD',
      targetId: 7,
      reason: LostFoundReportReason.spam,
      description: '重复广告',
    );
    await repository.blockLostFoundUser(9, reason: '屏蔽发布者');

    expect(page.items.single.title, '团子');
    expect(page.totalPages, 2);
    expect(created.contactPhone, '13800138000');
    expect(comments.items.single.user?.displayName, '热心市民');

    expect(requests[0].headers['authorization'], isNull);
    expect(requests[0].url.queryParameters, {
      'page': '2',
      'pageSize': '10',
      'recordType': 'LOST',
    });
    expect(requests[1].headers['authorization'], 'Bearer lost-found-token');
    expect(jsonDecode(requests[1].body), draft.toJson());
    expect(requests[2].headers['authorization'], 'Bearer lost-found-token');
    expect(jsonDecode(requests[3].body), {
      'content': '我在东门附近见过',
      'parentId': 5,
    });
    expect(jsonDecode(requests[4].body), {
      'targetType': 'LOST_FOUND_RECORD',
      'targetId': '7',
      'reason': 'SPAM',
      'description': '重复广告',
    });
    expect(jsonDecode(requests[5].body), {
      'blockedUserId': 9,
      'reason': '屏蔽发布者',
    });
  });

  test('发布草稿复刻 RN 字段校验', () {
    const invalidPhone = LostFoundDraft(
      petId: 3,
      recordType: LostFoundRecordType.adoption,
      contactName: '小顾',
      contactPhone: '123',
      description: '这是一段满足十个字符要求的领养说明。',
    );
    const valid = LostFoundDraft(
      petId: 3,
      recordType: LostFoundRecordType.adoption,
      contactName: '小顾',
      contactPhone: '13800138000',
      description: '这是一段满足十个字符要求的领养说明。',
    );

    expect(invalidPhone.validate(), '请输入正确的手机号码');
    expect(valid.validate(), isNull);
  });

  test('手动宠物草稿无需 petId 并提交宠物快照', () {
    const incomplete = LostFoundDraft(
      petId: null,
      petName: '小黑',
      petCategory: '狗',
      recordType: LostFoundRecordType.adoption,
      contactName: '小顾',
      contactPhone: '13800138000',
      description: '性格亲人，希望为它寻找认真负责的领养家庭。',
    );
    const valid = LostFoundDraft(
      petId: null,
      petName: ' 小黑 ',
      petCategory: ' 狗 ',
      petBreed: ' 中华田园犬 ',
      recordType: LostFoundRecordType.adoption,
      contactName: '小顾',
      contactPhone: '13800138000',
      description: '性格亲人，希望为它寻找认真负责的领养家庭。',
    );

    expect(incomplete.validate(), '请输入宠物品种');
    expect(valid.validate(), isNull);
    expect(valid.toJson(), containsPair('petId', null));
    expect(valid.toJson(), containsPair('petName', '小黑'));
    expect(valid.toJson(), containsPair('petCategory', '狗'));
    expect(valid.toJson(), containsPair('petBreed', '中华田园犬'));
  });

  test('无宠物关联时从快照解析展示信息', () {
    final json = Map<String, Object?>.from(_recordJson)
      ..addAll({
        'petId': null,
        'pet': null,
        'petName': '小黑',
        'petCategory': '狗',
        'petBreed': '中华田园犬',
      });

    final record = LostFoundRecord.fromJson(json);
    final draft = LostFoundDraft.fromRecord(record);

    expect(record.petId, isNull);
    expect(record.title, '小黑');
    expect(record.breedLabel, '狗 · 中华田园犬');
    expect(draft.petName, '小黑');
    expect(draft.petBreed, '中华田园犬');
  });
}

const _recordJson = {
  'id': 7,
  'petId': 3,
  'publisherId': 9,
  'pet': {
    'id': 3,
    'name': '团子',
    'avatar': '/uploads/pets/tuanzi.jpg',
    'category': {'id': 1, 'name': '猫'},
    'subCategory': {'id': 2, 'name': '英国短毛猫'},
  },
  'publisher': {
    'id': 9,
    'username': 'helper',
    'nickname': '发布人',
    'avatar': '/uploads/avatar.png',
  },
  'recordType': 'LOST',
  'contactName': '小顾',
  'contactPhone': '13800138000',
  'description': '昨晚在公园东门附近走失，戴着蓝色项圈。',
  'images': ['/uploads/lost-found/one.jpg'],
  'video': null,
  'videoCover': null,
  'isPinned': false,
  'isFound': false,
  'foundAt': null,
  'createdAt': '2026-07-25T08:00:00.000Z',
  'updatedAt': '2026-07-25T09:00:00.000Z',
};

const _commentJson = {
  'id': 5,
  'lostFoundId': 7,
  'userId': 11,
  'content': '我在东门附近见过',
  'parentId': null,
  'likeCount': 0,
  'createdAt': '2026-07-25T10:00:00.000Z',
  'user': {'id': 11, 'username': 'citizen', 'nickname': '热心市民', 'avatar': ''},
  'replies': <Object?>[],
};
