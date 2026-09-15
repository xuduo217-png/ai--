import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_relation_models.dart';
import 'package:pet_hospital_flutter/features/nearby/domain/nearby_models.dart';
import 'package:pet_hospital_flutter/features/nearby/presentation/nearby_controller.dart';

void main() {
  test('授权后上报位置、加载附近用户并切换距离', () async {
    final gateway = _NearbyGateway();
    final location = _NearbyLocationGateway();
    final controller = NearbyController(
      gateway: gateway,
      locationGateway: location,
    );

    await controller.initialize();

    expect(controller.viewState, NearbyViewState.ready);
    expect(controller.users.single.username, '小顾');
    expect(gateway.updatedLocations.single.latitude, 31.2304);
    expect(gateway.loadedDistances, [NearbyDistanceRange.fiveKilometers]);

    await controller.selectDistance(NearbyDistanceRange.city);

    expect(controller.selectedDistance, NearbyDistanceRange.city);
    expect(gateway.loadedDistances, [
      NearbyDistanceRange.fiveKilometers,
      NearbyDistanceRange.city,
    ]);
  });

  test('拒绝状态由用户操作触发授权，发现开关和好友申请同步更新 UI 状态', () async {
    final gateway = _NearbyGateway();
    final location = _NearbyLocationGateway(
      permission: NearbyLocationPermissionStatus.denied,
      requestedPermission: NearbyLocationPermissionStatus.granted,
    );
    final controller = NearbyController(
      gateway: gateway,
      locationGateway: location,
      sendFriendRequest: ({required receiverId, required message}) async {
        expect(receiverId, 8);
        expect(message, '你好，我想和你交个朋友');
        return const SendFriendRequestResult(
          success: true,
          status: SendFriendRequestStatus.outgoingPending,
          message: '好友申请已发送',
        );
      },
    );

    await controller.initialize();
    expect(controller.viewState, NearbyViewState.permissionRequired);
    expect(location.requestCalls, 0);

    await controller.requestLocationPermission();
    expect(location.requestCalls, 1);
    expect(controller.viewState, NearbyViewState.ready);

    final user = controller.users.single;
    final result = await controller.addFriend(user);
    expect(result?.status, SendFriendRequestStatus.outgoingPending);
    expect(controller.isFriendRequestPending(user.userId), isTrue);

    await controller.toggleDiscovery(false);
    expect(controller.discoveryEnabled, isFalse);
    expect(controller.users, isEmpty);
  });

  test('设备定位关闭时展示专用状态', () async {
    final controller = NearbyController(
      gateway: _NearbyGateway(),
      locationGateway: _NearbyLocationGateway(
        locationError: PlatformException(code: 'location_disabled'),
      ),
    );

    await controller.initialize();

    expect(controller.viewState, NearbyViewState.locationServiceDisabled);
    expect(controller.errorMessage, isNull);
  });

  test('获取位置期间销毁控制器会取消原生定位请求', () async {
    final location = _PendingNearbyLocationGateway();
    final controller = NearbyController(
      gateway: _NearbyGateway(),
      locationGateway: location,
    );

    final initialize = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    await initialize;

    expect(location.cancelCalls, 1);
  });

  test('权限检查期间销毁控制器后不再启动定位', () async {
    final location = _PendingPermissionLocationGateway();
    final controller = NearbyController(
      gateway: _NearbyGateway(),
      locationGateway: location,
    );

    final initialize = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    location.completePermission();
    await initialize;

    expect(location.locationCalls, 0);
  });
}

class _NearbyGateway implements NearbyGateway {
  final List<NearbyCoordinate> updatedLocations = [];
  final List<NearbyDistanceRange> loadedDistances = [];
  bool discoveryEnabled = true;

  @override
  Future<NearbyLocationSettings> loadNearbySettings() async {
    return NearbyLocationSettings(discoveryEnabled: discoveryEnabled);
  }

  @override
  Future<void> updateNearbyLocation(NearbyCoordinate location) async {
    updatedLocations.add(location);
  }

  @override
  Future<NearbyUserPage> loadNearbyUsers({
    required NearbyCoordinate location,
    required NearbyDistanceRange distance,
    required int page,
    int pageSize = 20,
  }) async {
    loadedDistances.add(distance);
    return const NearbyUserPage(
      items: [
        NearbyUser(
          userId: 8,
          username: '小顾',
          distanceMeters: 1250,
          isFriend: false,
          petTypes: ['猫'],
        ),
      ],
      page: 1,
      pageSize: 20,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<bool> updateNearbyDiscovery(bool enabled) async {
    discoveryEnabled = enabled;
    return enabled;
  }
}

class _NearbyLocationGateway implements NearbyLocationGateway {
  _NearbyLocationGateway({
    this.permission = NearbyLocationPermissionStatus.granted,
    NearbyLocationPermissionStatus? requestedPermission,
    this.locationError,
  }) : requestedPermission = requestedPermission ?? permission;

  NearbyLocationPermissionStatus permission;
  final NearbyLocationPermissionStatus requestedPermission;
  final Object? locationError;
  int requestCalls = 0;

  @override
  Future<NearbyLocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<NearbyCoordinate> getCurrentLocation() async {
    if (locationError != null) throw locationError!;
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

class _PendingNearbyLocationGateway
    implements CancellableNearbyLocationGateway {
  final Completer<NearbyCoordinate> _location = Completer<NearbyCoordinate>();
  int cancelCalls = 0;

  @override
  Future<void> cancelCurrentLocation() async {
    cancelCalls += 1;
    if (!_location.isCompleted) {
      _location.completeError(StateError('location cancelled'));
    }
  }

  @override
  Future<NearbyLocationPermissionStatus> checkPermission() async =>
      NearbyLocationPermissionStatus.granted;

  @override
  Future<NearbyCoordinate> getCurrentLocation() => _location.future;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<NearbyLocationPermissionStatus> requestPermission() async =>
      NearbyLocationPermissionStatus.granted;
}

class _PendingPermissionLocationGateway implements NearbyLocationGateway {
  final Completer<NearbyLocationPermissionStatus> _permission =
      Completer<NearbyLocationPermissionStatus>();
  int locationCalls = 0;

  void completePermission() {
    _permission.complete(NearbyLocationPermissionStatus.granted);
  }

  @override
  Future<NearbyLocationPermissionStatus> checkPermission() =>
      _permission.future;

  @override
  Future<NearbyCoordinate> getCurrentLocation() async {
    locationCalls += 1;
    return const NearbyCoordinate(latitude: 31.2304, longitude: 121.4737);
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<NearbyLocationPermissionStatus> requestPermission() async =>
      NearbyLocationPermissionStatus.granted;
}
