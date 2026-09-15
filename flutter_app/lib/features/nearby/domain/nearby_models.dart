enum NearbyDistanceRange {
  city(0, '同城'),
  fiveKilometers(5000, '5km'),
  tenKilometers(10000, '10km');

  const NearbyDistanceRange(this.radiusMeters, this.label);

  final int radiusMeters;
  final String label;
}

class NearbyCoordinate {
  const NearbyCoordinate({
    required this.latitude,
    required this.longitude,
    this.city,
    this.updatedAt,
  });

  factory NearbyCoordinate.fromJson(Object? value) {
    final json = nearbyJsonMap(value, 'current location');
    return NearbyCoordinate(
      latitude: nearbyRequiredDouble(json['latitude'], 'latitude'),
      longitude: nearbyRequiredDouble(json['longitude'], 'longitude'),
      city: nearbyNullableString(json['city']),
      updatedAt: nearbyDateTime(json['updatedAt']),
    );
  }

  final double latitude;
  final double longitude;
  final String? city;
  final DateTime? updatedAt;
}

class NearbyLocationSettings {
  const NearbyLocationSettings({
    required this.discoveryEnabled,
    this.currentLocation,
  });

  factory NearbyLocationSettings.fromJson(Object? value) {
    final json = nearbyJsonMap(value, 'location settings');
    return NearbyLocationSettings(
      discoveryEnabled: json['discoveryEnabled'] != false,
      currentLocation: json['currentLocation'] == null
          ? null
          : NearbyCoordinate.fromJson(json['currentLocation']),
    );
  }

  final bool discoveryEnabled;
  final NearbyCoordinate? currentLocation;
}

class NearbyUser {
  const NearbyUser({
    required this.userId,
    required this.username,
    required this.distanceMeters,
    required this.isFriend,
    this.avatarUrl,
    this.signature,
    this.lastActiveAt,
    this.petTypes = const [],
  });

  factory NearbyUser.fromJson(Object? value) {
    final json = nearbyJsonMap(value, 'nearby user');
    final userId = nearbyRequiredInt(json['userId'], 'userId');
    return NearbyUser(
      userId: userId,
      username: nearbyNullableString(json['username']) ?? '用户$userId',
      avatarUrl: nearbyNullableString(json['avatar']),
      signature: nearbyNullableString(json['signature']),
      distanceMeters: nearbyRequiredDouble(json['distance'], 'distance'),
      lastActiveAt: nearbyDateTime(json['lastActiveAt']),
      petTypes: nearbyStringList(json['petTypes']),
      isFriend: json['isFriend'] == true,
    );
  }

  final int userId;
  final String username;
  final String? avatarUrl;
  final String? signature;
  final double distanceMeters;
  final DateTime? lastActiveAt;
  final List<String> petTypes;
  final bool isFriend;

  NearbyUser copyWith({bool? isFriend}) {
    return NearbyUser(
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      signature: signature,
      distanceMeters: distanceMeters,
      lastActiveAt: lastActiveAt,
      petTypes: petTypes,
      isFriend: isFriend ?? this.isFriend,
    );
  }
}

class NearbyUserPage {
  const NearbyUserPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<NearbyUser> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
}

abstract interface class NearbyGateway {
  Future<NearbyLocationSettings> loadNearbySettings();

  Future<void> updateNearbyLocation(NearbyCoordinate location);

  Future<NearbyUserPage> loadNearbyUsers({
    required NearbyCoordinate location,
    required NearbyDistanceRange distance,
    required int page,
    int pageSize = 20,
  });

  Future<bool> updateNearbyDiscovery(bool enabled);
}

enum NearbyLocationPermissionStatus { granted, denied, deniedForever }

abstract interface class NearbyLocationGateway {
  Future<NearbyLocationPermissionStatus> checkPermission();

  Future<NearbyLocationPermissionStatus> requestPermission();

  Future<NearbyCoordinate> getCurrentLocation();

  Future<void> openAppSettings();

  Future<void> openLocationSettings();
}

abstract interface class CancellableNearbyLocationGateway
    implements NearbyLocationGateway {
  Future<void> cancelCurrentLocation();
}

Map<String, Object?> nearbyJsonMap(Object? value, String name) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw FormatException('$name must be a JSON object.');
}

int nearbyRequiredInt(Object? value, String name) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null) return parsed;
  throw FormatException('$name must be an integer.');
}

double nearbyRequiredDouble(Object? value, String name) {
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed != null) return parsed;
  throw FormatException('$name must be a number.');
}

String? nearbyNullableString(Object? value) {
  if (value == null) return null;
  final result = '$value'.trim();
  return result.isEmpty || result == 'null' ? null : result;
}

DateTime? nearbyDateTime(Object? value) {
  final raw = nearbyNullableString(value);
  return raw == null ? null : DateTime.tryParse(raw);
}

List<String> nearbyStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map(nearbyNullableString)
      .whereType<String>()
      .toList(growable: false);
}
