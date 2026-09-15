import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/domain/checkout_models.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';
import 'package:pet_hospital_flutter/features/mall/payment/presentation/payment_controller.dart';

void main() {
  test('微信支付保持不可用且不调用后端或 SDK', () async {
    final orderGateway = _OrderGateway();
    final paymentGateway = _PaymentGateway();
    final controller = _controller(
      orderGateway: orderGateway,
      paymentGateway: paymentGateway,
    );

    final result = await controller.submit(
      order: _order(),
      channel: PaymentChannel.wechat,
    );

    expect(result.status, PaymentFlowStatus.unavailable);
    expect(orderGateway.payCalls, isEmpty);
    expect(paymentGateway.calls, isEmpty);
  });

  test('余额不足时禁止提交', () async {
    final checkoutGateway = _CheckoutGateway(balance: 19.99);
    final orderGateway = _OrderGateway();
    final controller = _controller(
      checkoutGateway: checkoutGateway,
      orderGateway: orderGateway,
    );
    await controller.loadWalletBalance();

    final result = await controller.submit(
      order: _order(total: 20),
      channel: PaymentChannel.balance,
    );

    expect(result.status, PaymentFlowStatus.insufficientBalance);
    expect(orderGateway.payCalls, isEmpty);
  });

  test('余额支付以后端返回的已支付订单为准', () async {
    final orderGateway = _OrderGateway(
      payment: OrderPayment(order: _order(status: ShopOrderStatus.paid)),
    );
    final controller = _controller(orderGateway: orderGateway);
    await controller.loadWalletBalance();

    final result = await controller.submit(
      order: _order(),
      channel: PaymentChannel.balance,
    );

    expect(result.status, PaymentFlowStatus.success);
    expect(orderGateway.payCalls, [PaymentChannel.balance]);
    expect(orderGateway.loadCalls, 0);
  });

  test('支付宝取消和网络异常均保留订单且不误判成功', () async {
    for (final sdkStatus in [
      PaymentSdkStatus.cancelled,
      PaymentSdkStatus.networkError,
    ]) {
      final orderGateway = _OrderGateway();
      final paymentGateway = _PaymentGateway(status: sdkStatus);
      final controller = _controller(
        orderGateway: orderGateway,
        paymentGateway: paymentGateway,
      );

      final result = await controller.submit(
        order: _order(),
        channel: PaymentChannel.alipay,
        initialPayment: _alipayPayment(),
      );

      expect(
        result.status,
        sdkStatus == PaymentSdkStatus.cancelled
            ? PaymentFlowStatus.cancelled
            : PaymentFlowStatus.networkError,
      );
      expect(orderGateway.loadCalls, 0);
      expect(orderGateway.payCalls, isEmpty);
      expect(controller.loading, isFalse);
    }
  });

  test('支付宝 SDK 成功仅作参考，轮询服务端后才返回成功', () async {
    final orderGateway = _OrderGateway(
      confirmations: [
        _order(status: ShopOrderStatus.pending),
        _order(status: ShopOrderStatus.pending),
        _order(status: ShopOrderStatus.paid),
      ],
    );
    final delays = <Duration>[];
    final controller = _controller(
      orderGateway: orderGateway,
      delay: (duration) async => delays.add(duration),
    );

    final result = await controller.submit(
      order: _order(),
      channel: PaymentChannel.alipay,
      initialPayment: _alipayPayment(),
    );

    expect(result.status, PaymentFlowStatus.success);
    expect(orderGateway.loadCalls, 3);
    expect(delays, [
      PaymentController.confirmationInterval,
      PaymentController.confirmationInterval,
    ]);
  });

  test('服务端五次均未确认时返回处理中并保留订单', () async {
    final orderGateway = _OrderGateway(
      confirmations: List.generate(
        PaymentController.confirmationAttempts,
        (_) => _order(),
      ),
    );
    var delayCalls = 0;
    final controller = _controller(
      orderGateway: orderGateway,
      paymentGateway: _PaymentGateway(status: PaymentSdkStatus.processing),
      delay: (_) async => delayCalls += 1,
    );

    final result = await controller.submit(
      order: _order(),
      channel: PaymentChannel.alipay,
      initialPayment: _alipayPayment(),
    );

    expect(result.status, PaymentFlowStatus.processing);
    expect(orderGateway.loadCalls, PaymentController.confirmationAttempts);
    expect(delayCalls, PaymentController.confirmationAttempts - 1);
  });

  test('单次查询异常不会中断后续服务端确认', () async {
    final orderGateway = _OrderGateway(
      confirmationResults: [
        StateError('临时网络错误'),
        _order(status: ShopOrderStatus.shipped),
      ],
    );
    final controller = _controller(
      orderGateway: orderGateway,
      delay: (_) async {},
    );

    final result = await controller.submit(
      order: _order(),
      channel: PaymentChannel.alipay,
      initialPayment: _alipayPayment(),
    );

    expect(result.status, PaymentFlowStatus.success);
    expect(orderGateway.loadCalls, 2);
  });

  test('支付宝参数缺失和 SDK 失败均返回失败并保留后端订单', () async {
    final missingParamsGateway = _OrderGateway(
      payment: OrderPayment(order: _order()),
    );
    final missingResult = await _controller(
      orderGateway: missingParamsGateway,
    ).submit(order: _order(), channel: PaymentChannel.alipay);
    expect(missingResult.status, PaymentFlowStatus.failed);
    expect(missingResult.message, contains('未返回'));

    final sdkFailure =
        await _controller(
          paymentGateway: _PaymentGateway(
            status: PaymentSdkStatus.failed,
            memo: '用户账户受限',
          ),
        ).submit(
          order: _order(),
          channel: PaymentChannel.alipay,
          initialPayment: _alipayPayment(),
        );
    expect(sdkFailure.status, PaymentFlowStatus.failed);
    expect(sdkFailure.message, '用户账户受限');
  });
}

