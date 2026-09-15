import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/messaging/in_app_message_event.dart';
import 'package:pet_hospital_flutter/features/chat/data/consultation_realtime_socket_client.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/domain/doctor_portal_models.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/presentation/doctor_portal_controller.dart';

void main() {
  test('医生首页全局收到消息后更新摘要、未读和排序，并对重复事件去重', () async {
    final gateway = _DoctorGateway()
      ..consultations = [
        _consultation(
          id: 1,
          conversationId: 'conversation-1',
          lastMessage: '旧消息',
          lastMessageAt: DateTime.utc(2026, 7, 28, 8),
        ),
        _consultation(
          id: 2,
          conversationId: 'conversation-2',
          lastMessage: '较新消息',
          lastMessageAt: DateTime.utc(2026, 7, 28, 9),
        ),
      ];
    final realtime = _RealtimeGateway();
    final controller = DoctorConsultationsController(
      gateway: gateway,
      doctorId: 7,
      realtime: realtime,
      onSessionRevoked: () async {},
    );
    addTearDown(() async {
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
    });
    final events = <InAppMessageEvent>[];
    final subscription = controller.incomingMessageEvents.listen(events.add);
    addTearDown(subscription.cancel);

    await controller.start();
    expect(realtime.connectCount, 1);

    final incoming = _message(
      id: 101,
      conversationId: 'conversation-1',
      content: '宠物刚刚吐了',
    );
    realtime.emitMessage(incoming);
    realtime.emitMessage(incoming);
    await Future<void>.delayed(Duration.zero);

    expect(controller.consultations.map((item) => item.conversationId), [
      'conversation-1',
      'conversation-2',
    ]);
    expect(controller.consultations.first.lastMessage, '宠物刚刚吐了');
    expect(controller.consultations.first.unreadCount, 1);
    expect(controller.totalUnreadCount, 1);
    expect(events, hasLength(1));
    expect(events.single.conversationId, 'conversation-1');
    expect(events.single.title, '用户1');
    expect(events.single.preview, '宠物刚刚吐了');
  });

  test('聊天会话可见时收到消息保持已读，离开后重新累计未读', () async {
    final gateway = _DoctorGateway()
      ..consultations = [
        _consultation(id: 1, conversationId: 'conversation-1'),
      ];
    final realtime = _RealtimeGateway();
    final controller = DoctorConsultationsController(
      gateway: gateway,
      doctorId: 7,
      realtime: realtime,
      onSessionRevoked: () async {},
    );
    addTearDown(() async {
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
    });

    await controller.start();
    await controller.openConversation('conversation-1');
    realtime.emitMessage(
      _message(id: 102, conversationId: 'conversation-1', content: '还在吗'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.consultations.single.unreadCount, 0);
    expect(gateway.markedConversationIds, ['conversation-1', 'conversation-1']);

    controller.closeConversation('conversation-1');
    realtime.emitMessage(
      _message(id: 103, conversationId: 'conversation-1', content: '新的症状'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.consultations.single.unreadCount, 1);
  });

  test('医生端暂停时断开 Socket，恢复时刷新列表并重新连接', () async {
    final gateway = _DoctorGateway()
      ..consultations = [
        _consultation(id: 1, conversationId: 'conversation-1'),
      ];
    final realtime = _RealtimeGateway();
    final controller = DoctorConsultationsController(
      gateway: gateway,
      doctorId: 7,
      realtime: realtime,
      onSessionRevoked: () async {},
    );
    addTearDown(() async {
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
    });

    await controller.start();
    await controller.pause();
    await controller.resume();

    expect(realtime.pauseCount, 1);
    expect(realtime.connectCount, 2);
    expect(gateway.loadCount, 2);
  });
}

DoctorConsultation _consultation({
  required int id,
  required String conversationId,
  String? lastMessage,
  DateTime? lastMessageAt,
}) {
  return DoctorConsultation(
    id: id,
    conversationId: conversationId,
    userId: 12 + id,
    userName: '用户$id',
    userAvatarUrl: '',
    doctorId: 7,
    status: DoctorConsultationStatus.paid,
    serviceItemName: '在线咨询',
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
  );
}

ChatMessage _message({
  required int id,
  required String conversationId,
  required String content,
}) {
  return ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: 12,
    receiverId: 7,
    content: content,
    type: ChatMessageType.text,
    isAutoReply: false,
    isRead: false,
    createdAt: DateTime.utc(2026, 7, 28, 10, id),
  );
}

class _DoctorGateway implements DoctorPortalGateway {
  List<DoctorConsultation> consultations = const [];
  final List<String> markedConversationIds = [];
  int loadCount = 0;

  @override
  Future<DoctorConsultationPage> loadConsultations({
    required int doctorId,
    required DoctorConsultationStatus status,
    int page = 1,
    int pageSize = 20,
  }) async {
    loadCount += 1;
    return DoctorConsultationPage(
      items: consultations,
      total: consultations.length,
      page: page,
      pageSize: pageSize,
      totalPages: consultations.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    markedConversationIds.add(conversationId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RealtimeGateway implements ConsultationRealtimeGateway {
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
    _connected = false;
    await Future.wait<void>([
      _messages.close(),
      _connections.close(),
      _errors.close(),
      _revoked.close(),
    ]);
  }

  void emitMessage(ChatMessage message) => _messages.add(message);
}
