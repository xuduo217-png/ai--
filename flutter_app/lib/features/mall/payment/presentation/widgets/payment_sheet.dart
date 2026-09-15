import 'dart:async';

import 'package:flutter/material.dart';

import '../../../order/domain/order_models.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/payment_models.dart';
import '../payment_controller.dart';
import '../payment_sheet_session.dart';

Future<PaymentFlowResult?> showPaymentSheet(
  BuildContext context, {
  required PaymentController controller,
  required ShopOrder order,
  OrderPayment? initialPayment,
}) {
  return _showPaymentBottomSheet(
    context,
    loading: () => controller.loading,
    child: PaymentSheet(
      controller: controller,
      order: order,
      initialPayment: initialPayment,
    ),
  );
}

Future<PaymentFlowResult?> showUnifiedPaymentSheet(
  BuildContext context, {
  required PaymentSheetSession session,
  required PaymentSheetSummary summary,
}) {
  return _showPaymentBottomSheet(
    context,
    loading: () => session.loading,
    child: _UnifiedPaymentSheet(session: session, summary: summary),
  );
}

Future<PaymentFlowResult?> _showPaymentBottomSheet(
  BuildContext context, {
  required bool Function() loading,
  required Widget child,
}) {
  return showModalBottomSheet<PaymentFlowResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: !loading(),
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: const Color(0x990F172A),
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => child,
  );
}

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.controller,
    required this.order,
    this.initialPayment,
  });

  final PaymentController controller;
  final ShopOrder order;
  final OrderPayment? initialPayment;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  late final _OrderPaymentSheetSession _session;

  @override
  void initState() {
    super.initState();
    _session = _OrderPaymentSheetSession(
      controller: widget.controller,
      order: widget.order,
      initialPayment: widget.initialPayment,
    );
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _UnifiedPaymentSheet(
      session: _session,
      summary: PaymentSheetSummary(
        amount: widget.order.totalAmount,
        referenceLabel: '订单',
        referenceValue: widget.order.orderNo,
        timeoutMessage: '支付已超时，请在订单详情确认订单状态',
      ),
    );
  }
}

class _UnifiedPaymentSheet extends StatefulWidget {
  const _UnifiedPaymentSheet({required this.session, required this.summary});

  final PaymentSheetSession session;
  final PaymentSheetSummary summary;

  @override
  State<_UnifiedPaymentSheet> createState() => _UnifiedPaymentSheetState();
}

