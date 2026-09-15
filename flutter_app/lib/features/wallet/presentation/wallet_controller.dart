import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/wallet_models.dart';

class WalletController extends ChangeNotifier {
  WalletController(this._gateway);
  final WalletGateway _gateway;

  WalletStats? stats;
  WalletWithdrawalConfig? withdrawalConfig;
  String? statsError;
  String? configError;
  bool loading = false;
  bool refreshing = false;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() => _reload(refresh: false);
  Future<void> refresh() => _reload(refresh: true);

  Future<void> _reload({required bool refresh}) async {
    final generation = ++_generation;
    loading = !refresh;
    refreshing = refresh;
    statsError = null;
    configError = null;
    _notify();
    await Future.wait([_loadStats(generation), _loadConfig(generation)]);
    if (_isCurrent(generation)) {
      loading = false;
      refreshing = false;
      _notify();
    }
  }

  Future<void> _loadStats(int generation) async {
    try {
      final result = await _gateway.loadStats();
      if (_isCurrent(generation)) stats = result;
    } catch (error) {
      if (_isCurrent(generation)) statsError = '$error';
    }
  }

  Future<void> _loadConfig(int generation) async {
    try {
      final result = await _gateway.loadWithdrawalConfig();
      if (_isCurrent(generation)) withdrawalConfig = result;
    } catch (error) {
      if (_isCurrent(generation)) configError = '$error';
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
