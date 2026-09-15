import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../mall/order/domain/order_models.dart';
import '../../mall/payment/domain/payment_models.dart';
import '../../mall/payment/presentation/payment_controller.dart';
import '../../mall/payment/presentation/payment_sheet_session.dart';
import '../domain/charity_models.dart';
import 'charity_controller.dart';

typedef CharityPaymentIdempotencyKeyFactory = String Function();

class CharityPaymentController extends ChangeNotifier
    implements PaymentSheetSession {
  CharityPaymentController({
    required CharityDetailController detailController,
    required PaymentGateway paymentGateway,
    required this.amount,
    PaymentDelay? delay,
    CharityPaymentIdempotencyKeyFactory? idempotencyKeyFactory,
  }) : _detailController = detailController,
       _paymentGateway = paymentGateway,
       _delay = delay ?? Future<void>.delayed,
       _idempotencyKey = (idempotencyKeyFactory ?? _uuidV4)();

  static const confirmationInterval = Duration(seconds: 2);
  static const confirmationAttempts = 5;

  final CharityDetailController _detailController;
  final PaymentGateway _paymentGateway;
  final PaymentDelay _delay;
  final String _idempotencyKey;
  final double amount;

  @override
  bool loading = false;
  @override
  bool walletLoading = false;
  @override
  double walletBalance = 0;
  @override
  String? walletErrorMessage;

  @override
  Future<void> loadWalletBalance() async {
    walletLoading = true;
    walletErrorMessage = null;
    notifyListeners();
    try {
      walletBalance = await _detailController.loadWalletBalance();
    } catch (error) {
      walletErrorMessage = '$error';
    } finally {
      walletLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<PaymentFlowResult> submit(PaymentChannel channel) async {
    if (channel == PaymentChannel.wechat) {
      return const PaymentFlowResult(PaymentFlowStatus.unavailable, '微信支付暂未开放');
    }
    if (channel == PaymentChannel.balance && walletErrorMessage != null) {
      return const PaymentFlowResult(
        PaymentFlowStatus.unavailable,
        '余额加载失败，请重试',
      );
    }
    if (channel == PaymentChannel.balance && walletBalance < amount) {
      return const PaymentFlowResult(
        PaymentFlowStatus.insufficientBalance,
        '余额不足，请选择其他支付方式',
      );
    }

    loading = true;
    notifyListeners();
    try {
      if (channel == PaymentChannel.balance) {
        final donation = await _detailController.donate(amount);
        return PaymentFlowResult(PaymentFlowStatus.success, donation.message);
      }

      final payment = await _detailController.createDonationPayment(
        amount,
        _idempotencyKey,
      );
      final sdkResult = await _paymentGateway.pay(payment.alipayOrderString);
      if (sdkResult.status == PaymentSdkStatus.cancelled) {
        return const PaymentFlowResult(PaymentFlowStatus.cancelled, '已取消支付');
      }
      if (sdkResult.status == PaymentSdkStatus.networkError) {
        return const PaymentFlowResult(
          PaymentFlowStatus.networkError,
          '网络连接异常，请稍后在公益详情确认支付结果',
        );
      }
      if (sdkResult.status == PaymentSdkStatus.failed) {
        return PaymentFlowResult(
          PaymentFlowStatus.failed,
          sdkResult.memo.trim().isEmpty ? '支付失败，请稍后重试' : sdkResult.memo,
        );
      }

      final status = await _confirmPayment(payment.paymentNo);
      if (status.paid) {
        await _detailController.refresh();
        return const PaymentFlowResult(PaymentFlowStatus.success, '感谢您的爱心');
      }
      if (status.terminal) {
        return const PaymentFlowResult(
          PaymentFlowStatus.failed,
          '支付未完成，请重新发起捐款',
        );
      }
      return const PaymentFlowResult(
        PaymentFlowStatus.processing,
        '支付结果确认中，请稍后在公益详情查看最新状态',
      );
    } catch (error) {
      return PaymentFlowResult(PaymentFlowStatus.failed, '$error');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<CharityDonationPaymentStatus> _confirmPayment(String paymentNo) async {
    var latest = CharityDonationPaymentStatus.unknown;
    for (var attempt = 0; attempt < confirmationAttempts; attempt += 1) {
      try {
        latest = await _detailController.loadDonationPaymentStatus(paymentNo);
        if (latest.terminal) return latest;
      } catch (_) {
        // 单次查单失败不终止最终状态确认。
      }
      if (attempt < confirmationAttempts - 1) {
        await _delay(confirmationInterval);
      }
    }
    return latest;
  }
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