class _UnifiedPaymentSheetState extends State<_UnifiedPaymentSheet> {
  static const _initialSeconds = 30 * 60;
  PaymentChannel _channel = PaymentChannel.alipay;
  int _remainingSeconds = _initialSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.session.loadWalletBalance();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        Navigator.pop(
          context,
          PaymentFlowResult(
            PaymentFlowStatus.processing,
            widget.summary.timeoutMessage,
          ),
        );
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) => PopScope(
        canPop: !widget.session.loading,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.paddingOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择支付方式',
                            style: TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: widget.session.loading
                          ? null
                          : () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(36),
                        maximumSize: const Size.square(36),
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: const Color(0xFF4B5563),
                        disabledBackgroundColor: const Color(0xFFF7F7F8),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  key: const ValueKey('payment-summary'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8EBF5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '待支付',
                        style: TextStyle(
                          color: Color(0xFF7C8390),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              '¥',
                              style: TextStyle(
                                color: Color(0xFFE94F4F),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              widget.summary.amount.toStringAsFixed(2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE94F4F),
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 17,
                                  color: _remainingSeconds <= 300
                                      ? const Color(0xFFD84949)
                                      : const Color(0xFFC87516),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatTime(_remainingSeconds),
                                  style: TextStyle(
                                    color: _remainingSeconds <= 300
                                        ? const Color(0xFFD84949)
                                        : const Color(0xFFC87516),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      const Divider(height: 1, color: Color(0xFFE3E6EF)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 16,
                            color: Color(0xFF8A909D),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${widget.summary.referenceLabel} ${widget.summary.referenceValue}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF707786),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '支付方式',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _method(
                  PaymentChannel.alipay,
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFF1677FF),
                  iconBackground: const Color(0xFFEAF3FF),
                  title: '支付宝',
                  subtitle: '支付宝 App 安全支付',
                  badge: '推荐',
                ),
                const SizedBox(height: 8),
                _method(
                  PaymentChannel.balance,
                  icon: Icons.wallet_outlined,
                  iconColor: const Color(0xFF188864),
                  iconBackground: const Color(0xFFE9F7F2),
                  title: '余额支付',
                  subtitle: widget.session.walletLoading
                      ? '正在查询账户余额'
                      : widget.session.walletErrorMessage != null
                      ? '余额加载失败，点击重试'
                      : '可用余额 ¥${widget.session.walletBalance.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _method(
                  PaymentChannel.wechat,
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: const Color(0xFF9CA3AF),
                  iconBackground: const Color(0xFFF3F4F6),
                  title: '微信支付',
                  subtitle: '暂未开放',
                  enabled: false,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.session.loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: mallPrimary,
                    disabledBackgroundColor: const Color(0xFFD9DEEF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: widget.session.loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 19),
                            const SizedBox(width: 8),
                            Text(
                              '确认支付 ¥${widget.summary.amount.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _method(
    PaymentChannel channel, {
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    String? badge,
    bool enabled = true,
  }) {
    final isEnabled = enabled && !widget.session.loading;
    final selected = _channel == channel;

    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: selected,
      label: '$title，$subtitle',
      child: AnimatedContainer(
        key: ValueKey('payment-method-${channel.name}'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected && isEnabled ? const Color(0xFFF4F6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected && isEnabled
                ? mallPrimary
                : const Color(0xFFE5E7EB),
            width: selected && isEnabled ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled
                ? () {
                    setState(() => _channel = channel);
                    if (channel == PaymentChannel.balance &&
                        widget.session.walletErrorMessage != null) {
                      widget.session.loadWalletBalance();
                    }
                  }
                : null,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: iconColor, size: 23),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isEnabled
                                        ? const Color(0xFF262B35)
                                        : const Color(0xFF9CA3AF),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (badge != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EDFF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      color: Color(0xFF5875E8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isEnabled
                                  ? const Color(0xFF7C8390)
                                  : const Color(0xFFB5BAC4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isEnabled)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: selected ? mallPrimary : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? mallPrimary
                                : const Color(0xFFB8BEC9),
                            width: selected ? 0 : 1.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 15,
                              )
                            : null,
                      )
                    else
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFFB5BAC4),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final result = await widget.session.submit(_channel);
    if (!mounted) return;
    if (result.status == PaymentFlowStatus.insufficientBalance ||
        result.status == PaymentFlowStatus.unavailable) {
      showMallMessage(context, result.message, error: true);
      return;
    }
    Navigator.pop(context, result);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }
}

class _OrderPaymentSheetSession extends ChangeNotifier
    implements PaymentSheetSession {
  _OrderPaymentSheetSession({
    required this.controller,
    required this.order,
    required this.initialPayment,
  }) {
    controller.addListener(notifyListeners);
  }

  final PaymentController controller;
  final ShopOrder order;
  final OrderPayment? initialPayment;

  @override
  bool get loading => controller.loading;

  @override
  bool get walletLoading => controller.walletLoading;

  @override
  double get walletBalance => controller.walletBalance;

  @override
  String? get walletErrorMessage => controller.errorMessage;

  @override
  Future<void> loadWalletBalance() => controller.loadWalletBalance();

  @override
  Future<PaymentFlowResult> submit(PaymentChannel channel) => controller.submit(
    order: order,
    channel: channel,
    initialPayment: initialPayment,
  );

  @override
  void dispose() {
    controller.removeListener(notifyListeners);
    super.dispose();
  }
}
