import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/friends/data/friend_relations_repository.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_relation_models.dart';

void main() {
  test('好友关系接口使用固定方法、路径、参数和 token', () async {
    final requests = <http.Request>[];
    final repository = FriendRelationsRepository(
      apiClient: _client(requests, (request) {
        return switch ((request.method, request.url.path)) {
          ('POST', '/friends/search-by-phone') => _ok({
            'found': true,
            'user': {
              'id': 8,
              'username': '小顾',
              'phone': '13800138000',
              'avatar': '/avatar.png',
            },
            'message': '搜索成功',
          }),
          ('GET', '/friends/requests') => _ok({
            'data': [
              {
                'id': 3,
                'requestId': '3',
                'requesterId': 8,
                'requesterName': '小顾',
                'requesterPhone': '13800138000',
                'status': 'pending',
                'createdAt': '2026-07-25T08:00:00.000Z',
              },
            ],
            'total': 1,
            'page': 1,
            'pageSize': 20,
            'totalPages': 1,
          }),
          ('POST', '/friends/requests/3/accept') => _ok({'data': {}}),
          ('POST', '/friends/requests/3/reject') => _ok({}),
          ('GET', '/friends') => _ok({
            'data': [
              {'friendId': 8, 'friendName': '小顾', 'remark': '顾医生'},
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
            'totalPages': 1,
          }),
          ('GET', '/friends/relationship/8') => _ok({
            'isFriend': true,
            'outgoingPending': false,
            'incomingPending': false,
            'blockedByMe': false,
            'canSendMessage': true,
          }),
          ('POST', '/friends/chat-blocks') => _ok({
            'data': {
              'id': 5,
              'blockedUserId': 8,
              'blockedAt': '2026-07-27T08:00:00.000Z',
            },
          }),
          ('GET', '/friends/chat-blocks') => _ok({
            'data': [
              {
                'id': 5,
                'blockedUserId': 8,
                'blockedAt': '2026-07-27T08:00:00.000Z',
                'blockedUser': {
                  'id': 8,
                  'username': '小顾',
                  'avatar': '/avatar.png',
                },
              },
            ],
            'total': 1,
            'page': 1,
            'pageSize': 20,
            'totalPages': 1,
          }),
          ('DELETE', '/friends/chat-blocks/8') => _ok({}),
          ('PUT', '/friends/8/remark') => _ok({}),
          ('DELETE', '/friends/8') => _ok({}),
          _ => throw StateError(
            'Unexpected request: ${request.method} ${request.url}',
          ),
        };
      }),
    );

    final search = await repository.searchUserByPhone(phone: '13800138000');
    final requestPage = await repository.loadFriendRequests(
      status: FriendRequestStatus.pending,
      page: 1,
      pageSize: 20,
    );
    await repository.acceptFriendRequest(requestId: 3);
    await repository.rejectFriendRequest(requestId: 3);
    final friends = await repository.loadFriends(page: 1, pageSize: 100);
    final relationship = await repository.loadRelationshipSummary(
      targetUserId: 8,
    );
    await repository.blockFriendChat(blockedUserId: 8);
    final blocks = await repository.loadFriendChatBlocks(page: 1, pageSize: 20);
    await repository.unblockFriendChat(blockedUserId: 8);
    await repository.updateFriendRemark(friendId: 8, remark: '顾医生');
    await repository.deleteFriend(friendId: 8);

    expect(search.user?.displayName, '小顾');
    expect(requestPage.items.single.requesterPhone, '13800138000');
    expect(friends.items.single.displayName, '顾医生');
    expect(relationship.isFriend, isTrue);
    expect(relationship.canSendMessage, isTrue);
    expect(blocks.items.single.blockedUserName, '小顾');
    expect(requests[0].headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(requests[0].body), {'phone': '13800138000'});
    expect(requests[1].url.queryParameters, {
      'status': 'pending',
      'page': '1',
      'pageSize': '20',
    });
    expect(jsonDecode(requests[2].body), <String, Object?>{});
    expect(jsonDecode(requests[3].body), <String, Object?>{});
    expect(requests[4].url.queryParameters, {'page': '1', 'pageSize': '100'});
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/friends/chat-blocks' &&
            jsonDecode(request.body)['blockedUserId'] == 8,
      ),
      isTrue,
    );
    expect(
      requests.any(
        (request) =>
            request.method == 'DELETE' &&
            request.url.path == '/friends/chat-blocks/8',
      ),
      isTrue,
    );
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer test-token',
      ),
      isTrue,
    );
  });

  test('发送好友申请完整解析五种业务状态', () async {
    for (final status in const [
      'sent',
      'outgoing_pending',
      'incoming_pending',
      'already_friends',
      'self',
    ]) {
      final requests = <http.Request>[];
      final repository = FriendRelationsRepository(
        apiClient: _client(
          requests,
          (_) => _ok({
            'success': status == 'sent',
            'status': status,
            'message': 'result-$status',
            if (status == 'sent') 'requestId': 12,
          }),
        ),
      );

      final result = await repository.sendFriendRequest(
        receiverId: 8,
        message: '我是小明',
      );

      expect(result.status.name, _enumNameFor(status));
      expect(result.success, status == 'sent');
      expect(jsonDecode(requests.single.body), {
        'receiverId': 8,
        'message': '我是小明',
      });
      expect(requests.single.headers['authorization'], 'Bearer test-token');
    }
  });
}

String _enumNameFor(String status) {
  return switch (status) {
    'outgoing_pending' => 'outgoingPending',
    'incoming_pending' => 'incomingPending',
    'already_friends' => 'alreadyFriends',
    _ => status,
  };
}

ApiClient _client(
  List<http.Request> requests,
  http.Response Function(http.Request request) responder,
) {
  return ApiClient(
    baseUrl: 'https://example.test',
    client: MockClient((request) async {
      requests.add(request);
      return responder(request);
    }),
    tokenProvider: () async => 'test-token',
  );
}

http.Response _ok(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(<String, Object?>{'code': 0, ...body}),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
