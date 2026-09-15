import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../mall/payment/domain/payment_models.dart';
import '../../domain/wallet_models.dart';
import '../wallet_recharge_controller.dart';

const _rechargeHeaderGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
);

class WalletRechargePage extends StatefulWidget {
  const WalletRechargePage({
    super.key,
    required this.gateway,
    required this.paymentGateway,
  });

  final WalletGateway gateway;
  final PaymentGateway paymentGateway;

  @override
  State<WalletRechargePage> createState() => _WalletRechargePageState();
}

class _WalletRechargePageState extends State<WalletRechargePage> {
  late final WalletRechargeController _controller;
  final TextEditingController _amountController = TextEditingController();
  double? _selectedPreset;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _controller = WalletRechargeController(
      widget.gateway,
      widget.paymentGateway,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _controller.dispose();
    super.dispose();
  }

  String? _validateAmount(WalletRechargeConfig config) {
    final text = _amountController.text.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
      return '请输入正确的充值金额，最多保留两位小数';
    }
    final amount = double.tryParse(text);
    if (amount == null || !amount.isFinite) return '请输入正确的充值金额';
    if (amount < config.minAmount || amount > config.maxAmount) {
      return '单次充值金额为 ¥${config.minAmount.toStringAsFixed(2)} - ¥${config.maxAmount.toStringAsFixed(2)}';
    }
    return null;
  }

  Future<void> _submit(WalletRechargeConfig config) async {
    final validation = _validateAmount(config);
    setState(() => _amountError = validation);
    if (validation != null) return;

    final amount = double.parse(
      _amountController.text.trim(),
    ).toStringAsFixed(2);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认充值'),
        content: Text('将通过支付宝充值 ¥$amount'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            key: const ValueKey('wallet-recharge-cancel'),
            style: TextButton.styleFrom(
              minimumSize: const Size(72, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('wallet-recharge-confirm'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('去支付'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _controller.submit(amount);
    if (!mounted) return;
    if (result == null) {
      _showMessage(_controller.error == null ? '充值发起失败，请稍后重试' : '充值发起失败');
      return;
    }
    switch (result.status) {
      case WalletRechargeFlowStatus.succeeded:
        _showMessage(result.message);
        Navigator.of(context).pop(true);
      case WalletRechargeFlowStatus.cancelled:
      case WalletRechargeFlowStatus.processing:
      case WalletRechargeFlowStatus.failed:
        _showMessage(result.message);
    }
  }

  void _selectPreset(double value) {
    setState(() {
      _selectedPreset = value;
      _amountError = null;
      _amountController.text = value.toStringAsFixed(
        value == value.roundToDouble() ? 0 : 2,
      );
      _amountController.selection = TextSelection.collapsed(
        offset: _amountController.text.length,
      );
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('wallet-recharge-gradient-background'),
    decoration: const BoxDecoration(gradient: _rechargeHeaderGradient),
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
          '钱包充值',
          key: ValueKey('wallet-recharge-title'),
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
        builder: (context, _) => _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_controller.loading && _controller.config == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final config = _controller.config;
    if (config == null) {
      return _RechargeError(onRetry: _controller.load);
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _RechargePolicyBand(),
                const SizedBox(height: 12),
                _RechargeAmountSection(
                  config: config,
                  controller: _amountController,
                  selectedPreset: _selectedPreset,
                  amountError: _amountError,
                  submitting: _controller.submitting,
                  onPresetSelected: _selectPreset,
                  onAmountChanged: () => setState(() {
                    _selectedPreset = null;
                    _amountError = null;
                  }),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('wallet-recharge-submit'),
                onPressed: config.enabled && !_controller.submitting
                    ? () => _submit(config)
                    : null,
                icon: _controller.submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(_controller.submitting ? '正在确认支付结果' : '支付宝充值'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RechargePolicyBand extends StatelessWidget {
  const _RechargePolicyBand();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F5FF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD8E0FA)),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            '充值到账余额可用于消费或提现',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RechargeAmountSection extends StatelessWidget {
  const _RechargeAmountSection({
    required this.config,
    required this.controller,
    required this.selectedPreset,
    required this.amountError,
    required this.submitting,
    required this.onPresetSelected,
    required this.onAmountChanged,
  });

  final WalletRechargeConfig config;
  final TextEditingController controller;
  final double? selectedPreset;
  final String? amountError;
  final bool submitting;
  final ValueChanged<double> onPresetSelected;
  final VoidCallback onAmountChanged;

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
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                '充值金额',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 10.0;
              final chipWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: config.presets
                    .map(
                      (amount) => SizedBox(
                        width: chipWidth,
                        child: ChoiceChip(
                          key: ValueKey('wallet-recharge-preset-$amount'),
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              '¥${amount.toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          selected: selectedPreset == amount,
                          showCheckmark: false,
                          selectedColor: const Color(0xFFE7EEFF),
                          backgroundColor: Colors.white,
                          disabledColor: const Color(0xFFF3F4F6),
                          side: BorderSide(
                            color: selectedPreset == amount
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle: TextStyle(
                            color: selectedPreset == amount
                                ? AppColors.primary
                                : AppColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: config.enabled && !submitting
                              ? (_) => onPresetSelected(amount)
                              : null,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('wallet-recharge-amount'),
            controller: controller,
            enabled: config.enabled && !submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_moneyInputFormatter],
            decoration: InputDecoration(
              labelText: '其他金额',
              hintText: '请输入充值金额',
              prefixText: '¥ ',
              errorText: amountError,
            ),
            onChanged: (_) => onAmountChanged(),
          ),
          const SizedBox(height: 8),
          Text(
            '单次限额 ¥${config.minAmount.toStringAsFixed(2)} - ¥${config.maxAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (!config.enabled) ...[
            const SizedBox(height: 10),
            Text(
              config.unavailableReason ?? '支付宝充值服务暂不可用',
              style: const TextStyle(color: Color(0xFFB45309), fontSize: 13),
            ),
          ],
        ],
      ),
    ),
  );
}

class _RechargeError extends StatelessWidget {
  const _RechargeError({required this.onRetry});

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
        const Text('充值配置加载失败', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      ],
    ),
  );
}

final TextInputFormatter _moneyInputFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) {
    if (RegExp(r'^\d{0,8}(\.\d{0,2})?$').hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  },
);
