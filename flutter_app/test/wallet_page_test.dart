import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/pages/wallet_page.dart';

import 'support/wp11_viewports.dart';

void main() {
  for (final viewport in wp11Viewports) {
    testWidgets('钱包首页在 ${viewport.label} 下长金额不溢出', (tester) async {
      configureWp11Viewport(tester, viewport);
      final gateway = _Gateway();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: wp11TextScaleBuilder(viewport.textScale),
          home: WalletPage(
            gateway: gateway,
            paymentGateway: _PaymentGateway(),
            onOrderDetail: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我的钱包'), findsOneWidget);
      expect(find.text('可用余额'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wallet-recharge-button')),
        findsOneWidget,
      );
      expect(find.text('待到账'), findsOneWidget);
      expect(find.text('累计二手收益'), findsOneWidget);
      expect(find.text('提现中'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('提现关闭时余额和明细可用，按钮禁用并展示原因', (tester) async {
    final gateway = _Gateway(enabled: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WalletPage(
          gateway: gateway,
          paymentGateway: _PaymentGateway(),
          onOrderDetail: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('wallet-withdraw-button')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('支付宝提现服务暂未开放'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-transactions-entry')));
    await tester.pumpAndSettle();
    expect(find.text('钱包明细'), findsWidgets);
  });

  testWidgets('从子页面返回后刷新钱包首页', (tester) async {
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WalletPage(
          gateway: gateway,
          paymentGateway: _PaymentGateway(),
          onOrderDetail: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(gateway.statsCalls, 1);
    await tester.tap(find.byKey(const ValueKey('wallet-transactions-entry')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(gateway.statsCalls, 2);
  });
}

class _PaymentGateway implements PaymentGateway {
  @override
  Future<PaymentSdkResult> pay(String orderInfo) async =>
      const PaymentSdkResult(status: PaymentSdkStatus.cancelled);
}

class _Gateway implements WalletGateway {
  _Gateway({this.enabled = true});
  final bool enabled;
  int statsCalls = 0;
  @override
  Future<WalletStats> loadStats() async {
    statsCalls++;
    return const WalletStats(
      availableBalance: 999999999999.99,
      pendingSettlement: 123456789,
      totalSecondHandIncome: 888888888888.88,
      withdrawalFrozenBalance: 88,
    );
  }

  @override
  Future<WalletWithdrawalConfig> loadWithdrawalConfig() async =>
      WalletWithdrawalConfig(
        enabled: enabled,
        availableBalance: 100,
        minAmount: 1,
        maxAmountPerRequest: 50000,
        remainingDailyAmount: 50000,
        hasActiveWithdrawal: false,
        unavailableReason: enabled ? null : '支付宝提现服务暂未开放',
      );
  @override
  Future<WalletTransactionPage> loadTransactions(
    WalletTransactionQuery query,
  ) async => const WalletTransactionPage(
    items: [],
    total: 0,
    page: 1,
    pageSize: 10,
    totalPages: 0,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
