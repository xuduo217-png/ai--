import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/app.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/pages/set_password_page.dart';
import 'package:pet_hospital_flutter/features/chat/data/chat_repository.dart';
import 'package:pet_hospital_flutter/features/chat/data/consultation_realtime_socket_client.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/domain/doctor_portal_models.dart';
import 'package:pet_hospital_flutter/features/home/domain/home_models.dart';
import 'package:pet_hospital_flutter/features/mall/domain/mall_models.dart';

void main() {
  testWidgets('会话失效后清空受保护路由且不能回退', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _MemorySessionStore()
      ..session = const AuthSession(
        accessToken: 'token',
        accountType: AccountType.user,
        profile: {'id': 7, 'phone': '13800138000'},
      );
    final controller = AuthController(
      gateway: _FakeAuthGateway(),
      sessionStore: store,
    );
    await controller.initialize();

    await tester.pumpWidget(
      PetHospitalApp(
        authController: controller,
        homeGateway: _FakeHomeGateway(),
        mallGateway: _FakeMallGateway(),
        chatGateway: _FakeChatGateway(),
      ),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('受保护页面')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('受保护页面'), findsOneWidget);

    await controller.invalidateLocalSession();
    await tester.pumpAndSettle();

    expect(find.text('受保护页面'), findsNothing);
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('未登录时展示用户/医生登录与注册入口', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AuthController(
      gateway: _FakeAuthGateway(),
      sessionStore: _MemorySessionStore(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      PetHospitalApp(
        authController: controller,
        homeGateway: _FakeHomeGateway(),
        mallGateway: _FakeMallGateway(),
        chatGateway: _FakeChatGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录医生端'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('宠物爱好者...'), findsOneWidget);
    expect(find.text('登陆'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('login-phone-input'))),
      const Size(326, 56),
    );

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();

    expect(find.text('欢迎加入!'), findsOneWidget);
    expect(find.text('注册请继续'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
  });

  testWidgets('认证页在紧凑手机尺寸下不会溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AuthController(
      gateway: _FakeAuthGateway(),
      sessionStore: _MemorySessionStore(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      PetHospitalApp(
        authController: controller,
        homeGateway: _FakeHomeGateway(),
        mallGateway: _FakeMallGateway(),
        chatGateway: _FakeChatGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('登陆'), findsOneWidget);
  });

  testWidgets('设置密码页保留 RN 的标题、账号卡片和固定操作', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AuthController(
      gateway: _FakeAuthGateway(),
      sessionStore: _MemorySessionStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SetPasswordPage(
          authController: controller,
          phone: '13800138000',
          code: '123456',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置密码'), findsOneWidget);
    expect(find.text('账号安全'), findsOneWidget);
    expect(find.text('13800138000'), findsOneWidget);
    expect(find.text('完成注册'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('医生实时收到用户消息后展示全局顶部提示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _MemorySessionStore()
      ..session = const AuthSession(
        accessToken: 'doctor-token',
        accountType: AccountType.doctor,
        profile: {'id': 7, 'name': '张医生'},
      );
    final controller = AuthController(
      gateway: _FakeAuthGateway(),
      sessionStore: store,
    );
    final realtime = _FakeConsultationRealtimeGateway();
    await controller.initialize();

    await tester.pumpWidget(
      PetHospitalApp(
        authController: controller,
        homeGateway: _FakeHomeGateway(),
        mallGateway: _FakeMallGateway(),
        chatGateway: _FakeChatGateway(),
        doctorPortalGateway: _FakeDoctorPortalGateway(),
        doctorRealtimeGatewayFactory: () => realtime,
      ),
    );
    await tester.pumpAndSettle();

    realtime.emitMessage(
      ChatMessage(
        id: 9,
        conversationId: '12_7',
        senderId: 12,
        senderName: '林女士',
        receiverId: 7,
        content: '宠物刚刚吐了',
        type: ChatMessageType.text,
        isAutoReply: false,
        isRead: false,
        createdAt: DateTime(2026, 8, 15, 10),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('in-app-message-banner')), findsOneWidget);
    final banner = find.byKey(const ValueKey('in-app-message-banner'));
    expect(
      find.descendant(of: banner, matching: find.text('林女士')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: banner, matching: find.text('宠物刚刚吐了')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _MemorySessionStore implements SessionStore {
  AuthSession? session;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<String?> readToken() async => session?.accessToken;

  @override
  Future<void> saveSession(AuthSession session) async => this.session = session;
}

class _FakeAuthGateway implements AuthGateway {
  @override
  Future<AuthSession> login({
    required String phone,
    required String password,
    required AccountType accountType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> register({
    required String phone,
    required String code,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
    required AccountType accountType,
  }) async {}

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async =>
      savedSession;

  @override
  Future<int> sendCode({
    required String phone,
    required String type,
    AccountType accountType = AccountType.user,
  }) async => 120;

  @override
  Future<void> verifyRegisterCode({
    required String phone,
    required String code,
  }) async {}

  @override
  Future<void> verifyResetPasswordCode({
    required String phone,
    required String code,
    required AccountType accountType,
  }) async {}
}

class _FakeHomeGateway implements HomeGateway {
  @override
  Future<HomeSnapshot> loadHome({required bool authenticated}) async =>
      const HomeSnapshot();
}

class _FakeMallGateway implements MallGateway {
  @override
  Future<void> addToCart({
    required int productId,
    required int? skuId,
    required int quantity,
  }) async {}

  @override
  Future<bool> loadCartBadge() async => false;

  @override
  Future<MallSnapshot> loadMall({required bool authenticated}) async =>
      const MallSnapshot();

  @override
  Future<MallProduct> loadProduct(int productId) => throw UnimplementedError();
}

class _FakeChatGateway implements ChatGateway {
  @override
  Future<ChatBootstrap> loadChat(int doctorId) => throw UnimplementedError();

  @override
  Future<ChatBootstrap> loadOrderChat({
    required int doctorId,
    required int orderId,
    required bool viewOnly,
  }) => throw UnimplementedError();

  @override
  Future<void> purchasePackage({
    required int doctorId,
    required int serviceItemId,
    String? conversationId,
  }) => throw UnimplementedError();

  @override
  Future<ChatBootstrap> refreshChat(int doctorId) => throw UnimplementedError();

  @override
  Future<ChatUploadResult> uploadMedia({
    required String path,
    required String fileName,
    required ChatMessageType type,
  }) => throw UnimplementedError();
}

class _FakeDoctorPortalGateway implements DoctorPortalGateway {
  static final consultation = DoctorConsultation(
    id: 4,
    conversationId: '12_7',
    userId: 12,
    userName: '林女士',
    userAvatarUrl: '',
    doctorId: 7,
    status: DoctorConsultationStatus.paid,
    serviceItemName: '在线咨询',
    lastMessage: '旧消息',
    serviceEndAt: DateTime(2099),
  );

  @override
  Future<DoctorConsultationPage> loadConsultations({
    required int doctorId,
    required DoctorConsultationStatus status,
    int page = 1,
    int pageSize = 20,
  }) async => DoctorConsultationPage(
    items: [consultation],
    total: 1,
    page: page,
    pageSize: pageSize,
    totalPages: 1,
  );

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConsultationRealtimeGateway implements ConsultationRealtimeGateway {
  final _messages = StreamController<ChatMessage>.broadcast(sync: true);
  final _connections = StreamController<bool>.broadcast(sync: true);
  final _errors = StreamController<Object>.broadcast(sync: true);
  final _revokedSessions = StreamController<Object?>.broadcast(sync: true);
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
  Stream<Object?> get sessionRevoked => _revokedSessions.stream;

  @override
  Future<void> connect() async {
    _connected = true;
    _connections.add(true);
  }

  @override
  Future<void> pause() async {
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
      _revokedSessions.close(),
    ]);
  }

  void emitMessage(ChatMessage message) => _messages.add(message);
}
