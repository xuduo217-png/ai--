import 'package:flutter/services.dart';

enum EmergencyLocationPermission { granted, denied, blocked }

class EmergencyPosition {
  const EmergencyPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

abstract interface class EmergencyLocationGateway {
  Future<EmergencyLocationPermission> checkPermission();

  Future<EmergencyLocationPermission> requestPermission();

  Future<EmergencyPosition> getCurrentPosition();

  Future<bool> openSettings();
}

abstract interface class CancellableEmergencyLocationGateway
    implements EmergencyLocationGateway {
  Future<void> cancelCurrentPosition();
}

class MethodChannelEmergencyLocationGateway
    implements CancellableEmergencyLocationGateway {
  const MethodChannelEmergencyLocationGateway({
    MethodChannel channel = const MethodChannel(
      'com.good.pet.hospital/emergency_location',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<EmergencyLocationPermission> checkPermission() async {
    final status = await _channel.invokeMethod<String>('checkPermission');
    return _permissionFrom(status);
  }

  @override
  Future<EmergencyLocationPermission> requestPermission() async {
    final status = await _channel.invokeMethod<String>('requestPermission');
    return _permissionFrom(status);
  }

  @override
  Future<EmergencyPosition> getCurrentPosition() async {
    final payload = await _channel.invokeMapMethod<String, Object?>(
      'getCurrentLocation',
    );
    final latitude = _coordinate(payload?['latitude']);
    final longitude = _coordinate(payload?['longitude']);
    if (latitude == null || longitude == null) {
      throw PlatformException(code: 'invalid_location', message: '系统未返回有效位置');
    }
    return EmergencyPosition(latitude: latitude, longitude: longitude);
  }

  @override
  Future<void> cancelCurrentPosition() async {
    await _channel.invokeMethod<void>('cancelCurrentLocation');
  }

  @override
  Future<bool> openSettings() async {
    return await _channel.invokeMethod<bool>('openSettings') ?? false;
  }
}

EmergencyLocationPermission _permissionFrom(String? value) {
  return switch (value) {
    'granted' => EmergencyLocationPermission.granted,
    'blocked' => EmergencyLocationPermission.blocked,
    _ => EmergencyLocationPermission.denied,
  };
}

double? _coordinate(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text),
  _ => null,
};
