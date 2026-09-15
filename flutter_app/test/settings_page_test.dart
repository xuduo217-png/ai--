import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/platform/external_uri_launcher.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';
import 'package:pet_hospital_flutter/features/settings/domain/settings_models.dart';
import 'package:pet_hospital_flutter/features/settings/presentation/pages/settings_page.dart';

import 'support/wp11_viewports.dart';

void main() {
  for (final viewport in wp11Viewports) {
    testWidgets('设置页在 ${viewport.label} 稳定显示联系信息', (tester) async {
      configureWp11Viewport(tester, viewport);
      final auth = await _authenticatedController();
      final gateway = _SettingsGateway(
        contactInfo: const ContactInfo(
          hotline: '400-123-4567-EXT-888888',
          wechatQrCode: '',
          workingHours: '周一至周日 09:00-21:00，法定节假日工作时间以公告为准',
        ),
      );

      await tester.pumpWidget(
        _app(
          gateway: gateway,
          authController: auth,
          textScale: viewport.textScale,
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFDEE9FF));
      expect(appBar.surfaceTintColor, const Color(0xFFDEE9FF));
      expect(appBar.foregroundColor, AppColors.ink);
      expect(find.text('联系客服'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings-contact-qr-placeholder')),
        findsOneWidget,
      );
      expect(find.textContaining('400-123-4567'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('拨号确认后直接尝试启动且正确处理启动失败', (tester) async {
    final auth = await _authenticatedController();
    final launcher = _UriLauncher();
    final gateway = _SettingsGateway(
      contactInfo: const ContactInfo(
        hotline: '400-123-4567',
        wechatQrCode: '',
        workingHours: '全天',
      ),
    );
    await tester.pumpWidget(
      _app(gateway: gateway, authController: auth, launcher: launcher),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-phone')));
    await tester.pumpAndSettle();
    expect(find.text('拨打客服热线'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(launcher.canLaunchUris, isEmpty);
    expect(launcher.launchUris, isEmpty);

    await tester.tap(find.byKey(const ValueKey('settings-phone')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拨打'));
    await tester.pumpAndSettle();

    expect(launcher.canLaunchUris, isEmpty);
    expect(launcher.launchUris.single.toString(), 'tel:400-123-4567');

    launcher
      ..launchResult = false
      ..launchUris.clear();
    await tester.tap(find.byKey(const ValueKey('settings-phone')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拨打'));
    await tester.pumpAndSettle();
    expect(find.text('无法打开拨号界面'), findsOneWidget);
    expect(launcher.canLaunchUris, isEmpty);
    expect(launcher.launchUris.single.toString(), 'tel:400-123-4567');
  });

  testWidgets('退出登录取消不调用 gateway，确认期间阻止重复操作', (tester) async {
    final logoutCompleter = Completer<void>();
    final authGateway = _AuthGateway(logoutCompleter: logoutCompleter);
    final auth = await _authenticatedController(gateway: authGateway);
    await tester.pumpWidget(
      _app(gateway: _SettingsGateway(), authController: auth),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(authGateway.logoutCalls, 0);

    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出'));
    await tester.pump();

    expect(authGateway.logoutCalls, 1);
    final logoutButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('settings-logout')),
    );
    expect(logoutButton.onPressed, isNull);

    logoutCompleter.complete();
    await tester.pumpAndSettle();
    expect(auth.status, AuthStatus.unauthenticated);
  });

  testWidgets('注销操作使用危险样式，失败后保持登录并展示错误', (tester) async {
    final auth = await _authenticatedController();
    final accountGateway = _ProfileGateway()
      ..deleteError = StateError('server rejected');
    await tester.pumpWidget(
      _app(
        gateway: _SettingsGateway(),
        authController: auth,
        accountGateway: accountGateway,
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('settings-delete-account')),
    );
    expect(
      deleteButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      const Color(0xFFB42318),
    );

    await tester.tap(find.byKey(const ValueKey('settings-delete-account')));
    await tester.pumpAndSettle();
    expect(find.text('注销账号'), findsWidgets);
    expect(find.textContaining('订单等依法需要保留'), findsOneWidget);
    await tester.tap(find.text('再想想'));
    await tester.pumpAndSettle();
    expect(accountGateway.deleteCalls, 0);

    await tester.tap(find.byKey(const ValueKey('settings-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认注销'));
    await tester.pumpAndSettle();

    expect(accountGateway.deleteCalls, 1);
    expect(auth.status, AuthStatus.authenticated);
    expect(find.text('注销失败，请稍后重试'), findsOneWidget);
  });
}

Widget _app({
  required SettingsGateway gateway,
  required AuthController authController,
  ExternalUriLauncher? launcher,
  ProfileGateway? accountGateway,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: wp11TextScaleBuilder(textScale),
    home: SettingsPage(
      settingsGateway: gateway,
      accountGateway: accountGateway ?? _ProfileGateway(),
      authController: authController,
      uriLauncher: launcher ?? _UriLauncher(),
      contentBaseUrl: 'https://api.example.com/server-api',
    ),
  );
}

Future<AuthController> _authenticatedController({AuthGateway? gateway}) async {
  final controller = AuthController(
    gateway: gateway ?? _AuthGateway(),
    sessionStore: _SessionStore(_session),
  );
  await controller.initialize();
  return controller;
}

const _session = AuthSession(
  accessToken: 'token',
  accountType: AccountType.user,
  profile: {'id': 7, 'phone': '13800138000'},
);

class _SettingsGateway implements SettingsGateway {
  _SettingsGateway({this.contactInfo = ContactInfo.empty});

  final ContactInfo contactInfo;

  @override
  Future<ContactInfo> loadContactInfo() async => contactInfo;

  @override
  Future<SystemArticle?> loadArticle(SystemArticleType type) async => null;
}

class _UriLauncher implements ExternalUriLauncher {
  bool launchResult = true;
  final List<Uri> canLaunchUris = [];
  final List<Uri> launchUris = [];

  @override
  Future<bool> canLaunch(Uri uri) async {
    canLaunchUris.add(uri);
    return false;
  }

  @override
  Future<bool> launch(Uri uri) async {
    launchUris.add(uri);
    return launchResult;
  }
}

class _ProfileGateway implements ProfileGateway {
  Object? deleteError;
  int deleteCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls += 1;
    if (deleteError case final error?) throw error;
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
