import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/medical_orders/domain/medical_order_models.dart';
import 'package:pet_hospital_flutter/features/medical_orders/presentation/pages/medical_order_page.dart';

import 'support/wp11_viewports.dart';

void main() {
  testWidgets('请求未完成时显示首屏加载态', (tester) async {
    final page = Completer<MedicalOrderPage>();
    final gateway = _MedicalOrderGateway(page: page.future);

    await tester.pumpWidget(
      MaterialApp(home: MedicalOrderListPage(gateway: gateway)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    page.complete(_page(const []));
    await tester.pumpAndSettle();
    expect(find.text('暂无医疗服务订单'), findsOneWidget);
  });

  testWidgets('医疗订单使用一体化渐变、主题标题和紧凑卡片', (tester) async {
    final gateway = _MedicalOrderGateway(
      page: Future.value(_page([_order(1, avatarUrl: null)])),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MedicalOrderListPage(gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('medical-order-gradient-background')),
    );
    final backgroundDecoration = background.decoration as BoxDecoration;
    expect((backgroundDecoration.gradient! as LinearGradient).colors, const [
      Color(0xFFDEE9FF),
      Color(0xFFFAFBFF),
    ]);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(find.text('医疗服务订单'));
    expect(appBar.backgroundColor, Colors.transparent);
    expect(title.style?.color, AppColors.primary);

    final card = tester.widget<Material>(
      find.byKey(const ValueKey('medical-order-card-1')),
    );
    final cardShape = card.shape! as RoundedRectangleBorder;
    expect(card.color, Colors.white);
    expect(cardShape.side.color, AppColors.border);
    expect(cardShape.borderRadius, BorderRadius.circular(8));

    final status = tester.widget<Container>(
      find.byKey(const ValueKey('medical-order-status-1')),
    );
    expect((status.decoration as BoxDecoration).color, const Color(0xFF059669));
    final price = tester.widget<Text>(find.text('¥39.90'));
    expect(price.style?.color, AppColors.primary);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('medical-order-avatar-fallback-1')),
      ),
      const Size.square(52),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('医疗订单空态使用与订单页一致的图标层级', (tester) async {
    final gateway = _MedicalOrderGateway(page: Future.value(_page(const [])));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MedicalOrderListPage(gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无医疗服务订单'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('medical-order-state-icon-surface')),
      findsOneWidget,
    );
    expect(find.textContaining('订单会显示在这里'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in wp11Viewports) {
    testWidgets('医疗订单在 ${viewport.label} 展示 RN 核心字段和金额', (tester) async {
      configureWp11Viewport(tester, viewport);
      final gateway = _MedicalOrderGateway(
        page: Future.value(
          _page([
            _order(
              1,
              doctorName: '一位姓名特别长但仍然不会挤压状态与金额的宠物医院医生',
              avatarUrl: null,
            ),
          ]),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: wp11TextScaleBuilder(viewport.textScale),
          home: MedicalOrderListPage(gateway: gateway),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('医疗服务订单'), findsOneWidget);
      expect(find.textContaining('一位姓名特别长'), findsOneWidget);
      expect(find.text('图文咨询'), findsOneWidget);
      expect(find.text('30 分钟'), findsOneWidget);
      expect(find.text('¥39.90'), findsOneWidget);
      expect(find.text('已支付'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('medical-order-avatar-fallback-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('首屏错误可重试并进入明确空态', (tester) async {
    final gateway = _MedicalOrderGateway(page: Future.value(_page(const [])))
      ..error = StateError('offline');

    await tester.pumpWidget(
      MaterialApp(home: MedicalOrderListPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    expect(find.text('医疗订单加载失败'), findsOneWidget);

    gateway.error = null;
    await tester.tap(find.byKey(const ValueKey('medical-order-retry')));
    await tester.pumpAndSettle();

    expect(find.text('暂无医疗服务订单'), findsOneWidget);
    expect(gateway.calls, 2);
  });

  testWidgets('未知状态和网络头像失败均稳定降级', (tester) async {
    final gateway = _MedicalOrderGateway(
      page: Future.value(
        _page([
          _order(
            2,
            status: MedicalOrderStatus.unknown,
            avatarUrl: 'https://invalid.test/avatar.png',
          ),
        ]),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: MedicalOrderListPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('状态未知'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('medical-order-avatar-fallback-2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

MedicalOrderPage _page(List<MedicalServiceOrder> items) {
  return MedicalOrderPage(
    items: items,
    total: items.length,
    page: 1,
    pageSize: 20,
    totalPages: items.isEmpty ? 0 : 1,
  );
}

MedicalServiceOrder _order(
  int id, {
  String doctorName = '李医生',
  String? avatarUrl,
  MedicalOrderStatus status = MedicalOrderStatus.paid,
}) {
  return MedicalServiceOrder(
    id: id,
    orderNo: 'CHAT20260725$id',
    userId: 7,
    doctorId: 3,
    serviceItemId: 5,
    durationMinutes: 30,
    amount: 39.9,
    status: status,
    createdAt: DateTime(2026, 7, 25, 9, 5),
    updatedAt: DateTime(2026, 7, 25, 9, 6),
    doctor: MedicalOrderDoctor(id: 3, name: doctorName, avatarUrl: avatarUrl),
    serviceItem: const MedicalOrderServiceItem(
      id: 5,
      name: '图文咨询',
      durationMinutes: 30,
      price: 42.5,
    ),
  );
}

class _MedicalOrderGateway implements MedicalOrderGateway {
  _MedicalOrderGateway({required this.page});

  final Future<MedicalOrderPage> page;
  Object? error;
  int calls = 0;

  @override
  Future<MedicalOrderPage> loadOrders([
    MedicalOrderQuery query = const MedicalOrderQuery(),
  ]) async {
    calls += 1;
    if (error case final value?) throw value;
    return page;
  }
}
