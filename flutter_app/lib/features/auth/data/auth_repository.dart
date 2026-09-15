import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';
import '../presentation/auth_controller.dart';

class AuthRepository implements AuthGateway {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  static const _userLoginPath = '/auth/login/phone';
  static const _doctorLoginPath = '/auth/login/doctor/phone';
  static const _sendCodePath = '/auth/send-code';
  static const _verifyCodePath = '/auth/verify-code';
  static const _registerPath = '/auth/register/phone';
  static const _resetPasswordPath = '/auth/reset-password';
  static const _profilePath = '/auth/profile';
  static const _logoutPath = '/auth/logout';

  @override
  Future<AuthSession> login({
    required String phone,
    required String password,
    required AccountType accountType,
  }) async {
    final payload = await _apiClient.post(
      accountType == AccountType.doctor ? _doctorLoginPath : _userLoginPath,
      body: {'phone': phone, 'password': password},
    );
    return AuthSession.fromLoginPayload(_asMap(payload), accountType);
  }

  @override
  Future<int> sendCode({
    required String phone,
    required String type,
    AccountType accountType = AccountType.user,
  }) async {
    final body = <String, Object?>{'phone': phone, 'type': type};
    if (type == 'reset_password') {
      body['accountType'] = accountType.storageValue;
    }

    final payload = _asMap(await _apiClient.post(_sendCodePath, body: body));
    final expiresIn = payload['expiresIn'];
    return expiresIn is num && expiresIn > 0 ? expiresIn.floor() : 120;
  }

  @override
  Future<void> verifyRegisterCode({
    required String phone,
    required String code,
  }) async {
    await _apiClient.post(
      _verifyCodePath,
      body: {'phone': phone, 'code': code, 'type': 'register'},
    );
  }

  @override
  Future<void> verifyResetPasswordCode({
    required String phone,
    required String code,
    required AccountType accountType,
  }) async {
    await _apiClient.post(
      _verifyCodePath,
      body: {
        'phone': phone,
        'code': code,
        'type': 'reset_password',
        'accountType': accountType.storageValue,
      },
    );
  }

  @override
  Future<AuthSession> register({
    required String phone,
    required String code,
    required String password,
  }) async {
    final payload = await _apiClient.post(
      _registerPath,
      body: {'phone': phone, 'code': code, 'password': password},
    );
    return AuthSession.fromLoginPayload(_asMap(payload), AccountType.user);
  }

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
    required AccountType accountType,
  }) async {
    await _apiClient.post(
      _resetPasswordPath,
      body: {
        'phone': phone,
        'code': code,
        'newPassword': newPassword,
        'accountType': accountType.storageValue,
      },
    );
  }

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async {
    final profile = _asMap(
      await _apiClient.get(_profilePath, authenticated: true),
    );
    return savedSession.copyWith(profile: profile);
  }

  @override
  Future<void> logout() async {
    await _apiClient.post(_logoutPath, authenticated: true);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('服务器返回的数据格式不正确');
  }
}
