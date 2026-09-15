import 'package:flutter/foundation.dart';

import '../domain/doctor_models.dart';

class DoctorDirectoryController extends ChangeNotifier {
  DoctorDirectoryController({
    required DoctorDirectoryGateway gateway,
    required this.goldOnly,
  }) : _gateway = gateway;

  final DoctorDirectoryGateway _gateway;
  final bool goldOnly;

  List<DoctorProfile> doctors = const [];
  int page = 1;
  bool hasMore = false;
  bool isInitialLoading = true;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreError;

  bool _disposed = false;
  int _generation = 0;
  Future<void>? _activeReplacement;
  Future<void>? _activeLoadMore;

  Future<void> load() => _replace(refresh: false);

  Future<void> refresh() => _replace(refresh: true);

  Future<void> retry() => doctors.isEmpty ? load() : refresh();

  Future<void> _replace({required bool refresh}) {
    if (_disposed) return Future<void>.value();
    final active = _activeReplacement;
    if (active != null) return active;

    final generation = ++_generation;
    _activeLoadMore = null;
    isLoadingMore = false;
    loadMoreError = null;
    late final Future<void> replacement;
    replacement = _runReplacement(generation, refresh: refresh).whenComplete(
      () {
        if (_activeReplacement == replacement) _activeReplacement = null;
        _notify();
      },
    );
    _activeReplacement = replacement;
    _notify();
    return replacement;
  }

  Future<void> _runReplacement(int generation, {required bool refresh}) async {
    isInitialLoading = !refresh && doctors.isEmpty;
    isRefreshing = refresh;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadDoctors(page: 1, goldOnly: goldOnly);
      if (!_isCurrent(generation)) return;
      doctors = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } on Object {
      if (!_isCurrent(generation)) return;
      errorMessage = '医生列表加载失败，请稍后重试';
      if (doctors.isEmpty) hasMore = false;
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
        _activeReplacement != null) {
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
      final result = await _gateway.loadDoctors(
        page: page + 1,
        goldOnly: goldOnly,
      );
      if (!_isCurrent(generation)) return;
      final existingIds = doctors.map((doctor) => doctor.id).toSet();
      doctors = [
        ...doctors,
        ...result.items.where((doctor) => existingIds.add(doctor.id)),
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

class DoctorDetailController extends ChangeNotifier {
  DoctorDetailController({
    required DoctorDirectoryGateway gateway,
    required this.doctorId,
  }) : _gateway = gateway;

  final DoctorDirectoryGateway _gateway;
  final int doctorId;

  DoctorProfile? doctor;
  bool loading = true;
  String? errorMessage;
  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    _notify();
    try {
      doctor = await _gateway.loadDoctor(doctorId);
    } on Object {
      if (_disposed) return;
      errorMessage = '医生详情加载失败，请稍后重试';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
