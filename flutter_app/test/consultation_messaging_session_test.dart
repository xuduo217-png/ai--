import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/messaging/in_app_message_event.dart';
import 'package:pet_hospital_flutter/core/storage/conversation_visibility_store.dart';
import 'package:pet_hospital_flutter/features/chat/consultation_messaging_session.dart';
import 'package:pet_hospital_flutter/features/chat/data/consultation_messaging_repository.dart';
import 'package:pet_hospital_flutter/features/chat/data/consultation_realtime_socket_client.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/chat/domain/consultation_conversation.dart';

void main() {
  test('全局收到非活跃咨询消息时增加未读并去重', () async {
    final repository = _FakeConsultationRepository()
      ..unreadCount = 2
      ..conversations = [_conversation(unreadCount: 2)];
    final socket = _FakeConsultationSocket();
    final session = ConsultationMessagingSession(
      ownerUserId: 7,
      repository: repository,
      socket: socket,
      onSessionRevoked: () async {},
    );
    addTearDown(session.close);

    await session.start();
    expect(session.totalUnreadCount, 2);
    expect(socket.connectCount, 1);
    final events = <InAppMessageEvent>[];
    final subscription = session.incomingMessageEvents.listen(events.add);
    addTearDown(subscription.cancel);

    final message = _message(id: 101, conversationId: 'consultation-1');
    socket.emitMessage(message);
    socket.emitMessage(message);

    expect(session.totalUnreadCount, 3);
    expect(session.conversations.single.unreadCount, 3);
    expect(session.conversations.single.lastMessage?.id, 101);
    expect(events, hasLength(1));
    final event = events.single;
    expect(event.conversationId, 'consultation-1');
    expect(event.title, '陈医生');
    expect(event.preview, '医生回复');
  });

  test('活跃咨询收到消息时自动标记会话已读', () async {
    final repository = _FakeConsultationRepository()..unreadCount = 3;
    final socket = _FakeConsultationSocket();
    final session = ConsultationMessagingSession(
      ownerUserId: 7,
      repository: repository,
      socket: socket,
      onSessionRevoked: () async {},
    );
    addTearDown(session.close);

    await session.start();
    await session.openConversation('consultation-1');
    expect(session.totalUnreadCount, 0);

    socket.emitMessage(_message(id: 102, conversationId: 'consultation-1'));
    await Future<void>.delayed(Duration.zero);

    expect(session.totalUnreadCount, 0);
    expect(repository.markedConversationIds, [
      'consultation-1',
      'consultation-1',
    ]);
  });

  test('暂停后断开，恢复时重新连接并校准未读', () async {
    var revoked = false;
    final repository = _FakeConsultationRepository()..unreadCount = 1;
    final socket = _FakeConsultationSocket();
    final session = ConsultationMessagingSession(
      ownerUserId: 7,
      repository: repository,
      socket: socket,
      onSessionRevoked: () async {
        revoked = true;
      },
    );
    addTearDown(session.close);

    await session.start();
    await session.pause();
    repository.unreadCount = 5;
    await session.resume();

    expect(socket.pauseCount, 1);
    expect(socket.connectCount, 2);
    expect(session.totalUnreadCount, 5);

    socket.emitSessionRevoked();
    await Future<void>.delayed(Duration.zero);
    expect(revoked, isTrue);
  });

  test('医生会话分页合并时去重并保留倒序', () async {
    final repository = _FakeConsultationRepository()
      ..pages = {
        1: [
          _conversation(
            conversationId: 'consultation-1',
            unreadCount: 0,
            updatedAt: DateTime(2026, 7, 27, 10),
          ),
        ],
        2: [
          _conversation(
            conversationId: 'consultation-2',
            unreadCount: 0,
            updatedAt: DateTime(2026, 7, 27, 11),
          ),
        ],
      }
      ..configuredTotalPages = 2;
    final session = ConsultationMessagingSession(
      ownerUserId: 7,
      repository: repository,
      socket: _FakeConsultationSocket(),
      onSessionRevoked: () async {},
    );
    addTearDown(session.close);

    await session.start();
    expect(repository.requestedPages, [1]);
    expect(session.hasMoreConversations, isTrue);

    await session.loadMoreConversations();

    expect(repository.requestedPages, [1, 2]);
    expect(repository.requestedPageSizes, everyElement(20));
    expect(session.conversations.map((item) => item.conversationId), [
      'consultation-2',
      'consultation-1',
    ]);
    expect(session.hasMoreConversations, isFalse);
  });

  test('隐藏医生会话后新消息会恢复显示', () async {
    final repository = _FakeConsultationRepository()
      ..unreadCount = 2
      ..conversations = [_conversation(unreadCount: 2)];
    final visibility = _FakeVisibilityStore();
    final socket = _FakeConsultationSocket();
    final session = ConsultationMessagingSession(
      ownerUserId: 7,
      repository: repository,
      socket: socket,
      visibilityStore: visibility,
      onSessionRevoked: () async {},
    );
    addTearDown(session.close);

    await session.start();
    await session.hideConversation(session.conversations.single);

    expect(session.conversations, isEmpty);
    expect(visibility.hidden, {'consultation-1'});
    socket.emitMessage(_message(id: 103, conversationId: 'consultation-1'));
    await Future<void>.delayed(Duration.zero);

    expect(session.conversations.single.conversationId, 'consultation-1');
    expect(session.conversations.single.unreadCount, 1);
    expect(visibility.hidden, isEmpty);
  });
}

