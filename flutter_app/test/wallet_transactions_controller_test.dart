import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/wallet_transactions_controller.dart';

void main() {
  test('筛选切换忽略旧请求并透传类型与业务来源', () async {
    final gateway = _Gateway();
    final oldPage = Completer<WalletTransactionPage>();
    final newPage = Completer<WalletTransactionPage>();
    gateway.responses.addAll([oldPage.future, newPage.future]);
    final controller = WalletTransactionsController(gateway);

    final oldLoad = controller.changeFilters(
      type: WalletTransactionType.income,
    );
    final newLoad = controller.changeFilters(
      type: WalletTransactionType.expense,
      relatedType: WalletRelatedType.withdraw,
    );
    newPage.complete(_page([2]));
    await newLoad;
    oldPage.complete(_page([1]));
    await oldLoad;

    expect(controller.transactions.single.id, 2);
    expect(gateway.queries.last.type, WalletTransactionType.expense);
    expect(gateway.queries.last.relatedType, WalletRelatedType.withdraw);
  });

  test('加载更多防重复且保留首屏', () async {
    final gateway = _Gateway()
      ..responses.add(Future.value(_page([1], totalPages: 2)));
    final controller = WalletTransactionsController(gateway);
    await controller.load();
    final next = Completer<WalletTransactionPage>();
    gateway.responses.add(next.future);
    final first = controller.loadMore();
    final duplicate = controller.loadMore();
    next.complete(_page([2], page: 2, totalPages: 2));
    await Future.wait([first, duplicate]);
    expect(controller.transactions.map((item) => item.id), [1, 2]);
    expect(gateway.queries.where((query) => query.page == 2), hasLength(1));
  });
}

WalletTransactionPage _page(
  List<int> ids, {
  int page = 1,
  int totalPages = 1,
}) => WalletTransactionPage(
  items: ids
      .map(
        (id) => WalletTransaction(
          id: id,
          userId: 7,
          type: WalletTransactionType.income,
          amount: id.toDouble(),
          balanceBefore: 0,
          balanceAfter: id.toDouble(),
          relatedType: WalletRelatedType.order,
          relatedId: id + 40,
          status: WalletTransactionStatus.approved,
          createdAt: DateTime.utc(2026, 7, 30),
        ),
      )
      .toList(),
  total: totalPages * 10,
  page: page,
  pageSize: 10,
  totalPages: totalPages,
);

class _Gateway implements WalletGateway {
  final List<Future<WalletTransactionPage>> responses = [];
  final List<WalletTransactionQuery> queries = [];
  @override
  Future<WalletTransactionPage> loadTransactions(WalletTransactionQuery query) {
    queries.add(query);
    return responses.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
