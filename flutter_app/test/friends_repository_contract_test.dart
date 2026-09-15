import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_repository.dart';

void main() {
  test('好友分页和消息历史按服务端 contract 映射', () async {
    final requests = <http.Request>[];
    final repository = FriendsRepository(
      apiClient: _client(requests, (request) {
        if (request.url.path == '/friends') {
          return _ok({
            'data': [
              {
                'friendId': 8,
                'friendName': '小顾',
                'friendAvatar': '/avatar.png',
                'remark': '顾医生',
                'lastChatAt': '2026-07-24T08:00:00.000Z',
              },
            ],
            'total': 2,
            'page': 1,
            'pageSize': 1,
            'totalPages': 2,
          });
        }
        return _ok({
          'data': [
            {
              'id': 91,
              'messageId': 'server-91',
              'conversationId': '1_8',
              'senderId': 8,
              'receiverId': 1,
              'messageType': 'text',
              'content': '到院了吗',
              'isRead': 0,
              'createdAt': '2026-07-24T08:01:00.000Z',
              'updatedAt': '2026-07-24T08:01:00.000Z',
            },
          ],
          'total': 1,
          'page': 1,
          'pageSize': 50,
          'totalPages': 1,
        });
      }),
    );

    final friends = await repository.loadFriends(page: 1, pageSize: 1);
    final history = await repository.loadMessageHistory(
      friendId: 8,
      page: 1,
      pageSize: 50,
    );

    expect(friends.items.single.displayName, '顾医生');
    expect(friends.hasMore, isTrue);
    expect(history.items.single.messageId, 'server-91');
    expect(history.items.single.content, '到院了吗');
    expect(requests[0].url.queryParameters, {'page': '1', 'pageSize': '1'});
    expect(requests[1].url.path, '/friends/messages/8/history');
    expect(requests[1].url.queryParameters, {'page': '1', 'pageSize': '50'});
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer test-token',
      ),
      isTrue,
    );
  });

  test('未读数和 REST 已读上报携带 token 与完整 payload', () async {
    final requests = <http.Request>[];
    final repository = FriendsRepository(
      apiClient: _client(requests, (request) {
        if (request.method == 'GET') {
          return _ok({
            'data': {'count': 7},
          });
        }
        return _ok({
          'data': {'success': true},
        });
      }),
    );

    expect(await repository.loadUnreadCount(), 7);
    await repository.markMessageRead(
      messageId: 'message-1',
      conversationId: '1_8',
    );

    expect(requests[1].method, 'POST');
    expect(requests[1].url.path, '/friends/messages/read');
    expect(jsonDecode(requests[1].body), {
      'messageId': 'message-1',
      'conversationId': '1_8',
    });
    expect(requests[1].headers['authorization'], 'Bearer test-token');
  });

  test('撤回消息使用认证接口并解析撤回后的占位消息', () async {
    final requests = <http.Request>[];
    final repository = FriendsRepository(
      apiClient: _client(requests, (_) {
        return _ok({
          'message': {
            'messageId': 'message-1',
            'conversationId': '1_8',
            'senderId': 1,
            'receiverId': 8,
            'messageType': 'text',
            'content': '消息已撤回',
            'isRead': 1,
            'isRevoked': 1,
            'revokedAt': '2026-08-12T10:01:00.000Z',
            'createdAt': '2026-08-12T10:00:00.000Z',
            'updatedAt': '2026-08-12T10:01:00.000Z',
          },
        });
      }),
    );

    final message = await repository.revokeMessage(messageId: 'message-1');

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/friends/messages/message-1/revoke');
    expect(requests.single.headers['authorization'], 'Bearer test-token');
    expect(message.isRevoked, isTrue);
    expect(message.content, '消息已撤回');
  });

  test('非法分页结构会显式失败', () async {
    final repository = FriendsRepository(
      apiClient: _client(<http.Request>[], (_) => _ok({'data': {}})),
    );

    expect(
      () => repository.loadFriends(page: 1, pageSize: 20),
      throwsA(isA<FormatException>()),
    );
  });
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
