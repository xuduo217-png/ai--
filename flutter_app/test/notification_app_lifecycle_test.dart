import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/app.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/chat/data/chat_repository.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/home/domain/home_models.dart';
import 'package:pet_hospital_flutter/features/mall/domain/mall_models.dart';
import 'package:pet_hospital_flutter/features/notifications/domain/notification_models.dart';
import 'package:pet_hospital_flutter/features/notifications/presentation/notification_badge_controller.dart';

void main() {
  testWidgets('App 使用简体中文本地化', (tester) async {
    final authController = AuthController(
      gateway: const _AuthGateway(),
      sessionStore: _SessionStore(null),
    );
    await authController.initialize();

    await tester.pumpWidget(
      PetHospitalApp(
        authController: authController,
        homeGateway: const _HomeGateway(),
        mallGateway: const _MallGateway(),
        chatGateway: const _ChatGateway(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    final localizations = MaterialLocalizations.of(context);
    expect(Localizations.localeOf(context), const Locale('zh', 'CN'));
    expect(localizations.cutButtonLabel, '剪切');
    expect(localizations.copyButtonLabel, '复制');
    expect(localizations.pasteButtonLabel, '粘贴');
    expect(localizations.selectAllButtonLabel, '全选');
  });

  testWidgets('App 登录会话管理通知首拉、前后台轮询和退出清理', (tester) async {
    final store = _SessionStore(
      const AuthSession(
        accessToken: 'token',
        accountType: AccountType.user,
        profile: {'id': 7, 'phone': '13800138000'},
      ),
    );
    final authController = AuthController(
      gateway: const _AuthGateway(),
      sessionStore: store,
    );
    await authController.initialize();
    final gateway = _NotificationGateway()..counts.addAll([3, 4]);
    final timers = _PollFactory();
    final badgeController = NotificationBadgeController(
      gateway: gateway,
      timerFactory: timers.call,
    );

    await tester.pumpWidget(
      PetHospitalApp(
        authController: authController,
        homeGateway: const _HomeGateway(),
        mallGateway: const _MallGateway(),
        chatGateway: const _ChatGateway(),
        notificationBadgeController: badgeController,
      ),
    );
    await tester.pumpAndSettle();

    expect(badgeController.ownerUserId, 7);
    expect(badgeController.value, 3);
    expect(gateway.calls, 1);
    expect(timers.active, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(timers.active, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(badgeController.value, 4);
    expect(gateway.calls, 2);
    expect(timers.active, hasLength(1));

    await authController.invalidateLocalSession();
    await tester.pumpAndSettle();
    expect(badgeController.ownerUserId, isNull);
    expect(badgeController.value, 0);
    expect(timers.active, isEmpty);
  });
}

class _PollFactory {
  final List<_PollHandle> created = [];

  NotificationPollHandle call(Duration _, void Function() callback) {
    final handle = _PollHandle(callback);
    created.add(handle);
    return handle;
  }

  List<_PollHandle> get active =>
      created.where((handle) => !handle.cancelled).toList();
}

class _PollHandle implements NotificationPollHandle {
  _PollHandle(this.callback);

  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

class _NotificationGateway implements NotificationGateway {
  final List<int> counts = [];
  int calls = 0;

  @override
  Future<int> loadUnreadCount() async {
    calls += 1;
    return counts.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionStore implements SessionStore {
  _SessionStore(this.session);

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

class _AuthGateway implements AuthGateway {
  const _AuthGateway();

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async =>
      savedSession;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeGateway implements HomeGateway {
  const _HomeGateway();

  @override
  Future<HomeSnapshot> loadHome({required bool authenticated}) async =>
      const HomeSnapshot();
}

class _MallGateway implements MallGateway {
  const _MallGateway();

  @override
  Future<MallSnapshot> loadMall({required bool authenticated}) async =>
      const MallSnapshot();

  @override
  Future<bool> loadCartBadge() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatGateway implements ChatGateway {
  const _ChatGateway();

  @override
  Future<ChatBootstrap> loadChat(int doctorId) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
