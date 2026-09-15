import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/pages/wallet_withdrawal_page.dart';

void main() {
  testWidgets('全部提现使用可用范围，提交前确认脱敏信息并防重复', (tester) async {
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(home: WalletWithdrawalPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('wallet-withdraw-all')));
    await tester.enterText(
      find.byKey(const ValueKey('wallet-withdraw-account')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wallet-withdraw-name')),
      '测试用户',
    );
    await tester.tap(find.byKey(const ValueKey('wallet-withdraw-submit')));
    await tester.pumpAndSettle();

    expect(find.text('提现金额：¥80.00'), findsOneWidget);
    expect(find.textContaining('us***om'), findsOneWidget);
    expect(find.textContaining('测***'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-withdraw-confirm')));
    await tester.pumpAndSettle();
    expect(gateway.requests, hasLength(1));
    expect(find.text('提现详情'), findsOneWidget);
  });
}

class _Gateway implements WalletGateway {
  final List<CreateWalletWithdrawal> requests = [];
  @override
  Future<WalletWithdrawalConfig> loadWithdrawalConfig() async =>
      const WalletWithdrawalConfig(
        enabled: true,
        availableBalance: 100,
        minAmount: 1,
        maxAmountPerRequest: 90,
        remainingDailyAmount: 80,
        hasActiveWithdrawal: false,
      );
  @override
  Future<WalletWithdrawal> createWithdrawal(
    CreateWalletWithdrawal request,
  ) async {
    requests.add(request);
    return _withdrawal;
  }

  @override
  Future<WalletWithdrawal> loadWithdrawal(int id) async => _withdrawal;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _withdrawal = WalletWithdrawal(
  id: 1,
  withdrawalNo: 'W20260730001',
  amount: 80,
  status: WalletWithdrawalStatus.pendingReview,
  payeeAccountMasked: 'us***om',
  payeeNameMasked: '测***',
  createdAt: DateTime.utc(2026, 7, 30),
  updatedAt: DateTime.utc(2026, 7, 30),
);
