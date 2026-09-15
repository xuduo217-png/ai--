import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/wallet_models.dart';
import '../wallet_transactions_controller.dart';

typedef OpenWalletTransactionDetail = Future<void> Function(int id);

const _walletTypeFilters = <(String, WalletTransactionType?)>[
  ('全部', null),
  ('收入', WalletTransactionType.income),
  ('支出', WalletTransactionType.expense),
];

const _walletSourceFilters = <(String, WalletRelatedType?)>[
  ('全部来源', null),
  ('二手交易', WalletRelatedType.order),
  ('退款', WalletRelatedType.refund),
  ('余额充值', WalletRelatedType.recharge),
  ('支付宝提现', WalletRelatedType.withdraw),
  ('公益捐款', WalletRelatedType.charity),
  ('平台调整', WalletRelatedType.adjustment),
];

class WalletTransactionsPage extends StatefulWidget {
  const WalletTransactionsPage({
    super.key,
    required this.gateway,
    required this.onOrderDetail,
    required this.onWithdrawalDetail,
  });
  final WalletGateway gateway;
  final OpenWalletTransactionDetail onOrderDetail;
  final OpenWalletTransactionDetail onWithdrawalDetail;
  @override
  State<WalletTransactionsPage> createState() => _WalletTransactionsPageState();
}