ChatMessage _message({required int id, required String conversationId}) {
  return ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: 10,
    receiverId: 7,
    content: '医生回复',
    type: ChatMessageType.text,
    isAutoReply: false,
    isRead: false,
    createdAt: DateTime(2026, 7, 27, 12),
  );
}

class _FakeConsultationRepository
    implements ConsultationMessagingRepositoryGateway {
  int unreadCount = 0;
  List<ConsultationConversation> conversations = const [];
  Map<int, List<ConsultationConversation>> pages = const {};
  int? configuredTotalPages;
  final List<int> requestedPages = [];
  final List<int> requestedPageSizes = [];
  final List<String> markedConversationIds = [];

  @override
  Future<ConsultationConversationPage> loadConversations({
    int page = 1,
    int pageSize = 100,
  }) async {
    requestedPages.add(page);
    requestedPageSizes.add(pageSize);
    final items = pages.isEmpty
        ? (page == 1 ? conversations : const <ConsultationConversation>[])
        : pages[page] ?? const <ConsultationConversation>[];
    final totalPages = configuredTotalPages ?? (conversations.isEmpty ? 0 : 1);
    return ConsultationConversationPage(
      items: items,
      page: page,
      pageSize: pageSize,
      total: pages.isEmpty
          ? conversations.length
          : pages.values.fold(0, (total, items) => total + items.length),
      totalPages: totalPages,
    );
  }

  @override
  Future<int> loadUnreadCount() async => unreadCount;

  @override
  Future<void> markConversationRead(String conversationId) async {
    markedConversationIds.add(conversationId);
    unreadCount = 0;
  }
}

ConsultationConversation _conversation({
  String conversationId = 'consultation-1',
  required int unreadCount,
  DateTime? updatedAt,
}) {
  return ConsultationConversation(
    conversationId: conversationId,
    userId: 7,
    doctorId: 10,
    doctorName: '陈医生',
    doctorAvatarUrl: '/doctor.png',
    status: ChatSessionStatus.paid,
    paymentRequired: false,
    isTemporary: false,
    unreadCount: unreadCount,
    createdAt: DateTime(2026, 7, 27, 10),
    updatedAt: updatedAt ?? DateTime(2026, 7, 27, 11),
  );
}

class _FakeVisibilityStore implements ConversationVisibilityGateway {
  final Set<String> hidden = <String>{};

  @override
  Future<void> hideConversation({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required String conversationId,
  }) async {
    hidden.add(conversationId);
  }

  @override
  Future<Set<String>> loadHiddenConversationIds({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
  }) async => {...hidden};

  @override
  Future<void> restoreConversation({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required String conversationId,
  }) async {
    hidden.remove(conversationId);
  }
}

class _FakeConsultationSocket implements ConsultationRealtimeGateway {
  final _messages = StreamController<ChatMessage>.broadcast(sync: true);
  final _connections = StreamController<bool>.broadcast(sync: true);
  final _errors = StreamController<Object>.broadcast(sync: true);
  final _revoked = StreamController<Object?>.broadcast(sync: true);

  int connectCount = 0;
  int pauseCount = 0;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<ChatMessage> get messages => _messages.stream;

  @override
  Stream<bool> get connectionChanges => _connections.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Stream<Object?> get sessionRevoked => _revoked.stream;

  @override
  Future<void> connect() async {
    connectCount += 1;
    _connected = true;
    _connections.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    _connected = false;
    _connections.add(false);
  }

  @override
  Future<void> close() async {
    await Future.wait<void>([
      _messages.close(),
      _connections.close(),
      _errors.close(),
      _revoked.close(),
    ]);
  }

  void emitMessage(ChatMessage message) => _messages.add(message);

  void emitSessionRevoked() => _revoked.add(const {});
}
