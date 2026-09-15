import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_socket_client.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/data/marketplace_chat_database.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/data/marketplace_chat_local_store.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/data/marketplace_chat_repository.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/data/marketplace_chat_socket_client.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/domain/marketplace_chat_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('商城聊天仓库遵守会话、消息、未读和治理接口 contract', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/marketplace-chat/conversations' &&
            request.method == 'POST') {
          return _ok({'success': true, 'data': _conversationJson()});
        }
        if (path == '/marketplace-chat/conversations' &&
            request.method == 'GET') {
          return _ok(
            [_conversationJson()],
            pagination: const {
              'total': 1,
              'page': 1,
              'pageSize': 20,
              'totalPages': 1,
            },
          );
        }
        if (path == '/marketplace-chat/conversations/conversation-1') {
          return _ok({'success': true, 'data': _conversationJson()});
        }
        if (path.endsWith('/messages') && request.method == 'GET') {
          return _ok(
            [_messageJson()],
            pagination: const {
              'total': 1,
              'page': 1,
              'pageSize': 50,
              'totalPages': 1,
            },
          );
        }
        if (path == '/marketplace-chat/unread-count') {
          return _ok({
            'success': true,
            'data': {'count': 3},
          });
        }
        return _ok(null);
      }),
      tokenProvider: () async => 'token',
    );
    final repository = MarketplaceChatRepository(client);

    final opened = await repository.openConversation(20);
    final conversations = await repository.loadConversations(pageSize: 20);
    final detail = await repository.loadConversation('conversation-1');
    final messages = await repository.loadMessages(
      conversationId: 'conversation-1',
      page: 1,
    );
    expect(await repository.loadUnreadCount(), 3);
    await repository.markMessageRead(
      messageId: 'message-1',
      conversationId: 'conversation-1',
    );
    await repository.markConversationRead('conversation-1');
    await repository.reportMessage('message-1', description: '疑似欺诈');
    await repository.blockUser(9);

    expect(opened.product.name, '闲置猫包');
    expect(conversations.items.single.peer.id, 9);
    expect(conversations.total, 1);
    expect(detail.conversationId, 'conversation-1');
    expect(messages.items.single.content, '还在吗');
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer token',
      ),
      isTrue,
    );
    expect(
      _request(requests, 'POST', '/marketplace-chat/conversations').jsonBody,
      {'productId': 20},
    );
    expect(
      _request(requests, 'POST', '/moderation/reports').jsonBody,
      containsPair('targetType', 'MARKETPLACE_MESSAGE'),
    );
    expect(
      _request(requests, 'POST', '/moderation/blocks').jsonBody,
      containsPair('blockedUserId', 9),
    );
  });

  test('商城撤回接口携带认证并解析撤回后的消息', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requests.add(request);
        return _ok({
          'success': true,
          'data': {
            'message': _messageJson(content: '消息已撤回')
              ..['isRevoked'] = 1
              ..['isRead'] = 1,
          },
        });
      }),
      tokenProvider: () async => 'token',
    );
    final repository = MarketplaceChatRepository(client);

    final message = await repository.revokeMessage('message-1');

    expect(requests.single.method, 'POST');
    expect(
      requests.single.url.path,
      '/marketplace-chat/messages/message-1/revoke',
    );
    expect(requests.single.headers['authorization'], 'Bearer token');
    expect(message.isRevoked, isTrue);
    expect(message.content, '消息已撤回');
  });

  test('本地商城消息按账号隔离、去重并维护会话未读', () async {
    final database = MarketplaceChatDatabase.withFactory(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final store = MarketplaceChatLocalStore(database);
    await store.open();
    addTearDown(store.close);

    await store.persistConversation(1, _conversation(unreadCount: 2));
    await store.persistConversation(8, _conversation(unreadCount: 5));
    final message = FriendMessage.fromJson(_messageJson());

    expect(
      await store.persistMessage(ownerUserId: 1, message: message),
      isTrue,
    );
    expect(
      await store.persistMessage(ownerUserId: 1, message: message),
      isFalse,
    );
    expect(await store.messageCount(1, 'conversation-1'), 1);
    expect(await store.totalUnreadCount(1), 2);
    expect(await store.loadConversations(1, search: '猫包'), hasLength(1));

    final changed = await store.markConversationRead(1, 'conversation-1');
    expect(changed.single.messageId, 'message-1');
    expect(await store.totalUnreadCount(1), 0);
    expect((await store.loadMessages(1, 'conversation-1')).single.isRead, true);
    expect(await store.totalUnreadCount(8), 5);
  });

  test('商城撤回事件覆盖本地消息并报告被移除的未读', () async {
    final database = MarketplaceChatDatabase.withFactory(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final store = MarketplaceChatLocalStore(database);
    await store.open();
    addTearDown(store.close);
    final original = FriendMessage.fromJson(_messageJson());
    await store.persistMessage(ownerUserId: 1, message: original);

    final removedUnread = await store.applyRevokedMessage(
      ownerUserId: 1,
      message: original.copyWith(
        content: '消息已撤回',
        isRead: true,
        isRevoked: true,
        revokedAt: DateTime.utc(2026, 8, 12, 10, 1),
      ),
    );

    final saved = (await store.loadMessages(1, 'conversation-1')).single;
    expect(removedUnread, isTrue);
    expect(saved.isRevoked, isTrue);
    expect(saved.content, '消息已撤回');
  });

  test('商城 Socket 使用独立 namespace 并等待消息与离线命令 ACK', () async {
    late _FakeTransport transport;
    late String namespaceUrl;
    final client = MarketplaceChatSocketClient(
      baseUrl: 'https://example.test/',
      accessTokenProvider: () async => 'socket-token',
      transportFactory: (url, _) {
        namespaceUrl = url;
        return transport = _FakeTransport(
          onEmitWithAck: (event, data, ack) {
            if (event == MarketplaceChatSocketEvents.sendMessage) {
              ack({
                'success': true,
                'tempMessageId': data['tempMessageId'],
                'message': _messageJson(
                  content: data['content'] as String,
                  tempMessageId: data['tempMessageId'] as String,
                ),
              });
            } else {
              ack({'success': true});
            }
          },
        );
      },
    );

    await client.connect();
    final ack = await client.sendMessage(
      conversationId: 'conversation-1',
      messageType: 'text',
      content: '最低多少',
      tempMessageId: 'temp-1',
    );
    await client.fetchOfflineMessages();
    await client.acknowledgeOfflineMessages(['message-1']);
    await client.markMessageRead(
      messageId: 'message-1',
      conversationId: 'conversation-1',
    );

    expect(namespaceUrl, 'https://example.test/marketplace-chat');
    expect(transport.emitted.single.event, MarketplaceChatSocketEvents.join);
    expect(ack.message?.content, '最低多少');
    expect(transport.ackEmissions.map((item) => item.event), [
      MarketplaceChatSocketEvents.sendMessage,
      MarketplaceChatSocketEvents.fetchOffline,
      MarketplaceChatSocketEvents.acknowledgeOffline,
      MarketplaceChatSocketEvents.markRead,
    ]);
    await client.dispose();
  });
}

MarketplaceConversation _conversation({int unreadCount = 2}) =>
    MarketplaceConversation.fromJson(
      _conversationJson()..['unreadCount'] = unreadCount,
    );

Map<String, dynamic> _conversationJson() => {
  'conversationId': 'conversation-1',
  'productId': 20,
  'buyerId': 1,
  'sellerId': 9,
  'role': 'buyer',
  'peer': {'id': 9, 'nickname': '卖家', 'avatar': '/avatar.jpg'},
  'product': {
    'id': 20,
    'name': '闲置猫包',
    'image': '/cat-bag.jpg',
    'price': '88.00',
    'isActive': true,
    'isSold': false,
  },
  'lastMessage': null,
  'unreadCount': 2,
  'createdAt': '2026-07-27T08:00:00.000Z',
  'updatedAt': '2026-07-27T08:00:00.000Z',
};

Map<String, dynamic> _messageJson({
  String content = '还在吗',
  String? tempMessageId,
}) => {
  'messageId': 'message-1',
  'tempMessageId': tempMessageId,
  'conversationId': 'conversation-1',
  'senderId': 9,
  'receiverId': 1,
  'messageType': 'text',
  'content': content,
  'isRead': 0,
  'createdAt': '2026-07-27T08:01:00.000Z',
  'updatedAt': '2026-07-27T08:01:00.000Z',
};

http.Response _ok(Object? data, {Map<String, Object?>? pagination}) =>
    http.Response(
      jsonEncode({
        'success': true,
        'data': data,
        if (pagination != null) ...pagination,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

http.Request _request(
  List<http.Request> requests,
  String method,
  String path,
) => requests.singleWhere(
  (request) => request.method == method && request.url.path == path,
);

extension on http.Request {
  Map<String, dynamic> get jsonBody =>
      Map<String, dynamic>.from(jsonDecode(body) as Map);
}

typedef _Ack = void Function(dynamic data);
typedef _AckHandler =
    void Function(String event, Map<String, dynamic> data, _Ack ack);

class _FakeTransport implements FriendsSocketTransport {
  _FakeTransport({required this.onEmitWithAck});

  final _AckHandler onEmitWithAck;
  final Map<String, void Function(dynamic)> handlers = {};
  final List<_Emission> emitted = [];
  final List<_Emission> ackEmissions = [];
  bool _connected = false;

  @override
  bool get connected => _connected;

  @override
  void connect() {
    _connected = true;
    handlers[MarketplaceChatSocketEvents.connect]?.call(null);
  }

  @override
  void disconnect() => _connected = false;

  @override
  void dispose() {}

  @override
  void emit(String event, [dynamic data]) =>
      emitted.add(_Emission(event, data));

  @override
  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic data) ack,
  }) {
    final mapped = Map<String, dynamic>.from(data as Map);
    ackEmissions.add(_Emission(event, mapped));
    onEmitWithAck(event, mapped, ack);
  }

  @override
  void off(String event, void Function(dynamic data) handler) {
    if (identical(handlers[event], handler)) handlers.remove(event);
  }

  @override
  void on(String event, void Function(dynamic data) handler) {
    handlers[event] = handler;
  }
}

class _Emission {
  const _Emission(this.event, this.data);

  final String event;
  final dynamic data;
}
