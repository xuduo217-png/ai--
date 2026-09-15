import '../../../core/config/api_config.dart';
import '../../../core/network/asset_url_resolver.dart';

export '../../auth/domain/auth_models.dart' show mergeProfilePatch;

const defaultProfileMembershipLabel = '普通会员';

enum UserGender {
  unknown(0),
  male(1),
  female(2);

  const UserGender(this.wireValue);

  final int wireValue;
}

enum ProfileGenderIcon { person, male, female }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.phone,
    required this.avatarUrl,
    required this.gender,
    this.membershipLabel = defaultProfileMembershipLabel,
  });

  final int? id;
  final String username;
  final String displayName;
  final String phone;
  final String avatarUrl;
  final UserGender gender;
  final String membershipLabel;

  String resolvedAvatarUrl({String assetBaseUrl = ApiConfig.assetBaseUrl}) {
    return resolveAssetUrl(avatarUrl, assetBaseUrl: assetBaseUrl);
  }

  Map<String, Object?> toSessionPatch() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'username': username,
      'phone': phone,
      'avatar': avatarUrl,
      'gender': gender.wireValue,
    };
  }
}

class ProfileUpdateInput {
  const ProfileUpdateInput({this.username, this.avatarUrl, this.gender});

  final String? username;
  final String? avatarUrl;
  final UserGender? gender;

  bool get isEmpty => username == null && avatarUrl == null && gender == null;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (username != null) 'username': username!.trim(),
      if (avatarUrl != null) 'avatar': avatarUrl!.trim(),
      if (gender != null) 'gender': gender!.wireValue,
    };
  }
}

class ProfileEditDraft {
  const ProfileEditDraft({
    required this.nickname,
    required this.gender,
    required this.avatarUrl,
  });

  final String nickname;
  final UserGender gender;
  final String avatarUrl;

  ProfileUpdateInput changesFrom(UserProfile profile) {
    final normalizedNickname = nickname.trim();
    final normalizedAvatarUrl = avatarUrl.trim();
    return ProfileUpdateInput(
      username: normalizedNickname == profile.username
          ? null
          : normalizedNickname,
      avatarUrl: normalizedAvatarUrl == profile.avatarUrl
          ? null
          : normalizedAvatarUrl,
      gender: gender == profile.gender ? null : gender,
    );
  }
}

class ProfileValidationException implements Exception {
  const ProfileValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileImageUpload {
  const ProfileImageUpload({
    required this.id,
    required this.url,
    required this.filename,
    required this.originalName,
    required this.size,
  });

  final int? id;
  final String url;
  final String filename;
  final String originalName;
  final int size;

  String resolvedUrl({String assetBaseUrl = ApiConfig.assetBaseUrl}) {
    return resolveAssetUrl(url, assetBaseUrl: assetBaseUrl);
  }
}

abstract interface class ProfileGateway {
  Future<UserProfile> loadProfile();

  Future<UserProfile> updateProfile(ProfileUpdateInput input);

  Future<ProfileImageUpload> uploadAvatar({
    required String filePath,
    String? filename,
  });

  Future<void> deleteAccount();
}

UserProfile userProfileFromSessionProfile(Map<String, Object?> profile) {
  return UserProfile(
    id: _nullableInt(profile['id']),
    username: _trimmedString(profile['username']),
    displayName: profileDisplayName(profile),
    phone: _trimmedString(profile['phone']),
    avatarUrl: _trimmedString(profile['avatar'] ?? profile['avatarUrl']),
    gender: userGenderFromValue(profile['gender']),
  );
}

String profileDisplayName(Map<String, Object?> profile) {
  for (final key in const ['displayName', 'username', 'name']) {
    final candidate = _trimmedString(profile[key]);
    if (candidate.isNotEmpty) return candidate;
  }

  final phone = _trimmedString(profile['phone']);
  if (phone.isNotEmpty) {
    final suffix = phone.length <= 4
        ? phone
        : phone.substring(phone.length - 4);
    return '用户$suffix';
  }
  return '用户';
}

String maskProfilePhone(String? phone) {
  final normalized = phone?.trim() ?? '';
  if (!RegExp(r'^\d{11}$').hasMatch(normalized)) return normalized;
  return '${normalized.substring(0, 3)}****${normalized.substring(7)}';
}

UserGender userGenderFromValue(Object? value) {
  final wireValue = value is num
      ? value.toInt()
      : int.tryParse(value?.toString().trim() ?? '');
  return switch (wireValue) {
    1 => UserGender.male,
    2 => UserGender.female,
    _ => UserGender.unknown,
  };
}

ProfileGenderIcon genderIconSemantic(UserGender gender) {
  return switch (gender) {
    UserGender.unknown => ProfileGenderIcon.person,
    UserGender.male => ProfileGenderIcon.male,
    UserGender.female => ProfileGenderIcon.female,
  };
}

String _trimmedString(Object? value) {
  return value is String ? value.trim() : '';
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
