import '../../emergency/platform/emergency_location_gateway.dart';
import '../domain/nearby_models.dart';

class MethodChannelNearbyLocationGateway
    implements CancellableNearbyLocationGateway {
  const MethodChannelNearbyLocationGateway({
    EmergencyLocationGateway gateway =
        const MethodChannelEmergencyLocationGateway(),
  }) : _gateway = gateway;

  final EmergencyLocationGateway _gateway;

  @override
  Future<NearbyLocationPermissionStatus> checkPermission() async {
    return _mapPermission(await _gateway.checkPermission());
  }

  @override
  Future<NearbyLocationPermissionStatus> requestPermission() async {
    return _mapPermission(await _gateway.requestPermission());
  }

  @override
  Future<NearbyCoordinate> getCurrentLocation() async {
    final position = await _gateway.getCurrentPosition();
    return NearbyCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Future<void> cancelCurrentLocation() async {
    final gateway = _gateway;
    if (gateway is CancellableEmergencyLocationGateway) {
      await gateway.cancelCurrentPosition();
    }
  }

  @override
  Future<void> openAppSettings() async {
    await _gateway.openSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    await _gateway.openSettings();
  }
}

NearbyLocationPermissionStatus _mapPermission(
  EmergencyLocationPermission permission,
) {
  return switch (permission) {
    EmergencyLocationPermission.granted =>
      NearbyLocationPermissionStatus.granted,
    EmergencyLocationPermission.blocked =>
      NearbyLocationPermissionStatus.deniedForever,
    EmergencyLocationPermission.denied => NearbyLocationPermissionStatus.denied,
  };
}
