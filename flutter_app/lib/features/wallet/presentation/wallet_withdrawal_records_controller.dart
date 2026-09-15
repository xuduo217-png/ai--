import 'package:flutter/foundation.dart';

import '../domain/wallet_models.dart';

class WalletWithdrawalRecordsController extends ChangeNotifier {
  WalletWithdrawalRecordsController(this._gateway);
  final WalletGateway _gateway;
  List<WalletWithdrawal> records = const [];
  int page = 1;
  bool hasMore = false;
  bool loading = false;
  bool refreshing = false;
  bool loadingMore = false;
  String? error;
  WalletWithdrawalStatus? status;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() => _replace(false);
  Future<void> refresh() => _replace(true);
  Future<void> changeStatus(WalletWithdrawalStatus? value) {
    if (status == value) return Future.value();
    status = value;
    records = const [];
    page = 1;
    hasMore = false;
    return _replace(false);
  }

  Future<void> _replace(bool refresh) async {
    final generation = ++_generation;
    loading = !refresh;
    refreshing = refresh;
    loadingMore = false;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadWithdrawals(status: status);
      if (!_isCurrent(generation)) return;
      records = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } catch (caught) {
      if (_isCurrent(generation)) error = '$caught';
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        refreshing = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || loading || refreshing || loadingMore || _disposed) return;
    final generation = _generation;
    loadingMore = true;
    _notify();
    try {
      final result = await _gateway.loadWithdrawals(
        page: page + 1,
        status: status,
      );
      if (!_isCurrent(generation)) return;
      records = [...records, ...result.items];
      page = result.page;
      hasMore = result.hasMore;
    } catch (caught) {
      if (_isCurrent(generation)) error = '$caught';
    } finally {
      if (_isCurrent(generation)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
