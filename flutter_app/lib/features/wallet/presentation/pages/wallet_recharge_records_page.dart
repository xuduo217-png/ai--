import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/wallet_models.dart';
import '../wallet_recharge_records_controller.dart';

const _rechargeStatusFilters = <(String, WalletRechargeStatus?)>[
  ('全部', null),
  ('待确认', WalletRechargeStatus.pending),
  ('已到账', WalletRechargeStatus.succeeded),
];

class WalletRechargeRecordsPage extends StatefulWidget {
  const WalletRechargeRecordsPage({super.key, required this.gateway});

  final WalletGateway gateway;

  @override
  State<WalletRechargeRecordsPage> createState() =>
      _WalletRechargeRecordsPageState();
}

class _WalletRechargeRecordsPageState extends State<WalletRechargeRecordsPage> {
  late final WalletRechargeRecordsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WalletRechargeRecordsController(widget.gateway);
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
      key: const ValueKey('wallet-recharge-records-gradient-background'),
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
            '充值记录',
            key: ValueKey('wallet-recharge-records-title'),
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
              _buildStatusTabs(primary),
              Expanded(child: _buildContent(primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs(Color primary) => Container(
    key: const ValueKey('wallet-recharge-status-tabs'),
    height: 44,
    margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xD9FFFFFF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE3E8F2)),
    ),
    child: Row(
      children: _rechargeStatusFilters
          .map((filter) {
            final selected = _controller.status == filter.$2;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  child: InkWell(
                    key: ValueKey('wallet-recharge-status-${filter.$1}'),
                    onTap: selected
                        ? null
                        : () => unawaited(_controller.changeStatus(filter.$2)),
                    borderRadius: BorderRadius.circular(7),
                    child: AnimatedContainer(
                      key: ValueKey(
                        'wallet-recharge-status-surface-${filter.$1}',
                      ),
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
                          color: selected ? primary : AppColors.muted,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    ),
  );

  Widget _buildContent(Color primary) {
    if (_controller.loading && _controller.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 10),
            const Text(
              '加载中',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_controller.error != null && _controller.records.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _controller.load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('加载失败，点击重试'),
        ),
      );
    }
    if (_controller.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 42,
              color: Color(0xFFAAB2C0),
            ),
            const SizedBox(height: 10),
            Text(
              _emptyMessage(),
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 180) {
          unawaited(_controller.loadMore());
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView.builder(
          key: const ValueKey('wallet-recharge-record-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
          itemCount:
              _controller.records.length + (_controller.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _controller.records.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            final record = _controller.records[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RechargeRecordCard(
                record: record,
                confirming: _controller.confirmingId == record.id,
                onConfirm: () => _controller.confirm(record.id),
              ),
            );
          },
        ),
      ),
    );
  }

  String _emptyMessage() => switch (_controller.status) {
    null => '暂无充值记录',
    WalletRechargeStatus.pending => '暂无待确认的充值记录',
    WalletRechargeStatus.succeeded => '暂无已到账的充值记录',
    WalletRechargeStatus.failed ||
    WalletRechargeStatus.closed ||
    WalletRechargeStatus.unknown => '暂无充值记录',
  };
}

class _RechargeRecordCard extends StatelessWidget {
  const _RechargeRecordCard({
    required this.record,
    required this.confirming,
    required this.onConfirm,
  });

  final WalletRecharge record;
  final bool confirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final statusColor = _statusColor(record.status);
    return Material(
      key: ValueKey('wallet-recharge-record-${record.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                    Icons.add_card_outlined,
                    color: primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '支付宝充值',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(record.createdAt),
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
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '+¥${record.amount.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF16845B),
                        fontSize: 18,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                    record.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.failureMessage ?? record.rechargeNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (record.status == WalletRechargeStatus.pending) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    key: ValueKey('wallet-recharge-confirm-${record.id}'),
                    tooltip: '确认支付结果',
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    color: primary,
                    onPressed: confirming ? null : onConfirm,
                    icon: confirming
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(WalletRechargeStatus status) => switch (status) {
  WalletRechargeStatus.succeeded => const Color(0xFF16845B),
  WalletRechargeStatus.pending => const Color(0xFFC87516),
  WalletRechargeStatus.failed ||
  WalletRechargeStatus.closed => const Color(0xFFEF4444),
  WalletRechargeStatus.unknown => const Color(0xFF6B7280),
};

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
