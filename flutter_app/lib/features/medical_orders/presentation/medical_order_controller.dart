import 'package:flutter/foundation.dart';

import '../domain/medical_order_models.dart';

class MedicalOrderController extends ChangeNotifier {
  MedicalOrderController(this._gateway);

  final MedicalOrderGateway _gateway;

  List<MedicalServiceOrder> orders = const [];
  int page = 1;
  bool hasMore = false;
  bool isInitialLoading = true;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreError;

  bool _disposed = false;
  int _generation = 0;
  Future<void>? _activeReplace;
  Future<void>? _activeLoadMore;

  Future<void> load() => _replace(refresh: false);

  Future<void> refresh() => _replace(refresh: true);

  Future<void> retry() => orders.isEmpty ? load() : refresh();

  Future<void> _replace({required bool refresh}) {
    if (_disposed) return Future<void>.value();
    final active = _activeReplace;
    if (active != null) return active;

    final generation = ++_generation;
    _activeLoadMore = null;
    isLoadingMore = false;
    loadMoreError = null;
    late final Future<void> replacement;
    replacement = _runReplace(generation, refresh: refresh).whenComplete(() {
      if (_activeReplace == replacement) _activeReplace = null;
      _notify();
    });
    _activeReplace = replacement;
    _notify();
    return replacement;
  }

  Future<void> _runReplace(int generation, {required bool refresh}) async {
    isInitialLoading = !refresh && orders.isEmpty;
    isRefreshing = refresh;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadOrders();
      if (!_isCurrent(generation)) return;
      orders = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } on Object {
      if (!_isCurrent(generation)) return;
      errorMessage = '医疗订单加载失败，请稍后重试';
      if (orders.isEmpty) hasMore = false;
    } finally {
      if (_isCurrent(generation)) {
        isInitialLoading = false;
        isRefreshing = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() {
    if (_disposed ||
        !hasMore ||
        isInitialLoading ||
        isRefreshing ||
        _activeReplace != null) {
      return Future<void>.value();
    }
    final active = _activeLoadMore;
    if (active != null) return active;

    final generation = _generation;
    late final Future<void> loading;
    loading = _runLoadMore(generation).whenComplete(() {
      if (_activeLoadMore == loading) _activeLoadMore = null;
      _notify();
    });
    _activeLoadMore = loading;
    _notify();
    return loading;
  }

  Future<void> _runLoadMore(int generation) async {
    isLoadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final result = await _gateway.loadOrders(
        MedicalOrderQuery(page: page + 1),
      );
      if (!_isCurrent(generation)) return;
      final existingIds = orders.map((order) => order.id).toSet();
      orders = [
        ...orders,
        ...result.items.where((order) => existingIds.add(order.id)),
      ];
      page = result.page;
      hasMore = result.hasMore;
    } on Object {
      if (!_isCurrent(generation)) return;
      loadMoreError = '加载更多失败，请重试';
    } finally {
      if (_isCurrent(generation)) {
        isLoadingMore = false;
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
    _generation += 1;
    super.dispose();
  }
}
