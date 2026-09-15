import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/wallet_recharge_controller.dart';

void main() {
  test('支付宝 SDK 成功后仍轮询服务端，只有充值单 succeeded 才算到账', () async {
    final walletGateway = _WalletGateway(
      confirmations: [
        _recharge(),
        _recharge(),
        _recharge(status: WalletRechargeStatus.succeeded),
      ],
    );
    final paymentGateway = _PaymentGateway();
    final delays = <Duration>[];
    final controller = WalletRechargeController(
      walletGateway,
      paymentGateway,
      delay: (duration) async => delays.add(duration),
    );

    final result = await controller.submit('50.00');

    expect(paymentGateway.calls, ['signed-order-info']);
    expect(walletGateway.loadCalls, 3);
    expect(delays, const [Duration(seconds: 2), Duration(seconds: 2)]);
    expect(result?.status, WalletRechargeFlowStatus.succeeded);
    expect(result?.recharge.status, WalletRechargeStatus.succeeded);
    expect(walletGateway.requests.single.amount, '50.00');
    expect(
      walletGateway.requests.single.idempotencyKey,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('用户取消支付宝后保留待确认充值单且不误报成功', () async {
    final walletGateway = _WalletGateway();
    final controller = WalletRechargeController(
      walletGateway,
      _PaymentGateway(status: PaymentSdkStatus.cancelled),
      delay: (_) async {},
    );

    final result = await controller.submit('10.00');

    expect(result?.status, WalletRechargeFlowStatus.cancelled);
    expect(result?.recharge.status, WalletRechargeStatus.pending);
    expect(walletGateway.loadCalls, 0);
  });

  test('创建请求失败后同金额重试复用幂等键，提交中拒绝重复发起', () async {
    final walletGateway = _WalletGateway()..failCreate = true;
    final paymentCompleter = Completer<PaymentSdkResult>();
    final paymentGateway = _PaymentGateway(completer: paymentCompleter);
    final controller = WalletRechargeController(
      walletGateway,
      paymentGateway,
      delay: (_) async {},
    );

    expect(await controller.submit('20.00'), isNull);
    walletGateway.failCreate = false;
    final activeSubmit = controller.submit('20.00');
    await Future<void>.delayed(Duration.zero);
    expect(await controller.submit('20.00'), isNull);
    paymentCompleter.complete(
      const PaymentSdkResult(status: PaymentSdkStatus.cancelled),
    );
    await activeSubmit;

    expect(walletGateway.requests, hasLength(2));
    expect(
      walletGateway.requests.first.idempotencyKey,
      walletGateway.requests.last.idempotencyKey,
    );
    expect(paymentGateway.calls, hasLength(1));
  });
}

WalletRecharge _recharge({
  WalletRechargeStatus status = WalletRechargeStatus.pending,
}) => WalletRecharge(
  id: 7,
  rechargeNo: 'RC20260731001',
  amount: 50,
  status: status,
  paymentNo: 'PAY20260731001',
  alipayOrderString: 'signed-order-info',
  paidAt: status == WalletRechargeStatus.succeeded
      ? DateTime.utc(2026, 7, 31, 9, 1)
      : null,
  createdAt: DateTime.utc(2026, 7, 31, 9),
  updatedAt: DateTime.utc(2026, 7, 31, 9, 1),
);

class _WalletGateway implements WalletGateway {
  _WalletGateway({List<WalletRecharge>? confirmations})
    : _confirmations = confirmations ?? [];

  final List<WalletRecharge> _confirmations;
  final List<CreateWalletRecharge> requests = [];
  bool failCreate = false;
  int loadCalls = 0;

  @override
  Future<WalletRecharge> createRecharge(CreateWalletRecharge request) async {
    requests.add(request);
    if (failCreate) throw StateError('网络失败');
    return _recharge();
  }

  @override
  Future<WalletRecharge> loadRecharge(int id) async {
    final value = _confirmations[loadCalls];
    loadCalls += 1;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PaymentGateway implements PaymentGateway {
  _PaymentGateway({this.status = PaymentSdkStatus.success, this.completer});

  final PaymentSdkStatus status;
  final Completer<PaymentSdkResult>? completer;
  final List<String> calls = [];

  @override
  Future<PaymentSdkResult> pay(String orderInfo) {
    calls.add(orderInfo);
    return completer?.future ?? Future.value(PaymentSdkResult(status: status));
  }
}
