import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/coupons/domain/coupon_models.dart';
import 'package:pet_hospital_flutter/features/coupons/presentation/pages/coupon_center_page.dart';

import 'support/wp11_viewports.dart';

void main() {
  testWidgets('请求未完成时显示 loading，完成后显示明确空态', (tester) async {
    final pending = Completer<List<UserCoupon>>();
    final gateway = _CouponGateway(
      responses: {UserCouponStatus.available: pending.future},
    );

    await tester.pumpWidget(
      MaterialApp(home: CouponCenterPage(gateway: gateway)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('暂无可用优惠券'), findsOneWidget);
    expect(find.text('快去领取优惠券吧'), findsOneWidget);
  });

  testWidgets('页面严格使用 RN 渐变背景、透明标题栏和蓝色纯文案页签', (tester) async {
    final gateway = _CouponGateway(
      counts: const CouponCounts(available: 3, used: 1, expired: 2),
      responses: {UserCouponStatus.available: Future.value(const [])},
    );

    await tester.pumpWidget(
      MaterialApp(home: CouponCenterPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('coupon-gradient-background')),
    );
    final decoration = background.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [Color(0xFFDEE9FF), Color(0xFFFAFBFF)]);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.surfaceTintColor, Colors.transparent);

    expect(find.text('可使用'), findsOneWidget);
    expect(find.text('已使用'), findsOneWidget);
    expect(find.text('已过期'), findsOneWidget);
    expect(find.text('可使用 3'), findsNothing);
    expect(find.text('已使用 1'), findsNothing);
    expect(find.text('已过期 2'), findsNothing);

    final activeTab = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('coupon-tab-active-AVAILABLE')),
    );
    final activeDecoration = activeTab.decoration as BoxDecoration;
    expect(activeDecoration.border?.bottom.color, const Color(0xFF2196F3));
    expect(activeDecoration.border?.bottom.width, 2);

    final offerIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('coupon-empty-icon')),
    );
    expect(offerIcon.icon, Icons.local_offer_outlined);
    expect(offerIcon.size, 64);
    expect(offerIcon.color, const Color(0xFF9CA3AF));
  });

  for (final viewport in wp11Viewports) {
    testWidgets('优惠券在 ${viewport.label} 稳定展示长名称和核心规则', (tester) async {
      configureWp11Viewport(tester, viewport);
      final gateway = _CouponGateway(
        responses: {
          UserCouponStatus.available: Future.value([
            _coupon(1, name: '一张名称特别长但不会挤压券面金额和有效期的宠物用品优惠券'),
          ]),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: wp11TextScaleBuilder(viewport.textScale),
          home: CouponCenterPage(gateway: gateway),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我的优惠券'), findsOneWidget);
      expect(find.text('¥20'), findsOneWidget);
      expect(find.text('满100元可用'), findsOneWidget);
      expect(find.text('07.01 - 2026.07.31'), findsOneWidget);
      expect(find.textContaining('一张名称特别长'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('页签保持纯文案，三类券面和无门槛规则按服务端数据展示', (tester) async {
    final gateway = _CouponGateway(
      counts: const CouponCounts(available: 3, used: 1, expired: 2),
      responses: {
        UserCouponStatus.available: Future.value([
          _coupon(1),
          _coupon(2, type: CouponType.discount, discount: 8.5),
          _coupon(
            3,
            type: CouponType.directDiscount,
            discount: 5,
            minAmount: 0,
          ),
        ]),
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: CouponCenterPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('可使用'), findsOneWidget);
    expect(find.text('已使用'), findsOneWidget);
    expect(find.text('已过期'), findsOneWidget);
    expect(find.text('可使用 3'), findsNothing);
    expect(gateway.countCalls, 1);
    expect(find.text('¥20'), findsOneWidget);
    expect(find.text('8.5折'), findsOneWidget);
    expect(find.text('¥5'), findsOneWidget);
    expect(find.text('无门槛'), findsOneWidget);
  });

  testWidgets('可用券严格使用橙色票券结构并可展开规则详情', (tester) async {
    final gateway = _CouponGateway(
      responses: {
        UserCouponStatus.available: Future.value([
          _coupon(1, description: '宠物用品专享优惠'),
        ]),
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: CouponCenterPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('coupon-card-1')),
    );
    final cardDecoration = card.decoration as BoxDecoration;
    expect(cardDecoration.color, const Color(0xFFFFF7ED));
    expect(cardDecoration.border?.top.color, const Color(0xFFF59E0B));
    expect(cardDecoration.borderRadius, BorderRadius.circular(6));

    final amountPanel = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('coupon-card-amount-1')),
    );
    expect(amountPanel.color, const Color(0xFFF59E0B));
    expect(
      find.byKey(const ValueKey('coupon-card-connector-dot-1-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coupon-card-notch-top-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coupon-card-notch-bottom-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('coupon-expand-1')));
    await tester.pumpAndSettle();
    expect(find.text('描述'), findsOneWidget);
    expect(find.text('宠物用品专享优惠'), findsOneWidget);
    expect(find.text('使用范围'), findsOneWidget);
    expect(find.text('全场通用'), findsOneWidget);
    expect(find.text('叠加规则'), findsOneWidget);
    expect(find.text('不可叠加'), findsOneWidget);
  });

  testWidgets('切换状态请求对应列表，卡片点击不触发选择或返回', (tester) async {
    final gateway = _CouponGateway(
      counts: const CouponCounts(available: 1, used: 1, expired: 0),
      responses: {
        UserCouponStatus.available: Future.value([_coupon(1)]),
        UserCouponStatus.used: Future.value([
          _coupon(2, status: UserCouponStatus.used),
        ]),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => CouponCenterPage(gateway: gateway),
                ),
              ),
              child: const Text('打开券中心'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开券中心'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已使用'));
    await tester.pumpAndSettle();

    expect(gateway.statuses, [
      UserCouponStatus.available,
      UserCouponStatus.used,
    ]);
    expect(find.byKey(const ValueKey('coupon-card-2')), findsOneWidget);
    final usedCard = tester.widget<Container>(
      find.byKey(const ValueKey('coupon-card-2')),
    );
    final usedCardDecoration = usedCard.decoration as BoxDecoration;
    expect(usedCardDecoration.color, Colors.white);
    expect(usedCardDecoration.border?.top.color, const Color(0xFFE5E7EB));
    final usedAmountPanel = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('coupon-card-amount-2')),
    );
    expect(usedAmountPanel.color, const Color(0xFFD1D5DB));
    expect(find.byKey(const ValueKey('coupon-expand-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('coupon-card-2')));
    await tester.pumpAndSettle();
    expect(find.text('我的优惠券'), findsOneWidget);
  });

  testWidgets('首屏错误可重试，下拉刷新重新加载列表和统计', (tester) async {
    final gateway = _CouponGateway(
      responses: {
        UserCouponStatus.available: Future.value([_coupon(1)]),
      },
    )..listError = StateError('offline');

    await tester.pumpWidget(
      MaterialApp(home: CouponCenterPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    expect(find.text('优惠券加载失败'), findsOneWidget);

    gateway.listError = null;
    await tester.tap(find.byKey(const ValueKey('coupon-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coupon-card-1')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('coupon-list')),
      const Offset(0, 320),
    );
    await tester.pumpAndSettle();
    expect(gateway.statuses, hasLength(3));
    expect(gateway.countCalls, 3);
  });
}

UserCoupon _coupon(
  int id, {
  UserCouponStatus status = UserCouponStatus.available,
  CouponType type = CouponType.fullReduction,
  double discount = 20,
  double minAmount = 100,
  String name = '夏日优惠券',
  String? description,
}) {
  return UserCoupon(
    id: id,
    userId: 7,
    couponId: 10 + id,
    status: status,
    validFrom: DateTime.utc(2026, 7, 1, 12),
    validUntil: DateTime.utc(2026, 7, 31, 12),
    createdAt: DateTime.utc(2026, 6, 25, 12),
    rule: CouponRule(
      id: 10 + id,
      name: name,
      description: description,
      type: type,
      scope: CouponScope.all,
      status: 'ACTIVE',
      discountValue: discount,
      minAmount: minAmount,
      validFrom: DateTime.utc(2026, 7, 1, 12),
      validUntil: DateTime.utc(2026, 7, 31, 12),
      canStack: false,
      isEnabled: true,
    ),
  );
}

class _CouponGateway implements CouponGateway {
  _CouponGateway({
    required this.responses,
    this.counts = const CouponCounts(available: 0, used: 0, expired: 0),
  });

  final Map<UserCouponStatus, Future<List<UserCoupon>>> responses;
  final CouponCounts counts;
  final List<UserCouponStatus> statuses = [];
  Object? listError;
  Object? countError;
  int countCalls = 0;

  @override
  Future<List<UserCoupon>> loadCoupons(UserCouponStatus status) async {
    statuses.add(status);
    if (listError case final error?) throw error;
    return responses[status] ?? const [];
  }

  @override
  Future<CouponCounts> loadCounts() async {
    countCalls += 1;
    if (countError case final error?) throw error;
    return counts;
  }
}
