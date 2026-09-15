import '../../../core/network/api_client.dart';
import '../domain/profile_models.dart';

class ProfileRepository implements ProfileGateway {
  const ProfileRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UserProfile> loadProfile() async {
    final response = await _apiClient.get('/users/me');
    return _parseProfile(response);
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async {
    final response = await _apiClient.put('/users/me', body: input.toJson());
    return _parseProfile(response);
  }

  UserProfile _parseProfile(Object? response) {
    final json = _asMap(response, 'profile response');
    if (_requiredString(json['phone'], 'profile phone').isEmpty) {
      throw const FormatException('profile phone must not be empty.');
    }
    return userProfileFromSessionProfile(json);
  }

  @override
  Future<ProfileImageUpload> uploadAvatar({
    required String filePath,
    String? filename,
  }) async {
    final response = await _apiClient.uploadFile(
      '/upload/image',
      filePath: filePath,
      fieldName: 'file',
      filename: filename,
      fields: const {'category': 'user-avatar'},
      authenticated: true,
    );
    final json = _asMap(response, 'profile image upload response');
    return ProfileImageUpload(
      id: _nullableInt(json['id']),
      url: _requiredString(json['url'], 'upload url'),
      filename: _requiredString(json['filename'], 'upload filename'),
      originalName: _requiredString(
        json['originalName'],
        'upload originalName',
      ),
      size: _requiredInt(json['size'], 'upload size'),
    );
  }

  @override
  Future<void> deleteAccount() async {
    await _apiClient.delete('/users/me');
  }
}

Map<String, Object?> _asMap(Object? value, String name) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw FormatException('$name must be a JSON object.');
}

String _requiredString(Object? value, String name) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$name must be a non-empty string.');
}

int _requiredInt(Object? value, String name) {
  final parsed = _nullableInt(value);
  if (parsed != null) return parsed;
  throw FormatException('$name must be an integer.');
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
