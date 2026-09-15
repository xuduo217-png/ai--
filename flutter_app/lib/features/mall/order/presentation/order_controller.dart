import 'package:flutter/foundation.dart';

import '../domain/order_models.dart';

class OrderListController extends ChangeNotifier {
  OrderListController(this._gateway, {this.viewRole = OrderViewRole.buyer});
  final OrderGateway _gateway;
  final OrderViewRole viewRole;

  ShopOrderStatus? status;
  String? afterSaleStatus;
  List<ShopOrder> orders = const [];
  int page = 1;
  bool hasMore = false;
  bool loading = false;
  bool loadingMore = false;
  String? errorMessage;
  int _requestRevision = 0;
  bool _disposed = false;

  Future<void> load({
    ShopOrderStatus? filter,
    String? afterSaleFilter,
    bool replaceFilter = false,
  }) async {
    if (_disposed) return;
    if (replaceFilter &&
        (status != filter || afterSaleStatus != afterSaleFilter)) {
      status = filter;
      afterSaleStatus = afterSaleFilter;
      orders = const [];
    }
    final revision = ++_requestRevision;
    final requestStatus = status;
    loading = true;
    loadingMore = false;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadOrders(
        OrderQuery(
          status: requestStatus,
          afterSaleStatus: afterSaleStatus,
          viewRole: viewRole,
          page: 1,
        ),
      );
      if (!_isCurrent(revision)) return;
      orders = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      errorMessage = '$error';
    } finally {
      if (_isCurrent(revision)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || !hasMore || loading || loadingMore) return;
    final revision = ++_requestRevision;
    final requestStatus = status;
    final nextPage = page + 1;
    loadingMore = true;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadOrders(
        OrderQuery(
          status: requestStatus,
          afterSaleStatus: afterSaleStatus,
          viewRole: viewRole,
          page: nextPage,
        ),
      );
      if (!_isCurrent(revision)) return;
      final byId = <int, ShopOrder>{
        for (final order in orders) order.id: order,
      };
      for (final order in result.items) {
        byId[order.id] = order;
      }
      orders = byId.values.toList(growable: false);
      page = result.page;
      hasMore = result.hasMore;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      errorMessage = '$error';
    } finally {
      if (_isCurrent(revision)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> cancel(ShopOrder order) async {
    if (_disposed) return;
    await _gateway.cancelOrder(order.id, reason: '用户取消');
    if (!_disposed) await load();
  }

  Future<void> confirm(ShopOrder order) async {
    if (_disposed) return;
    await _gateway.confirmOrder(order.id);
    if (!_disposed) await load();
  }

  bool _isCurrent(int revision) => !_disposed && revision == _requestRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestRevision += 1;
    super.dispose();
  }
}

class OrderDetailController extends ChangeNotifier {
  OrderDetailController(this._gateway, this.orderId);
  final OrderGateway _gateway;
  final int orderId;

  ShopOrder? order;
  bool loading = false;
  String? errorMessage;
  bool _disposed = false;
  int _requestRevision = 0;

  Future<void> load() async {
    if (_disposed) return;
    final revision = ++_requestRevision;
    loading = true;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadOrder(orderId);
      if (!_isCurrent(revision)) return;
      order = result;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      errorMessage = '$error';
    } finally {
      if (_isCurrent(revision)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> cancel() async {
    if (_disposed) return;
    await _gateway.cancelOrder(orderId, reason: '不想要了');
    if (!_disposed) await load();
  }

  Future<void> confirm() async {
    if (_disposed) return;
    await _gateway.confirmOrder(orderId);
    if (!_disposed) await load();
  }

  bool _isCurrent(int revision) => !_disposed && revision == _requestRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestRevision += 1;
    super.dispose();
  }
}
