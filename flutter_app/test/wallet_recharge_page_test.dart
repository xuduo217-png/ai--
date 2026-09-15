import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/pages/wallet_recharge_page.dart';

void main() {
  testWidgets('展示余额可提现规则，预设金额经确认后发起支付宝支付', (tester) async {
    final walletGateway = _WalletGateway();
    final paymentGateway = _PaymentGateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WalletRechargePage(
          gateway: walletGateway,
          paymentGateway: paymentGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(
      find.byKey(const ValueKey('wallet-recharge-title')),
    );
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.foregroundColor, AppColors.ink);
    expect(appBar.centerTitle, isTrue);
    expect(title.style?.color, AppColors.ink);
    expect(
      find.byKey(const ValueKey('wallet-recharge-gradient-background')),
      findsOneWidget,
    );
    expect(find.text('充值到账余额可用于消费或提现'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-recharge-preset-50.0')));
    await tester.pump();
    final selectedPreset = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('wallet-recharge-preset-50.0')),
    );
    expect(selectedPreset.selected, isTrue);
    expect(selectedPreset.selectedColor, const Color(0xFFE7EEFF));
    await tester.tap(find.byKey(const ValueKey('wallet-recharge-submit')));
    await tester.pumpAndSettle();
    expect(find.text('将通过支付宝充值 ¥50.00'), findsOneWidget);
    final cancelButton = find.byKey(const ValueKey('wallet-recharge-cancel'));
    final confirmButton = find.byKey(const ValueKey('wallet-recharge-confirm'));
    expect(
      tester.getCenter(cancelButton).dy,
      tester.getCenter(confirmButton).dy,
    );
    expect(
      tester.getCenter(cancelButton).dx,
      lessThan(tester.getCenter(confirmButton).dx),
    );
    expect(tester.getSize(confirmButton).width, lessThan(160));
    await tester.tap(find.text('去支付'));
    await tester.pumpAndSettle();

    expect(walletGateway.requests.single.amount, '50.00');
    expect(paymentGateway.calls, ['signed-order-info']);
    expect(find.text('已取消支付'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拒绝超出服务端配置范围的充值金额', (tester) async {
    final walletGateway = _WalletGateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WalletRechargePage(
          gateway: walletGateway,
          paymentGateway: _PaymentGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('wallet-recharge-amount')),
      '0.50',
    );
    await tester.tap(find.byKey(const ValueKey('wallet-recharge-submit')));
    await tester.pump();

    expect(find.textContaining('单次充值金额为'), findsOneWidget);
    expect(walletGateway.requests, isEmpty);
  });

  testWidgets('窄屏下充值页面布局不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WalletRechargePage(
          gateway: _WalletGateway(),
          paymentGateway: _PaymentGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('钱包充值'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wallet-recharge-submit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _WalletGateway implements WalletGateway {
  final List<CreateWalletRecharge> requests = [];

  @override
  Future<WalletRechargeConfig> loadRechargeConfig() async =>
      const WalletRechargeConfig(
        enabled: true,
        minAmount: 1,
        maxAmount: 50000,
        presets: [10, 50, 100, 200],
      );

  @override
  Future<WalletRecharge> createRecharge(CreateWalletRecharge request) async {
    requests.add(request);
    return WalletRecharge(
      id: 7,
      rechargeNo: 'RC20260731001',
      amount: double.parse(request.amount),
      status: WalletRechargeStatus.pending,
      paymentNo: 'PAY20260731001',
      alipayOrderString: 'signed-order-info',
      createdAt: DateTime.utc(2026, 7, 31, 9),
      updatedAt: DateTime.utc(2026, 7, 31, 9),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PaymentGateway implements PaymentGateway {
  final List<String> calls = [];

  @override
  Future<PaymentSdkResult> pay(String orderInfo) async {
    calls.add(orderInfo);
    return const PaymentSdkResult(status: PaymentSdkStatus.cancelled);
  }
}