class _WalletTransactionsPageState extends State<WalletTransactionsPage> {
  late final WalletTransactionsController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WalletTransactionsController(widget.gateway);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      key: const ValueKey('wallet-transactions-gradient-background'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 52,
          centerTitle: false,
          foregroundColor: AppColors.ink,
          title: const Text(
            '钱包明细',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            children: [
              _buildTypeTabs(primary),
              _buildSourcePicker(primary),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTabs(Color primary) => Container(
    key: const ValueKey('wallet-type-filter-tabs'),
    height: 44,
    margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xD9FFFFFF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE3E8F2)),
    ),
    child: Row(
      children: List.generate(_walletTypeFilters.length, (index) {
        final filter = _walletTypeFilters[index];
        final selected = _controller.type == filter.$2;
        return Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              child: InkWell(
                key: ValueKey('wallet-type-${filter.$1}'),
                onTap: selected
                    ? null
                    : () => unawaited(
                        _controller.changeFilters(
                          type: filter.$2,
                          relatedType: _controller.relatedType,
                        ),
                      ),
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  key: ValueKey('wallet-type-surface-${filter.$1}'),
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE7EEFF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    filter.$1,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? primary : const Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _buildSourcePicker(Color primary) {
    final selected = _walletSourceFilters.firstWhere(
      (filter) => filter.$2 == _controller.relatedType,
      orElse: () => _walletSourceFilters.first,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: const Color(0xF2FFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE3E8F2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('wallet-related-type-filter'),
          onTap: _showSourcePicker,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 20, color: primary),
                  const SizedBox(width: 10),
                  const Text(
                    '业务来源',
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    selected.$1,
                    style: TextStyle(
                      color: primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Color(0xFF8A94A3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSourcePicker() {
    final labels = _walletSourceFilters
        .map((filter) => filter.$1)
        .toList(growable: false);
    final selectedIndex = _walletSourceFilters.indexWhere(
      (filter) => filter.$2 == _controller.relatedType,
    );
    final style = DefaultPickerStyle(haveRadius: true, title: '选择业务来源')
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = const Color(0xFF22252B);

    Pickers.showSinglePicker(
      context,
      data: labels,
      selectData: labels[selectedIndex < 0 ? 0 : selectedIndex],
      pickerStyle: style,
      onConfirm: (_, index) {
        if (!mounted) return;
        unawaited(
          _controller.changeFilters(
            type: _controller.type,
            relatedType: _walletSourceFilters[index].$2,
          ),
        );
      },
    );
  }

  Widget _buildList() {
    if (_controller.loading && _controller.transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF5B75E5)),
            SizedBox(height: 10),
            Text(
              '加载中...',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (_controller.error != null && _controller.transactions.isEmpty) {
      return _StateView(message: '钱包明细加载失败', onRetry: _controller.retry);
    }
    if (_controller.transactions.isEmpty) {
      return const _StateView(message: '暂无钱包明细');
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 220) {
          unawaited(_controller.loadMore());
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView.builder(
          key: const ValueKey('wallet-transaction-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 16),
          itemCount:
              _controller.transactions.length +
              (_controller.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _controller.transactions.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final item = _controller.transactions[index];
            return _TransactionTile(
              transaction: item,
              onOrderDetail: () => _openDetail(
                () => widget.onOrderDetail(item.relatedId),
                '关联订单不可用',
              ),
              onWithdrawalDetail: () => _openDetail(
                () => widget.onWithdrawalDetail(item.relatedId),
                '提现详情不可用',
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDetail(Future<void> Function() action, String error) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onOrderDetail,
    required this.onWithdrawalDetail,
  });
  final WalletTransaction transaction;
  final VoidCallback onOrderDetail;
  final VoidCallback onWithdrawalDetail;
  @override
  Widget build(BuildContext context) {
    final credit = transaction.type.isCredit;
    final amountColor = credit
        ? const Color(0xFF16845B)
        : const Color(0xFFEF4444);
    final primary = Theme.of(context).colorScheme.primary;
    final statusColor = _statusColor(transaction);
    final source = transaction.historicalAdjustment
        ? '历史余额调整'
        : transaction.relatedType.label;
    final hasDetail =
        transaction.hasValidOrderLink || transaction.hasValidWithdrawalLink;
    final openDetail = transaction.hasValidOrderLink
        ? onOrderDetail
        : transaction.hasValidWithdrawalLink
        ? onWithdrawalDetail
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: ValueKey('wallet-transaction-${transaction.id}'),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openDetail,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _sourceIcon(transaction.relatedType),
                        size: 21,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatWalletTransactionTime(transaction.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 166),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${credit ? '+' : '-'}¥${transaction.amount.abs().toStringAsFixed(2)}',
                              maxLines: 1,
                              style: TextStyle(
                                color: amountColor,
                                fontSize: 18,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '余额 ¥${transaction.balanceAfter.toStringAsFixed(2)}',
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFEFEFEF)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transaction.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (transaction.remark case final remark?) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          remark,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (hasDetail) ...[
                      const SizedBox(width: 8),
                      KeyedSubtree(
                        key: ValueKey(
                          transaction.hasValidOrderLink
                              ? 'wallet-order-${transaction.relatedId}'
                              : 'wallet-withdrawal-${transaction.relatedId}',
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              transaction.hasValidOrderLink ? '查看订单' : '提现详情',
                              style: TextStyle(
                                color: primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _sourceIcon(WalletRelatedType type) => switch (type) {
  WalletRelatedType.order => Icons.shopping_bag_outlined,
  WalletRelatedType.refund => Icons.replay_rounded,
  WalletRelatedType.recharge => Icons.add_card_rounded,
  WalletRelatedType.withdraw => Icons.account_balance_outlined,
  WalletRelatedType.charity => Icons.volunteer_activism_outlined,
  WalletRelatedType.adjustment => Icons.tune_rounded,
  WalletRelatedType.unknown => Icons.receipt_long_outlined,
};

Color _statusColor(WalletTransaction transaction) {
  if (transaction.withdrawalStatus case final status?) {
    return switch (status) {
      WalletWithdrawalStatus.pendingReview => const Color(0xFFC87516),
      WalletWithdrawalStatus.processing => const Color(0xFF376996),
      WalletWithdrawalStatus.succeeded => const Color(0xFF16845B),
      WalletWithdrawalStatus.rejected => const Color(0xFFEF4444),
      WalletWithdrawalStatus.failed => const Color(0xFFEF4444),
      WalletWithdrawalStatus.unknown => const Color(0xFF6B7280),
    };
  }
  return switch (transaction.status) {
    WalletTransactionStatus.pending => const Color(0xFFC87516),
    WalletTransactionStatus.approved => const Color(0xFF16845B),
    WalletTransactionStatus.rejected => const Color(0xFFEF4444),
    WalletTransactionStatus.unknown => const Color(0xFF6B7280),
  };
}

class _StateView extends StatelessWidget {
  const _StateView({required this.message, this.onRetry});
  final String message;
  final Future<void> Function()? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 48,
          color: Color(0xFF98A0AA),
        ),
        const SizedBox(height: 10),
        Text(message),
        if (onRetry != null)
          TextButton.icon(
            key: const ValueKey('wallet-transactions-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
      ],
    ),
  );
}

String formatWalletTransactionTime(DateTime value, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = value.toLocal();
  final days = DateTime(
    current.year,
    current.month,
    current.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days == 0) return '今天';
  if (days == 1) return '昨天';
  if (days > 1 && days < 7) return '$days天前';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
