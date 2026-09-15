import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/pages/wallet_withdrawal_records_page.dart';

void main() {
  testWidgets('提现记录展示脱敏信息和业务状态并可打开详情', (tester) async {
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WalletWithdrawalRecordsPage(gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('wallet-withdrawal-records-gradient-background'),
      ),
      findsOneWidget,
    );
    expect(find.text('支付宝提现'), findsOneWidget);
    expect(find.text('转账中'), findsOneWidget);
    expect(find.textContaining('13***00'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wallet-withdrawal-status-tabs')),
      findsOneWidget,
    );
    for (final filter in const <(String, WalletWithdrawalStatus)>[
      ('审核中', WalletWithdrawalStatus.pendingReview),
      ('已通过', WalletWithdrawalStatus.processing),
      ('已拒绝', WalletWithdrawalStatus.rejected),
      ('已到账', WalletWithdrawalStatus.succeeded),
    ]) {
      await tester.tap(
        find.byKey(ValueKey('wallet-withdrawal-status-${filter.$1}')),
      );
      await tester.pumpAndSettle();
      expect(gateway.statuses.last, filter.$2);
    }
    await tester.tap(find.byKey(const ValueKey('wallet-withdrawal-record-1')));
    await tester.pumpAndSettle();
    expect(find.text('提现详情'), findsOneWidget);
    expect(find.text('W20260730001'), findsOneWidget);
  });
}

class _Gateway implements WalletGateway {
  final List<WalletWithdrawalStatus?> statuses = [];
  final record = WalletWithdrawal(
    id: 1,
    withdrawalNo: 'W20260730001',
    amount: 10,
    status: WalletWithdrawalStatus.processing,
    payeeAccountMasked: '13***00',
    payeeNameMasked: '张*',
    createdAt: DateTime.utc(2026, 7, 30),
    updatedAt: DateTime.utc(2026, 7, 30),
  );
  @override
  Future<WalletWithdrawalPageResult> loadWithdrawals({
    int page = 1,
    int pageSize = 10,
    WalletWithdrawalStatus? status,
  }) async {
    statuses.add(status);
    return WalletWithdrawalPageResult(
      items: [record],
      total: 1,
      page: 1,
      pageSize: 10,
    );
  }

  @override
  Future<WalletWithdrawal> loadWithdrawal(int id) async => record;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
