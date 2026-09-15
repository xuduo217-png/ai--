import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_socket_client.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_relation_models.dart';

void main() {
  test('只创建一个带 token 的 websocket 连接并加入好友 namespace', () async {
    late _FakeTransport transport;
    late String capturedUrl;
    late Map<String, dynamic> capturedOptions;
    var factoryCalls = 0;
    final client = FriendsSocketClient(
      baseUrl: 'https://example.test/',
      accessTokenProvider: () async => 'socket-token',
      transportFactory: (url, options) {
        factoryCalls += 1;
        capturedUrl = url;
        capturedOptions = options;
        return transport = _FakeTransport();
      },
    );
    final connectionStates = <bool>[];
    final subscription = client.connectionChanges.listen(connectionStates.add);

    await Future.wait<void>([client.connect(), client.connect()]);

    expect(factoryCalls, 1);
    expect(capturedUrl, 'https://example.test/friends');
    expect(capturedOptions['transports'], ['websocket']);
    expect(capturedOptions['auth'], {'token': 'socket-token'});
    expect(transport.emitted.single.event, FriendsSocketEvents.join);
    expect(connectionStates, [true]);

    await client.stop();
    expect(transport.emitted.last.event, FriendsSocketEvents.leave);
    expect(transport.offEvents, containsAll(transport.registeredEvents));
    expect(transport.wasDisposed, isTrue);
    await subscription.cancel();
    await client.dispose();
  });

  test('发送文本使用固定 payload 并兼容 callback ACK', () async {
    late _FakeTransport transport;
    final client = FriendsSocketClient(
      baseUrl: 'https://example.test',
      accessTokenProvider: () async => 'token',
      transportFactory: (_, _) => transport = _FakeTransport(
        onEmitWithAck: (event, data, ack) {
          ack({
            'success': true,
            'tempMessageId': data['tempMessageId'],
            'message': {
              'messageId': 'server-1',
              'conversationId': '1_8',
              'senderId': 1,
              'receiverId': 8,
              'messageType': 'text',
              'content': data['content'],
              'isRead': 0,
              'createdAt': '2026-07-24T08:00:00.000Z',
            },
          });
        },
      ),
    );

    final acknowledgement = await client.sendTextMessage(
      receiverId: 8,
      content: '你好',
      tempMessageId: 'temp-1',
    );

    final sent = transport.ackEmissions.single;
    expect(sent.event, FriendsSocketEvents.sendMessage);
    expect(sent.data, {
      'receiverId': 8,
      'messageType': 'text',
      'content': '你好',
      'tempMessageId': 'temp-1',
    });
    expect(acknowledgement.success, isTrue);
    expect(acknowledgement.messageId, 'server-1');
    expect(acknowledgement.message?.content, '你好');
    await client.dispose();
  });

  test('消息、好友关系和会话失效载荷均映射为事件', () async {
    late _FakeTransport transport;
    final client = FriendsSocketClient(
      baseUrl: 'https://example.test',
      accessTokenProvider: () async => 'token',
      transportFactory: (_, _) => transport = _FakeTransport(),
    );
    await client.connect();

    final messageFuture = client.messages.first;
    final ackFuture = client.acknowledgements.first;
    final readFuture = client.readReceipts.first;
    final deletedFuture = client.friendshipDeleted.first;
    final newRequestFuture = client.newFriendRequests.first;
    final acceptedRequestFuture = client.acceptedFriendRequests.first;
    final rejectedRequestFuture = client.rejectedFriendRequests.first;
    final revokedFuture = client.sessionRevoked.first;
    transport.trigger(FriendsSocketEvents.newMessage, {
      'messageId': 'incoming-1',
      'conversationId': '1_8',
      'senderId': 8,
      'receiverId': 1,
      'messageType': 'text',
      'content': '离线消息',
      'isRead': 0,
      'deliveryMode': 'offline',
      'createdAt': '2026-07-24T08:00:00.000Z',
    });
    transport.trigger(FriendsSocketEvents.messageAck, {
      'success': true,
      'messageId': 'server-2',
      'tempMessageId': 'temp-2',
    });
    transport.trigger(FriendsSocketEvents.readReceipt, {
      'messageId': 'server-2',
      'conversationId': '1_8',
      'readerId': 8,
    });
    transport.trigger(FriendsSocketEvents.deletedFriendship, {
      'friendId': 8,
      'deletedByUserId': 8,
    });
    transport.trigger(FriendsSocketEvents.newFriendRequest, {
      'id': 12,
      'requestId': '12',
      'requesterId': 9,
      'requesterName': '新用户',
      'status': 'pending',
      'createdAt': '2026-07-24T08:02:00.000Z',
    });
    transport.trigger(FriendsSocketEvents.acceptedFriendRequest, {
      'requestId': '13',
      'friendId': 10,
      'friendName': '已接受用户',
      'acceptedAt': '2026-07-24T08:03:00.000Z',
    });
    transport.trigger(FriendsSocketEvents.rejectedFriendRequest, {
      'requestId': '14',
      'receiverId': 11,
      'receiverName': '已拒绝用户',
      'rejectedAt': '2026-07-24T08:04:00.000Z',
    });
    transport.trigger(FriendsSocketEvents.revokedSession, {'reason': 'logout'});

    expect((await messageFuture).deliveryMode, 'offline');
    expect((await ackFuture).messageId, 'server-2');
    expect((await readFuture).readerId, 8);
    expect((await deletedFuture).friendId, 8);
    expect((await newRequestFuture).status, FriendRequestStatus.pending);
    expect((await acceptedRequestFuture).friendId, 10);
    expect((await rejectedRequestFuture).receiverId, 11);
    expect((await revokedFuture).reason, 'logout');
    await client.dispose();
  });

  test('离线拉取、确认和已读上报等待服务端 ACK', () async {
    late _FakeTransport transport;
    final client = FriendsSocketClient(
      baseUrl: 'https://example.test',
      accessTokenProvider: () async => 'token',
      transportFactory: (_, _) => transport = _FakeTransport(
        onEmitWithAck: (_, _, ack) => ack({'success': true}),
      ),
    );

    await client.fetchOfflineMessages();
    await client.acknowledgeOfflineMessages(['m1', 'm2']);
    await client.markMessageRead(messageId: 'm1', conversationId: '1_8');

    expect(transport.ackEmissions.map((event) => event.event), [
      FriendsSocketEvents.fetchOffline,
      FriendsSocketEvents.acknowledgeOffline,
      FriendsSocketEvents.markRead,
    ]);
    expect(transport.ackEmissions[1].data, {
      'messageIds': ['m1', 'm2'],
    });
    await client.dispose();
  });

  test('消息 ACK 超时会失败且连接缺少 token 时拒绝启动', () async {
    final timeoutClient = FriendsSocketClient(
      baseUrl: 'https://example.test',
      accessTokenProvider: () async => 'token',
      transportFactory: (_, _) => _FakeTransport(),
      commandTimeout: const Duration(milliseconds: 10),
    );
    expect(
      () => timeoutClient.sendTextMessage(
        receiverId: 8,
        content: 'timeout',
        tempMessageId: 'temp-timeout',
      ),
      throwsA(isA<TimeoutException>()),
    );
    await timeoutClient.dispose();

    final unauthorizedClient = FriendsSocketClient(
      baseUrl: 'https://example.test',
      accessTokenProvider: () async => null,
    );
    expect(unauthorizedClient.connect, throwsA(isA<StateError>()));
    await unauthorizedClient.dispose();
  });
}

