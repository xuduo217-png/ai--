import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_relation_models.dart';
import 'package:pet_hospital_flutter/features/nearby/domain/nearby_models.dart';
import 'package:pet_hospital_flutter/features/nearby/presentation/nearby_page.dart';

void main() {
  testWidgets('附近页面展示真实列表并可发送好友申请', (tester) async {
    final gateway = _PageNearbyGateway();
    final location = _PageLocationGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: NearbyPage(
          gateway: gateway,
          locationGateway: location,
          sendFriendRequest: ({required receiverId, required message}) async {
            gateway.friendRequestUserId = receiverId;
            return const SendFriendRequestResult(
              success: true,
              status: SendFriendRequestStatus.sent,
              message: '好友申请已发送',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('附近的人'), findsOneWidget);
    expect(find.text('小顾'), findsOneWidget);
    expect(find.text('1.3km'), findsOneWidget);
    expect(find.text('猫'), findsOneWidget);
    expect(find.text('加好友'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('nearby-distance-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('nearby-discovery-action')),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(SegmentedButton<NearbyDistanceRange>), findsNothing);

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('nearby-gradient-background')),
    );
    final decoration = background.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [Color(0xFFDEE9FF), Color(0xFFFAFBFF)]);

    await tester.tap(find.byKey(const ValueKey('nearby-add-friend-8')));
    await tester.pumpAndSettle();
    expect(find.text('发送好友申请'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nearby-friend-confirm-8')));
    await tester.pumpAndSettle();

    expect(gateway.friendRequestUserId, 8);
    expect(find.text('申请已发送'), findsOneWidget);
    expect(find.text('好友申请已发送'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android 首次进入先展示定位说明，确认后才申请系统权限', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final location = _PageLocationGateway(
        permission: NearbyLocationPermissionStatus.denied,
        requestedPermission: NearbyLocationPermissionStatus.granted,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NearbyPage(
            gateway: _PageNearbyGateway(),
            locationGateway: location,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('需要位置权限'), findsOneWidget);
      expect(find.text('查找附近的养宠用户'), findsOneWidget);
      expect(location.requestCalls, 0);
      await tester.tap(
        find.byKey(const ValueKey('nearby-location-rationale-confirm')),
      );
      await tester.pumpAndSettle();

      expect(location.requestCalls, 1);
      expect(find.text('小顾'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS 首次进入不展示定位说明，用户操作后直接申请系统权限', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final location = _PageLocationGateway(
        permission: NearbyLocationPermissionStatus.denied,
        requestedPermission: NearbyLocationPermissionStatus.granted,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NearbyPage(
            gateway: _PageNearbyGateway(),
            locationGateway: location,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('需要位置权限'), findsNothing);
      expect(location.requestCalls, 0);

      await tester.tap(find.byKey(const ValueKey('nearby-location-action')));
      await tester.pumpAndSettle();

      expect(find.text('需要位置权限'), findsNothing);
      expect(location.requestCalls, 1);
      expect(find.text('小顾'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('发现状态使用 RN 右上角眼睛按钮切换', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyPage(
          gateway: _PageNearbyGateway(),
          locationGateway: _PageLocationGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nearby-discovery-action')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    expect(find.text('附近暂无用户'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RN 卡片布局在 320 宽度和 1.3 倍字体下无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: NearbyPage(
          gateway: _PageNearbyGateway(
            username: '名字很长的附近养宠用户',
            signature: '一起交流科学养宠和日常护理经验',
          ),
          locationGateway: _PageLocationGateway(),
          sendFriendRequest: ({required receiverId, required message}) async {
            return const SendFriendRequestResult(
              success: true,
              status: SendFriendRequestStatus.sent,
              message: '好友申请已发送',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nearby-user-8')), findsOneWidget);
    expect(find.text('加好友'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('距离和活跃时间格式与 RN 行为一致', () {
    final now = DateTime(2026, 7, 25, 12);
    expect(formatNearbyDistance(320), '320m');
    expect(formatNearbyDistance(1250), '1.3km');
    expect(
      formatNearbyLastActive(DateTime(2026, 7, 25, 11, 45), now: now),
      '15分钟前活跃',
    );
  });
}

class _PageNearbyGateway implements NearbyGateway {
  _PageNearbyGateway({this.username = '小顾', this.signature = '今天也要照顾好毛孩子'});

  final String username;
  final String signature;
  int? friendRequestUserId;

  @override
  Future<NearbyLocationSettings> loadNearbySettings() async {
    return const NearbyLocationSettings(discoveryEnabled: true);
  }

  @override
  Future<void> updateNearbyLocation(NearbyCoordinate location) async {}

  @override
  Future<NearbyUserPage> loadNearbyUsers({
    required NearbyCoordinate location,
    required NearbyDistanceRange distance,
    required int page,
    int pageSize = 20,
  }) async {
    return NearbyUserPage(
      items: [
        NearbyUser(
          userId: 8,
          username: username,
          signature: signature,
          distanceMeters: 1250,
          lastActiveAt: DateTime.now().subtract(const Duration(minutes: 8)),
          petTypes: const ['猫'],
          isFriend: false,
        ),
      ],
      page: 1,
      pageSize: 20,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<bool> updateNearbyDiscovery(bool enabled) async => enabled;
}

class _PageLocationGateway implements NearbyLocationGateway {
  _PageLocationGateway({
    this.permission = NearbyLocationPermissionStatus.granted,
    NearbyLocationPermissionStatus? requestedPermission,
  }) : requestedPermission = requestedPermission ?? permission;

  NearbyLocationPermissionStatus permission;
  final NearbyLocationPermissionStatus requestedPermission;
  int requestCalls = 0;

  @override
  Future<NearbyLocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<NearbyCoordinate> getCurrentLocation() async {
    return const NearbyCoordinate(latitude: 31.2304, longitude: 121.4737);
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<NearbyLocationPermissionStatus> requestPermission() async {
    requestCalls += 1;
    return permission = requestedPermission;
  }
}
