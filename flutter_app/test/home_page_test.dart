import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/activity/domain/activity_models.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/chat/data/chat_repository.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/charity/domain/charity_models.dart';
import 'package:pet_hospital_flutter/features/emergency/domain/emergency_models.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';
import 'package:pet_hospital_flutter/features/home/domain/home_models.dart';
import 'package:pet_hospital_flutter/features/home/presentation/home_page.dart';
import 'package:pet_hospital_flutter/features/lost_found/domain/lost_found_models.dart';
import 'package:pet_hospital_flutter/features/mall/domain/mall_models.dart';
import 'package:pet_hospital_flutter/features/mall/navigation/mall_dependencies.dart';
import 'package:pet_hospital_flutter/features/mall/navigation/mall_navigation_coordinator.dart';
import 'package:pet_hospital_flutter/features/nearby/domain/nearby_models.dart';
import 'package:pet_hospital_flutter/features/notifications/domain/notification_models.dart';
import 'package:pet_hospital_flutter/features/notifications/presentation/notification_badge_controller.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_navigation_coordinator.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';
import 'package:pet_hospital_flutter/features/profile/presentation/profile_controller.dart';
import 'package:pet_hospital_flutter/features/scanner/presentation/qr_scanner_page.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';

void main() {
  testWidgets('首页消息角标超过 99 时显示 99+', (tester) async {
    HomeTab? selectedTab;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: HomeBottomBar(
            activeTab: HomeTab.medical,
            unreadMessageCount: 100,
            onChanged: (tab) => selectedTab = tab,
          ),
        ),
      ),
    );

    expect(find.text('99+'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-tab-messages')));
    expect(selectedTab, HomeTab.messages);
  });

  testWidgets('首页好友标签显示申请角标并可切换', (tester) async {
    HomeTab? selectedTab;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: HomeBottomBar(
            activeTab: HomeTab.medical,
            pendingFriendRequestCount: 5,
            onChanged: (tab) => selectedTab = tab,
          ),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-tab-friends')));
    expect(selectedTab, HomeTab.friends);
  });

  testWidgets('底部导航五个入口等宽且图标与文字中心对齐', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: HomeBottomBar(
            activeTab: HomeTab.medical,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    const tabs = ['medical', 'mall', 'messages', 'friends', 'profile'];
    final buttonWidths = <double>[];
    final iconTops = <double>[];
    final labelTops = <double>[];
    for (final tab in tabs) {
      final button = find.byKey(ValueKey('home-tab-$tab'));
      final iconSlot = find.byKey(ValueKey('home-tab-$tab-icon-slot'));
      final label = find.byKey(ValueKey('home-tab-$tab-label'));
      final buttonCenter = tester.getCenter(button).dx;

      buttonWidths.add(tester.getSize(button).width);
      iconTops.add(tester.getTopLeft(iconSlot).dy);
      labelTops.add(tester.getTopLeft(label).dy);
      expect(tester.getCenter(iconSlot).dx, closeTo(buttonCenter, 0.1));
      expect(tester.getCenter(label).dx, closeTo(buttonCenter, 0.1));
    }

    expect(buttonWidths.toSet(), hasLength(1));
    expect(iconTops.toSet(), hasLength(1));
    expect(labelTops.toSet(), hasLength(1));
  });

  testWidgets('医疗首页保留 RN 首屏结构与 Banner 比例', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('medical-home-top-bar')), findsOneWidget);
    expect(find.text('热门搜索...'), findsOneWidget);
    expect(find.text('宠物档案'), findsOneWidget);
    expect(find.text('二手商城'), findsOneWidget);
    expect(find.text('热门活动'), findsOneWidget);
    expect(find.text('热门医生'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('商城'), findsOneWidget);

    final bannerSize = tester.getSize(
      find.byKey(const ValueKey('medical-home-ai-diagnosis-banner')),
    );
    expect(bannerSize.width, 390);
    expect(bannerSize.height, closeTo(390 / (1029 / 420) + 6, 0.6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('医疗首页在 Banner 下方展示滚动公告', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _AnnouncementHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.byKey(const ValueKey('medical-home-scrolling-announcement')),
      findsOneWidget,
    );
    expect(
      find.text('首页公告：本周五下午 3 点起系统维护，部分功能可能短暂不可用，请关注后续通知并合理安排就诊时间'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('医疗首页公告为空时隐藏公告区域', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('medical-home-scrolling-announcement')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('医疗首页热门搜索进入 RN 对应的商品搜索路由', (tester) async {
    final mallNavigation = _RecordingMallNavigation();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          mallNavigation: mallNavigation,
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('medical-home-search-entry')));
    await tester.pump();

    expect(mallNavigation.calls, ['search']);
    expect(mallNavigation.authenticatedValues, [isFalse]);
    expect(find.text('热门搜索...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('医疗首页扫一扫入口打开扫码页面', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('medical-home-scan-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(QrScannerPage), findsOneWidget);
    expect(find.text('扫码说明'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已登录医疗首页通知入口打开通知消息页', (tester) async {
    const session = AuthSession(
      accessToken: 'test-token',
      accountType: AccountType.user,
      profile: {'id': 8, 'name': '测试用户'},
    );
    final authController = AuthController(
      gateway: _UnusedAuthGateway(),
      sessionStore: _MemorySessionStore(session),
    );
    await authController.initialize();
    addTearDown(authController.dispose);
    final profileNavigation = _RecordingProfileNavigator();
    final badgeController = NotificationBadgeController(
      gateway: _UnusedNotificationGateway(),
    )..setLocalCount(2);
    addTearDown(badgeController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          authController: authController,
          session: session,
          chatGateway: _FakeChatGateway(),
          profileNavigation: profileNavigation,
          notificationBadgeController: badgeController,
          profileControllerFactory: (auth) => ProfileController(
            profileGateway: _HomeProfileGateway(),
            walletGateway: _HomeWalletGateway(),
            authController: auth,
          ),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('medical-home-notification-entry')),
    );
    await tester.pump();

    expect(profileNavigation.calls, ['notifications']);
    expect(
      find.byKey(const ValueKey('medical-home-notification-badge-dot')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('medical-home-notification-badge-dot')),
          )
          .width,
      greaterThan(10),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('游客点击医疗首页通知入口时先提示登录', (tester) async {
    final profileNavigation = _RecordingProfileNavigator();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          profileNavigation: profileNavigation,
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('medical-home-notification-entry')),
    );
    await tester.pumpAndSettle();

    expect(find.text('请先登录'), findsOneWidget);
    expect(find.text('登录后即可查看通知消息'), findsOneWidget);
    expect(profileNavigation.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页急救中心入口进入已移植页面', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _EmergencyHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emergencyEntry = find.byKey(
      const ValueKey('medical-home-feature-emergency'),
    );
    await tester.ensureVisible(emergencyEntry);
    await tester.tap(emergencyEntry);
    await tester.pumpAndSettle();

    expect(find.text('紧急求助'), findsOneWidget);
    expect(find.text('紧急热线：400-123-4567'), findsOneWidget);
  });

  testWidgets('已登录首页营养师入口进入真实健康管理页面', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const session = AuthSession(
      accessToken: 'test-token',
      accountType: AccountType.user,
      profile: {'id': 8, 'name': '测试用户'},
    );
    final authController = AuthController(
      gateway: _UnusedAuthGateway(),
      sessionStore: _MemorySessionStore(session),
    );
    await authController.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          gateway: _HealthHomeGateway(),
          mallGateway: _FakeMallGateway(),
          authController: authController,
          session: session,
          chatGateway: _FakeChatGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final healthEntry = find.byKey(
      const ValueKey('medical-home-feature-health'),
    );
    await tester.ensureVisible(healthEntry);
    await tester.tap(healthEntry);
    await tester.pumpAndSettle();

    expect(find.text('宠智灵营养师'), findsOneWidget);
    expect(find.text('健康提醒'), findsOneWidget);
    expect(find.text('护理建议'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已登录首页附近入口进入真实附近用户页面', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const session = AuthSession(
      accessToken: 'test-token',
      accountType: AccountType.user,
      profile: {'id': 8, 'name': '测试用户'},
    );
    final authController = AuthController(
      gateway: _UnusedAuthGateway(),
      sessionStore: _MemorySessionStore(session),
    );
    await authController.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          gateway: _NearbyHomeGateway(),
          mallGateway: _FakeMallGateway(),
          authController: authController,
          session: session,
          chatGateway: _FakeChatGateway(),
          nearbyLocationGateway: _HomeNearbyLocationGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nearbyEntry = find.byKey(
      const ValueKey('medical-home-feature-nearby'),
    );
    await tester.ensureVisible(nearbyEntry);
    await tester.tap(nearbyEntry);
    await tester.pumpAndSettle();

    expect(find.text('附近的人'), findsOneWidget);
    expect(find.text('附近测试用户'), findsOneWidget);
    expect(find.text('5km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页公益中心入口进入真实公益列表', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _CharityHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final charityEntry = find.byKey(
      const ValueKey('medical-home-feature-charity'),
    );
    await tester.ensureVisible(charityEntry);
    await tester.tap(charityEntry);
    await tester.pumpAndSettle();

    expect(find.text('公益中心'), findsOneWidget);
    expect(find.text('公益测试项目'), findsOneWidget);
    expect(find.byKey(const ValueKey('charity-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页走失领养入口进入真实瀑布流列表', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _LostFoundHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lostFoundEntry = find.byKey(
      const ValueKey('medical-home-feature-lost-found'),
    );
    await tester.ensureVisible(lostFoundEntry);
    await tester.tap(lostFoundEntry);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lost-found-list')), findsOneWidget);
    expect(find.text('首页走失测试宠物'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页活动管理入口进入真实活动列表', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _ActivityHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final activityEntry = find.byKey(
      const ValueKey('medical-home-feature-activity'),
    );
    await tester.ensureVisible(activityEntry);
    await tester.tap(activityEntry);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity-list')), findsOneWidget);
    expect(find.text('首页活动测试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已登录医疗首页的宠物档案入口接入真实导航', (tester) async {
    const session = AuthSession(
      accessToken: 'test-token',
      accountType: AccountType.user,
      profile: {'id': 8, 'name': '测试用户'},
    );
    final authController = AuthController(
      gateway: _UnusedAuthGateway(),
      sessionStore: _MemorySessionStore(session),
    );
    await authController.initialize();
    final profileNavigation = _RecordingProfileNavigator();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          authController: authController,
          session: session,
          chatGateway: _FakeChatGateway(),
          profileNavigation: profileNavigation,
          profileControllerFactory: (authController) => ProfileController(
            profileGateway: _HomeProfileGateway(),
            walletGateway: _HomeWalletGateway(),
            authController: authController,
          ),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final petsEntry = find.byKey(
      const ValueKey('medical-home-feature-pet-list'),
    );
    await tester.drag(
      find.byKey(const ValueKey('medical-home-scroll-view')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(petsEntry);
    await tester.pump();

    expect(profileNavigation.calls, ['pets']);
  });

  testWidgets('游客点击账号标签时显示 RN 同款登录确认', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-tab-messages')));
    await tester.pumpAndSettle();

    expect(find.text('请先登录'), findsOneWidget);
    expect(find.text('登录后即可使用消息功能'), findsOneWidget);
    expect(find.text('继续浏览'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('完整个人中心子页面返回后仍停留在我的 Tab', (tester) async {
    final profileNavigation = _RecordingProfileNavigator(pushOrdersPage: true);
    const session = AuthSession(
      accessToken: 'test-token',
      accountType: AccountType.user,
      profile: {'id': 8, 'name': '测试用户'},
    );
    final authController = AuthController(
      gateway: _UnusedAuthGateway(),
      sessionStore: _MemorySessionStore(session),
    );
    await authController.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          authController: authController,
          session: session,
          chatGateway: _FakeChatGateway(),
          profileNavigation: profileNavigation,
          profileControllerFactory: (authController) => ProfileController(
            profileGateway: _HomeProfileGateway(),
            walletGateway: _HomeWalletGateway(),
            authController: authController,
          ),
          initialTab: HomeTab.profile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ordersEntry = find.byKey(const ValueKey('profile-service-orders'));
    await tester.ensureVisible(ordersEntry);
    await tester.tap(ordersEntry);
    await tester.pumpAndSettle();
    expect(find.text('商城订单测试目标'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-services-card')), findsOneWidget);
    expect(find.text('我买到的'), findsOneWidget);
    expect(find.text('商城服务'), findsNothing);
    expect(profileNavigation.calls, ['orders']);
  });

  test('已登录个人中心导航必须与 controller factory 成对注入', () {
    expect(
      () => HomePage(
        gateway: _FakeHomeGateway(),
        mallGateway: _FakeMallGateway(),
        authController: AuthController(
          gateway: _UnusedAuthGateway(),
          sessionStore: _MemorySessionStore(),
        ),
        session: const AuthSession(
          accessToken: 'test-token',
          accountType: AccountType.user,
          profile: {'id': 8},
        ),
        chatGateway: _FakeChatGateway(),
        profileNavigation: _RecordingProfileNavigator(),
      ),
      throwsAssertionError,
    );
  });

  testWidgets('已登录首页使用完整个人中心而不是商城服务占位页', (tester) async {
    final store = _MemorySessionStore(
      const AuthSession(
        accessToken: 'test-token',
        accountType: AccountType.user,
        profile: {
          'id': 8,
          'phone': '13800138000',
          'username': '首页用户',
          'gender': 0,
          'avatar': '',
        },
      ),
    );
    final auth = AuthController(
      gateway: _UnusedAuthGateway(),
      sessionStore: store,
    );
    await auth.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          authController: auth,
          session: auth.session!,
          chatGateway: _FakeChatGateway(),
          profileNavigation: _RecordingProfileNavigator(),
          profileControllerFactory: (authController) => ProfileController(
            profileGateway: _HomeProfileGateway(),
            walletGateway: _HomeWalletGateway(),
            authController: authController,
          ),
          initialTab: HomeTab.profile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('个人中心'), findsOneWidget);
    expect(find.text('首页用户'), findsOneWidget);
    expect(find.text('我的宠物'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('商城服务'), findsNothing);
    expect(find.text('退出登录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('游客不能通过个人中心导航绕过登录拦截', (tester) async {
    final profileNavigation = _RecordingProfileNavigator();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          profileNavigation: profileNavigation,
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-tab-profile')));
    await tester.pumpAndSettle();

    expect(find.text('请先登录'), findsOneWidget);
    expect(find.text('登录后即可使用个人中心功能'), findsOneWidget);
    expect(profileNavigation.calls, isEmpty);
  });

  testWidgets('首页固定展示原商城图片，刷新可更新且切换商城不弹窗', (tester) async {
    final mall = _FakeMallGateway(
      popupImageUrl: 'https://example.test/home-image.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: _FakeHomeGateway(),
          mallGateway: mall,
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = find.byKey(const ValueKey('medical-home-promotion-image'));
    await tester.scrollUntilVisible(
      image,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      (tester.widget<Image>(image).image as NetworkImage).url,
      mall.popupImageUrl,
    );
    expect(tester.widget<Image>(image).fit, BoxFit.contain);
    expect(find.text('历史咨询'), findsNothing);
    expect(find.byType(Dialog), findsNothing);

    mall.popupImageUrl = 'https://example.test/updated-home-image.jpg';
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Image>(image).image as NetworkImage).url,
      mall.popupImageUrl,
    );
    await tester.tap(find.byKey(const ValueKey('home-tab-mall')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('mall-home-popup-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final outcome in ['success', 'cancel', 'failure']) {
    testWidgets('首页图片长按保存 $outcome', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const url = 'https://example.test/save-image.png';
      final frame = (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          base64Decode(
            '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAEKADAAQAAAABAAAAEAAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAEAAQAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A7iiiiv4zP9RD/9k=',
          ),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame;
      }))!;
      PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage(url),
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: frame.image)),
        ),
      );
      addTearDown(() => PaintingBinding.instance.imageCache.clear());
      const channel = MethodChannel(
        'com.good.pet.hospital/activity_share_poster',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return outcome != 'failure';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage.guest(
            gateway: _FakeHomeGateway(),
            mallGateway: _FakeMallGateway(popupImageUrl: url),
            initialTab: HomeTab.medical,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = find.byKey(const ValueKey('medical-home-promotion-image'));
      await tester.scrollUntilVisible(
        image,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.longPress(image);
      await tester.pumpAndSettle();
      expect(find.text('保存首页图片'), findsOneWidget);
      await tester.tap(
        find.byKey(
          ValueKey(
            outcome == 'cancel'
                ? 'home-image-save-cancel'
                : 'home-image-save-confirm',
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      if (outcome == 'cancel') {
        expect(calls, isEmpty);
      } else {
        expect(calls.single.method, 'savePng');
        expect((calls.single.arguments['bytes'] as Uint8List).take(8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]);
        expect(
          find.text(outcome == 'success' ? '图片已保存到相册' : '保存失败，请检查相册权限后重试'),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('mall-home-popup-dialog')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('首页不再展示历史咨询模块', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          gateway: _FakeHomeGateway(),
          mallGateway: _FakeMallGateway(),
          authController: AuthController(
            gateway: _UnusedAuthGateway(),
            sessionStore: _MemorySessionStore(),
          ),
          session: const AuthSession(
            accessToken: 'test-token',
            accountType: AccountType.user,
            profile: {'id': 8, 'name': '测试用户'},
          ),
          chatGateway: _FakeChatGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('medical-home-promotion-image')),
      findsNothing,
    );
    expect(find.text('历史咨询'), findsNothing);
    expect(find.byKey(const ValueKey('home-consultation-71')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _RecordingProfileNavigator implements ProfileNavigator {
  _RecordingProfileNavigator({this.pushOrdersPage = false});

  final bool pushOrdersPage;
  final List<String> calls = [];

  @override
  Future<void> openPets(BuildContext context) async {
    calls.add('pets');
  }

  @override
  Future<void> openOrders(BuildContext context) async {
    calls.add('orders');
    if (!pushOrdersPage) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(appBar: AppBar(), body: const Text('商城订单测试目标')),
      ),
    );
  }

  @override
  Future<void> openNotifications(BuildContext context) async {
    calls.add('notifications');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _RecordingMallNavigation extends MallNavigationCoordinator {
  _RecordingMallNavigation() : super(_UnusedMallDependencies());

  final List<String> calls = [];
  final List<bool> authenticatedValues = [];

  @override
  Future<void> openSearch(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) async {
    calls.add('search');
    authenticatedValues.add(authenticated);
  }
}

class _UnusedMallDependencies implements MallDependencies {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedNotificationGateway implements NotificationGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHomeGateway implements HomeGateway {
  @override
  Future<HomeSnapshot> loadHome({required bool authenticated}) async {
    return const HomeSnapshot(
      doctors: [
        HomeDoctor(
          id: 2,
          name: '张晶',
          avatarUrl: '',
          specialty: '中兽医，外科，内科',
          experience: 8,
          price: '20.00',
          isGold: true,
          username: '张医生',
        ),
      ],
      activities: [
        HomeActivity(
          id: 17,
          title: '宠物选美大赛',
          coverImageUrl: '',
          status: 'ONGOING',
          activityType: 'ONLINE',
        ),
      ],
      consultations: [
        HomeConsultation(
          id: 71,
          doctorId: 2,
          doctorName: '张晶',
          doctorAvatarUrl: '',
          status: 'EXPIRED',
          paidAt: null,
          lastMessage: '请查看历史问诊记录',
        ),
      ],
    );
  }
}

class _AnnouncementHomeGateway extends _FakeHomeGateway {
  @override
  Future<HomeSnapshot> loadHome({required bool authenticated}) async {
    return const HomeSnapshot(
      scrollingAnnouncement: '首页公告：本周五下午 3 点起系统维护，部分功能可能短暂不可用，请关注后续通知并合理安排就诊时间',
      doctors: [
        HomeDoctor(
          id: 2,
          name: '张晶',
          avatarUrl: '',
          specialty: '中兽医，外科，内科',
          experience: 8,
          price: '20.00',
          isGold: true,
          username: '张医生',
        ),
      ],
      activities: [
        HomeActivity(
          id: 17,
          title: '宠物选美大赛',
          coverImageUrl: '',
          status: 'ONGOING',
          activityType: 'ONLINE',
        ),
      ],
      consultations: [
        HomeConsultation(
          id: 71,
          doctorId: 2,
          doctorName: '张晶',
          doctorAvatarUrl: '',
          status: 'EXPIRED',
          paidAt: null,
          lastMessage: '请查看历史问诊记录',
        ),
      ],
    );
  }
}

class _EmergencyHomeGateway extends _FakeHomeGateway
    implements EmergencyGateway {
  static final guide = AidGuide(
    id: 1,
    title: '宠物心肺复苏',
    content: '<p>检查呼吸</p>',
    categoryId: 7,
    status: 'PUBLISHED',
    sortOrder: 1,
    createdAt: DateTime(2026, 7, 20),
  );

  @override
  Future<EmergencyCenterConfig> loadEmergencyConfig() async =>
      const EmergencyCenterConfig(
        emergencyTime: '24小时在线',
        emergencyHotline: '400-123-4567',
      );

  @override
  Future<List<AidGuide>> loadAidGuides({int? categoryId}) async => [guide];

  @override
  Future<List<AidGuideCategory>> loadAidGuideCategories() async => const [];

  @override
  Future<AidGuide> loadAidGuide(int guideId) async => guide;

  @override
  Future<List<NearbyHospital>> loadNearbyHospitals({
    required double latitude,
    required double longitude,
    int limit = 10,
  }) async => const [];
}

class _HealthHomeGateway extends _FakeHomeGateway implements HealthGateway {
  @override
  Future<List<Pet>> loadHealthPets() async => [_healthPet];

  @override
  Future<PetHealthStats> loadPetHealthStats(int petId) async {
    return const PetHealthStats(
      vaccine: HealthMetric(count: 3, daysUntilNext: 7),
      deworming: HealthMetric(count: 5, daysUntilNext: 2),
      checkup: HealthMetric(count: 1, daysUntilNext: 30),
    );
  }

  @override
  Future<AppointmentPage> loadAppointments({
    required int petId,
    int page = 1,
    int pageSize = 20,
    HealthAppointmentType? type,
    HealthAppointmentStatus? status,
  }) async {
    return const AppointmentPage(items: [], page: 1, totalPages: 1, total: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NearbyHomeGateway extends _FakeHomeGateway implements NearbyGateway {
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
    return const NearbyUserPage(
      items: [
        NearbyUser(
          userId: 18,
          username: '附近测试用户',
          distanceMeters: 860,
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

class _CharityHomeGateway extends _FakeHomeGateway implements CharityGateway {
  static const activity = CharityActivity(
    id: 21,
    title: '公益测试项目',
    description: '首页公益入口测试',
    details: '',
    coverImageUrl: '',
    targetCheckIns: 10,
    completedCheckIns: 3,
    donatedAmount: 0,
    participantType: CharityParticipantType.checkIn,
    status: CharityStatus.active,
    hasCheckedToday: false,
  );

  @override
  Future<CharityPage> loadCharities({
    required bool authenticated,
    CharityStatus? status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async => const CharityPage(
    items: [activity],
    total: 1,
    page: 1,
    pageSize: 10,
    totalPages: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _LostFoundHomeGateway extends _FakeHomeGateway
    implements LostFoundGateway {
  @override
  Future<LostFoundPage> loadLostFoundRecords({
    required bool authenticated,
    LostFoundRecordType? recordType,
    bool? isFound,
    int? publisherId,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async => LostFoundPage(
    items: [
      LostFoundRecord(
        id: 31,
        petId: 8,
        publisherId: 9,
        pet: const LostFoundPet(
          id: 8,
          name: '首页走失测试宠物',
          avatarUrl: '',
          categoryName: '猫',
          subCategoryName: '英国短毛猫',
        ),
        publisher: const LostFoundUser(
          id: 9,
          username: 'publisher',
          nickname: '发布人',
          avatarUrl: '',
        ),
        recordType: recordType ?? LostFoundRecordType.lost,
        contactName: '小顾',
        contactPhone: '13800138000',
        description: '昨晚在公园东门附近走失，戴着蓝色项圈。',
        images: const [],
        videoUrl: '',
        videoCoverUrl: '',
        isPinned: false,
        isFound: false,
        foundAt: null,
        createdAt: DateTime(2026, 7, 25),
        updatedAt: DateTime(2026, 7, 25),
      ),
    ],
    total: 1,
    page: 1,
    pageSize: pageSize,
    totalPages: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName}');
  }
}

class _ActivityHomeGateway extends _FakeHomeGateway implements ActivityGateway {
  @override
  Future<ActivityPage> loadActivities({
    required bool authenticated,
    required ActivityStatus status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async => ActivityPage(
    items: status == ActivityStatus.ongoing ? [_activity] : const [],
    total: status == ActivityStatus.ongoing ? 1 : 0,
    page: page,
    pageSize: pageSize,
    totalPages: status == ActivityStatus.ongoing ? 1 : 0,
  );

  static final _activity = ActivityItem(
    id: 17,
    title: '首页活动测试',
    startTime: DateTime(2026, 7, 20),
    endTime: DateTime(2026, 8, 20),
    location: '',
    summary: '首页活动入口测试',
    description: '',
    coverImageUrl: '',
    sharePosterImageUrl: '',
    sharePosterTitle: '',
    sharePosterDescription: '',
    hospitalId: 1,
    hospitalName: '测试医院',
    registrationCount: 0,
    status: ActivityStatus.ongoing,
    activityType: ActivityType.online,
    voteOptions: const [],
    isRegistered: false,
    canRegister: true,
    createdAt: DateTime(2026, 7, 20),
    updatedAt: DateTime(2026, 7, 20),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _HomeNearbyLocationGateway implements NearbyLocationGateway {
  @override
  Future<NearbyLocationPermissionStatus> checkPermission() async {
    return NearbyLocationPermissionStatus.granted;
  }

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
    return NearbyLocationPermissionStatus.granted;
  }
}

final _healthPet = Pet(
  id: 8,
  name: '团子',
  avatarUrl: '',
  categoryId: 1,
  subCategoryId: 2,
  gender: PetGender.male,
  birthDate: DateTime(2024, 1, 1),
  weight: 5.5,
  isNeutered: true,
  vaccineCount: 3,
  category: const PetCategory(id: 1, name: '猫', parentId: null, sortOrder: 1),
  subCategory: const PetCategory(id: 2, name: '英短', parentId: 1, sortOrder: 1),
  ownerId: 5,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 7, 1),
);

class _FakeMallGateway implements MallGateway {
  _FakeMallGateway({this.popupImageUrl = ''});
  String popupImageUrl;
  @override
  Future<void> addToCart({
    required int productId,
    required int? skuId,
    required int quantity,
  }) async {}

  @override
  Future<bool> loadCartBadge() async => false;

  @override
  Future<MallSnapshot> loadMall({required bool authenticated}) async =>
      MallSnapshot(homePopupImageUrl: popupImageUrl);

  @override
  Future<MallProduct> loadProduct(int productId) => throw UnimplementedError();
}

class _FakeChatGateway implements ChatGateway {
  int? requestedDoctorId;
  int? requestedOrderId;
  bool? requestedViewOnly;

  @override
  Future<ChatBootstrap> loadOrderChat({
    required int doctorId,
    required int orderId,
    required bool viewOnly,
  }) async {
    requestedDoctorId = doctorId;
    requestedOrderId = orderId;
    requestedViewOnly = viewOnly;
    return ChatBootstrap(
      session: null,
      canSend: false,
      messages: [
        ChatMessage(
          id: 91,
          conversationId: '8_2',
          senderId: doctorId,
          receiverId: 8,
          content: '历史订单内的问诊消息',
          type: ChatMessageType.text,
          isAutoReply: false,
          isRead: true,
          createdAt: DateTime(2026, 7, 20, 10),
        ),
      ],
      doctorOnline: false,
      availablePackages: const [],
    );
  }

  @override
  Future<ChatBootstrap> loadChat(int doctorId) => throw UnimplementedError();

  @override
  Future<void> purchasePackage({
    required int doctorId,
    required int serviceItemId,
    String? conversationId,
  }) => throw UnimplementedError();

  @override
  Future<ChatBootstrap> refreshChat(int doctorId) => throw UnimplementedError();

  @override
  Future<ChatUploadResult> uploadMedia({
    required String path,
    required String fileName,
    required ChatMessageType type,
  }) => throw UnimplementedError();
}

class _MemorySessionStore implements SessionStore {
  _MemorySessionStore([this.session]);

  AuthSession? session;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<String?> readToken() async => session?.accessToken;

  @override
  Future<void> saveSession(AuthSession session) async => this.session = session;
}

class _HomeProfileGateway implements ProfileGateway {
  @override
  Future<UserProfile> loadProfile() async => const UserProfile(
    id: 8,
    username: '首页用户',
    displayName: '首页用户',
    phone: '13800138000',
    avatarUrl: '',
    gender: UserGender.unknown,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeWalletGateway implements WalletSummaryGateway {
  @override
  Future<WalletStats> loadStats() async => const WalletStats(
    availableBalance: 8,
    pendingSettlement: 2,
    totalSecondHandIncome: 10,
    withdrawalFrozenBalance: 0,
  );
}

class _UnusedAuthGateway implements AuthGateway {
  @override
  Future<AuthSession> login({
    required String phone,
    required String password,
    required AccountType accountType,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> register({
    required String phone,
    required String code,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
    required AccountType accountType,
  }) async {}

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async =>
      savedSession;

  @override
  Future<int> sendCode({
    required String phone,
    required String type,
    AccountType accountType = AccountType.user,
  }) async => 120;

  @override
  Future<void> verifyRegisterCode({
    required String phone,
    required String code,
  }) async {}

  @override
  Future<void> verifyResetPasswordCode({
    required String phone,
    required String code,
    required AccountType accountType,
  }) async {}
}
