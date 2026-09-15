import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/domain/checkout_models.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';
import 'package:pet_hospital_flutter/features/mall/payment/presentation/payment_controller.dart';
import 'package:pet_hospital_flutter/features/mall/payment/presentation/widgets/payment_sheet.dart';

void main() {
  testWidgets('支付弹窗在 iPhone 尺寸下保持完整层级', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PaymentController(
      checkoutGateway: _CheckoutGateway(),
      orderGateway: _OrderGateway(),
      paymentGateway: _PaymentGateway(),
      delay: (_) async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showPaymentSheet(
                  context,
                  controller: controller,
                  order: _order(),
                ),
                child: const Text('打开支付'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开支付'));
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(find.text('选择支付方式'), findsOneWidget);
    expect(find.text('支付方式'), findsOneWidget);
    expect(find.text('支付宝 App 安全支付'), findsOneWidget);
    expect(find.text('暂未开放'), findsOneWidget);
    expect(find.text('确认支付 ¥50.00'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-summary')), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/payment_sheet_widget.png'),
    );
  });
}

ShopOrder _order() {
  return const ShopOrder(
    id: 12,
    orderNo: 'ORD202607260001',
    status: ShopOrderStatus.pending,
    totalAmount: 50,
    originalAmount: 50,
    couponDiscount: 0,
    items: [],
  );
}

class _CheckoutGateway implements CheckoutGateway {
  @override
  Future<double> loadWalletBalance() async => 10000;

  @override
  Future<CheckoutResult> createOrder(CreateOrderInput input) =>
      throw UnimplementedError();

  @override
  Future<OrderPreview> preview(List<CheckoutItem> items, {int? userCouponId}) =>
      throw UnimplementedError();
}

class _OrderGateway implements OrderGateway {
  @override
  Future<ShopOrder> loadOrder(int orderId) async => _order();

  @override
  Future<OrderPage> loadOrders(OrderQuery query) => throw UnimplementedError();

  @override
  Future<ShopOrder> cancelOrder(int orderId, {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<ShopOrder> confirmOrder(int orderId) => throw UnimplementedError();

  @override
  Future<OrderPayment> payOrder(int orderId, PaymentChannel channel) =>
      throw UnimplementedError();
}

class _PaymentGateway implements PaymentGateway {
  @override
  Future<PaymentSdkResult> pay(String orderInfo) async =>
      const PaymentSdkResult(status: PaymentSdkStatus.success);
}