typedef _AckHandler = void Function(dynamic data);
typedef _EmitWithAckHandler =
    void Function(String event, Map<String, dynamic> data, _AckHandler ack);

class _FakeTransport implements FriendsSocketTransport {
  _FakeTransport({this.onEmitWithAck});

  final _EmitWithAckHandler? onEmitWithAck;
  final Map<String, void Function(dynamic)> handlers = {};
  final List<_Emission> emitted = [];
  final List<_Emission> ackEmissions = [];
  final List<String> offEvents = [];
  final List<String> registeredEvents = [];

  bool _connected = false;
  bool wasDisposed = false;

  @override
  bool get connected => _connected;

  @override
  void connect() {
    _connected = true;
    handlers[FriendsSocketEvents.connect]?.call(null);
  }

  @override
  void disconnect() {
    _connected = false;
  }

  @override
  void dispose() {
    wasDisposed = true;
  }

  @override
  void emit(String event, [dynamic data]) {
    emitted.add(_Emission(event, data));
  }

  @override
  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic data) ack,
  }) {
    final mapped = Map<String, dynamic>.from(data as Map);
    ackEmissions.add(_Emission(event, mapped));
    onEmitWithAck?.call(event, mapped, ack);
  }

  @override
  void off(String event, void Function(dynamic data) handler) {
    offEvents.add(event);
    if (identical(handlers[event], handler)) handlers.remove(event);
  }

  @override
  void on(String event, void Function(dynamic data) handler) {
    registeredEvents.add(event);
    handlers[event] = handler;
  }

  void trigger(String event, dynamic data) => handlers[event]?.call(data);
}

class _Emission {
  const _Emission(this.event, this.data);

  final String event;
  final dynamic data;
}
