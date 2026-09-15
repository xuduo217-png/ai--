import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';

void main() {
  group('UserProfile', () {
    test('从 session map 解析强类型字段和数字字符串', () {
      final profile = userProfileFromSessionProfile(const {
        'id': '42',
        'username': ' 小顾 ',
        'phone': ' 13800138000 ',
        'avatar': ' /uploads/avatar.png ',
        'gender': '2',
      });

      expect(profile.id, 42);
      expect(profile.username, '小顾');
      expect(profile.displayName, '小顾');
      expect(profile.phone, '13800138000');
      expect(profile.avatarUrl, '/uploads/avatar.png');
      expect(
        profile.resolvedAvatarUrl(assetBaseUrl: 'https://assets.example.test/'),
        'https://assets.example.test/uploads/avatar.png',
      );
      expect(profile.gender, UserGender.female);
      expect(profile.membershipLabel, '普通会员');
      expect(genderIconSemantic(profile.gender), ProfileGenderIcon.female);
    });

    test('null 和非法字段使用稳定边界值', () {
      final profile = userProfileFromSessionProfile(const {
        'id': null,
        'username': null,
        'phone': null,
        'avatar': null,
        'gender': 'unexpected',
      });

      expect(profile.id, isNull);
      expect(profile.username, isEmpty);
      expect(profile.displayName, '用户');
      expect(profile.phone, isEmpty);
      expect(profile.avatarUrl, isEmpty);
      expect(profile.resolvedAvatarUrl(), isEmpty);
      expect(profile.gender, UserGender.unknown);
      expect(genderIconSemantic(profile.gender), ProfileGenderIcon.person);
    });

    test('显示名按显式名称、用户名、手机号尾号依次降级', () {
      expect(
        profileDisplayName(const {
          'displayName': ' 显示名 ',
          'username': '用户名',
          'phone': '13800138000',
        }),
        '显示名',
      );
      expect(
        profileDisplayName(const {
          'displayName': ' ',
          'username': '用户名',
          'phone': '13800138000',
        }),
        '用户名',
      );
      expect(profileDisplayName(const {'phone': '13800138000'}), '用户8000');
      expect(profileDisplayName(const {}), '用户');
    });

    test('手机号仅对标准 11 位数字脱敏', () {
      expect(maskProfilePhone(' 13800138000 '), '138****8000');
      expect(maskProfilePhone('1234567'), '1234567');
      expect(maskProfilePhone('138-0013-8000'), '138-0013-8000');
      expect(maskProfilePhone(null), isEmpty);
    });

    test('性别兼容数字与数字字符串并提供平台无关图标语义', () {
      expect(userGenderFromValue(1), UserGender.male);
      expect(userGenderFromValue('2'), UserGender.female);
      expect(userGenderFromValue(0), UserGender.unknown);
      expect(userGenderFromValue(null), UserGender.unknown);
      expect(genderIconSemantic(UserGender.male), ProfileGenderIcon.male);
    });
  });

  test('profile patch 覆盖已知值、保留未知字段且不修改原 map', () {
    final original = <String, dynamic>{
      'username': '修改前',
      'avatar': '/uploads/old.png',
      'opaque': const {'version': 1},
    };

    final merged = mergeProfilePatch(original, const {
      'username': '修改后',
      'avatar': null,
      'gender': 2,
    });

    expect(merged, {
      'username': '修改后',
      'avatar': null,
      'gender': 2,
      'opaque': const {'version': 1},
    });
    expect(original['username'], '修改前');
    expect(original['avatar'], '/uploads/old.png');
  });
}
