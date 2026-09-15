import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/core/media/gallery_media_picker.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/domain/checkout_models.dart';
import 'package:pet_hospital_flutter/features/mall/order/data/after_sale_repository.dart';
import 'package:pet_hospital_flutter/features/mall/order/data/order_repository.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/after_sale_models.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/order/presentation/pages/after_sale_pages.dart';
import 'package:pet_hospital_flutter/features/mall/order/presentation/pages/order_detail_page.dart';
import 'package:pet_hospital_flutter/features/mall/order/presentation/pages/shipping_page.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';

void main() {
  test('买卖订单、无单号发货、补单号和售后使用统一接口 contract', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requests.add(request);
        final response = switch ((request.method, request.url.path)) {
          ('GET', '/shop/orders/sales') => {
            'code': 0,
            'data': [_orderJson(status: 'paid', viewRole: 'seller')],
            'pagination': {
              'total': 1,
              'page': 1,
              'pageSize': 20,
              'totalPages': 1,
            },
          },
          ('POST', '/shop/orders/1/ship') => {
            'code': 0,
            'data': _orderJson(status: 'shipped', viewRole: 'seller'),
          },
          ('PATCH', '/shop/orders/1/tracking') => {
            'code': 0,
            'data': _orderJson(
              status: 'shipped',
              viewRole: 'seller',
              trackingNumber: 'SF123456789',
            ),
          },
          ('GET', '/shop/orders/action-summary') => {
            'code': 0,
            'data': {
              'purchases': {'pendingReceipt': 2, 'afterSaleResult': 1},
              'sales': {'pendingShipment': 3, 'pendingAfterSale': 4},
            },
          },
          ('POST', '/shop/orders/1/after-sales') => {
            'code': 0,
            'data': {
              'id': 9,
              'afterSaleNo': 'AS20260730001',
              'orderId': 1,
              'status': 'pending_seller',
              'reasonCode': 'damaged',
              'refundAmount': 88,
              'viewRole': 'buyer',
              'availableActions': ['cancel_after_sale'],
            },
          },
          _ => throw StateError(
            'unexpected request ${request.method} ${request.url.path}',
          ),
        };
        return http.Response(
          jsonEncode(response),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async => 'token',
    );
    final orders = OrderRepository(client);
    final afterSales = AfterSaleRepository(client);

    final sales = await orders.loadOrders(
      const OrderQuery(
        viewRole: OrderViewRole.seller,
        afterSaleStatus: 'active',
      ),
    );
    final shipped = await orders.shipOrder(1);
    final tracked = await orders.updateTracking(
      1,
      trackingNumber: ' SF123456789 ',
    );
    final summary = await orders.loadActionSummary();
    final afterSale = await afterSales.createAfterSale(
      1,
      afterSaleType: AfterSaleType.refundOnly,
      items: const [AfterSaleRequestItem(lineKey: 'line-1', quantity: 1)],
      reasonCode: 'damaged',
      description: ' 外包装破损 ',
    );

    expect(requests.first.url.path, '/shop/orders/sales');
    expect(requests.first.url.queryParameters['afterSaleStatus'], 'active');
    expect(sales.items.single.viewRole, OrderViewRole.seller);
    expect(shipped.trackingNumber, isNull);
    expect(jsonDecode(requests[1].body)['trackingNumber'], isNull);
    expect(jsonDecode(requests[2].body)['trackingNumber'], 'SF123456789');
    expect(tracked.trackingNumber, 'SF123456789');
    expect(summary.purchaseCount, 2);
    expect(summary.salesCount, 7);
    expect(afterSale.id, 9);
    expect(afterSale.hasAction('cancel_after_sale'), isTrue);
    expect(jsonDecode(requests.last.body), {
      'afterSaleType': 'refund_only',
      'items': [
        {'lineKey': 'line-1', 'quantity': 1},
      ],
      'reasonCode': 'damaged',
      'description': '外包装破损',
      'evidenceUrls': <Object>[],
    });
  });

  testWidgets('卖家可不填物流单号确认发货', (tester) async {
    final gateway = _ShippingGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ShippingPage(
          order: _order(status: ShopOrderStatus.paid),
          gateway: gateway,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('confirm-shipping-button')));
    await tester.pumpAndSettle();

    expect(gateway.shippedOrderId, 1);
    expect(gateway.trackingNumber, isNull);
  });

  testWidgets('售后凭证使用统一相册选择器且原因不使用原生下拉', (tester) async {
    final pickerGateway = _RecordingGalleryGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ApplyAfterSalePage(
          order: _order(status: ShopOrderStatus.shipped),
          gateway: _AfterSaleGateway(),
          galleryMediaPicker: GalleryMediaPicker(gateway: pickerGateway),
        ),
      ),
    );

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.byKey(const ValueKey('after-sale-reason')));
    await tester.pumpAndSettle();
    expect(find.text('选择售后原因'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final addEvidence = find.byIcon(Icons.add_photo_alternate_outlined);
    await tester.drag(
      find.byKey(const ValueKey('after-sale-apply-form')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(addEvidence);
    await tester.pumpAndSettle();
    expect(pickerGateway.pickCalls, 1);
    expect(pickerGateway.options?.mediaType, GalleryMediaType.image);
    expect(pickerGateway.options?.maxCount, 9);
  });

  testWidgets('申请售后使用商城统一背景、分区和胶囊页签', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ApplyAfterSalePage(
          order: _order(status: ShopOrderStatus.shipped),
          gateway: _AfterSaleGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('after-sale-apply-gradient-background')),
    );
    final decoration = background.decoration as BoxDecoration;
    expect((decoration.gradient! as LinearGradient).colors, const [
      Color(0xFFDEE9FF),
      Color(0xFFFAFBFF),
    ]);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(find.byType(SegmentedButton<AfterSaleType>), findsNothing);
    expect(find.byKey(const ValueKey('after-sale-type-tabs')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('after-sale-type-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('after-sale-items-section')),
      findsOneWidget,
    );

    var selectedTab = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('after-sale-type-tab-surface-refund_only')),
    );
    expect(
      (selectedTab.decoration as BoxDecoration).color,
      const Color(0xFFE7EEFF),
    );

    await tester.tap(
      find.byKey(const ValueKey('after-sale-type-tab-return_refund')),
    );
    await tester.pumpAndSettle();

    selectedTab = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('after-sale-type-tab-surface-return_refund')),
    );
    expect(
      (selectedTab.decoration as BoxDecoration).color,
      const Color(0xFFE7EEFF),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('售后详情按订单详情样式分组并适配窄屏', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AfterSaleDetailPage(
          afterSaleId: 9,
          gateway: _DetailAfterSaleGateway(_afterSale()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('after-sale-status-waiting_handler_receipt')),
      findsOneWidget,
    );
    expect(find.text('等待确认收货'), findsOneWidget);
    expect(find.text('卖家处理'), findsWidgets);
    expect(find.text('商品损坏'), findsOneWidget);
    expect(find.text('damaged'), findsNothing);
    expect(
      find.byKey(const ValueKey('after-sale-section-售后申请')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('after-sale-section-退货信息')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SF-RETURN-001'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('after-sale-section-处理记录')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('买家提交退货'), findsOneWidget);
    expect(find.text('买家 · 2026-07-30 11:00'), findsOneWidget);
    expect(find.text('平台拒绝申请'), findsOneWidget);
    expect(find.text('platform_reject'), findsNothing);
    expect(find.text('取消售后'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('商城与个人商品订单均展示完整物流单号并可复制', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    for (final orderType in const ['normal', 'second_hand']) {
      final trackingNumber = orderType == 'normal'
          ? 'YT123456789'
          : 'SF123456789';
      final gateway = _OrderGateway(
        _order(
          status: ShopOrderStatus.shipped,
          orderType: orderType,
          trackingNumber: trackingNumber,
          availableActions: const [],
        ),
      );
      copied = null;

      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailPage(
            key: ValueKey(orderType),
            orderId: 1,
            gateway: gateway,
            checkoutGateway: _UnusedCheckoutGateway(),
            paymentGateway: _UnusedPaymentGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byTooltip('复制物流单号'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(trackingNumber), findsOneWidget);
      expect(find.text('快递公司'), findsNothing);
      await tester.tap(find.byTooltip('复制物流单号'));
      await tester.pump();
      expect(copied, trackingNumber, reason: 'orderType=$orderType');
      expect(find.text('物流单号已复制'), findsOneWidget);
    }
  });

  testWidgets('售后结束后详情入口移入信息区且底部操作保持同排', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = _order(
      status: ShopOrderStatus.shipped,
      availableActions: const [
        'confirm_receipt',
        'apply_after_sale',
        'view_after_sale',
      ],
      afterSaleSummary: const OrderAfterSaleSummary(
        id: 9,
        afterSaleNo: 'AS20260730001',
        status: 'closed',
        refundAmount: 88,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: OrderDetailPage(
          orderId: order.id,
          gateway: _OrderGateway(order),
          checkoutGateway: _UnusedCheckoutGateway(),
          paymentGateway: _UnusedPaymentGateway(),
          afterSaleGateway: _AfterSaleGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('重新申请售后'), findsOneWidget);
    expect(find.text('查看售后进度'), findsNothing);
    expect(
      tester.getCenter(find.text('确认收货')).dy,
      tester.getCenter(find.text('重新申请售后')).dy,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('order-after-sale-detail-button')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('查看售后详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, Object?> _orderJson({
  required String status,
  required String viewRole,
  String? trackingNumber,
}) => {
  'id': 1,
  'orderNo': 'SO20260730001',
  'orderType': 'second_hand',
  'status': status,
  'totalAmount': 88,
  'originalAmount': 88,
  'couponDiscount': 0,
  'trackingNumber': trackingNumber,
  'viewRole': viewRole,
  'availableActions': status == 'paid' ? ['ship'] : ['update_tracking'],
  'items': [
    {
      'productId': 2,
      'productName': '二手航空箱',
      'productImage': '/uploads/box.jpg',
      'quantity': 1,
      'price': 88,
    },
  ],
};

ShopOrder _order({
  required ShopOrderStatus status,
  String orderType = 'second_hand',
  String? trackingNumber,
  List<String> availableActions = const ['ship'],
  OrderAfterSaleSummary? afterSaleSummary,
}) => ShopOrder(
  id: 1,
  orderNo: 'SO20260730001',
  orderType: orderType,
  status: status,
  totalAmount: 88,
  originalAmount: 88,
  couponDiscount: 0,
  receiverName: '张三',
  receiverPhone: '13800000000',
  shippingAddress: '北京市朝阳区健康路 1 号',
  shippedAt: status == ShopOrderStatus.shipped ? DateTime(2026, 7, 30) : null,
  trackingNumber: trackingNumber,
  availableActions: availableActions,
  afterSaleSummary: afterSaleSummary,
  items: const [
    ShopOrderItem(
      productId: 2,
      productName: '二手航空箱',
      productImage: '',
      lineKey: 'line-1',
      paidAmount: 88,
      quantity: 1,
      price: 88,
    ),
  ],
);

OrderAfterSale _afterSale() => OrderAfterSale(
  id: 9,
  afterSaleNo: 'AS20260730001',
  orderId: 1,
  status: AfterSaleStatus.waitingHandlerReceipt,
  reasonCode: 'damaged',
  refundAmount: 88,
  description: '商品外包装破损，内部有明显划痕。',
  handlerDecision: 'approved',
  handlerReason: '同意退货，收到商品后退款。',
  returnRequired: true,
  returnAddress: '北京市朝阳区健康路 1 号',
  returnTrackingNumber: 'SF-RETURN-001',
  currentDeadlineAt: DateTime(2026, 8, 1, 18),
  availableActions: const ['cancel_after_sale'],
  order: _order(status: ShopOrderStatus.shipped, availableActions: const []),
  logs: [
    AfterSaleLog(
      id: 1,
      action: 'create',
      operatorType: 'buyer',
      description: '买家提交售后申请',
      createdAt: DateTime(2026, 7, 30, 9),
    ),
    AfterSaleLog(
      id: 2,
      action: 'seller_approve_return',
      operatorType: 'seller',
      description: '卖家同意退货',
      createdAt: DateTime(2026, 7, 30, 10),
    ),
    AfterSaleLog(
      id: 3,
      action: 'submit_return',
      operatorType: 'buyer',
      description: '买家已提交退货信息',
      createdAt: DateTime(2026, 7, 30, 11),
    ),
    AfterSaleLog(
      id: 4,
      action: 'platform_reject',
      operatorType: 'admin',
      description: '平台拒绝本次售后申请',
      createdAt: DateTime(2026, 7, 30, 12),
    ),
  ],
);

class _ShippingGateway implements SecondHandOrderGateway {
  int? shippedOrderId;
  String? trackingNumber;

  @override
  Future<ShopOrder> shipOrder(int orderId, {String? trackingNumber}) async {
    shippedOrderId = orderId;
    this.trackingNumber = trackingNumber;
    return _order(status: ShopOrderStatus.shipped);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _OrderGateway implements OrderGateway {
  _OrderGateway(this.order);

  final ShopOrder order;

  @override
  Future<ShopOrder> loadOrder(int orderId) async => order;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedCheckoutGateway implements CheckoutGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedPaymentGateway implements PaymentGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _AfterSaleGateway implements AfterSaleGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _DetailAfterSaleGateway implements AfterSaleGateway {
  _DetailAfterSaleGateway(this.afterSale);

  final OrderAfterSale afterSale;

  @override
  Future<OrderAfterSale> loadAfterSale(int afterSaleId) async => afterSale;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _RecordingGalleryGateway implements GalleryMediaPickerGateway {
  int pickCalls = 0;
  GalleryMediaPickerOptions? options;

  @override
  Future<bool> hasPermission(GalleryMediaPickerOptions options) async => true;

  @override
  Future<List<XFile>> pick(
    BuildContext context,
    GalleryMediaPickerOptions options,
  ) async {
    pickCalls += 1;
    this.options = options;
    return const [];
  }
}
