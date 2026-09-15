import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/emergency/platform/emergency_location_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('定位 channel 映射权限、坐标和设置操作', () async {
    const channel = MethodChannel('test/emergency_location');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'checkPermission' => 'denied',
            'requestPermission' => 'granted',
            'getCurrentLocation' => {'latitude': 39.9, 'longitude': '116.4'},
            'cancelCurrentLocation' => null,
            'openSettings' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const gateway = MethodChannelEmergencyLocationGateway(channel: channel);

    expect(await gateway.checkPermission(), EmergencyLocationPermission.denied);
    expect(
      await gateway.requestPermission(),
      EmergencyLocationPermission.granted,
    );
    final position = await gateway.getCurrentPosition();
    expect(position.latitude, 39.9);
    expect(position.longitude, 116.4);
    await gateway.cancelCurrentPosition();
    expect(await gateway.openSettings(), isTrue);
    expect(calls, [
      'checkPermission',
      'requestPermission',
      'getCurrentLocation',
      'cancelCurrentLocation',
      'openSettings',
    ]);
  });

  test('无效坐标返回明确平台异常', () async {
    const channel = MethodChannel('test/emergency_location_invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {'latitude': 'bad', 'longitude': 116.4},
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const gateway = MethodChannelEmergencyLocationGateway(channel: channel);

    expect(gateway.getCurrentPosition(), throwsA(isA<PlatformException>()));
  });
}
