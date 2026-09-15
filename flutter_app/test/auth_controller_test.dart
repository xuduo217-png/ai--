import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';

void main() {
  test('登录成功后保存会话并切换认证状态', () async {
    final store = _MemorySessionStore();
    final controller = AuthController(
      gateway: _SuccessGateway(),
      sessionStore: store,
    );
    await controller.initialize();

    await controller.login(
      phone: '13800138000',
      password: '123456',
      accountType: AccountType.user,
    );

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.session?.phone, '13800138000');
    expect(store.session?.accessToken, 'test-token');
  });

  test('启动校验失败时清理过期会话', () async {
    final store = _MemorySessionStore()
      ..session = const AuthSession(
        accessToken: 'expired',
        accountType: AccountType.user,
        profile: {'phone': '13800138000'},
      );
    final controller = AuthController(
      gateway: _RestoreFailureGateway(),
      sessionStore: store,
    );

    await controller.initialize();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(store.session, isNull);
  });

  test('注册成功后保存用户会话并完成自动登录', () async {
    final store = _MemorySessionStore();
    final controller = AuthController(
      gateway: _SuccessGateway(),
      sessionStore: store,
    );
    await controller.initialize();

    await controller.register(
      phone: '13800138000',
      code: '123456',
      password: '123456',
    );

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.session?.accountType, AccountType.user);
    expect(store.session?.accessToken, 'register-token');
  });

  test('本地会话失效先执行账号数据清理，再清除认证状态', () async {
    final store = _MemorySessionStore();
    final events = <String>[];
    final controller = AuthController(
      gateway: _SuccessGateway(),
      sessionStore: store,
    );
    controller.setLocalSessionInvalidator((session) async {
      events.add('cleanup:${session.phone}');
      expect(store.session, isNotNull);
    });
    await controller.login(
      phone: '13800138000',
      password: '123456',
      accountType: AccountType.user,
    );

    await controller.invalidateLocalSession();

    expect(events, ['cleanup:13800138000']);
    expect(controller.status, AuthStatus.unauthenticated);
    expect(store.session, isNull);
  });

  test('服务端登出失败仍清理账号数据与本地认证状态', () async {
    final store = _MemorySessionStore();
    final controller = AuthController(
      gateway: _LogoutFailureGateway(),
      sessionStore: store,
    );
    await controller.login(
      phone: '13800138000',
      password: '123456',
      accountType: AccountType.user,
    );
    var cleanedPhone = '';
    controller.setLocalSessionInvalidator((session) async {
      cleanedPhone = session.phone;
    });

    await controller.logout();

    expect(cleanedPhone, '13800138000');
    expect(store.session, isNull);
    expect(controller.status, AuthStatus.unauthenticated);
  });

  test('资料 patch 持久化后更新内存、通知监听器并保留未知字段', () async {
    final store = _MemorySessionStore();
    final controller = AuthController(
      gateway: _SuccessGateway(),
      sessionStore: store,
    );
    await controller.login(
      phone: '13800138000',
      password: '123456',
      accountType: AccountType.user,
    );
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    await controller.updateProfile(const {
      'username': '修改后',
      'gender': 2,
      'avatar': null,
    });

    expect(controller.session?.accessToken, 'test-token');
    expect(controller.session?.profile, {
      'phone': '13800138000',
      'username': '修改后',
      'gender': 2,
      'avatar': null,
      'opaque': const {'version': 1},
    });
    expect(store.session?.profile, controller.session?.profile);
    expect(notifications, 1);

    final restoredController = AuthController(
      gateway: _SuccessGateway(),
      sessionStore: store,
    );
    await restoredController.initialize();
    expect(restoredController.session?.profile['username'], '修改后');
    expect(restoredController.session?.profile['opaque'], const {'version': 1});
  });

  test('资料持久化失败时传播错误且不修改内存或发送通知', () async {
    final store = _MemorySessionStore();
    final controller = AuthController(
      gateway: _SuccessGateway(),
      sessionStore: store,
    );
    await controller.login(
      phone: '13800138000',
      password: '123456',
      accountType: AccountType.user,
    );
    final originalSession = controller.session;
    var notifications = 0;
    controller.addListener(() => notifications += 1);
    store.failNextSave = true;

    await expectLater(
      controller.updateProfile(const {'username': '不会生效'}),
      throwsStateError,
    );

    expect(controller.session, same(originalSession));
    expect(store.session, same(originalSession));
    expect(notifications, 0);
  });

  test('未登录时拒绝资料 patch 且不写入 store', () async {
    final store = _MemorySessionStore();
    final controller = AuthController(
      gateway: _SuccessGateway(),
      sessionStore: store,
    );
    await controller.initialize();
    final saveAttempts = store.saveAttempts;

    await expectLater(
      controller.updateProfile(const {'username': '无效'}),
      throwsStateError,
    );

    expect(store.saveAttempts, saveAttempts);
    expect(controller.status, AuthStatus.unauthenticated);
  });
}

class _MemorySessionStore implements SessionStore {
  AuthSession? session;
  bool failNextSave = false;
  int saveAttempts = 0;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<String?> readToken() async => session?.accessToken;

  @override
  Future<void> saveSession(AuthSession session) async {
    saveAttempts += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    this.session = session;
  }
}

class _SuccessGateway implements AuthGateway {
  @override
  Future<AuthSession> login({
    required String phone,
    required String password,
    required AccountType accountType,
  }) async {
    return AuthSession(
      accessToken: 'test-token',
      accountType: accountType,
      profile: {
        'phone': phone,
        'username': '修改前',
        'opaque': const {'version': 1},
      },
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> register({
    required String phone,
    required String code,
    required String password,
  }) async {
    return AuthSession(
      accessToken: 'register-token',
      accountType: AccountType.user,
      profile: {'phone': phone},
    );
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

class _RestoreFailureGateway extends _SuccessGateway {
  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) {
    throw Exception('expired');
  }
}

class _LogoutFailureGateway extends _SuccessGateway {
  @override
  Future<void> logout() => throw StateError('server unavailable');
}
