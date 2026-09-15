import '../../../core/network/api_client.dart';
import '../domain/nearby_models.dart';

class NearbyRepository implements NearbyGateway {
  const NearbyRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<NearbyLocationSettings> loadNearbySettings() async {
    return NearbyLocationSettings.fromJson(
      await _apiClient.get('/nearby/settings'),
    );
  }

  @override
  Future<void> updateNearbyLocation(NearbyCoordinate location) async {
    await _apiClient.post(
      '/nearby/location',
      authenticated: true,
      body: <String, Object?>{
        'latitude': location.latitude,
        'longitude': location.longitude,
        if (location.city != null) 'city': location.city,
      },
    );
  }

  @override
  Future<NearbyUserPage> loadNearbyUsers({
    required NearbyCoordinate location,
    required NearbyDistanceRange distance,
    required int page,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/nearby/users',
      queryParameters: <String, Object?>{
        'latitude': location.latitude,
        'longitude': location.longitude,
        'radius': distance.radiusMeters,
        'page': page,
        'pageSize': pageSize,
      },
    );
    final envelope = nearbyJsonMap(response, 'nearby user page');
    final rawItems = envelope['data'];
    if (rawItems is! List) {
      throw const FormatException('nearby user page data must be a list.');
    }
    final pagination = envelope['pagination'] is Map
        ? Map<String, Object?>.from(envelope['pagination']! as Map)
        : envelope;
    final total = _optionalInt(pagination['total']) ?? rawItems.length;
    final resolvedPageSize =
        _optionalInt(pagination['pageSize'] ?? pagination['limit']) ?? pageSize;
    final totalPages =
        _optionalInt(pagination['totalPages']) ??
        (total == 0 ? 0 : (total / resolvedPageSize).ceil());
    return NearbyUserPage(
      items: rawItems.map(NearbyUser.fromJson).toList(growable: false),
      page: _optionalInt(pagination['page']) ?? page,
      pageSize: resolvedPageSize,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<bool> updateNearbyDiscovery(bool enabled) async {
    final response = await _apiClient.put(
      '/nearby/settings/discovery',
      body: <String, Object?>{'enabled': enabled},
    );
    final json = nearbyJsonMap(response, 'nearby discovery result');
    return json['discoveryEnabled'] == true;
  }
}

int? _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
