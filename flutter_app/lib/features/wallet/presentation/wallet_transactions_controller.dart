import 'package:flutter/foundation.dart';

import '../domain/wallet_models.dart';

class WalletTransactionsController extends ChangeNotifier {
  WalletTransactionsController(this._gateway);
  final WalletGateway _gateway;

  List<WalletTransaction> transactions = const [];
  WalletTransactionType? type;
  WalletRelatedType? relatedType;
  int page = 1;
  bool hasMore = false;
  bool loading = false;
  bool refreshing = false;
  bool loadingMore = false;
  String? error;
  String? loadMoreError;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() => _replace(refresh: false, clear: false);
  Future<void> refresh() => _replace(refresh: true, clear: false);
  Future<void> retry() => _replace(refresh: false, clear: false);

  Future<void> changeFilters({
    WalletTransactionType? type,
    WalletRelatedType? relatedType,
  }) {
    this.type = type;
    this.relatedType = relatedType;
    return _replace(refresh: false, clear: true);
  }

  Future<void> _replace({required bool refresh, required bool clear}) async {
    final generation = ++_generation;
    final requestType = type;
    final requestRelatedType = relatedType;
    loading = !refresh;
    refreshing = refresh;
    error = null;
    loadMoreError = null;
    page = 1;
    hasMore = true;
    if (clear) transactions = const [];
    _notify();
    try {
      final result = await _gateway.loadTransactions(
        WalletTransactionQuery(
          type: requestType,
          relatedType: requestRelatedType,
        ),
      );
      if (!_isCurrent(generation, requestType, requestRelatedType)) return;
      transactions = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } catch (caught) {
      if (!_isCurrent(generation, requestType, requestRelatedType)) return;
      error = '$caught';
      if (transactions.isEmpty) hasMore = false;
    } finally {
      if (_isCurrent(generation, requestType, requestRelatedType)) {
        loading = false;
        refreshing = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || loading || refreshing || loadingMore || _disposed) return;
    final generation = _generation;
    final requestType = type;
    final requestRelatedType = relatedType;
    loadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final result = await _gateway.loadTransactions(
        WalletTransactionQuery(
          type: requestType,
          relatedType: requestRelatedType,
          page: page + 1,
        ),
      );
      if (!_isCurrent(generation, requestType, requestRelatedType)) return;
      transactions = [...transactions, ...result.items];
      page = result.page;
      hasMore = result.hasMore;
    } catch (caught) {
      if (_isCurrent(generation, requestType, requestRelatedType)) {
        loadMoreError = '$caught';
      }
    } finally {
      if (_isCurrent(generation, requestType, requestRelatedType)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  bool _isCurrent(
    int generation,
    WalletTransactionType? requestType,
    WalletRelatedType? requestRelatedType,
  ) =>
      !_disposed &&
      generation == _generation &&
      requestType == type &&
      requestRelatedType == relatedType;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
