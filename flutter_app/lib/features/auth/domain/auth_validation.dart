class AuthValidation {
  const AuthValidation._();

  static final RegExp _phonePattern = RegExp(r'^1[3-9]\d{9}$');

  static String? phone(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '请输入手机号';
    }
    if (!_phonePattern.hasMatch(normalized)) {
      return '请输入正确的11位手机号';
    }
    return null;
  }

  static String? password(String? value) {
    final normalized = value ?? '';
    if (normalized.trim().isEmpty) {
      return '请输入密码';
    }
    if (normalized.length < 6) {
      return '密码长度不能少于6位';
    }
    if (normalized.length > 20) {
      return '密码长度不能超过20位';
    }
    return null;
  }

  static String? code(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '请输入验证码';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      return '请输入6位数字验证码';
    }
    return null;
  }
}
