import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/emergency/domain/emergency_models.dart';
import 'package:pet_hospital_flutter/features/emergency/platform/emergency_location_gateway.dart';
import 'package:pet_hospital_flutter/features/emergency/presentation/emergency_controller.dart';

void main() {
  test('未授权初始化不弹权限也不读取坐标，主动确认后加载附近医院', () async {
    final gateway = _EmergencyGateway();
    final location = _LocationGateway(EmergencyLocationPermission.denied);
    final controller = EmergencyController(
      gateway: gateway,
      locationGateway: location,
    );

    await controller.initialize();

    expect(location.requestCalls, 0);
    expect(location.positionCalls, 0);
    expect(gateway.nearbyCalls, 0);
    expect(controller.nearbyState, NearbyHospitalsViewState.guide);
    expect(controller.guides.single.title, '宠物心肺复苏');

    await controller.requestNearbyHospitals(() async => true);

    expect(location.requestCalls, 1);
    expect(location.positionCalls, 1);
    expect(gateway.nearbyCalls, 1);
    expect(gateway.lastLatitude, 39.9);
    expect(gateway.lastLongitude, 116.4);
    expect(controller.nearbyState, NearbyHospitalsViewState.list);
    expect(controller.hospitals.single.name, '测试宠物医院');
  });

  test('永久拒绝定位时直接展示设置入口，不重复弹授权说明', () async {
    final gateway = _EmergencyGateway();
    final location = _LocationGateway(EmergencyLocationPermission.blocked);
    final controller = EmergencyController(
      gateway: gateway,
      locationGateway: location,
    );
    var confirmCalls = 0;

    await controller.requestNearbyHospitals(() async {
      confirmCalls += 1;
      return true;
    });

    expect(confirmCalls, 0);
    expect(location.requestCalls, 0);
    expect(controller.nearbyState, NearbyHospitalsViewState.blocked);
    expect(await controller.openLocationSettings(), isTrue);
    expect(location.settingsCalls, 1);
  });

  test('定位失败时不请求医院接口并提示定位失败', () async {
    final gateway = _EmergencyGateway();
    final location = _LocationGateway(
      EmergencyLocationPermission.granted,
      positionError: StateError('location timeout'),
    );
    final controller = EmergencyController(
      gateway: gateway,
      locationGateway: location,
    );

    await controller.refreshGrantedLocation();

    expect(gateway.nearbyCalls, 0);
    expect(controller.nearbyState, NearbyHospitalsViewState.error);
    expect(controller.locationError, '当前位置获取失败，请检查定位服务后重试');
  });

  test('重复刷新定位时复用进行中的请求', () async {
    final gateway = _EmergencyGateway(
      loadNearbyDelay: const Duration(milliseconds: 10),
    );
    final location = _LocationGateway(EmergencyLocationPermission.granted);
    final controller = EmergencyController(
      gateway: gateway,
      locationGateway: location,
    );

    await Future.wait([
      controller.refreshGrantedLocation(),
      controller.refreshGrantedLocation(),
    ]);

    expect(location.positionCalls, 1);
    expect(gateway.nearbyCalls, 1);
  });

  test('获取位置期间销毁控制器会取消原生定位请求', () async {
    final location = _CancellableLocationGateway();
    final controller = EmergencyController(
      gateway: _EmergencyGateway(),
      locationGateway: location,
    );

    final load = controller.refreshGrantedLocation();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    await load;

    expect(location.cancelCalls, 1);
  });

  test('指南分类切换与下拉刷新保留当前分类', () async {
    final gateway = _EmergencyGateway();
    final controller = AidGuideListController(gateway);

    await controller.initialize();
    await controller.selectCategory(7);
    await controller.refresh();

    expect(controller.selectedCategoryId, 7);
    expect(gateway.guideCategoryRequests, [null, 7, 7]);
    expect(controller.categories.single.name, '基础急救');
  });
}

class _EmergencyGateway implements EmergencyGateway {
  _EmergencyGateway({this.loadNearbyDelay = Duration.zero});

  int nearbyCalls = 0;
  final Duration loadNearbyDelay;
  double? lastLatitude;
  double? lastLongitude;
  final List<int?> guideCategoryRequests = [];

  static final guide = AidGuide(
    id: 1,
    title: '宠物心肺复苏',
    content: '<p>检查呼吸</p>',
    categoryId: 7,
    status: 'PUBLISHED',
    sortOrder: 1,
    createdAt: DateTime(2026, 7, 20),
    category: const AidGuideCategory(
      id: 7,
      name: '基础急救',
      sortOrder: 1,
      isActive: true,
      guideCount: 1,
    ),
  );

  @override
  Future<EmergencyCenterConfig> loadEmergencyConfig() async =>
      const EmergencyCenterConfig(
        emergencyTime: '24小时在线',
        emergencyHotline: '400-123-4567',
      );

  @override
  Future<List<AidGuide>> loadAidGuides({int? categoryId}) async {
    guideCategoryRequests.add(categoryId);
    return [guide];
  }

  @override
  Future<List<AidGuideCategory>> loadAidGuideCategories() async => [
    guide.category!,
  ];

  @override
  Future<AidGuide> loadAidGuide(int guideId) async => guide;

  @override
  Future<List<NearbyHospital>> loadNearbyHospitals({
    required double latitude,
    required double longitude,
    int limit = 10,
  }) async {
    nearbyCalls += 1;
    if (loadNearbyDelay > Duration.zero) {
      await Future<void>.delayed(loadNearbyDelay);
    }
    lastLatitude = latitude;
    lastLongitude = longitude;
    return const [
      NearbyHospital(
        id: 3,
        name: '测试宠物医院',
        address: '测试路 1 号',
        phone: '010-12345678',
        latitude: 39.91,
        longitude: 116.41,
        businessStatusText: '营业中',
        distance: 1.2,
      ),
    ];
  }
}

class _LocationGateway implements EmergencyLocationGateway {
  _LocationGateway(this.status, {this.positionError});

  EmergencyLocationPermission status;
  int requestCalls = 0;
  int positionCalls = 0;
  int settingsCalls = 0;
  final Object? positionError;

  @override
  Future<EmergencyLocationPermission> checkPermission() async => status;

  @override
  Future<EmergencyPosition> getCurrentPosition() async {
    positionCalls += 1;
    if (positionError != null) throw positionError!;
    return const EmergencyPosition(latitude: 39.9, longitude: 116.4);
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls += 1;
    return true;
  }

  @override
  Future<EmergencyLocationPermission> requestPermission() async {
    requestCalls += 1;
    status = EmergencyLocationPermission.granted;
    return status;
  }
}

class _CancellableLocationGateway
    implements CancellableEmergencyLocationGateway {
  final Completer<EmergencyPosition> _position = Completer<EmergencyPosition>();
  int cancelCalls = 0;

  @override
  Future<void> cancelCurrentPosition() async {
    cancelCalls += 1;
    if (!_position.isCompleted) {
      _position.completeError(StateError('location cancelled'));
    }
  }

  @override
  Future<EmergencyLocationPermission> checkPermission() async =>
      EmergencyLocationPermission.granted;

  @override
  Future<EmergencyPosition> getCurrentPosition() => _position.future;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<EmergencyLocationPermission> requestPermission() async =>
      EmergencyLocationPermission.granted;
}
