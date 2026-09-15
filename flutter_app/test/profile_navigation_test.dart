import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/mall/navigation/mall_dependencies.dart';
import 'package:pet_hospital_flutter/features/mall/navigation/mall_navigation_coordinator.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_dependencies.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_navigation_coordinator.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_routes.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';

void main() {
  group('parseProfileNotificationDestination', () {
    test('订单通知解析为强类型商城订单详情目标', () {
      final destination = parseProfileNotificationDestination(
        const ProfileNotificationAction(
          actionType: 'order',
          actionData: {'orderId': '73'},
        ),
      );

      expect(destination, isA<ProfileOrderDetailDestination>());
      expect((destination as ProfileOrderDetailDestination).args.orderId, 73);
    });

    test('订单通知按角色打开订单或售后详情', () {
      final sellerOrder =
          parseProfileNotificationDestination(
                const ProfileNotificationAction(
                  actionType: 'order',
                  actionData: {'orderId': 73, 'viewRole': 'seller'},
                ),
              )
              as ProfileOrderDetailDestination;
      final afterSale =
          parseProfileNotificationDestination(
                const ProfileNotificationAction(
                  actionType: 'order',
                  actionData: {'afterSaleId': 81, 'viewRole': 'buyer'},
                ),
              )
              as ProfileAfterSaleDestination;

      expect(sellerOrder.args.viewRole, OrderViewRole.seller);
      expect(afterSale.args.afterSaleId, 81);
      expect(afterSale.args.viewRole, OrderViewRole.buyer);
    });

    test('page 通知只解析已支持的强类型页面', () {
      final orderDestination = parseProfileNotificationDestination(
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {
            'path': 'OrderDetail',
            'params': {'id': 31},
          },
        ),
      );
      final settingsDestination = parseProfileNotificationDestination(
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {'path': 'SecuritySettings'},
        ),
      );

      expect(
        (orderDestination as ProfileOrderDetailDestination).args.orderId,
        31,
      );
      expect(settingsDestination, isA<ProfileSettingsDestination>());
    });

    test('未知 action 安全解析为统一的不支持目标', () {
      final destination = parseProfileNotificationDestination(
        const ProfileNotificationAction(
          actionType: 'future-action',
          actionData: {'id': 1},
        ),
      );

      expect(destination, isA<ProfileUnsupportedDestination>());
      expect(
        (destination as ProfileUnsupportedDestination).reason,
        ProfileUnsupportedReason.unknownAction,
      );
    });
  });

  testWidgets('协调器覆盖个人中心主入口并将商城入口委托给 Mall', (tester) async {
    final mallNavigation = _RecordingMallNavigation();
    final pageFactory = _RecordingProfilePageFactory();
    final coordinator = ProfileNavigationCoordinator(
      ProfileDependencies(
        profileGateway: _UnusedProfileGateway(),
        walletGateway: _UnusedWalletGateway(),
        mallNavigation: mallNavigation,
        pageFactory: pageFactory,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ListView(
              children: [
                _routeButton(
                  key: 'pets',
                  onPressed: () => coordinator.openPets(context),
                ),
                _routeButton(
                  key: 'orders',
                  onPressed: () => coordinator.openOrders(context),
                ),
                _routeButton(
                  key: 'medical-orders',
                  onPressed: () => coordinator.openMedicalOrders(context),
                ),
                _routeButton(
                  key: 'addresses',
                  onPressed: () => coordinator.openAddresses(context),
                ),
                _routeButton(
                  key: 'notifications',
                  onPressed: () => coordinator.openNotifications(context),
                ),
                _routeButton(
                  key: 'lost-found-posts',
                  onPressed: () => coordinator.openLostFoundPosts(context),
                ),
                _routeButton(
                  key: 'community',
                  onPressed: () => coordinator.openCommunityProfile(context),
                ),
                _routeButton(
                  key: 'coupons',
                  onPressed: () => coordinator.openCoupons(context),
                ),
                _routeButton(
                  key: 'favorites',
                  onPressed: () => coordinator.openFavorites(context),
                ),
                _routeButton(
                  key: 'published-products',
                  onPressed: () => coordinator.openPublishedProducts(context),
                ),
                _routeButton(
                  key: 'settings',
                  onPressed: () => coordinator.openSettings(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final key in const [
      'pets',
      'medical-orders',
      'notifications',
      'lost-found-posts',
      'community',
      'coupons',
      'settings',
    ]) {
      await tester.tap(find.byKey(ValueKey('route-$key')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('profile-page-$key')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    for (final key in const [
      'orders',
      'addresses',
      'favorites',
      'published-products',
    ]) {
      await tester.tap(find.byKey(ValueKey('route-$key')));
      await tester.pump();
    }

    expect(pageFactory.destinationKeys, [
      'pets',
      'medical-orders',
      'notifications',
      'lost-found-posts',
      'community',
      'coupons',
      'settings',
    ]);
    expect(mallNavigation.calls, [
      'orders',
      'addresses',
      'favorites',
      'published-products',
    ]);
    expect(mallNavigation.authenticatedValues, everyElement(isTrue));
  });

  testWidgets('个人中心四个商城入口打开统一 Mall 协调器的真实页面', (tester) async {
    final requestedPaths = <String>[];
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final body = switch (request.url.path) {
          '/shop/orders/purchases' ||
          '/shop/favorites' ||
          '/shop/products/my' => {
            'code': 0,
            'data': <Object?>[],
            'pagination': {
              'total': 0,
              'page': 1,
              'pageSize': 20,
              'totalPages': 0,
            },
          },
          '/addresses' => {'code': 0, 'data': <Object?>[]},
          _ => throw StateError('unexpected ${request.url.path}'),
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async => 'test-token',
    );
    final mallNavigation = MallNavigationCoordinator(
      MallDependencies.production(apiClient),
    );
    final coordinator = ProfileNavigationCoordinator(
      ProfileDependencies(
        profileGateway: _UnusedProfileGateway(),
        walletGateway: _UnusedWalletGateway(),
        mallNavigation: mallNavigation,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ListView(
              children: [
                _routeButton(
                  key: 'real-orders',
                  onPressed: () => coordinator.openOrders(context),
                ),
                _routeButton(
                  key: 'real-addresses',
                  onPressed: () => coordinator.openAddresses(context),
                ),
                _routeButton(
                  key: 'real-favorites',
                  onPressed: () => coordinator.openFavorites(context),
                ),
                _routeButton(
                  key: 'real-published-products',
                  onPressed: () => coordinator.openPublishedProducts(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final entry in const [
      ('real-orders', '我买到的', '/shop/orders/purchases'),
      ('real-addresses', '收货地址', '/addresses'),
      ('real-favorites', '我的收藏', '/shop/favorites'),
      ('real-published-products', '我发布商品', '/shop/products/my'),
    ]) {
      await tester.tap(find.byKey(ValueKey('route-${entry.$1}')));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(requestedPaths, contains(entry.$3));
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('钱包交易使用强类型参数委托商城订单详情', (tester) async {
    final mallNavigation = _RecordingMallNavigation();
    final coordinator = ProfileNavigationCoordinator(
      ProfileDependencies(
        profileGateway: _UnusedProfileGateway(),
        walletGateway: _UnusedWalletGateway(),
        mallNavigation: mallNavigation,
        pageFactory: _RecordingProfilePageFactory(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(coordinator.openWallet(context)),
              child: const Text('打开钱包'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-order-47')));
    await tester.pump();

    expect(mallNavigation.orderDetailArgs?.orderId, 47);
    expect(mallNavigation.authenticatedValues, everyElement(isTrue));
  });

  testWidgets('生产工厂注册个人中心真实业务页面并限定本人发布', (tester) async {
    final requestedPaths = <String>[];
    final lostFoundRequests = <Uri>[];
    final mallNavigation = _RecordingMallNavigation();
    final authController = AuthController(
      gateway: _NavigationAuthGateway(),
      sessionStore: _NavigationSessionStore(
        const AuthSession(
          accessToken: 'token',
          accountType: AccountType.user,
          profile: {'id': 7, 'phone': '13800138000'},
        ),
      ),
    );
    await authController.initialize();
    final dependencies = ProfileDependencies.production(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path == '/lost-found') {
            lostFoundRequests.add(request.url);
          }
          final body = switch (request.url.path) {
            '/shop/wallet/stats' => {
              'success': true,
              'data': {'available': 12, 'pending': 3, 'total': 40, 'frozen': 0},
            },
            '/shop/wallet/withdrawals/config' => {
              'enabled': false,
              'availableBalance': 12,
              'minAmount': 1,
              'maxAmountPerRequest': 50000,
              'remainingDailyAmount': 50000,
              'hasActiveWithdrawal': false,
              'unavailableReason': '支付宝提现服务暂未开放',
            },
            '/shop/wallet/transactions' => {
              'data': <Object?>[],
              'total': 0,
              'page': 1,
              'limit': 10,
            },
            '/system-configs/contact_info' => {
              'data': {
                'configKey': 'contact_info',
                'configValue': {
                  'hotline': '',
                  'wechatQrCode': '',
                  'workingHours': '',
                },
              },
            },
            '/pet-categories/tree' => {'code': 0, 'data': <Object?>[]},
            '/pets/my' => {'code': 0, 'data': <Object?>[]},
            '/chat/orders' => {
              'code': 0,
              'data': {
                'data': <Object?>[],
                'total': 0,
                'page': 1,
                'pageSize': 20,
                'totalPages': 0,
              },
            },
            '/notifications' => {
              'code': 0,
              'data': [
                {
                  'id': 31,
                  'userId': 7,
                  'type': 'system',
                  'title': '订单状态更新',
                  'content': '订单已发货',
                  'isRead': false,
                  'actionType': 'order',
                  'actionData': {'orderId': 47},
                  'priority': 0,
                  'createdAt': 1784941200000,
                  'updatedAt': 1784941200000,
                  'readAt': null,
                },
              ],
              'pagination': {
                'total': 1,
                'page': 1,
                'pageSize': 20,
                'totalPages': 1,
              },
            },
            '/notifications/31/read' => {
              'code': 0,
              'data': {'success': true},
            },
            '/shop/coupons/my' => {'code': 0, 'data': <Object?>[]},
            '/shop/coupons/my/count' => {
              'code': 0,
              'data': {'available': 0, 'used': 0, 'expired': 0},
            },
            '/lost-found' => {
              'code': 0,
              'data': <Object?>[],
              'pagination': {
                'total': 0,
                'page': 1,
                'pageSize': 10,
                'totalPages': 0,
              },
            },
            _ => throw StateError('unexpected ${request.url.path}'),
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
        tokenProvider: () async => 'test-token',
      ),
      mallNavigation: mallNavigation,
      authController: authController,
    );
    final coordinator = ProfileNavigationCoordinator(dependencies);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                FilledButton(
                  key: const ValueKey('open-production-settings'),
                  onPressed: () => unawaited(coordinator.openSettings(context)),
                  child: const Text('真实设置'),
                ),
                FilledButton(
                  key: const ValueKey('open-production-wallet'),
                  onPressed: () => unawaited(coordinator.openWallet(context)),
                  child: const Text('真实钱包'),
                ),
                FilledButton(
                  key: const ValueKey('open-production-pets'),
                  onPressed: () => unawaited(coordinator.openPets(context)),
                  child: const Text('真实宠物'),
                ),
                FilledButton(
                  key: const ValueKey('open-production-medical-orders'),
                  onPressed: () =>
                      unawaited(coordinator.openMedicalOrders(context)),
                  child: const Text('真实医疗订单'),
                ),
                FilledButton(
                  key: const ValueKey('open-production-notifications'),
                  onPressed: () =>
                      unawaited(coordinator.openNotifications(context)),
                  child: const Text('真实通知'),
                ),
                FilledButton(
                  key: const ValueKey('open-production-coupons'),
                  onPressed: () => unawaited(coordinator.openCoupons(context)),
                  child: const Text('真实优惠券'),
                ),
                FilledButton(
                  key: const ValueKey('open-production-lost-found-posts'),
                  onPressed: () =>
                      unawaited(coordinator.openLostFoundPosts(context)),
                  child: const Text('真实走失领养发布'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-production-wallet')));
    await tester.pumpAndSettle();
    expect(find.text('我的钱包'), findsOneWidget);
    expect(find.text('钱包明细'), findsOneWidget);
    expect(
      requestedPaths,
      containsAll(<String>[
        '/shop/wallet/stats',
        '/shop/wallet/withdrawals/config',
      ]),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-production-settings')));
    await tester.pumpAndSettle();
    expect(find.text('系统设置'), findsOneWidget);
    expect(find.text('隐私协议'), findsOneWidget);
    expect(requestedPaths, contains('/system-configs/contact_info'));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-production-pets')));
    await tester.pumpAndSettle();
    expect(find.text('我的宠物'), findsOneWidget);
    expect(find.text('暂无宠物'), findsOneWidget);
    expect(find.text('点击下方按钮添加'), findsOneWidget);
    expect(
      requestedPaths,
      containsAll(<String>['/pet-categories/tree', '/pets/my']),
    );

    await tester.tap(find.byKey(const ValueKey('pet-page-back')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('open-production-medical-orders')),
    );
    await tester.pumpAndSettle();
    expect(find.text('医疗服务订单'), findsOneWidget);
    expect(find.text('暂无医疗服务订单'), findsOneWidget);
    expect(requestedPaths, contains('/chat/orders'));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('open-production-notifications')),
    );
    await tester.pumpAndSettle();
    expect(find.text('通知消息'), findsOneWidget);
    expect(find.text('订单状态更新'), findsOneWidget);
    expect(requestedPaths, contains('/notifications'));

    await tester.tap(find.byKey(const ValueKey('notification-card-31')));
    await tester.pumpAndSettle();
    expect(requestedPaths, contains('/notifications/31/read'));
    expect(mallNavigation.orderDetailArgs?.orderId, 47);
    expect(mallNavigation.authenticatedValues, contains(true));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('真实通知'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-production-coupons')));
    await tester.pumpAndSettle();
    expect(find.text('我的优惠券'), findsOneWidget);
    expect(find.text('暂无可用优惠券'), findsOneWidget);
    expect(
      requestedPaths,
      containsAll(<String>['/shop/coupons/my', '/shop/coupons/my/count']),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('open-production-lost-found-posts')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lost-found-tabs')), findsOneWidget);
    expect(find.text('暂时没有走失信息'), findsOneWidget);
    expect(lostFoundRequests, hasLength(1));
    expect(lostFoundRequests.single.queryParameters['publisherId'], '7');
    expect(lostFoundRequests.single.queryParameters['recordType'], 'LOST');
  });

  testWidgets('未知通知目标显示统一反馈且不抛异常', (tester) async {
    final coordinator = ProfileNavigationCoordinator(
      ProfileDependencies(
        profileGateway: _UnusedProfileGateway(),
        walletGateway: _UnusedWalletGateway(),
        mallNavigation: _RecordingMallNavigation(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                coordinator.openNotificationAction(
                  context,
                  const ProfileNotificationAction(
                    actionType: 'unsupported',
                    actionData: {'id': 1},
                  ),
                ),
              ),
              child: const Text('打开通知'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开通知'));
    await tester.pump();

    expect(find.text(profileUnsupportedDestinationMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _UnusedWalletGateway implements WalletSummaryGateway {
  @override
  Future<WalletStats> loadStats() => throw UnimplementedError();
}

class _NavigationSessionStore implements SessionStore {
  _NavigationSessionStore(this.session);

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

class _NavigationAuthGateway implements AuthGateway {
  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async =>
      savedSession;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _routeButton({
  required String key,
  required Future<void> Function() onPressed,
}) {
  return FilledButton(
    key: ValueKey('route-$key'),
    onPressed: () => unawaited(onPressed()),
    child: Text(key),
  );
}

class _RecordingProfilePageFactory implements ProfilePageFactory {
  final List<String> destinationKeys = [];

  @override
  Widget buildPage(
    ProfileOwnedDestination destination, {
    required OpenProfileOrderDetail onOrderDetail,
    required OpenProfileNotificationAction onNotificationAction,
  }) {
    final key = destination.key;
    destinationKeys.add(key);
    return Scaffold(
      appBar: AppBar(title: Text(key)),
      body: Column(
        children: [
          SizedBox(key: ValueKey('profile-page-$key')),
          if (destination is ProfileWalletDestination)
            TextButton(
              key: const ValueKey('wallet-order-47'),
              onPressed: () =>
                  unawaited(onOrderDetail(const OrderRouteArgs(47))),
              child: const Text('查看订单'),
            ),
        ],
      ),
    );
  }
}

class _RecordingMallNavigation extends MallNavigationCoordinator {
  _RecordingMallNavigation() : super(_UnusedMallDependencies());

  final List<String> calls = [];
  final List<bool> authenticatedValues = [];
  OrderRouteArgs? orderDetailArgs;

  @override
  Future<void> openOrders(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
    OrderViewRole viewRole = OrderViewRole.buyer,
  }) async {
    calls.add(viewRole == OrderViewRole.seller ? 'sales' : 'orders');
    authenticatedValues.add(authenticated);
  }

  @override
  Future<void> openAddresses(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) async {
    calls.add('addresses');
    authenticatedValues.add(authenticated);
  }

  @override
  Future<void> openFavorites(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) async {
    calls.add('favorites');
    authenticatedValues.add(authenticated);
  }

  @override
  Future<void> openPublishedProducts(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) async {
    calls.add('published-products');
    authenticatedValues.add(authenticated);
  }

  @override
  Future<void> openOrderDetail(
    BuildContext context,
    OrderRouteArgs args, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) async {
    calls.add('order-detail');
    authenticatedValues.add(authenticated);
    orderDetailArgs = args;
  }
}

class _UnusedMallDependencies implements MallDependencies {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedProfileGateway implements ProfileGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
