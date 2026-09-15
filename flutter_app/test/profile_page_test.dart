import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_navigation_coordinator.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_routes.dart';
import 'package:pet_hospital_flutter/features/profile/presentation/pages/profile_page.dart';
import 'package:pet_hospital_flutter/features/profile/presentation/profile_controller.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';

import 'support/wp11_viewports.dart';

void main() {
  testWidgets('展示真实资料、钱包摘要、常用服务、工具和设置入口', (tester) async {
    final harness = await _Harness.create(notificationUnreadCount: 100);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.text('个人中心'), findsOneWidget);
    expect(find.text('小顾'), findsOneWidget);
    expect(find.text('普通会员'), findsOneWidget);
    final defaultAvatar = tester.widget<Image>(
      find.byKey(const ValueKey('profile-default-avatar')),
    );
    expect(
      (defaultAvatar.image as AssetImage).assetName,
      'assets/images/health/pet_avatar.png',
    );
    expect(find.byKey(const ValueKey('profile-gender-female')), findsOneWidget);
    expect(find.text('¥12.30'), findsOneWidget);
    expect(find.text('¥4.00'), findsOneWidget);
    expect(find.text('¥98.75'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-unread-dot')), findsOneWidget);
    expect(find.text('退出登录'), findsNothing);
    expect(find.text('商城服务'), findsNothing);
    expect(find.text('常用服务'), findsOneWidget);
    expect(find.text('我的工具'), findsOneWidget);

    const labels = [
      '我的宠物',
      '我买到的',
      '医疗服务',
      '收货地址',
      '社区主页',
      '走失领养发布',
      '通知消息',
      '我的优惠券',
      '我的收藏',
      '我卖出的',
      '我发布商品',
      '设置',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('profile-wallet-card')));
    for (final id in const [
      'pets',
      'orders',
      'medical-orders',
      'addresses',
      'community',
      'lost-found-posts',
      'notifications',
      'coupons',
      'favorites',
      'sales',
      'published-products',
      'settings',
    ]) {
      final item = find.byKey(ValueKey('profile-service-$id'));
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pump();
    }
    expect(harness.navigator.calls, [
      'wallet',
      'pets',
      'orders',
      'medical-orders',
      'addresses',
      'community',
      'lost-found-posts',
      'notifications',
      'coupons',
      'favorites',
      'sales',
      'published-products',
      'settings',
    ]);
  });

  testWidgets('主页面遵循淡蓝头部、轻量卡片、主次钱包和分组服务视觉基线', (tester) async {
    configureWp11Viewport(tester, (
      label: '淡蓝视觉基线',
      size: const Size(402, 874),
      textScale: 1,
    ));
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('profile-background')),
    );
    final backgroundDecoration = background.decoration as BoxDecoration;
    expect(backgroundDecoration.color, const Color(0xFFDEE9FF));
    expect(backgroundDecoration.gradient, isNull);

    final systemUiRegion = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.ancestor(
        of: find.byKey(const ValueKey('profile-background')),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(systemUiRegion.value.statusBarColor, const Color(0xFFDEE9FF));
    expect(systemUiRegion.value.statusBarIconBrightness, Brightness.dark);

    final headerBand = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('profile-header-band')),
    );
    final headerDecoration = headerBand.decoration as BoxDecoration;
    expect(headerDecoration.color, const Color(0xFFDEE9FF));

    expect(tester.getCenter(find.text('个人中心')).dx, closeTo(201, 0.5));
    expect(find.text('我的服务'), findsNothing);
    expect(find.text('常用服务'), findsOneWidget);
    expect(find.text('我的工具'), findsOneWidget);
    expect(find.text('查看系统通知和消息'), findsNothing);
    expect(find.text('查看我的优惠券'), findsNothing);
    expect(find.text('查看收藏的商品'), findsNothing);
    expect(find.text('查看我发布的商品'), findsNothing);

    for (final key in const [
      'profile-wallet-card',
      'profile-services-card',
      'profile-quick-services-card',
      'profile-tools-card',
      'profile-settings-card',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.left, closeTo(13, 0.5));
      expect(rect.right, closeTo(389, 0.5));
    }

    final toolsCard = find.byKey(const ValueKey('profile-tools-card'));
    final toolDividers = tester.widgetList<Divider>(
      find.descendant(of: toolsCard, matching: find.byType(Divider)),
    );
    expect(toolDividers, hasLength(3));
    for (final divider in toolDividers) {
      expect(divider.thickness, 0.5);
      expect(divider.color, const Color(0xFFF1F4F8));
    }
    final toolVerticalDividers = tester.widgetList<VerticalDivider>(
      find.descendant(of: toolsCard, matching: find.byType(VerticalDivider)),
    );
    expect(toolVerticalDividers, hasLength(3));
    for (final divider in toolVerticalDividers) {
      expect(divider.thickness, 0.5);
      expect(divider.color, const Color(0xFFF1F4F8));
    }

    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('¥12.30')).style?.color,
      const Color(0xFF3988E8),
    );
    expect(
      tester.widget<Text>(find.text('¥4.00')).style?.color,
      const Color(0xFF223047),
    );
    expect(
      tester.widget<Text>(find.text('¥98.75')).style?.color,
      const Color(0xFF223047),
    );

    const serviceVisuals = <String, (IconData, Color, Color)>{
      'pets': (Icons.pets, Color(0xFFF0645A), Color(0xFFFFF0ED)),
      'orders': (
        Icons.shopping_bag_outlined,
        Color(0xFFD99518),
        Color(0xFFFFF6DE),
      ),
      'medical-orders': (
        Icons.medical_services_outlined,
        Color(0xFF397EDB),
        Color(0xFFEAF3FF),
      ),
      'addresses': (
        Icons.location_on_outlined,
        Color(0xFF159DB0),
        Color(0xFFE7F8FA),
      ),
      'notifications': (
        Icons.notifications_none_rounded,
        Color(0xFF3988E8),
        Color(0xFFEDF4FF),
      ),
      'coupons': (
        Icons.confirmation_number_outlined,
        Color(0xFFE69622),
        Color(0xFFFFF4E5),
      ),
      'favorites': (
        Icons.star_border_rounded,
        Color(0xFF3988E8),
        Color(0xFFEDF4FF),
      ),
      'sales': (Icons.sell_outlined, Color(0xFFB45309), Color(0xFFFFF3E6)),
      'published-products': (
        Icons.storefront_outlined,
        Color(0xFF18A6B2),
        Color(0xFFE8F8F8),
      ),
      'settings': (
        Icons.settings_outlined,
        Color(0xFF7C8793),
        Color(0xFFF1F3F5),
      ),
    };
    for (final entry in serviceVisuals.entries) {
      final iconBox = find.byKey(ValueKey('profile-service-icon-${entry.key}'));
      await tester.ensureVisible(iconBox);
      final decoration =
          tester.widget<DecoratedBox>(iconBox).decoration as BoxDecoration;
      final icon = tester.widget<Icon>(
        find.descendant(of: iconBox, matching: find.byType(Icon)),
      );
      expect(decoration.color, entry.value.$3);
      expect(icon.icon, entry.value.$1);
      expect(icon.color, entry.value.$2);
    }
  });

  testWidgets('钱包局部失败不隐藏资料，也不显示伪造金额', (tester) async {
    final harness = await _Harness.create(walletError: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.text('小顾'), findsOneWidget);
    expect(find.text('钱包数据加载失败，请稍后重试'), findsOneWidget);
    expect(find.text('¥0.00'), findsNothing);
    expect(find.byKey(const ValueKey('profile-wallet-retry')), findsOneWidget);
  });

  testWidgets('通知红点监听全局值并通过语义保留精确未读数', (tester) async {
    final semantics = tester.ensureSemantics();
    final unreadCount = ValueNotifier<int>(0);
    addTearDown(unreadCount.dispose);
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app(notificationUnreadCount: unreadCount));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-unread-dot')), findsNothing);

    unreadCount.value = 1;
    await tester.pump();
    final unreadDot = find.byKey(const ValueKey('profile-unread-dot'));
    expect(unreadDot, findsOneWidget);
    expect(tester.getSize(unreadDot), const Size.square(18));
    expect(find.bySemanticsLabel('通知消息，1 条未读'), findsOneWidget);

    unreadCount.value = 99;
    await tester.pump();
    expect(find.bySemanticsLabel('通知消息，99 条未读'), findsOneWidget);

    unreadCount.value = 100;
    await tester.pump();
    final overflowBadgeSize = tester.getSize(unreadDot);
    expect(overflowBadgeSize.height, 18);
    expect(overflowBadgeSize.width, greaterThan(18));
    expect(find.bySemanticsLabel('通知消息，100 条未读'), findsOneWidget);

    unreadCount.value = 0;
    await tester.pump();
    expect(find.byKey(const ValueKey('profile-unread-dot')), findsNothing);
    expect(find.bySemanticsLabel('通知消息，查看系统通知和消息'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('下拉刷新折叠并重新请求资料与钱包', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(harness.profileGateway.loadCalls, 1);
    expect(harness.walletGateway.loadCalls, 1);

    await tester.fling(
      find.byKey(const ValueKey('profile-scroll-view')),
      const Offset(0, 500),
      1000,
    );
    await tester.pumpAndSettle();

    expect(harness.profileGateway.loadCalls, 2);
    expect(harness.walletGateway.loadCalls, 2);
  });

  testWidgets('从收益页返回后重新同步首页钱包摘要', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.text('¥12.30'), findsOneWidget);

    harness.walletGateway.stats = const WalletStats(
      availableBalance: 22,
      pendingSettlement: 5,
      totalSecondHandIncome: 120,
      withdrawalFrozenBalance: 2,
    );
    await tester.tap(find.byKey(const ValueKey('profile-wallet-card')));
    await tester.pumpAndSettle();

    expect(harness.walletGateway.loadCalls, 2);
    expect(find.text('¥22.00'), findsOneWidget);
    expect(find.text('¥5.00'), findsOneWidget);
    expect(find.text('¥120.00'), findsOneWidget);
  });

  testWidgets('应用从后台恢复后重新同步资料和钱包', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(harness.profileGateway.loadCalls, 1);
    expect(harness.walletGateway.loadCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(harness.profileGateway.loadCalls, 2);
    expect(harness.walletGateway.loadCalls, 2);
  });

  for (final viewport in wp11Viewports) {
    testWidgets('${viewport.label} 下个人中心无布局溢出', (tester) async {
      configureWp11Viewport(tester, viewport);
      final harness = await _Harness.create();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.app(textScale: viewport.textScale));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('头像、编辑、钱包、服务和未读数提供可访问语义与触控面积', (tester) async {
    final semantics = tester.ensureSemantics();
    final harness = await _Harness.create(notificationUnreadCount: 100);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('头像，小顾'), findsOneWidget);
    expect(find.bySemanticsLabel('性别，女'), findsOneWidget);
    expect(find.bySemanticsLabel('编辑个人资料'), findsOneWidget);
    expect(find.bySemanticsLabel('可提现余额，12.30 元'), findsOneWidget);
    expect(find.bySemanticsLabel('我的宠物，添加和管理您的宠物信息'), findsOneWidget);
    expect(find.bySemanticsLabel('通知消息，100 条未读'), findsOneWidget);

    expect(
      tester.getSize(find.byKey(const ValueKey('profile-edit-button'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('profile-wallet-card'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('profile-service-pets'))).height,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
  });
}

class _Harness {
  _Harness({
    required this.auth,
    required this.controller,
    required this.profileGateway,
    required this.walletGateway,
    required this.navigator,
  });

  final AuthController auth;
  final ProfileController controller;
  final _ProfileGateway profileGateway;
  final _WalletGateway walletGateway;
  final _RecordingNavigator navigator;

  static Future<_Harness> create({
    bool walletError = false,
    int notificationUnreadCount = 0,
  }) async {
    final auth = AuthController(
      gateway: const _AuthGateway(),
      sessionStore: _SessionStore(
        const AuthSession(
          accessToken: 'token',
          accountType: AccountType.user,
          profile: {
            'id': 8,
            'phone': '13800138000',
            'username': '小顾',
            'gender': 2,
            'avatar': '',
          },
        ),
      ),
    );
    await auth.initialize();
    final profileGateway = _ProfileGateway();
    final walletGateway = _WalletGateway(shouldFail: walletError);
    final navigator = _RecordingNavigator();
    return _Harness(
      auth: auth,
      profileGateway: profileGateway,
      walletGateway: walletGateway,
      navigator: navigator,
      controller: ProfileController(
        profileGateway: profileGateway,
        walletGateway: walletGateway,
        authController: auth,
        imagePicker: const _Picker(),
        notificationUnreadCount: notificationUnreadCount,
      ),
    );
  }

  Widget app({
    ValueListenable<int>? notificationUnreadCount,
    double textScale = 1,
  }) {
    return MaterialApp(
      builder: wp11TextScaleBuilder(textScale),
      home: Scaffold(
        body: ProfilePage(
          controller: controller,
          navigator: navigator,
          notificationUnreadCount: notificationUnreadCount,
        ),
      ),
    );
  }

  void dispose() => controller.dispose();
}

class _ProfileGateway implements ProfileGateway {
  int loadCalls = 0;

  @override
  Future<UserProfile> loadProfile() async {
    loadCalls += 1;
    return const UserProfile(
      id: 8,
      username: '小顾',
      displayName: '小顾',
      phone: '13800138000',
      avatarUrl: '',
      gender: UserGender.female,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WalletGateway implements WalletSummaryGateway {
  _WalletGateway({required this.shouldFail});

  final bool shouldFail;
  WalletStats stats = const WalletStats(
    availableBalance: 12.3,
    pendingSettlement: 4,
    totalSecondHandIncome: 98.75,
    withdrawalFrozenBalance: 0,
  );
  int loadCalls = 0;

  @override
  Future<WalletStats> loadStats() async {
    loadCalls += 1;
    if (shouldFail) throw StateError('wallet failed');
    return stats;
  }
}

class _RecordingNavigator implements ProfileNavigator {
  final List<String> calls = [];

  Future<void> _record(String call) async => calls.add(call);

  @override
  Future<void> openAddresses(BuildContext context) => _record('addresses');

  @override
  Future<void> openCoupons(BuildContext context) => _record('coupons');

  @override
  Future<void> openFavorites(BuildContext context) => _record('favorites');

  @override
  Future<void> openMedicalOrders(BuildContext context) =>
      _record('medical-orders');

  @override
  Future<void> openLostFoundPosts(BuildContext context) =>
      _record('lost-found-posts');

  @override
  Future<void> openCommunityProfile(BuildContext context) =>
      _record('community');

  @override
  Future<void> openNotifications(BuildContext context) =>
      _record('notifications');

  @override
  Future<void> openOrders(BuildContext context) => _record('orders');

  @override
  Future<void> openSales(BuildContext context) => _record('sales');

  @override
  Future<void> openPets(BuildContext context) => _record('pets');

  @override
  Future<void> openPublishedProducts(BuildContext context) =>
      _record('published-products');

  @override
  Future<void> openSettings(BuildContext context) => _record('settings');

  @override
  Future<void> openWallet(BuildContext context) => _record('wallet');

  @override
  Future<void> openNotificationAction(
    BuildContext context,
    ProfileNotificationAction action,
  ) => _record('notification-action');

  @override
  Future<void> openOrderDetail(BuildContext context, OrderRouteArgs args) =>
      _record('order-detail');
}

class _Picker implements ProfileImagePicker {
  const _Picker();

  @override
  Future<PickedProfileImage?> pickAvatar({BuildContext? context}) async => null;
}

class _AuthGateway implements AuthGateway {
  const _AuthGateway();

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async =>
      savedSession;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionStore implements SessionStore {
  _SessionStore(this.session);

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
