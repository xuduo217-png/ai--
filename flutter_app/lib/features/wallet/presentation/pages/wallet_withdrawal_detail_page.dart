import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/wallet_models.dart';

const _withdrawalDetailGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
);

class WalletWithdrawalDetailPage extends StatefulWidget {
  const WalletWithdrawalDetailPage({
    super.key,
    required this.gateway,
    required this.withdrawalId,
    this.initialWithdrawal,
  });
  final WalletGateway gateway;
  final int withdrawalId;
  final WalletWithdrawal? initialWithdrawal;
  @override
  State<WalletWithdrawalDetailPage> createState() =>
      _WalletWithdrawalDetailPageState();
}

class _WalletWithdrawalDetailPageState
    extends State<WalletWithdrawalDetailPage> {
  WalletWithdrawal? _withdrawal;
  String? _error;
  bool _loading = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _withdrawal = widget.initialWithdrawal;
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.gateway.loadWithdrawal(widget.withdrawalId);
      if (mounted && generation == _generation) {
        setState(() => _withdrawal = result);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('wallet-withdrawal-detail-gradient-background'),
    decoration: const BoxDecoration(gradient: _withdrawalDetailGradient),
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
          '提现详情',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('wallet-withdrawal-detail-refresh'),
            tooltip: '刷新状态',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    ),
  );

  Widget _buildBody() {
    final withdrawal = _withdrawal;
    if (withdrawal == null) {
      return _DetailStateView(
        loading: _loading,
        message: _error ?? '提现详情加载失败',
        onRetry: _load,
      );
    }

    final details = <(String, String)>[
      ('提现单号', withdrawal.withdrawalNo),
      ('收款方式', '支付宝'),
      ('支付宝账号', withdrawal.payeeAccountMasked),
      ('实名姓名', withdrawal.payeeNameMasked),
      ('申请时间', _formatDetailTime(withdrawal.createdAt)),
      if (withdrawal.reviewedAt != null)
        ('审核时间', _formatDetailTime(withdrawal.reviewedAt!)),
      if (withdrawal.completedAt != null)
        ('完成时间', _formatDetailTime(withdrawal.completedAt!)),
      if (withdrawal.rejectReason != null) ('拒绝原因', withdrawal.rejectReason!),
      if (withdrawal.failureMessage != null)
        ('失败原因', withdrawal.failureMessage!),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WithdrawalStatusSummary(withdrawal: withdrawal),
                  const SizedBox(height: 12),
                  _WithdrawalDetailSection(details: details),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _RefreshError(message: _error!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalStatusSummary extends StatelessWidget {
  const _WithdrawalStatusSummary({required this.withdrawal});

  final WalletWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(withdrawal.status);
    return Semantics(
      label:
          '提现金额，${withdrawal.amount.toStringAsFixed(2)} 元，状态，${withdrawal.status.label}',
      child: DecoratedBox(
        key: const ValueKey('wallet-withdrawal-detail-status'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3E8F2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    _statusIcon(withdrawal.status),
                    size: 30,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                withdrawal.status.label,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _statusDescription(withdrawal.status),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '¥${withdrawal.amount.toStringAsFixed(2)}',
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '支付宝提现',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WithdrawalDetailSection extends StatelessWidget {
  const _WithdrawalDetailSection({required this.details});

  final List<(String, String)> details;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('wallet-withdrawal-detail-info'),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE3E8F2)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '提现信息',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < details.length; index++) ...[
            _DetailRow(details[index].$1, details[index].$2),
            if (index != details.length - 1)
              const Divider(height: 1, color: Color(0xFFF0F2F5)),
          ],
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailStateView extends StatelessWidget {
  const _DetailStateView({
    required this.loading,
    required this.message,
    required this.onRetry,
  });

  final bool loading;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: loading
        ? const CircularProgressIndicator(color: AppColors.primary)
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: Color(0xFFAAB2C0),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ),
  );
}

class _RefreshError extends StatelessWidget {
  const _RefreshError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F0),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.accent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

Color _statusColor(WalletWithdrawalStatus status) => switch (status) {
  WalletWithdrawalStatus.pendingReview => const Color(0xFFD97706),
  WalletWithdrawalStatus.processing => const Color(0xFF397EDB),
  WalletWithdrawalStatus.succeeded => const Color(0xFF16845B),
  WalletWithdrawalStatus.rejected ||
  WalletWithdrawalStatus.failed => const Color(0xFFC2413B),
  WalletWithdrawalStatus.unknown => const Color(0xFF6A7582),
};
IconData _statusIcon(WalletWithdrawalStatus status) => switch (status) {
  WalletWithdrawalStatus.pendingReview => Icons.schedule_rounded,
  WalletWithdrawalStatus.processing => Icons.sync_rounded,
  WalletWithdrawalStatus.succeeded => Icons.check_circle_outline,
  WalletWithdrawalStatus.rejected ||
  WalletWithdrawalStatus.failed => Icons.error_outline,
  WalletWithdrawalStatus.unknown => Icons.help_outline,
};
String _statusDescription(WalletWithdrawalStatus status) => switch (status) {
  WalletWithdrawalStatus.pendingReview => '提现申请已提交，请等待审核',
  WalletWithdrawalStatus.processing => '正在处理中，请留意到账状态',
  WalletWithdrawalStatus.succeeded => '提现已完成',
  WalletWithdrawalStatus.rejected => '提现申请未通过',
  WalletWithdrawalStatus.failed => '提现未完成',
  WalletWithdrawalStatus.unknown => '状态更新中，请稍后刷新',
};
String _formatDetailTime(DateTime value) =>
    value.toLocal().toString().substring(0, 16);
