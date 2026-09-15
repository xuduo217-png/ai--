import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/platform/external_uri_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('相对网页地址按服务端 origin 解析且仅允许 http/https', () {
    expect(
      resolveSafeWebUri(
        '/uploads/article.png',
        baseUrl: 'https://api.example.com/server-api',
      ).toString(),
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/article.png',
    );
    expect(
      resolveSafeWebUri(
        'docs/privacy',
        baseUrl: 'https://api.example.com/server-api',
      ).toString(),
      'https://api.example.com/docs/privacy',
    );
    expect(
      resolveSafeWebUri(
        'https://docs.example.com/privacy',
        baseUrl: 'https://api.example.com',
      ).toString(),
      'https://docs.example.com/privacy',
    );
    expect(
      resolveSafeWebUri(
        'javascript:alert(1)',
        baseUrl: 'https://api.example.com',
      ),
      isNull,
    );
    expect(
      resolveSafeWebUri(
        'data:text/html,bad',
        baseUrl: 'https://api.example.com',
      ),
      isNull,
    );
    expect(resolveSafeWebUri('', baseUrl: 'https://api.example.com'), isNull);
  });

  test('MethodChannel launcher 的 capability 与 launch 可独立调用', () async {
    const channel = MethodChannel('test/external_uri');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'canLaunchUri';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final launcher = MethodChannelExternalUriLauncher(channel: channel);
    final uri = Uri.parse('tel:4001234567');

    expect(await launcher.canLaunch(uri), isTrue);
    expect(await launcher.launch(uri), isFalse);
    expect(calls.map((call) => call.method), ['canLaunchUri', 'launchUri']);
    expect(calls.first.arguments, {'uri': 'tel:4001234567'});
  });
}
