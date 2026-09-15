import 'package:flutter/foundation.dart';

import '../domain/auth_models.dart';

enum AuthStatus { initializing, unauthenticated, authenticated }

abstract interface class SessionStore {
  Future<String?> readToken();
  Future<AuthSession?> readSession();
  Future<void> saveSession(AuthSession session);
  Future<void> clearSession();
}

abstract interface class AuthGateway {
  Future<AuthSession> login({
    required String phone,
    required String password,
    required AccountType accountType,
  });

  Future<int> sendCode({
    required String phone,
    required String type,
    AccountType accountType = AccountType.user,
  });

  Future<void> verifyRegisterCode({
    required String phone,
    required String code,
  });

  Future<void> verifyResetPasswordCode({
    required String phone,
    required String code,
    required AccountType accountType,
  });

  Future<AuthSession> register({
    required String phone,
    required String code,
    required String password,
  });

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
    required AccountType accountType,
  });

  Future<AuthSession> restoreSession(AuthSession savedSession);
  Future<void> logout();
}

typedef LocalSessionInvalidator = Future<void> Function(AuthSession session);

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthGateway gateway,
    required SessionStore sessionStore,
  }) : _gateway = gateway,
       _sessionStore = sessionStore;

  final AuthGateway _gateway;
  final SessionStore _sessionStore;

  AuthStatus _status = AuthStatus.initializing;
  AuthSession? _session;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  LocalSessionInvalidator? _localSessionInvalidator;

  void setLocalSessionInvalidator(LocalSessionInvalidator? invalidator) {
    _localSessionInvalidator = invalidator;
  }

  Future<void> initialize() async {
    try {
      final savedSession = await _sessionStore.readSession();
      if (savedSession == null) {
        _setUnauthenticated();
        return;
      }

      final restoredSession = await _gateway.restoreSession(savedSession);
      await _sessionStore.saveSession(restoredSession);
      _session = restoredSession;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } on Object {
      await _sessionStore.clearSession();
      _setUnauthenticated();
    }
  }

  Future<void> login({
    required String phone,
    required String password,
    required AccountType accountType,
  }) async {
    final session = await _gateway.login(
      phone: phone,
      password: password,
      accountType: accountType,
    );
    await _establishSession(session);
  }

  Future<int> sendRegisterCode(String phone) {
    return _gateway.sendCode(phone: phone, type: 'register');
  }

  Future<int> sendResetPasswordCode(String phone, AccountType accountType) {
    return _gateway.sendCode(
      phone: phone,
      type: 'reset_password',
      accountType: accountType,
    );
  }

  Future<void> verifyRegisterCode({
    required String phone,
    required String code,
  }) {
    return _gateway.verifyRegisterCode(phone: phone, code: code);
  }

  Future<void> verifyResetPasswordCode({
    required String phone,
    required String code,
    required AccountType accountType,
  }) {
    return _gateway.verifyResetPasswordCode(
      phone: phone,
      code: code,
      accountType: accountType,
    );
  }

  Future<void> register({
    required String phone,
    required String code,
    required String password,
  }) async {
    final session = await _gateway.register(
      phone: phone,
      code: code,
      password: password,
    );
    await _establishSession(session);
  }

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
    required AccountType accountType,
  }) {
    return _gateway.resetPassword(
      phone: phone,
      code: code,
      newPassword: newPassword,
      accountType: accountType,
    );
  }

  Future<void> updateProfile(Map<String, Object?> patch) async {
    final currentSession = _session;
    if (_status != AuthStatus.authenticated || currentSession == null) {
      throw StateError('未登录，无法更新用户资料');
    }
    if (patch.isEmpty) return;

    final updatedSession = currentSession.copyWith(
      profile: mergeProfilePatch(currentSession.profile, patch),
    );
    await _sessionStore.saveSession(updatedSession);
    _session = updatedSession;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _gateway.logout();
    } on Object {
      // 退出以清除本地认证状态为准，服务端撤销失败不阻塞用户。
    } finally {
      await invalidateLocalSession();
    }
  }

  Future<void> invalidateLocalSession() async {
    final endingSession = _session;
    if (endingSession != null) {
      await _localSessionInvalidator?.call(endingSession);
    }
    await _sessionStore.clearSession();
    _setUnauthenticated();
  }

  Future<void> _establishSession(AuthSession session) async {
    await _sessionStore.saveSession(session);
    _session = session;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
