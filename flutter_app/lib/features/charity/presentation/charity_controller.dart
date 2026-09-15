import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/charity_models.dart';

class CharityListController extends ChangeNotifier {
  CharityListController({
    required CharityGateway gateway,
    required this.authenticated,
  }) : _gateway = gateway;

  final CharityGateway _gateway;
  final bool authenticated;

  CharityListFilter selectedFilter = CharityListFilter.active;
  String searchKeyword = '';
  List<CharityActivity> activities = const [];
  bool loading = true;
  bool refreshing = false;
  bool loadingMore = false;
  String? error;

  int _page = 0;
  int _totalPages = 0;
  int _generation = 0;
  bool _disposed = false;

  bool get hasMore => _page < _totalPages;

  Future<void> load() => _replace(showLoading: activities.isEmpty);

  Future<void> refresh() => _replace(showLoading: false, refresh: true);

  Future<void> retry() => activities.isEmpty ? load() : refresh();

  Future<void> selectFilter(CharityListFilter filter) async {
    if (_disposed || selectedFilter == filter) return;
    selectedFilter = filter;
    activities = const [];
    await _replace(showLoading: true);
  }

  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    if (_disposed || searchKeyword == normalized) return;
    searchKeyword = normalized;
    activities = const [];
    await _replace(showLoading: true);
  }

  Future<void> loadMore() async {
    if (_disposed || loading || refreshing || loadingMore || !hasMore) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadCharities(
        authenticated: authenticated,
        status: selectedFilter.status,
        keyword: searchKeyword,
        page: _page + 1,
      );
      if (!_isCurrent(generation)) return;
      activities = _merge(activities, result.items);
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object {
      if (_isCurrent(generation)) error = '加载更多失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> _replace({
    required bool showLoading,
    bool refresh = false,
  }) async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = showLoading;
    refreshing = refresh;
    loadingMore = false;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadCharities(
        authenticated: authenticated,
        status: selectedFilter.status,
        keyword: searchKeyword,
      );
      if (!_isCurrent(generation)) return;
      activities = result.items;
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object {
      if (_isCurrent(generation)) error = '公益列表加载失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        refreshing = false;
        _notify();
      }
    }
  }

  List<CharityActivity> _merge(
    List<CharityActivity> current,
    List<CharityActivity> incoming,
  ) {
    final ids = current.map((item) => item.id).toSet();
    return [...current, ...incoming.where((item) => ids.add(item.id))];
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

class CharityDetailController extends ChangeNotifier {
  CharityDetailController({
    required CharityGateway gateway,
    required this.charityId,
    required this.authenticated,
  }) : _gateway = gateway;

  final CharityGateway _gateway;
  final int charityId;
  final bool authenticated;

  CharityActivity? activity;
  List<CharityRecord> records = const [];
  bool loading = true;
  bool recordsLoading = false;
  bool loadingMore = false;
  bool actionLoading = false;
  String? error;
  String? recordsError;

  int _recordPage = 0;
  int _recordTotalPages = 0;
  int _generation = 0;
  bool _disposed = false;

  bool get hasMoreRecords => _recordPage < _recordTotalPages;

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    recordsError = null;
    _notify();
    try {
      final loaded = await _gateway.loadCharityDetail(
        charityId,
        authenticated: authenticated,
      );
      if (!_isCurrent(generation)) return;
      activity = loaded;
      await _loadFirstRecordPage(generation);
    } on Object {
      if (_isCurrent(generation)) error = '无法加载公益详情，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    error = null;
    recordsError = null;
    _notify();
    try {
      activity = await _gateway.loadCharityDetail(
        charityId,
        authenticated: authenticated,
      );
      if (!_isCurrent(generation)) return;
      await _loadFirstRecordPage(generation);
    } on Object {
      if (_isCurrent(generation)) error = '公益详情刷新失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) _notify();
    }
  }

  Future<CharityCheckInResult> checkIn() async {
    if (_disposed || actionLoading) {
      throw StateError('签到操作正在进行中');
    }
    actionLoading = true;
    _notify();
    try {
      final result = await _gateway.checkInCharity(charityId);
      if (result.success || result.alreadyChecked) await refresh();
      return result;
    } finally {
      if (!_disposed) {
        actionLoading = false;
        _notify();
      }
    }
  }

  Future<double> loadWalletBalance() => _gateway.loadCharityWalletBalance();

  Future<CharityDonationResult> donate(double amount) async {
    if (_disposed || actionLoading) {
      throw StateError('捐款操作正在进行中');
    }
    actionLoading = true;
    _notify();
    try {
      final result = await _gateway.donateCharity(charityId, amount: amount);
      await refresh();
      return result;
    } finally {
      if (!_disposed) {
        actionLoading = false;
        _notify();
      }
    }
  }

  Future<CharityDonationPayment> createDonationPayment(
    double amount,
    String idempotencyKey,
  ) => _gateway.createCharityDonationPayment(
    charityId,
    amount: amount,
    idempotencyKey: idempotencyKey,
  );

  Future<CharityDonationPaymentStatus> loadDonationPaymentStatus(
    String paymentNo,
  ) => _gateway.loadCharityDonationPaymentStatus(paymentNo);

  Future<void> loadMoreRecords() async {
    if (_disposed || loadingMore || recordsLoading || !hasMoreRecords) return;
    final current = activity;
    if (current == null || (!authenticated && !current.isDonation)) return;
    final generation = _generation;
    loadingMore = true;
    recordsError = null;
    _notify();
    try {
      final result = await _loadRecords(current, _recordPage + 1);
      if (!_isCurrent(generation)) return;
      final ids = records.map((record) => record.id).toSet();
      records = [
        ...records,
        ...result.items.where((record) => ids.add(record.id)),
      ];
      _recordPage = result.page;
      _recordTotalPages = result.totalPages;
    } on Object {
      if (_isCurrent(generation)) recordsError = '加载更多失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> _loadFirstRecordPage(int generation) async {
    final current = activity;
    records = const [];
    _recordPage = 0;
    _recordTotalPages = 0;
    recordsError = null;
    if (current == null || (!authenticated && !current.isDonation)) return;
    recordsLoading = true;
    _notify();
    try {
      final result = await _loadRecords(current, 1);
      if (!_isCurrent(generation)) return;
      records = result.items;
      _recordPage = result.page;
      _recordTotalPages = result.totalPages;
    } on ApiException catch (exception) {
      if (!_isCurrent(generation)) return;
      if (exception.statusCode != 401) {
        recordsError = '参与记录加载失败，请稍后重试';
      }
    } on Object {
      if (_isCurrent(generation)) recordsError = '参与记录加载失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        recordsLoading = false;
        _notify();
      }
    }
  }

  Future<CharityRecordPage> _loadRecords(CharityActivity current, int page) {
    return current.isDonation
        ? _gateway.loadCharityDonations(
            charityId,
            authenticated: authenticated,
            page: page,
          )
        : _gateway.loadCharityRecords(charityId, page: page);
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
