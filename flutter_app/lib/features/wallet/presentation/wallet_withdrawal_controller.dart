import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/wallet_models.dart';

class WalletWithdrawalController extends ChangeNotifier {
  WalletWithdrawalController(this._gateway);
  final WalletGateway _gateway;

  WalletWithdrawalConfig? config;
  WalletWithdrawal? submittedWithdrawal;
  bool loading = false;
  bool submitting = false;
  String? error;
  String? _idempotencyKey;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadWithdrawalConfig();
      if (_isCurrent(generation)) config = result;
    } catch (caught) {
      if (_isCurrent(generation)) error = '$caught';
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<WalletWithdrawal?> submit({
    required String amount,
    required String alipayAccount,
    required String payeeRealName,
  }) async {
    if (submitting || _disposed) return null;
    submitting = true;
    error = null;
    _idempotencyKey ??= _uuidV4();
    _notify();
    try {
      final result = await _gateway.createWithdrawal(
        CreateWalletWithdrawal(
          amount: amount,
          alipayAccount: alipayAccount.trim(),
          payeeRealName: payeeRealName.trim(),
          idempotencyKey: _idempotencyKey!,
        ),
      );
      if (_disposed) return null;
      submittedWithdrawal = result;
      return result;
    } catch (caught) {
      if (!_disposed) error = '$caught';
      return null;
    } finally {
      if (!_disposed) {
        submitting = false;
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

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
