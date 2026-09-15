import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/chat/consultation_messaging_session.dart';
import 'package:pet_hospital_flutter/features/chat/data/consultation_messaging_repository.dart';
import 'package:pet_hospital_flutter/features/chat/data/consultation_realtime_socket_client.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/chat/domain/consultation_conversation.dart';
import 'package:pet_hospital_flutter/features/chat/presentation/consultation_conversation_list_view.dart';

void main() {
  testWidgets('医生咨询列表在窄屏展示状态、消息和未读并支持搜索与打开', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ListRepository();
    final socket = _ListSocket();
    final session = ConsultationMessagingSession(
      ownerUserId: 7,
      repository: repository,
      socket: socket,
      onSessionRevoked: () async {},
    );
    await session.start();
    ConsultationConversation? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationConversationListView(
          session: session,
          onOpenConversation: (conversation) => opened = conversation,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('医生咨询'), findsOneWidget);
    expect(find.text('陈医生'), findsOneWidget);
    expect(find.text('服务中'), findsOneWidget);
    expect(find.text('检查结果正常'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey('consultation-conversation-conversation-1')),
    );
    expect(opened?.conversationId, 'conversation-1');

    await tester.enterText(
      find.byKey(const ValueKey('consultation-conversation-search')),
      '不存在',
    );
    await tester.pump();
    expect(find.text('没有匹配的咨询会话'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('consultation-conversation-search')),
      '',
    );
    await tester.pump();
    await tester.fling(
      find.byKey(const ValueKey('consultation-swipe-conversation-1')),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('consultation-hide-conversation-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('consultation-conversation-conversation-1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('consultation-hide-conversation-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('consultation-conversation-conversation-1')),
      findsNothing,
    );
  });
}

class _ListRepository implements ConsultationMessagingRepositoryGateway {
  @override
  Future<ConsultationConversationPage> loadConversations({
    int page = 1,
    int pageSize = 100,
  }) async {
    return ConsultationConversationPage(
      items: [
        ConsultationConversation(
          conversationId: 'conversation-1',
          userId: 7,
          doctorId: 10,
          doctorName: '陈医生',
          doctorAvatarUrl: '',
          status: ChatSessionStatus.paid,
          paymentRequired: false,
          isTemporary: false,
          orderId: 71,
          lastMessage: ConsultationConversationLastMessage(
            id: 101,
            conversationId: 'conversation-1',
            senderId: 10,
            receiverId: 7,
            content: '检查结果正常',
            type: ChatMessageType.text,
            isAutoReply: false,
            createdAt: DateTime(2026, 7, 27, 12),
          ),
          unreadCount: 7,
          createdAt: DateTime(2026, 7, 27, 10),
          updatedAt: DateTime(2026, 7, 27, 12),
        ),
      ],
      page: page,
      pageSize: pageSize,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<int> loadUnreadCount() async => 7;

  @override
  Future<void> markConversationRead(String conversationId) async {}
}

class _ListSocket implements ConsultationRealtimeGateway {
  bool _connected = false;

  @override
  Stream<bool> get connectionChanges => const Stream.empty();

  @override
  Stream<Object> get errors => const Stream.empty();

  @override
  bool get isConnected => _connected;

  @override
  Stream<ChatMessage> get messages => const Stream.empty();

  @override
  Stream<Object?> get sessionRevoked => const Stream.empty();

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> pause() async {
    _connected = false;
  }

  @override
  Future<void> close() async {}
}
