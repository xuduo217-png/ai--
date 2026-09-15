import 'dart:async';

import 'package:flutter/material.dart';

import '../../../mall/payment/domain/payment_models.dart';
import '../../domain/wallet_models.dart';
import '../wallet_controller.dart';
import 'wallet_recharge_page.dart';
import 'wallet_recharge_records_page.dart';
import 'wallet_transactions_page.dart';
import 'wallet_withdrawal_detail_page.dart';
import 'wallet_withdrawal_page.dart';
import 'wallet_withdrawal_records_page.dart';

typedef OpenWalletOrderDetail = Future<void> Function(int orderId);

const _walletHeaderColor = Color(0xFFDEE9FF);

class WalletPage extends StatefulWidget {
  const WalletPage({
    super.key,
    required this.gateway,
    required this.paymentGateway,
    required this.onOrderDetail,
  });
  final WalletGateway gateway;
  final PaymentGateway paymentGateway;
  final OpenWalletOrderDetail onOrderDetail;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late final WalletController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WalletController(widget.gateway);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    appBar: AppBar(
      title: const Text('我的钱包'),
      backgroundColor: _walletHeaderColor,
      surfaceTintColor: _walletHeaderColor,
      actions: [
        if (_controller.refreshing)
          const Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    ),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.loading && _controller.stats == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.stats == null) {
          return _WalletError(message: '钱包概览加载失败', onRetry: _controller.load);
        }
        final stats = _controller.stats!;
        final config = _controller.withdrawalConfig;
        final withdrawalEnabled =
            config?.enabled == true && config?.hasActiveWithdrawal != true;
        final unavailableReason = config?.hasActiveWithdrawal == true
            ? '已有一笔提现正在处理中'
            : config?.unavailableReason;
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ColoredBox(
                key: const ValueKey('wallet-stats-band'),
                color: _walletHeaderColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '可用余额',
                        style: TextStyle(
                          color: Color(0xFF536273),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        key: const ValueKey('wallet-available-balance'),
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '¥${stats.availableBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1C2430),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              key: const ValueKey('wallet-recharge-button'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                backgroundColor: const Color(0xFF18794E),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _open(
                                WalletRechargePage(
                                  gateway: widget.gateway,
                                  paymentGateway: widget.paymentGateway,
                                ),
                              ),
                              icon: const Icon(Icons.add_card_outlined),
                              label: const Text('充值'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              key: const ValueKey('wallet-withdraw-button'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: withdrawalEnabled
                                  ? () => _open(
                                      WalletWithdrawalPage(
                                        gateway: widget.gateway,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.outbox_outlined),
                              label: const Text('提现'),
                            ),
                          ),
                        ],
                      ),
                      if (!withdrawalEnabled && unavailableReason != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          unavailableReason,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A5A00),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  key: const ValueKey('wallet-stats'),
                  children: [
                    _Metric(label: '待到账', amount: stats.pendingSettlement),
                    const SizedBox(
                      height: 42,
                      child: VerticalDivider(width: 24),
                    ),
                    _Metric(
                      label: '累计二手收益',
                      amount: stats.totalSecondHandIncome,
                    ),
                    const SizedBox(
                      height: 42,
                      child: VerticalDivider(width: 24),
                    ),
                    _Metric(
                      label: '提现中',
                      amount: stats.withdrawalFrozenBalance,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _WalletEntry(
                key: const ValueKey('wallet-transactions-entry'),
                icon: Icons.receipt_long_outlined,
                title: '钱包明细',
                subtitle: '查看全部资金变化',
                onTap: () => _open(
                  WalletTransactionsPage(
                    gateway: widget.gateway,
                    onOrderDetail: widget.onOrderDetail,
                    onWithdrawalDetail: (id) => _open(
                      WalletWithdrawalDetailPage(
                        gateway: widget.gateway,
                        withdrawalId: id,
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 64),
              _WalletEntry(
                key: const ValueKey('wallet-recharge-records-entry'),
                icon: Icons.add_card_outlined,
                title: '充值记录',
                subtitle: '查看支付确认与到账状态',
                onTap: () =>
                    _open(WalletRechargeRecordsPage(gateway: widget.gateway)),
              ),
              const Divider(height: 1, indent: 64),
              _WalletEntry(
                key: const ValueKey('wallet-withdrawal-records-entry'),
                icon: Icons.account_balance_outlined,
                title: '提现记录',
                subtitle: '查看审核与到账状态',
                onTap: () =>
                    _open(WalletWithdrawalRecordsPage(gateway: widget.gateway)),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.amount});
  final String label;
  final double amount;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '¥${amount.toStringAsFixed(2)}',
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(fontSize: 12, color: Color(0xFF687483)),
        ),
      ],
    ),
  );
}

class _WalletEntry extends StatelessWidget {
  const _WalletEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: ListTile(
      minTileHeight: 64,
      leading: Icon(icon, color: const Color(0xFF397EDB)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _WalletError extends StatelessWidget {
  const _WalletError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('wallet-stats-retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      ],
    ),
  );
}
