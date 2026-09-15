import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/pages/wallet_transactions_page.dart';

void main() {
  testWidgets('交易页透传类型和来源筛选并显示提现业务状态', (tester) async {
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WalletTransactionsPage(
          gateway: gateway,
          onOrderDetail: (_) async {},
          onWithdrawalDetail: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('wallet-transactions-gradient-background')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wallet-type-filter-tabs')),
      findsOneWidget,
    );
    expect(find.text('审核中'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-withdrawal-9')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-type-支出')));
    await tester.pumpAndSettle();
    expect(gateway.queries.last.type, WalletTransactionType.expense);
    expect(
      find.byKey(const ValueKey('wallet-related-type-filter')),
      findsOneWidget,
    );
    expect(find.text('全部来源'), findsOneWidget);
  });

  test('交易时间语义保持稳定', () {
    final now = DateTime(2026, 7, 30, 12);
    expect(
      formatWalletTransactionTime(DateTime(2026, 7, 30, 1), now: now),
      '今天',
    );
    expect(
      formatWalletTransactionTime(DateTime(2026, 7, 29, 23), now: now),
      '昨天',
    );
    expect(formatWalletTransactionTime(DateTime(2026, 7, 25), now: now), '5天前');
  });
}

class _Gateway implements WalletGateway {
  final List<WalletTransactionQuery> queries = [];
  @override
  Future<WalletTransactionPage> loadTransactions(
    WalletTransactionQuery query,
  ) async {
    queries.add(query);
    return WalletTransactionPage(
      items: [
        WalletTransaction(
          id: 1,
          userId: 7,
          type: WalletTransactionType.expense,
          amount: 10,
          balanceBefore: 20,
          balanceAfter: 10,
          relatedType: WalletRelatedType.withdraw,
          relatedId: 9,
          status: WalletTransactionStatus.pending,
          withdrawalStatus: WalletWithdrawalStatus.pendingReview,
          withdrawalNo: 'W20260730001',
          createdAt: DateTime.utc(2026, 7, 30),
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
