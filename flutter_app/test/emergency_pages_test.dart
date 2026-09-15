import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/config/api_config.dart';
import 'package:pet_hospital_flutter/core/media/rich_text_video_player.dart';
import 'package:pet_hospital_flutter/core/platform/external_uri_launcher.dart';
import 'package:pet_hospital_flutter/features/emergency/domain/emergency_models.dart';
import 'package:pet_hospital_flutter/features/emergency/platform/emergency_location_gateway.dart';
import 'package:pet_hospital_flutter/features/emergency/presentation/pages/aid_guide_list_page.dart';
import 'package:pet_hospital_flutter/features/emergency/presentation/pages/aid_guide_detail_page.dart';
import 'package:pet_hospital_flutter/features/emergency/presentation/pages/emergency_center_page.dart';
import 'package:pet_hospital_flutter/features/emergency/presentation/widgets/emergency_widgets.dart';

void main() {
  testWidgets('急救主页展示服务端配置并可打开指南详情', (tester) async {
    final gateway = _EmergencyGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: EmergencyCenterPage(
          gateway: gateway,
          locationGateway: _LocationGateway(EmergencyLocationPermission.denied),
          uriLauncher: _UriLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('紧急求助'), findsOneWidget);
    expect(find.text('全天候在线'), findsOneWidget);
    expect(find.text('紧急热线：400-123-4567'), findsOneWidget);
    expect(find.text('宠物心肺复苏'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('emergency-guide-1')));
    await tester.pumpAndSettle();

    expect(find.text('急救指南详情'), findsOneWidget);
    expect(find.text('基础急救'), findsOneWidget);
    expect(find.text('检查呼吸'), findsOneWidget);
  });

  testWidgets('常见急救指南保持 RN 双列横向卡片布局', (tester) async {
    tester.view.physicalSize = const Size(402, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EmergencyCenterPage(
          gateway: _EmergencyGateway(),
          locationGateway: _LocationGateway(EmergencyLocationPermission.denied),
          uriLauncher: _UriLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = tester.getRect(
      find.byKey(const ValueKey('emergency-guide-1')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('emergency-guide-2')),
    );
    final panel = tester.getRect(
      find.byKey(const ValueKey('emergency-guide-panel')),
    );

    expect(first.top, second.top);
    expect(first.width, closeTo(second.width, 0.1));
    expect(second.left, greaterThan(first.right));
    expect(first.height, 44);
    expect(panel.height, lessThan(120));
  });

  testWidgets('指南分类使用 RN 实心选中 Tab 且可切换', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AidGuideListPage(gateway: _EmergencyGateway())),
    );
    await tester.pumpAndSettle();

    final allTab = find.byKey(const ValueKey('aid-guide-category-all'));
    final categoryTab = find.byKey(const ValueKey('aid-guide-category-7'));

    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      tester
          .widget<Material>(
            find.descendant(of: allTab, matching: find.byType(Material)).first,
          )
          .color,
      emergencyRed,
    );
    expect(
      tester
          .widget<Text>(find.descendant(of: allTab, matching: find.text('全部')))
          .style
          ?.color,
      Colors.white,
    );

    await tester.tap(categoryTab);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Material>(
            find
                .descendant(of: categoryTab, matching: find.byType(Material))
                .first,
          )
          .color,
      emergencyRed,
    );
  });

  testWidgets('急救详情可识别 wangEditor 富文本视频节点并开启可见时自动播放', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AidGuideDetailPage(gateway: _VideoEmergencyGateway(), guideId: 5),
      ),
    );
    await tester.pump();
    await tester.pump();

    final video = find.byKey(const ValueKey('aid-guide-video-0'));
    expect(video, findsOneWidget);
    expect(
      tester.widget<Semantics>(video).properties.value,
      '${ApiConfig.assetBaseUrl}/uploads/test.mov',
    );
    expect(
      tester
          .widget<RichTextVideoPlayer>(find.byType(RichTextVideoPlayer))
          .autoPlayWhenVisible,
      isTrue,
    );
    expect(find.text('视频地址无效'), findsNothing);
  });

  testWidgets('急救详情对不安全的视频地址显示明确占位', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AidGuideDetailPage(
          gateway: _VideoEmergencyGateway(unsafe: true),
          guideId: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('aid-guide-video-unavailable-0')),
      findsOneWidget,
    );
    expect(find.text('视频地址无效'), findsOneWidget);
  });

  testWidgets('急救热线不受 capability 假阴性影响并直接通过 tel URI 打开', (tester) async {
    final launcher = _UriLauncher();
    await tester.pumpWidget(
      MaterialApp(
        home: EmergencyCenterPage(
          gateway: _EmergencyGateway(),
          locationGateway: _LocationGateway(EmergencyLocationPermission.denied),
          uriLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('emergency-hotline-call')));
    await tester.pumpAndSettle();

    expect(find.text('确定要拨打 4001234567 吗？'), findsNothing);
    expect(launcher.canLaunchUris, isEmpty);
    expect(launcher.launched.single.toString(), 'tel:4001234567');
  });

  testWidgets(
    'Android 用户确认定位用途后可直接拨打医院电话并打开地图导航',
    (tester) async {
      final location = _LocationGateway(EmergencyLocationPermission.denied);
      final launcher = _UriLauncher();
      final gateway = _EmergencyGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyCenterPage(
            gateway: gateway,
            locationGateway: location,
            uriLauncher: launcher,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(location.requestCalls, 0);
      final nearbyRequest = find.byKey(
        const ValueKey('emergency-nearby-request'),
      );
      await tester.drag(
        find.byKey(const ValueKey('emergency-center-scroll')),
        const Offset(0, -520),
      );
      await tester.pumpAndSettle();
      await tester.tap(nearbyRequest);
      await tester.pumpAndSettle();
      expect(find.text('允许访问位置信息'), findsOneWidget);
      expect(location.requestCalls, 0);

      await tester.tap(
        find.byKey(const ValueKey('emergency-location-confirm')),
      );
      await tester.pumpAndSettle();

      expect(location.requestCalls, 1);
      expect(location.positionCalls, 1);
      expect(gateway.nearbyCalls, 1);
      expect(find.text('测试宠物医院'), findsOneWidget);

      final hospitalCall = find.byKey(
        const ValueKey('emergency-hospital-call-3'),
      );
      final navigation = find.byKey(
        const ValueKey('emergency-hospital-navigation-3'),
      );
      expect(tester.widget(hospitalCall), isA<OutlinedButton>());
      expect(tester.widget(navigation), isA<OutlinedButton>());
      expect(tester.getSize(hospitalCall).height, 40);
      expect(tester.getSize(navigation), tester.getSize(hospitalCall));

      await tester.ensureVisible(hospitalCall);
      await tester.tap(hospitalCall);
      await tester.pumpAndSettle();

      expect(find.text('确定要拨打 01012345678 吗？'), findsNothing);
      expect(launcher.launched.last.toString(), 'tel:01012345678');

      await tester.ensureVisible(navigation);
      await tester.tap(navigation);
      await tester.pumpAndSettle();

      final uri = launcher.launched.last;
      expect(uri.scheme, 'https');
      expect(uri.host, 'uri.amap.com');
      expect(uri.queryParameters['to'], contains('测试宠物医院'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS 请求附近医院时不展示自绘定位弹窗',
    (tester) async {
      final location = _LocationGateway(EmergencyLocationPermission.denied);
      final gateway = _EmergencyGateway();

      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyCenterPage(
            gateway: gateway,
            locationGateway: location,
            uriLauncher: _UriLauncher(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nearbyRequest = find.byKey(
        const ValueKey('emergency-nearby-request'),
      );
      await tester.drag(
        find.byKey(const ValueKey('emergency-center-scroll')),
        const Offset(0, -520),
      );
      await tester.pumpAndSettle();
      await tester.tap(nearbyRequest);
      await tester.pumpAndSettle();

      expect(find.text('允许访问位置信息'), findsNothing);
      expect(location.requestCalls, 1);
      expect(location.positionCalls, 1);
      expect(gateway.nearbyCalls, 1);
      expect(find.text('测试宠物医院'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  test('地图导航 URI 使用经纬度、名称和受控 HTTPS 域名', () {
    final uri = buildHospitalNavigationUri(_EmergencyGateway.hospital);

    expect(uri.scheme, 'https');
    expect(uri.host, 'uri.amap.com');
    expect(uri.queryParameters['to'], '116.41,39.91,测试宠物医院');
    expect(uri.queryParameters['callnative'], '1');
  });
}

class _EmergencyGateway implements EmergencyGateway {
  int nearbyCalls = 0;

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

  static final secondGuide = AidGuide(
    id: 2,
    title: '休克',
    content: '<p>保持呼吸通畅</p>',
    categoryId: 8,
    status: 'PUBLISHED',
    sortOrder: 2,
    createdAt: DateTime(2026, 7, 21),
  );

  static const hospital = NearbyHospital(
    id: 3,
    name: '测试宠物医院',
    address: '测试路 1 号',
    phone: '010-12345678',
    latitude: 39.91,
    longitude: 116.41,
    businessStatusText: '营业中',
    distance: 1.2,
  );

  @override
  Future<EmergencyCenterConfig> loadEmergencyConfig() async =>
      const EmergencyCenterConfig(
        emergencyTime: '全天候在线',
        emergencyHotline: '400-123-4567',
      );

  @override
  Future<List<AidGuide>> loadAidGuides({int? categoryId}) async => [
    guide,
    secondGuide,
  ];

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
    return const [hospital];
  }
}

class _VideoEmergencyGateway extends _EmergencyGateway {
  _VideoEmergencyGateway({this.unsafe = false});

  final bool unsafe;

  @override
  Future<AidGuide> loadAidGuide(int guideId) async => AidGuide(
    id: guideId,
    title: '休克',
    content:
        '<p><br></p><div data-w-e-type="video" data-w-e-is-void>'
        '<video poster="" controls="true">'
        '<source src="${unsafe ? 'javascript:alert(1)' : '/uploads/test.mov'}" '
        'type="video/mp4"/></video></div><p><br></p>',
    categoryId: 7,
    status: 'PUBLISHED',
    sortOrder: 1,
    createdAt: DateTime(2026, 3, 23),
    category: _EmergencyGateway.guide.category,
  );
}

class _LocationGateway implements EmergencyLocationGateway {
  _LocationGateway(this.status);

  EmergencyLocationPermission status;
  int requestCalls = 0;
  int positionCalls = 0;

  @override
  Future<EmergencyLocationPermission> checkPermission() async => status;

  @override
  Future<EmergencyPosition> getCurrentPosition() async {
    positionCalls += 1;
    return const EmergencyPosition(latitude: 39.9, longitude: 116.4);
  }

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<EmergencyLocationPermission> requestPermission() async {
    requestCalls += 1;
    status = EmergencyLocationPermission.granted;
    return status;
  }
}

class _UriLauncher implements ExternalUriLauncher {
  final List<Uri> canLaunchUris = [];
  final List<Uri> launched = [];

  @override
  Future<bool> canLaunch(Uri uri) async {
    canLaunchUris.add(uri);
    return false;
  }

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return true;
  }
}
