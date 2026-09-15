import 'package:flutter/foundation.dart';

import '../../checkout/domain/checkout_models.dart';
import '../../order/domain/order_models.dart';
import '../domain/payment_models.dart';

typedef PaymentDelay = Future<void> Function(Duration duration);

class PaymentController extends ChangeNotifier {
  PaymentController({
    required CheckoutGateway checkoutGateway,
    required OrderGateway orderGateway,
    required PaymentGateway paymentGateway,
    PaymentDelay? delay,
  }) : _checkoutGateway = checkoutGateway,
       _orderGateway = orderGateway,
       _paymentGateway = paymentGateway,
       _delay = delay ?? Future<void>.delayed;

  static const confirmationInterval = Duration(seconds: 2);
  static const confirmationAttempts = 5;

  final CheckoutGateway _checkoutGateway;
  final OrderGateway _orderGateway;
  final PaymentGateway _paymentGateway;
  final PaymentDelay _delay;

  bool loading = false;
  bool walletLoading = false;
  double walletBalance = 0;
  String? errorMessage;

  Future<void> loadWalletBalance() async {
    walletLoading = true;
    notifyListeners();
    try {
      walletBalance = await _checkoutGateway.loadWalletBalance();
      errorMessage = null;
    } catch (error) {
      walletBalance = 0;
      errorMessage = '$error';
    } finally {
      walletLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentFlowResult> submit({
    required ShopOrder order,
    required PaymentChannel channel,
    OrderPayment? initialPayment,
  }) async {
    if (channel == PaymentChannel.wechat) {
      return const PaymentFlowResult(PaymentFlowStatus.unavailable, '微信支付暂未开放');
    }
    if (channel == PaymentChannel.balance &&
        walletBalance < order.totalAmount) {
      return const PaymentFlowResult(
        PaymentFlowStatus.insufficientBalance,
        '余额不足，请选择其他支付方式',
      );
    }

    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (channel == PaymentChannel.balance) {
        final payment = await _orderGateway.payOrder(order.id, channel);
        if (payment.order.paid || await _confirmPaid(order.id)) {
          return const PaymentFlowResult(PaymentFlowStatus.success, '支付成功');
        }
        return const PaymentFlowResult(
          PaymentFlowStatus.processing,
          '支付结果确认中，请在订单详情查看最新状态',
        );
      }

      final payment = initialPayment?.alipayOrderString == null
          ? await _orderGateway.payOrder(order.id, channel)
          : initialPayment!;
      final orderInfo = payment.alipayOrderString;
      if (orderInfo == null) {
        return const PaymentFlowResult(
          PaymentFlowStatus.failed,
          '后端未返回可用的支付宝支付参数',
        );
      }

      final sdkResult = await _paymentGateway.pay(orderInfo);
      if (sdkResult.status == PaymentSdkStatus.cancelled) {
        return const PaymentFlowResult(
          PaymentFlowStatus.cancelled,
          '已取消支付，订单已保留',
        );
      }
      if (sdkResult.status == PaymentSdkStatus.networkError) {
        return const PaymentFlowResult(
          PaymentFlowStatus.networkError,
          '网络连接异常，请在订单详情确认支付结果',
        );
      }
      if (sdkResult.status == PaymentSdkStatus.failed) {
        return PaymentFlowResult(
          PaymentFlowStatus.failed,
          sdkResult.memo.trim().isEmpty ? '支付失败，订单已保留' : sdkResult.memo,
        );
      }

      if (await _confirmPaid(order.id)) {
        return const PaymentFlowResult(PaymentFlowStatus.success, '支付成功');
      }
      return const PaymentFlowResult(
        PaymentFlowStatus.processing,
        '支付结果确认中，请在订单详情查看最新状态',
      );
    } catch (error) {
      errorMessage = '$error';
      return PaymentFlowResult(
        PaymentFlowStatus.failed,
        errorMessage ?? '支付失败，订单已保留',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> _confirmPaid(int orderId) async {
    for (var attempt = 0; attempt < confirmationAttempts; attempt += 1) {
      try {
        final order = await _orderGateway.loadOrder(orderId);
        if (order.paid) return true;
      } catch (_) {
        // 单次轮询失败不终止支付状态确认。
      }
      if (attempt < confirmationAttempts - 1) {
        await _delay(confirmationInterval);
      }
    }
    return false;
  }
}
