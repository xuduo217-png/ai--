import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/pages/wallet_recharge_records_page.dart';

void main() {
  testWidgets('待确认充值可主动查单并更新为已到账', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WalletRechargeRecordsPage(gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(
      find.byKey(const ValueKey('wallet-recharge-records-title')),
    );
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.foregroundColor, AppColors.ink);
    expect(title.style?.color, AppColors.ink);
    expect(
      find.byKey(const ValueKey('wallet-recharge-records-gradient-background')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wallet-recharge-status-tabs')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wallet-recharge-record-list')),
      findsOneWidget,
    );
    expect(find.text('待确认'), findsWidgets);
    expect(find.text('+¥50.00'), findsOneWidget);
    await tester.tap(find.byTooltip('确认支付结果'));
    await tester.pumpAndSettle();

    expect(gateway.detailCalls, 1);
    expect(find.text('已到账'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('wallet-recharge-status-待确认')));
    await tester.pumpAndSettle();
    expect(gateway.statuses.last, WalletRechargeStatus.pending);
    await tester.tap(find.byKey(const ValueKey('wallet-recharge-status-已到账')));
    await tester.pumpAndSettle();
    expect(gateway.statuses.last, WalletRechargeStatus.succeeded);
    expect(tester.takeException(), isNull);
  });
}

class _Gateway implements WalletGateway {
  int detailCalls = 0;
  final List<WalletRechargeStatus?> statuses = [];

  @override
  Future<WalletRechargePageResult> loadRecharges({
    int page = 1,
    int pageSize = 10,
    WalletRechargeStatus? status,
  }) async {
    statuses.add(status);
    return WalletRechargePageResult(
      items: [_recharge(status: status ?? WalletRechargeStatus.pending)],
      total: 1,
      page: 1,
      pageSize: 10,
    );
  }

  @override
  Future<WalletRecharge> loadRecharge(int id) async {
    detailCalls += 1;
    return _recharge(status: WalletRechargeStatus.succeeded);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletRecharge _recharge({
  WalletRechargeStatus status = WalletRechargeStatus.pending,
}) => WalletRecharge(
  id: 7,
  rechargeNo: 'RC20260731001',
  amount: 50,
  status: status,
  paymentNo: 'PAY20260731001',
  paidAt: status == WalletRechargeStatus.succeeded
      ? DateTime.utc(2026, 7, 31, 9, 1)
      : null,
  createdAt: DateTime.utc(2026, 7, 31, 9),
  updatedAt: DateTime.utc(2026, 7, 31, 9, 1),
);
