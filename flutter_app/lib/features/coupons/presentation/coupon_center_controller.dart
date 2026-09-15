import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/coupon_models.dart';

class CouponCenterController extends ChangeNotifier {
  CouponCenterController(this._gateway);

  final CouponGateway _gateway;

  UserCouponStatus selectedStatus = UserCouponStatus.available;
  List<UserCoupon> coupons = const [];
  CouponCounts? counts;
  bool isInitialLoading = true;
  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;
  String? countError;

  Future<void>? _activeReplacement;
  Future<void>? _activeStatusLoad;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() => _replace(refresh: false);

  Future<void> refresh() => _replace(refresh: true);

  Future<void> retry() => coupons.isEmpty ? load() : refresh();

  Future<void> _replace({required bool refresh}) {
    if (_disposed) return Future<void>.value();
    final active = _activeReplacement;
    if (active != null) return active;

    final generation = ++_generation;
    _activeStatusLoad = null;
    late final Future<void> operation;
    operation = _runReplacement(generation, refresh: refresh).whenComplete(() {
      if (_activeReplacement == operation) _activeReplacement = null;
      _notify();
    });
    _activeReplacement = operation;
    return operation;
  }

  Future<void> _runReplacement(int generation, {required bool refresh}) async {
    isInitialLoading = !refresh && coupons.isEmpty;
    isLoading = true;
    isRefreshing = refresh;
    errorMessage = null;
    countError = null;
    _notify();

    await Future.wait([
      _loadList(generation, selectedStatus),
      _loadCounts(generation),
    ]);

    if (_isCurrent(generation)) {
      isInitialLoading = false;
      isLoading = false;
      isRefreshing = false;
      _notify();
    }
  }

  Future<void> selectStatus(UserCouponStatus status) {
    if (_disposed || status == UserCouponStatus.unknown) {
      return Future<void>.value();
    }
    if (status == selectedStatus) {
      return _activeStatusLoad ?? _activeReplacement ?? Future<void>.value();
    }

    final generation = ++_generation;
    selectedStatus = status;
    coupons = const [];
    errorMessage = null;
    isInitialLoading = false;
    isRefreshing = false;
    isLoading = true;
    _activeReplacement = null;
    _notify();

    if (counts == null) {
      unawaited(_loadCounts(generation));
    }

    late final Future<void> operation;
    operation = _loadList(generation, status).whenComplete(() {
      if (_activeStatusLoad == operation) _activeStatusLoad = null;
      if (_isCurrent(generation)) {
        isLoading = false;
        _notify();
      }
    });
    _activeStatusLoad = operation;
    return operation;
  }

  Future<void> _loadList(
    int generation,
    UserCouponStatus requestedStatus,
  ) async {
    try {
      final result = await _gateway.loadCoupons(requestedStatus);
      if (!_isCurrent(generation)) return;
      final ids = <int>{};
      coupons = result
          .where(
            (coupon) => coupon.status == requestedStatus && ids.add(coupon.id),
          )
          .toList(growable: false);
      errorMessage = null;
      _notify();
    } on Object {
      if (!_isCurrent(generation)) return;
      errorMessage = '优惠券加载失败，请稍后重试';
      _notify();
    }
  }

  Future<void> _loadCounts(int generation) async {
    try {
      final result = await _gateway.loadCounts();
      if (!_isCurrent(generation)) return;
      counts = result;
      countError = null;
      _notify();
    } on Object {
      if (!_isCurrent(generation)) return;
      countError = '优惠券统计暂不可用';
      _notify();
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
