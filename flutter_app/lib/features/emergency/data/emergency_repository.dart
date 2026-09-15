import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../domain/emergency_models.dart';

class EmergencyRepository implements EmergencyGateway {
  EmergencyRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<EmergencyCenterConfig> loadEmergencyConfig() async {
    final payload = await _apiClient.get(
      '/system-configs/emergency_center',
      authenticated: false,
    );
    final record = _asMap(payload);
    final config = _asMap(_decodeJsonValue(record['configValue']));
    final hotline = _string(config['emergencyHotline']);
    return EmergencyCenterConfig(
      emergencyTime: _string(config['emergencyTime']),
      emergencyHotline: hotline.isEmpty
          ? EmergencyCenterConfig.fallback.emergencyHotline
          : hotline,
    );
  }

  @override
  Future<List<AidGuide>> loadAidGuides({int? categoryId}) async {
    final payload = await _apiClient.get(
      categoryId == null ? '/aid-guides' : '/aid-guides/category/$categoryId',
      authenticated: false,
      queryParameters: categoryId == null
          ? const {'status': 'PUBLISHED', 'sortBy': 'sortOrder:ASC'}
          : const {},
    );
    return _asList(payload)
        .map(_asMap)
        .where((item) => item.isNotEmpty)
        .map(_guideFromJson)
        .toList(growable: false);
  }

  @override
  Future<List<AidGuideCategory>> loadAidGuideCategories() async {
    final payload = await _apiClient.get(
      '/aid-guides/categories',
      authenticated: false,
      queryParameters: const {'page': 1, 'pageSize': 50, 'isActive': true},
    );
    return _asList(payload)
        .map(_asMap)
        .where((item) => item.isNotEmpty)
        .map(_categoryFromJson)
        .toList(growable: false);
  }

  @override
  Future<AidGuide> loadAidGuide(int guideId) async {
    final payload = await _apiClient.get(
      '/aid-guides/$guideId',
      authenticated: false,
    );
    final record = _asMap(payload);
    if (record.isEmpty) throw const ApiException('指南信息不存在');
    return _guideFromJson(record);
  }

  @override
  Future<List<NearbyHospital>> loadNearbyHospitals({
    required double latitude,
    required double longitude,
    int limit = 10,
  }) async {
    final payload = await _apiClient.get(
      '/hospitals/nearby',
      authenticated: false,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'limit': limit,
      },
    );
    return _asList(payload)
        .map(_asMap)
        .where((item) => item.isNotEmpty)
        .map(_hospitalFromJson)
        .toList(growable: false);
  }

  AidGuide _guideFromJson(Map<String, Object?> json) {
    final category = _asMap(json['category']);
    return AidGuide(
      id: _integer(json['id']),
      title: _string(json['title']),
      content: _string(json['content']),
      categoryId: _integer(json['categoryId']),
      status: _string(json['status']),
      sortOrder: _integer(json['sortOrder']),
      createdAt: _date(json['createdAt']),
      iconUrl: resolveAssetUrl(
        _string(json['icon']),
        assetBaseUrl: _apiClient.baseUrl,
      ),
      category: category.isEmpty ? null : _categoryFromJson(category),
      publishedAt: _optionalDate(json['publishedAt']),
    );
  }

  AidGuideCategory _categoryFromJson(Map<String, Object?> json) {
    return AidGuideCategory(
      id: _integer(json['id']),
      name: _string(json['name']),
      sortOrder: _integer(json['sortOrder']),
      isActive: _boolean(json['isActive']),
      guideCount: _integer(json['guideCount']),
      iconUrl: resolveAssetUrl(
        _string(json['icon']),
        assetBaseUrl: _apiClient.baseUrl,
      ),
    );
  }

  NearbyHospital _hospitalFromJson(Map<String, Object?> json) {
    return NearbyHospital(
      id: _integer(json['id']),
      name: _string(json['name']),
      address: _string(json['address']),
      phone: _string(json['phone']),
      latitude: _number(json['latitude']),
      longitude: _number(json['longitude']),
      businessStatusText: _string(json['businessStatusText']),
      distance: _number(json['distance']),
      logoUrl: resolveAssetUrl(
        _string(json['logo']),
        assetBaseUrl: _apiClient.baseUrl,
      ),
    );
  }
}

Object? _decodeJsonValue(Object? value) {
  if (value is! String) return value;
  final source = value.trim();
  if (source.isEmpty) return null;
  try {
    return jsonDecode(source);
  } on FormatException {
    return null;
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry('$key', item));
}

List<Object?> _asList(Object? value) {
  if (value is List) return value.cast<Object?>();
  final data = _asMap(value)['data'];
  return data is List ? data.cast<Object?>() : const [];
}

String _string(Object? value) => value == null ? '' : '$value'.trim();

int _integer(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  _ => int.tryParse(_string(value)) ?? 0,
};

double _number(Object? value) => switch (value) {
  final double number => number,
  final num number => number.toDouble(),
  _ => double.tryParse(_string(value)) ?? 0,
};

bool _boolean(Object? value) => switch (value) {
  final bool flag => flag,
  final num number => number != 0,
  _ => const {'true', '1'}.contains(_string(value).toLowerCase()),
};

DateTime _date(Object? value) =>
    _optionalDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _optionalDate(Object? value) {
  final source = _string(value);
  return source.isEmpty ? null : DateTime.tryParse(source)?.toLocal();
}
