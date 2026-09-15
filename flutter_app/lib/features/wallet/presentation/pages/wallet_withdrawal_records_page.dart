import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/wallet_models.dart';
import '../wallet_withdrawal_records_controller.dart';
import 'wallet_withdrawal_detail_page.dart';

const _withdrawalStatusFilters = <(String, WalletWithdrawalStatus?)>[
  ('全部', null),
  ('审核中', WalletWithdrawalStatus.pendingReview),
  ('已通过', WalletWithdrawalStatus.processing),
  ('已拒绝', WalletWithdrawalStatus.rejected),
  ('已到账', WalletWithdrawalStatus.succeeded),
];

class WalletWithdrawalRecordsPage extends StatefulWidget {
  const WalletWithdrawalRecordsPage({super.key, required this.gateway});
  final WalletGateway gateway;
  @override
  State<WalletWithdrawalRecordsPage> createState() =>
      _WalletWithdrawalRecordsPageState();
}

class _WalletWithdrawalRecordsPageState
    extends State<WalletWithdrawalRecordsPage> {
  late final WalletWithdrawalRecordsController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WalletWithdrawalRecordsController(widget.gateway);
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
      key: const ValueKey('wallet-withdrawal-records-gradient-background'),
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
            '提现记录',
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
              Expanded(child: _buildBody(primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs(Color primary) => Container(
    key: const ValueKey('wallet-withdrawal-status-tabs'),
    height: 44,
    margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xD9FFFFFF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE3E8F2)),
    ),
    child: Row(
      children: _withdrawalStatusFilters
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
                    key: ValueKey('wallet-withdrawal-status-${filter.$1}'),
                    onTap: selected
                        ? null
                        : () => unawaited(_controller.changeStatus(filter.$2)),
                    borderRadius: BorderRadius.circular(7),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFE7EEFF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
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
              ),
            );
          })
          .toList(growable: false),
    ),
  );

  Widget _buildBody(Color primary) {
    if (_controller.loading && _controller.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 10),
            const Text(
              '加载中',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
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
          key: const ValueKey('wallet-withdrawal-record-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
          itemCount:
              _controller.records.length + (_controller.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _controller.records.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WithdrawalRecordCard(
                record: _controller.records[index],
                onTap: () => _openDetail(_controller.records[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  String _emptyMessage() => switch (_controller.status) {
    null => '暂无提现记录',
    WalletWithdrawalStatus.pendingReview => '暂无审核中的提现记录',
    WalletWithdrawalStatus.processing => '暂无已通过的提现记录',
    WalletWithdrawalStatus.rejected => '暂无已拒绝的提现记录',
    WalletWithdrawalStatus.succeeded => '暂无已到账的提现记录',
    WalletWithdrawalStatus.failed || WalletWithdrawalStatus.unknown => '暂无提现记录',
  };

  void _openDetail(WalletWithdrawal record) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WalletWithdrawalDetailPage(
          gateway: widget.gateway,
          withdrawalId: record.id,
          initialWithdrawal: record,
        ),
      ),
    );
  }
}

class _WithdrawalRecordCard extends StatelessWidget {
  const _WithdrawalRecordCard({required this.record, required this.onTap});

  final WalletWithdrawal record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final statusColor = _statusColor(record.status);
    return Material(
      key: ValueKey('wallet-withdrawal-record-${record.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                      Icons.account_balance_outlined,
                      size: 21,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '支付宝提现',
                          style: TextStyle(
                            color: Color(0xFF1F2937),
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
                        '-¥${record.amount.toStringAsFixed(2)}',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
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
                      '支付宝 ${record.payeeAccountMasked}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColor(WalletWithdrawalStatus status) => switch (status) {
  WalletWithdrawalStatus.pendingReview => const Color(0xFFC87516),
  WalletWithdrawalStatus.processing => const Color(0xFF376996),
  WalletWithdrawalStatus.succeeded => const Color(0xFF16845B),
  WalletWithdrawalStatus.rejected ||
  WalletWithdrawalStatus.failed => const Color(0xFFEF4444),
  WalletWithdrawalStatus.unknown => const Color(0xFF6B7280),
};

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
