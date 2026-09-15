import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/wallet_models.dart';
import '../wallet_withdrawal_controller.dart';
import 'wallet_withdrawal_detail_page.dart';

const _withdrawalHeaderGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
);

class WalletWithdrawalPage extends StatefulWidget {
  const WalletWithdrawalPage({super.key, required this.gateway});
  final WalletGateway gateway;
  @override
  State<WalletWithdrawalPage> createState() => _WalletWithdrawalPageState();
}

class _WalletWithdrawalPageState extends State<WalletWithdrawalPage> {
  late final WalletWithdrawalController _controller;
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _account = TextEditingController();
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = WalletWithdrawalController(widget.gateway);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    _name.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _fillAll() {
    final config = _controller.config;
    if (config == null) return;
    final amount = [
      config.availableBalance,
      config.maxAmountPerRequest,
      config.remainingDailyAmount,
    ].reduce((a, b) => a < b ? a : b);
    _amount.text = amount.toStringAsFixed(2);
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final amount = double.parse(_amount.text);
    final config = _controller.config!;
    if (amount < config.minAmount ||
        amount > config.maxAmountPerRequest ||
        amount > config.remainingDailyAmount ||
        amount > config.availableBalance) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提现金额超出当前可用范围')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认提现信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('提现金额：¥${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('支付宝账号：${_maskAccount(_account.text.trim())}'),
            const SizedBox(height: 8),
            Text('实名姓名：${_maskName(_name.text.trim())}'),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('返回修改'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('wallet-withdraw-confirm'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认申请'),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _controller.submit(
      amount: _amount.text,
      alipayAccount: _account.text,
      payeeRealName: _name.text,
    );
    if (result != null && mounted) {
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => WalletWithdrawalDetailPage(
            gateway: widget.gateway,
            withdrawalId: result.id,
            initialWithdrawal: result,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('wallet-withdrawal-gradient-background'),
    decoration: const BoxDecoration(gradient: _withdrawalHeaderGradient),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 52,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        title: const Text(
          '支付宝提现',
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
        builder: (context, _) => _buildBody(context),
      ),
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (_controller.loading && _controller.config == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final config = _controller.config;
    if (config == null) {
      return _ErrorState(
        message: _controller.error ?? '提现信息加载失败',
        onRetry: _controller.load,
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          _buildBalanceSummary(config),
          const SizedBox(height: 12),
          _FormSection(
            icon: Icons.payments_outlined,
            title: '提现金额',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('wallet-withdraw-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,8}(?:\.\d{0,2})?'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: '输入提现金额',
                    hintText: '请输入金额',
                    prefixText: '¥ ',
                    suffixIcon: TextButton(
                      key: const ValueKey('wallet-withdraw-all'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: _fillAll,
                      child: const Text('全部提现'),
                    ),
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^(?:0\.(?:0[1-9]|[1-9]\d?)|[1-9]\d{0,7}(?:\.\d{1,2})?)$',
                      ).hasMatch(value ?? '')
                      ? null
                      : '请输入大于 0 且最多两位小数的金额',
                ),
                const SizedBox(height: 8),
                Text(
                  '最低 ¥${config.minAmount.toStringAsFixed(2)} · 单笔最高 ¥${config.maxAmountPerRequest.toStringAsFixed(2)} · 今日剩余 ¥${config.remainingDailyAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _FormSection(
            icon: Icons.account_balance_wallet_outlined,
            title: '收款信息',
            child: Column(
              children: [
                TextFormField(
                  key: const ValueKey('wallet-withdraw-account'),
                  controller: _account,
                  maxLength: 128,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '支付宝账号（手机号/邮箱）',
                    hintText: '请输入支付宝账号',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.length >= 5 &&
                            !text.contains(RegExp(r'[\x00-\x1F\x7F]'))
                        ? null
                        : '请输入正确的支付宝账号';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('wallet-withdraw-name'),
                  controller: _name,
                  maxLength: 64,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '支付宝实名姓名',
                    hintText: '请输入实名姓名',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.length >= 2 &&
                            !text.contains(RegExp(r'[\x00-\x1F\x7F]'))
                        ? null
                        : '请输入支付宝实名姓名';
                  },
                ),
              ],
            ),
          ),
          if (_controller.error != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: _controller.error!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey('wallet-withdraw-submit'),
              onPressed:
                  _controller.submitting ||
                      !config.enabled ||
                      config.hasActiveWithdrawal
                  ? null
                  : _submit,
              icon: _controller.submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(_controller.submitting ? '提交中...' : '确认提现'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '提现申请提交后将进入审核，到账状态可在提现记录中查看。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary(WalletWithdrawalConfig config) {
    return Semantics(
      label: '可提现余额，${config.availableBalance.toStringAsFixed(2)} 元',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3E8F2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '可提现余额',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¥${config.availableBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '支付宝到账',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _maskAccount(String value) {
  if (value.length <= 4) return '${value.substring(0, 1)}***';
  return '${value.substring(0, 2)}***${value.substring(value.length - 2)}';
}

String _maskName(String value) => value.length <= 1
    ? '*'
    : '${value.substring(0, 1)}${List.filled(value.length - 1, '*').join()}';

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 44,
          color: Color(0xFFAAB2C0),
        ),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    ),
  );
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE3E8F2)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

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
            size: 18,
            color: AppColors.accent,
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
