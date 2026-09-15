enum AccountType {
  user,
  doctor;

  String get storageValue => name;

  String get label => this == AccountType.user ? '用户端' : '医生端';
}

Map<String, dynamic> mergeProfilePatch(
  Map<String, dynamic> currentProfile,
  Map<String, Object?> patch,
) {
  return <String, dynamic>{...currentProfile, ...patch};
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.accountType,
    required this.profile,
  });

  final String accessToken;
  final AccountType accountType;
  final Map<String, dynamic> profile;

  String get displayName {
    final candidates = [profile['name'], profile['username'], profile['phone']];
    return candidates.whereType<String>().firstWhere(
      (value) => value.trim().isNotEmpty,
      orElse: () => accountType.label,
    );
  }

  String get phone => '${profile['phone'] ?? ''}';

  AuthSession copyWith({Map<String, dynamic>? profile}) {
    return AuthSession(
      accessToken: accessToken,
      accountType: accountType,
      profile: profile ?? this.profile,
    );
  }

  factory AuthSession.fromLoginPayload(
    Map<String, dynamic> payload,
    AccountType accountType,
  ) {
    final token = payload['access_token'];
    final profileKey = accountType == AccountType.doctor ? 'doctor' : 'user';
    final profile = payload[profileKey];

    if (token is! String || token.isEmpty || profile is! Map) {
      throw const FormatException('登录响应缺少 Token 或账号信息');
    }

    return AuthSession(
      accessToken: token,
      accountType: accountType,
      profile: Map<String, dynamic>.from(profile),
    );
  }
}
