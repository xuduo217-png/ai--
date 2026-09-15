import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/wallet_withdrawal_controller.dart';

void main() {
  test('提交失败重试复用稳定 UUID 幂等键，成功后保留结果', () async {
    final gateway = _Gateway();
    final controller = WalletWithdrawalController(gateway);
    gateway.fail = true;
    await controller.submit(
      amount: '10.00',
      alipayAccount: 'user@example.com',
      payeeRealName: '测试用户',
    );
    gateway.fail = false;
    final result = await controller.submit(
      amount: '10.00',
      alipayAccount: 'user@example.com',
      payeeRealName: '测试用户',
    );

    expect(gateway.requests, hasLength(2));
    expect(
      gateway.requests[0].idempotencyKey,
      gateway.requests[1].idempotencyKey,
    );
    expect(
      gateway.requests.first.idempotencyKey,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(result?.status, WalletWithdrawalStatus.pendingReview);
    expect(controller.submitting, isFalse);
  });
}

class _Gateway implements WalletGateway {
  bool fail = false;
  final List<CreateWalletWithdrawal> requests = [];
  @override
  Future<WalletWithdrawal> createWithdrawal(
    CreateWalletWithdrawal request,
  ) async {
    requests.add(request);
    if (fail) throw StateError('网络失败');
    return WalletWithdrawal(
      id: 1,
      withdrawalNo: 'W20260730001',
      amount: 10,
      status: WalletWithdrawalStatus.pendingReview,
      payeeAccountMasked: 'us***om',
      payeeNameMasked: '测***',
      createdAt: DateTime.utc(2026, 7, 30),
      updatedAt: DateTime.utc(2026, 7, 30),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
