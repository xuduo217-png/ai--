import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/auth_models.dart';
import '../presentation/auth_controller.dart';

class AuthStorage implements SessionStore {
  AuthStorage._(this._preferences);

  static const _tokenKey = '@auth_token';
  static const _userInfoKey = '@user_info';
  static const _userTypeKey = '@user_type';
  static const _loggedInKey = '@is_logged_in';

  final SharedPreferences _preferences;

  static Future<AuthStorage> create() async {
    return AuthStorage._(await SharedPreferences.getInstance());
  }

  @override
  Future<String?> readToken() async => _preferences.getString(_tokenKey);

  @override
  Future<AuthSession?> readSession() async {
    if (!(_preferences.getBool(_loggedInKey) ?? false)) {
      return null;
    }

    final token = _preferences.getString(_tokenKey);
    final profileJson = _preferences.getString(_userInfoKey);
    final typeValue = _preferences.getString(_userTypeKey);
    if (token == null || profileJson == null || typeValue == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(profileJson);
      final accountType = AccountType.values.byName(typeValue);
      if (decoded is! Map) {
        return null;
      }
      return AuthSession(
        accessToken: token,
        accountType: accountType,
        profile: Map<String, dynamic>.from(decoded),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveSession(AuthSession session) async {
    await Future.wait([
      _preferences.setString(_tokenKey, session.accessToken),
      _preferences.setString(_userInfoKey, jsonEncode(session.profile)),
      _preferences.setString(_userTypeKey, session.accountType.storageValue),
      _preferences.setBool(_loggedInKey, true),
    ]);
  }

  @override
  Future<void> clearSession() async {
    await Future.wait([
      _preferences.remove(_tokenKey),
      _preferences.remove(_userInfoKey),
      _preferences.remove(_userTypeKey),
      _preferences.remove(_loggedInKey),
    ]);
  }
}