PaymentController _controller({
  _CheckoutGateway? checkoutGateway,
  _OrderGateway? orderGateway,
  _PaymentGateway? paymentGateway,
  PaymentDelay? delay,
}) {
  return PaymentController(
    checkoutGateway: checkoutGateway ?? _CheckoutGateway(balance: 100),
    orderGateway: orderGateway ?? _OrderGateway(),
    paymentGateway: paymentGateway ?? _PaymentGateway(),
    delay: delay ?? (_) async {},
  );
}

ShopOrder _order({
  ShopOrderStatus status = ShopOrderStatus.pending,
  double total = 20,
}) {
  return ShopOrder(
    id: 7,
    orderNo: 'ORDER-7',
    status: status,
    totalAmount: total,
    originalAmount: total,
    couponDiscount: 0,
    items: const [],
  );
}

OrderPayment _alipayPayment() {
  return OrderPayment(
    order: _order(),
    paymentParams: const {'alipayOrderString': 'signed-order-info'},
  );
}

class _PaymentGateway implements PaymentGateway {
  _PaymentGateway({this.status = PaymentSdkStatus.success, this.memo = ''});

  final PaymentSdkStatus status;
  final String memo;
  final List<String> calls = [];

  @override
  Future<PaymentSdkResult> pay(String orderInfo) async {
    calls.add(orderInfo);
    return PaymentSdkResult(status: status, memo: memo);
  }
}

class _CheckoutGateway implements CheckoutGateway {
  _CheckoutGateway({this.balance = 100});
  final double balance;

  @override
  Future<double> loadWalletBalance() async => balance;

  @override
  Future<CheckoutResult> createOrder(CreateOrderInput input) async =>
      throw UnimplementedError();

  @override
  Future<OrderPreview> preview(
    List<CheckoutItem> items, {
    int? userCouponId,
  }) async => throw UnimplementedError();
}

class _OrderGateway implements OrderGateway {
  _OrderGateway({
    OrderPayment? payment,
    List<ShopOrder> confirmations = const [],
    List<Object>? confirmationResults,
  }) : payment = payment ?? _alipayPayment(),
       confirmationResults = confirmationResults ?? confirmations;

  final OrderPayment payment;
  final List<Object> confirmationResults;
  final List<PaymentChannel> payCalls = [];
  int loadCalls = 0;

  @override
  Future<OrderPayment> payOrder(int orderId, PaymentChannel channel) async {
    payCalls.add(channel);
    return payment;
  }

  @override
  Future<ShopOrder> loadOrder(int orderId) async {
    final index = loadCalls;
    loadCalls += 1;
    final result = index < confirmationResults.length
        ? confirmationResults[index]
        : _order();
    if (result is Error) throw result;
    if (result is Exception) throw result;
    return result as ShopOrder;
  }

  @override
  Future<ShopOrder> cancelOrder(int orderId, {String? reason}) async =>
      throw UnimplementedError();

  @override
  Future<ShopOrder> confirmOrder(int orderId) async =>
      throw UnimplementedError();

  @override
  Future<OrderPage> loadOrders(OrderQuery query) async =>
      throw UnimplementedError();
}
