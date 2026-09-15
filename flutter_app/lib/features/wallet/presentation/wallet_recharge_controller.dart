import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../mall/payment/domain/payment_models.dart';
import '../domain/wallet_models.dart';

enum WalletRechargeFlowStatus { succeeded, cancelled, processing, failed }

class WalletRechargeFlowResult {
  const WalletRechargeFlowResult({
    required this.status,
    required this.message,
    required this.recharge,
  });

  final WalletRechargeFlowStatus status;
  final String message;
  final WalletRecharge recharge;
}

typedef RechargePollDelay = Future<void> Function(Duration duration);

class WalletRechargeController extends ChangeNotifier {
  WalletRechargeController(
    this._walletGateway,
    this._paymentGateway, {
    RechargePollDelay delay = Future<void>.delayed,
    int pollAttempts = 5,
  }) : _delay = delay,
       _pollAttempts = pollAttempts;

  final WalletGateway _walletGateway;
  final PaymentGateway _paymentGateway;
  final RechargePollDelay _delay;
  final int _pollAttempts;

  WalletRechargeConfig? config;
  WalletRecharge? recharge;
  bool loading = false;
  bool submitting = false;
  String? error;
  String? _idempotencyKey;
  String? _idempotencyAmount;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await _walletGateway.loadRechargeConfig();
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

  Future<WalletRechargeFlowResult?> submit(String amount) async {
    if (submitting || _disposed) return null;
    final normalizedAmount = amount.trim();
    if (_idempotencyAmount != normalizedAmount) {
      _idempotencyAmount = normalizedAmount;
      _idempotencyKey = _uuidV4();
    }

    submitting = true;
    error = null;
    _notify();
    try {
      final created = await _walletGateway.createRecharge(
        CreateWalletRecharge(
          amount: normalizedAmount,
          idempotencyKey: _idempotencyKey!,
        ),
      );
      recharge = created;
      if (created.status == WalletRechargeStatus.succeeded) {
        return _result(WalletRechargeFlowStatus.succeeded, '充值已到账', created);
      }

      final orderInfo = created.alipayOrderString;
      if (orderInfo == null || orderInfo.isEmpty) {
        return _confirm(created, attempts: 1);
      }

      final sdkResult = await _paymentGateway.pay(orderInfo);
      if (_disposed) return null;
      if (sdkResult.status == PaymentSdkStatus.cancelled) {
        return _result(WalletRechargeFlowStatus.cancelled, '已取消支付', created);
      }

      final attempts = sdkResult.status == PaymentSdkStatus.failed
          ? 1
          : _pollAttempts;
      final confirmed = await _confirm(created, attempts: attempts);
      if (confirmed.status != WalletRechargeFlowStatus.processing ||
          sdkResult.status != PaymentSdkStatus.failed) {
        return confirmed;
      }
      return _result(
        WalletRechargeFlowStatus.failed,
        sdkResult.memo.trim().isEmpty ? '支付未完成，请稍后重试' : sdkResult.memo,
        confirmed.recharge,
      );
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

  Future<WalletRechargeFlowResult> _confirm(
    WalletRecharge initial, {
    required int attempts,
  }) async {
    var latest = initial;
    final count = attempts < 1 ? 1 : attempts;
    for (var attempt = 0; attempt < count; attempt++) {
      try {
        latest = await _walletGateway.loadRecharge(initial.id);
        if (_disposed) {
          return _result(
            WalletRechargeFlowStatus.processing,
            '支付结果确认中，请稍后查看充值记录',
            latest,
          );
        }
        recharge = latest;
        switch (latest.status) {
          case WalletRechargeStatus.succeeded:
            return _result(WalletRechargeFlowStatus.succeeded, '充值已到账', latest);
          case WalletRechargeStatus.failed:
          case WalletRechargeStatus.closed:
            _resetIdempotency();
            return _result(
              WalletRechargeFlowStatus.failed,
              latest.failureMessage ?? latest.status.label,
              latest,
            );
          case WalletRechargeStatus.pending:
          case WalletRechargeStatus.unknown:
            break;
        }
      } catch (_) {
        // 支付结果查询允许短暂失败，最终仍保持“确认中”而不是误报失败。
      }
      if (attempt + 1 < count) {
        await _delay(const Duration(seconds: 2));
      }
    }
    return _result(
      WalletRechargeFlowStatus.processing,
      '支付结果确认中，请稍后查看充值记录',
      latest,
    );
  }

  WalletRechargeFlowResult _result(
    WalletRechargeFlowStatus status,
    String message,
    WalletRecharge value,
  ) => WalletRechargeFlowResult(
    status: status,
    message: message,
    recharge: value,
  );

  void _resetIdempotency() {
    _idempotencyKey = null;
    _idempotencyAmount = null;
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
