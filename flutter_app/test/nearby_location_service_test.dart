import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/emergency/platform/emergency_location_gateway.dart';
import 'package:pet_hospital_flutter/features/nearby/data/nearby_location_service.dart';
import 'package:pet_hospital_flutter/features/nearby/domain/nearby_models.dart';

void main() {
  test('附近定位适配器复用原生定位通道并映射权限和坐标', () async {
    final nativeGateway = _EmergencyLocationGateway();
    final gateway = MethodChannelNearbyLocationGateway(gateway: nativeGateway);

    expect(
      await gateway.checkPermission(),
      NearbyLocationPermissionStatus.denied,
    );
    expect(
      await gateway.requestPermission(),
      NearbyLocationPermissionStatus.granted,
    );
    final location = await gateway.getCurrentLocation();
    expect(location.latitude, 31.2304);
    expect(location.longitude, 121.4737);

    await gateway.cancelCurrentLocation();
    expect(nativeGateway.cancelCalls, 1);

    await gateway.openAppSettings();
    await gateway.openLocationSettings();
    expect(nativeGateway.settingsCalls, 2);
  });
}

class _EmergencyLocationGateway implements CancellableEmergencyLocationGateway {
  int settingsCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> cancelCurrentPosition() async {
    cancelCalls += 1;
  }

  @override
  Future<EmergencyLocationPermission> checkPermission() async {
    return EmergencyLocationPermission.denied;
  }

  @override
  Future<EmergencyPosition> getCurrentPosition() async {
    return const EmergencyPosition(latitude: 31.2304, longitude: 121.4737);
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls += 1;
    return true;
  }

  @override
  Future<EmergencyLocationPermission> requestPermission() async {
    return EmergencyLocationPermission.granted;
  }
}
