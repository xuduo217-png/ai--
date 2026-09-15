import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';
import 'package:pet_hospital_flutter/features/settings/domain/settings_models.dart';
import 'package:pet_hospital_flutter/features/settings/presentation/settings_controller.dart';

void main() {
  test('联系方式加载错误可重试且不会残留旧错误', () async {
    final gateway = _SettingsGateway()..contactError = StateError('offline');
    final controller = _controller(settingsGateway: gateway);

    await controller.loadContactInfo();

    expect(controller.contactInfo, ContactInfo.empty);
    expect(controller.contactError, isA<StateError>());

    gateway
      ..contactError = null
      ..contactInfo = const ContactInfo(
        hotline: '400-000-0000',
        wechatQrCode: '',
        workingHours: '全天',
      );
    await controller.loadContactInfo();

    expect(controller.contactInfo.hotline, '400-000-0000');
    expect(controller.contactError, isNull);
  });

  test('登出复用 AuthController 且进行中拒绝重复提交', () async {
    final completer = Completer<void>();
    final authGateway = _AuthGateway(logoutCompleter: completer);
    final store = _SessionStore(_session);
    final authController = AuthController(
      gateway: authGateway,
      sessionStore: store,
    );
    await authController.initialize();
    final controller = _controller(authController: authController);

    final first = controller.logout();
    await Future<void>.delayed(Duration.zero);
    final second = await controller.logout();

    expect(controller.loggingOut, isTrue);
    expect(second, isFalse);
    expect(authGateway.logoutCalls, 1);

    completer.complete();
    expect(await first, isTrue);
    expect(authController.status, AuthStatus.unauthenticated);
    expect(store.clearCalls, 1);
  });

  test('注销失败时保持登录且不提前清理本地会话', () async {
    final accountGateway = _ProfileGateway()
      ..deleteError = StateError('delete failed');
    final store = _SessionStore(_session);
    final authController = AuthController(
      gateway: _AuthGateway(),
      sessionStore: store,
    );
    await authController.initialize();
    final controller = _controller(
      authController: authController,
      accountGateway: accountGateway,
    );

    expect(await controller.deleteAccount(), isFalse);

    expect(accountGateway.deleteCalls, 1);
    expect(authController.status, AuthStatus.authenticated);
    expect(store.clearCalls, 0);
    expect(controller.accountActionError, isA<StateError>());
  });

  test('注销成功后才清理完整本地会话', () async {
    final accountGateway = _ProfileGateway();
    final store = _SessionStore(_session);
    final authController = AuthController(
      gateway: _AuthGateway(),
      sessionStore: store,
    );
    await authController.initialize();
    var invalidatedUserId = 0;
    authController.setLocalSessionInvalidator((session) async {
      invalidatedUserId = session.profile['id'] as int;
    });
    final controller = _controller(
      authController: authController,
      accountGateway: accountGateway,
    );

    expect(await controller.deleteAccount(), isTrue);

    expect(accountGateway.deleteCalls, 1);
    expect(invalidatedUserId, 7);
    expect(store.clearCalls, 1);
    expect(authController.status, AuthStatus.unauthenticated);
  });

  test('注销进行中拒绝重复请求', () async {
    final completer = Completer<void>();
    final accountGateway = _ProfileGateway(deleteCompleter: completer);
    final authController = AuthController(
      gateway: _AuthGateway(),
      sessionStore: _SessionStore(_session),
    );
    await authController.initialize();
    final controller = _controller(
      authController: authController,
      accountGateway: accountGateway,
    );

    final first = controller.deleteAccount();
    await Future<void>.delayed(Duration.zero);
    final second = await controller.deleteAccount();

    expect(second, isFalse);
    expect(controller.deletingAccount, isTrue);
    expect(accountGateway.deleteCalls, 1);

    completer.complete();
    expect(await first, isTrue);
  });

  test('文章 controller 区分空态、错误与重试成功', () async {
    final gateway = _SettingsGateway();
    final controller = SystemArticleController(
      gateway: gateway,
      type: SystemArticleType.aboutUs,
    );

    await controller.load();
    expect(controller.isEmpty, isTrue);
    expect(controller.error, isNull);

    gateway.articleError = StateError('offline');
    await controller.load();
    expect(controller.error, isA<StateError>());

    gateway
      ..articleError = null
      ..article = const SystemArticle(
        id: 3,
        type: SystemArticleType.aboutUs,
        html: '<p>关于我们</p>',
      );
    await controller.load();

    expect(controller.article?.html, contains('关于我们'));
    expect(controller.error, isNull);
    expect(controller.isEmpty, isFalse);
  });
}

SettingsController _controller({
  SettingsGateway? settingsGateway,
  ProfileGateway? accountGateway,
  AuthController? authController,
}) {
  return SettingsController(
    settingsGateway: settingsGateway ?? _SettingsGateway(),
    accountGateway: accountGateway ?? _ProfileGateway(),
    authController:
        authController ??
        AuthController(gateway: _AuthGateway(), sessionStore: _SessionStore()),
  );
}

const _session = AuthSession(
  accessToken: 'token',
  accountType: AccountType.user,
  profile: {'id': 7, 'phone': '13800138000'},
);

class _SettingsGateway implements SettingsGateway {
  ContactInfo contactInfo = ContactInfo.empty;
  Object? contactError;
  SystemArticle? article;
  Object? articleError;

  @override
  Future<ContactInfo> loadContactInfo() async {
    if (contactError case final error?) throw error;
    return contactInfo;
  }

  @override
  Future<SystemArticle?> loadArticle(SystemArticleType type) async {
    if (articleError case final error?) throw error;
    return article;
  }
}

class _ProfileGateway implements ProfileGateway {
  _ProfileGateway({this.deleteCompleter});

  final Completer<void>? deleteCompleter;
  Object? deleteError;
  int deleteCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls += 1;
    if (deleteError case final error?) throw error;
    await deleteCompleter?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionStore implements SessionStore {
  _SessionStore([this.session]);

  AuthSession? session;
  int clearCalls = 0;

  @override
  Future<void> clearSession() async {
    clearCalls += 1;
    session = null;
  }

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<String?> readToken() async => session?.accessToken;

  @override
  Future<void> saveSession(AuthSession session) async => this.session = session;
}

class _AuthGateway implements AuthGateway {
  _AuthGateway({this.logoutCompleter});

  final Completer<void>? logoutCompleter;
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    await logoutCompleter?.future;
  }

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async =>
      savedSession;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
