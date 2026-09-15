import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';
import 'package:pet_hospital_flutter/features/wallet/presentation/wallet_controller.dart';

void main() {
  test('钱包首页并发加载统计和提现配置，错误相互隔离', () async {
    final gateway = _WalletGateway();
    final stats = Completer<WalletStats>();
    final config = Completer<WalletWithdrawalConfig>();
    gateway.statsResponse = stats.future;
    gateway.configResponse = config.future;
    final controller = WalletController(gateway);

    final loading = controller.load();
    stats.complete(_stats(available: 12));
    config.completeError(StateError('配置失败'));
    await loading;

    expect(controller.stats?.availableBalance, 12);
    expect(controller.statsError, isNull);
    expect(controller.withdrawalConfig, isNull);
    expect(controller.configError, contains('配置失败'));
    expect(controller.loading, isFalse);
  });

  test('刷新时忽略较晚返回的旧首页请求', () async {
    final gateway = _WalletGateway();
    final oldStats = Completer<WalletStats>();
    final newStats = Completer<WalletStats>();
    gateway.statsResponses.addAll([oldStats.future, newStats.future]);
    gateway.configResponses.addAll([
      Future.value(_config()),
      Future.value(_config()),
    ]);
    final controller = WalletController(gateway);

    final oldLoad = controller.load();
    final refresh = controller.refresh();
    newStats.complete(_stats(available: 20));
    await refresh;
    oldStats.complete(_stats(available: 1));
    await oldLoad;

    expect(controller.stats?.availableBalance, 20);
  });
}

WalletStats _stats({required double available}) => WalletStats(
  availableBalance: available,
  pendingSettlement: 2,
  totalSecondHandIncome: 10,
  withdrawalFrozenBalance: 3,
);

WalletWithdrawalConfig _config() => const WalletWithdrawalConfig(
  enabled: true,
  availableBalance: 10,
  minAmount: 1,
  maxAmountPerRequest: 100,
  remainingDailyAmount: 100,
  hasActiveWithdrawal: false,
);

class _WalletGateway implements WalletGateway {
  Future<WalletStats>? statsResponse;
  Future<WalletWithdrawalConfig>? configResponse;
  final List<Future<WalletStats>> statsResponses = [];
  final List<Future<WalletWithdrawalConfig>> configResponses = [];

  @override
  Future<WalletStats> loadStats() =>
      statsResponses.isNotEmpty ? statsResponses.removeAt(0) : statsResponse!;

  @override
  Future<WalletWithdrawalConfig> loadWithdrawalConfig() =>
      configResponses.isNotEmpty
      ? configResponses.removeAt(0)
      : configResponse!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
