import '../../../core/network/api_client.dart';
import '../domain/settings_models.dart';

class SettingsRepository implements SettingsGateway {
  const SettingsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<ContactInfo> loadContactInfo() async {
    final response = await _apiClient.get(
      '/system-configs/contact_info',
      authenticated: false,
    );
    final json = _asMap(response, 'contact info response');
    final rawConfig = json['configValue'];
    if (rawConfig == null) return ContactInfo.empty;
    final config = _asMap(rawConfig, 'contact info configValue');
    return ContactInfo(
      hotline: _optionalString(config['hotline']),
      wechatQrCode: _optionalString(config['wechatQrCode']),
      workingHours: _optionalString(config['workingHours']),
    );
  }

  @override
  Future<SystemArticle?> loadArticle(SystemArticleType type) async {
    final response = await _apiClient.get(
      '/system-articles/${type.wireValue}',
      authenticated: false,
    );
    if (response == null) return null;
    final json = _asMap(response, 'system article response');
    final responseType = SystemArticleType.tryParse(json['type']);
    if (responseType == null || responseType != type) {
      throw const FormatException(
        'system article type must match the requested type.',
      );
    }
    final content = json['content'];
    if (content is! String) {
      throw const FormatException('system article content must be a string.');
    }
    return SystemArticle(
      id: _requiredPositiveInt(json['id'], 'system article id'),
      type: responseType,
      html: content,
    );
  }
}

Map<String, Object?> _asMap(Object? value, String name) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw FormatException('$name must be a JSON object.');
}

String _optionalString(Object? value) {
  return value is String ? value.trim() : '';
}

int _requiredPositiveInt(Object? value, String name) {
  final parsed = switch (value) {
    final int number => number,
    final num number => number.toInt(),
    _ => int.tryParse(value?.toString().trim() ?? ''),
  };
  if (parsed != null && parsed > 0) return parsed;
  throw FormatException('$name must be a positive integer.');
}
