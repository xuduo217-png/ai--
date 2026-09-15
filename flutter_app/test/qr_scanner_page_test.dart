import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/scanner/presentation/qr_scanner_page.dart';

void main() {
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const scannerChannel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') return 0;
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionChannel, null);
    messenger.setMockMethodCallHandler(scannerChannel, null);
  });

  testWidgets('扫一扫页面提供相机、相册、补光和扫码说明', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QrScannerPage(
          onCouponScanned: (_) async {},
          onActivityScanned: (_) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.byKey(const ValueKey('scanner-camera-card')), findsOneWidget);
    expect(find.text('扫码说明'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scanner-gallery-action')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('scanner-torch-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android 首次进入先显示相机权限说明', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final scannerCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(scannerChannel, (call) async {
            scannerCalls.add(call.method);
            return switch (call.method) {
              'state' => 0,
              'request' => false,
              _ => null,
            };
          });

      await tester.pumpWidget(
        MaterialApp(
          home: QrScannerPage(
            onCouponScanned: (_) async {},
            onActivityScanned: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsOneWidget);
      expect(scannerCalls, isNot(contains('state')));
      expect(scannerCalls, isNot(contains('request')));

      await tester.tap(
        find.byKey(const ValueKey('scanner-permission-confirm')),
      );
      await tester.pumpAndSettle();

      expect(scannerCalls, containsAllInOrder(['state', 'request']));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS 首次进入跳过自绘弹窗并直接申请系统相机权限', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final scannerCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(scannerChannel, (call) async {
            scannerCalls.add(call.method);
            return switch (call.method) {
              'state' => 0,
              'request' => false,
              _ => null,
            };
          });

      await tester.pumpWidget(
        MaterialApp(
          home: QrScannerPage(
            onCouponScanned: (_) async {},
            onActivityScanned: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsNothing);
      expect(scannerCalls, containsAllInOrder(['state', 'request']));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
