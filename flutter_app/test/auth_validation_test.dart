import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_validation.dart';

void main() {
  group('AuthValidation', () {
    test('只接受有效中国大陆手机号', () {
      expect(AuthValidation.phone('13800138000'), isNull);
      expect(AuthValidation.phone(''), '请输入手机号');
      expect(AuthValidation.phone('12800138000'), '请输入正确的11位手机号');
    });

    test('密码限制为6到20位', () {
      expect(AuthValidation.password('123456'), isNull);
      expect(AuthValidation.password('12345'), '密码长度不能少于6位');
      expect(AuthValidation.password('1' * 21), '密码长度不能超过20位');
    });

    test('验证码必须是6位数字', () {
      expect(AuthValidation.code('123456'), isNull);
      expect(AuthValidation.code('12345a'), '请输入6位数字验证码');
    });
  });
}
