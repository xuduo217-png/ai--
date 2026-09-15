import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../checkout/domain/checkout_models.dart';
import '../../../payment/domain/payment_models.dart';
import '../../../payment/presentation/payment_controller.dart';
import '../../../payment/presentation/widgets/payment_sheet.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/order_models.dart';
import '../../domain/after_sale_models.dart';
import 'after_sale_pages.dart';
import 'shipping_page.dart';
import '../order_controller.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.orderId,
    required this.gateway,
    required this.checkoutGateway,
    required this.paymentGateway,
    this.afterSaleGateway,
  });

  final int orderId;
  final OrderGateway gateway;
  final CheckoutGateway checkoutGateway;
  final PaymentGateway paymentGateway;
  final AfterSaleGateway? afterSaleGateway;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late final OrderDetailController _controller;
  late final PaymentController _paymentController;
  Timer? _countdownTimer;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _controller = OrderDetailController(widget.gateway, widget.orderId)..load();
    _paymentController = PaymentController(
      checkoutGateway: widget.checkoutGateway,
      orderGateway: widget.gateway,
      paymentGateway: widget.paymentGateway,
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _controller.order?.canPay != true) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _paymentController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final order = _controller.order;
        return DecoratedBox(
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
              toolbarHeight: 58,
              centerTitle: true,
              title: const Text(
                '订单详情',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: _body(),
            bottomNavigationBar: order == null ? null : _actions(order),
          ),
        );
      },
    );
  }

  Widget _statusCard(ShopOrder order, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(height: 4, color: color),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(_statusIcon(order.status), size: 64, color: color),
                const SizedBox(height: 10),
                Text(
                  order.status.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (order.canPay)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      children: [
                        const Text(
                          '请在订单有效期内完成支付',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                        if (_remainingPaymentTime(order)
                            case final remaining?) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: Color(0xFFC87516),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '支付倒计时 ${_formatCountdown(remaining)}',
                                style: const TextStyle(
                                  color: Color(0xFFC87516),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_controller.loading && _controller.order == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null || _controller.order == null) {
      return MallStateView(
        icon: Icons.receipt_long_outlined,
        message: _controller.errorMessage ?? '订单不存在',
        onRetry: _controller.load,
      );
    }
    final order = _controller.order!;
    final color = _statusColor(order.status);
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 2, bottom: 24),
        children: [
          _statusCard(order, color),
          if (order.receiverName?.isNotEmpty == true)
            _section(
              '收货信息',
              Padding(
                padding: const EdgeInsets.only(left: 27),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.receiverName ?? ''}  ${order.receiverPhone ?? ''}',
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.shippingAddress ?? '',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              icon: Icons.location_on_outlined,
            ),
          _section(
            '商品信息',
            Column(
              children: order.items.map(_productItem).toList(growable: false),
            ),
          ),
          if (order.charityDonationAmount case final amount? when amount > 0)
            _charityDonationCard(amount),
          _section(
            '金额明细',
            Column(
              children: [
                _infoRow('商品总额', '¥${order.originalAmount.toStringAsFixed(2)}'),
                if (order.couponDiscount > 0)
                  _infoRow(
                    '优惠券',
                    '-¥${order.couponDiscount.toStringAsFixed(2)}',
                    valueColor: const Color(0xFFE29A22),
                  ),
                _infoRow('运费', '+¥0.00'),
                const Divider(),
                _infoRow(
                  '实付金额',
                  '¥${order.totalAmount.toStringAsFixed(2)}',
                  strong: true,
                  valueColor: const Color(0xFFE95656),
                ),
              ],
            ),
          ),
          if (order.shippedAt != null)
            _section(
              '物流信息',
              order.trackingNumber?.isNotEmpty == true
                  ? _trackingRow(order.trackingNumber!)
                  : const Text(
                      '卖家已发货，未填写物流单号',
                      style: TextStyle(color: Color(0xFF667085)),
                    ),
              icon: Icons.local_shipping_outlined,
            ),
          if (order.afterSaleSummary case final afterSale?)
            _section(
              '售后信息',
              Column(
                children: [
                  _infoRow('售后编号', afterSale.afterSaleNo),
                  _infoRow('售后状态', _afterSaleLabel(afterSale.status)),
                  _infoRow(
                    '退款金额',
                    '¥${afterSale.refundAmount.toStringAsFixed(2)}',
                  ),
                  if (widget.afterSaleGateway != null &&
                      order.hasAction('view_after_sale')) ...[
                    const Divider(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('order-after-sale-detail-button'),
                        onPressed: _acting
                            ? null
                            : () => _openAfterSale(
                                order,
                                widget.afterSaleGateway!,
                              ),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('查看售后详情'),
                      ),
                    ),
                  ],
                ],
              ),
              icon: Icons.support_agent_outlined,
            ),
          _section(
            '订单信息',
            Column(
              children: [
                _infoRow('订单编号', order.orderNo),
                if (order.createdAt != null)
                  _infoRow('创建时间', _formatDate(order.createdAt!)),
                if (order.paidAt != null)
                  _infoRow('支付时间', _formatDate(order.paidAt!)),
                if (order.shippedAt != null)
                  _infoRow('发货时间', _formatDate(order.shippedAt!)),
                if (order.autoConfirmAt != null &&
                    order.status == ShopOrderStatus.shipped)
                  _infoRow('自动确认时间', _formatDate(order.autoConfirmAt!)),
                if (order.completedAt != null)
                  _infoRow('完成时间', _formatDate(order.completedAt!)),
                if (order.cancelReason?.isNotEmpty == true)
                  _infoRow('取消原因', order.cancelReason!),
                if (order.remark?.isNotEmpty == true)
                  _infoRow('订单备注', order.remark!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _charityDonationCard(double amount) {
    return Container(
      key: const ValueKey('order-charity-donation-card'),
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9EEE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F4EA),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF177A50),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '本单公益',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '爱心金额',
                    style: TextStyle(color: Color(0xFF738078), fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFC87516),
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '感谢你的每一次选择，让爱心抵达更多需要帮助的毛孩子。',
            style: TextStyle(
              color: Color(0xFF5F6F65),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackingRow(String trackingNumber) {
    return Row(
      children: [
        const SizedBox(
          width: 82,
          child: Text('物流单号', style: TextStyle(color: Color(0xFF7E8592))),
        ),
        Expanded(
          child: SelectableText(trackingNumber, textAlign: TextAlign.right),
        ),
        IconButton(
          tooltip: '复制物流单号',
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          onPressed: () => _copyTracking(trackingNumber),
          icon: const Icon(Icons.copy_outlined),
        ),
      ],
    );
  }

  Widget _productItem(ShopOrderItem item) {
    final skuName = item.skuName?.trim();
    final spec = skuName != null && skuName.isNotEmpty && skuName != '默认规格'
        ? '$skuName  '
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: MallNetworkImage(
              url: item.productImage,
              width: 76,
              height: 76,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${spec}x${item.quantity}',
                  style: const TextStyle(color: Color(0xFF8A909D)),
                ),
                const SizedBox(height: 6),
                Text(
                  '¥${item.price.toStringAsFixed(2)}',
                  style: const TextStyle(color: mallPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: mallPrimary),
                const SizedBox(width: 7),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool strong = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF7E8592)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontWeight: strong ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _actions(ShopOrder order) {
    final tradeGateway = widget.gateway is SecondHandOrderGateway
        ? widget.gateway as SecondHandOrderGateway
        : null;
    final afterSaleGateway = widget.afterSaleGateway;
    final actionButtons = <Widget>[];
    if (order.canCancel) {
      actionButtons.add(
        OutlinedButton(
          onPressed: _acting ? null : _cancel,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            foregroundColor: const Color(0xFF6B7280),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            shape: const StadiumBorder(),
          ),
          child: const Text('取消订单'),
        ),
      );
    }
    if (order.canPay) {
      actionButtons.add(
        FilledButton(
          onPressed: _acting ? null : _pay,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: mallPrimary,
            shape: const StadiumBorder(),
          ),
          child: const Text('立即支付'),
        ),
      );
    }
    if (order.canConfirm) {
      actionButtons.add(
        FilledButton(
          onPressed: _acting ? null : _confirm,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: const Color(0xFF10B981),
            shape: const StadiumBorder(),
          ),
          child: const Text('确认收货'),
        ),
      );
    }
    if (order.hasAction('ship') && tradeGateway != null) {
      actionButtons.add(
        FilledButton.icon(
          onPressed: _acting ? null : () => _openShipping(order, tradeGateway),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('确认发货'),
        ),
      );
    }
    if (order.hasAction('update_tracking') && tradeGateway != null) {
      actionButtons.add(
        OutlinedButton.icon(
          onPressed: _acting
              ? null
              : () => _openShipping(order, tradeGateway, updateOnly: true),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('补充物流单号'),
        ),
      );
    }
    if (order.hasAction('apply_after_sale') && afterSaleGateway != null) {
      actionButtons.add(
        OutlinedButton.icon(
          onPressed: _acting
              ? null
              : () => _applyAfterSale(order, afterSaleGateway),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.support_agent_outlined),
          label: Text(order.afterSaleSummary == null ? '申请售后' : '重新申请售后'),
        ),
      );
    }
    if (order.afterSaleSummary != null && afterSaleGateway != null) {
      final (label, icon) = order.hasAction('handle_after_sale')
          ? ('处理售后', Icons.fact_check_outlined)
          : order.hasAction('request_arbitration')
          ? ('申请平台仲裁', Icons.gavel_outlined)
          : order.hasAction('submit_return')
          ? ('提交退货', Icons.local_shipping_outlined)
          : order.hasAction('confirm_return')
          ? ('确认收到退货', Icons.inventory_2_outlined)
          : (null, null);
      if (label != null && icon != null) {
        actionButtons.add(
          FilledButton.icon(
            onPressed: _acting
                ? null
                : () => _openAfterSale(order, afterSaleGateway),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: Icon(icon),
            label: Text(label),
          ),
        );
      }
    }
    if (actionButtons.isEmpty) return null;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                for (var index = 0; index < actionButtons.length; index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(child: actionButtons[index]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openShipping(
    ShopOrder order,
    SecondHandOrderGateway gateway, {
    bool updateOnly = false,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShippingPage(
          order: order,
          gateway: gateway,
          updateOnly: updateOnly,
        ),
      ),
    );
    if (mounted) await _controller.load();
  }

  Future<void> _applyAfterSale(
    ShopOrder order,
    AfterSaleGateway gateway,
  ) async {
    final result = await Navigator.of(context).push<OrderAfterSale>(
      MaterialPageRoute(
        builder: (_) => ApplyAfterSalePage(order: order, gateway: gateway),
      ),
    );
    if (!mounted) return;
    await _controller.load();
    if (result != null && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              AfterSaleDetailPage(afterSaleId: result.id, gateway: gateway),
        ),
      );
      if (mounted) await _controller.load();
    }
  }

  Future<void> _openAfterSale(ShopOrder order, AfterSaleGateway gateway) async {
    final afterSaleId = order.afterSaleSummary?.id;
    if (afterSaleId == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AfterSaleDetailPage(afterSaleId: afterSaleId, gateway: gateway),
      ),
    );
    if (mounted) await _controller.load();
  }

  Future<void> _copyTracking(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showMallMessage(context, '物流单号已复制');
  }

  Future<void> _cancel() async {
    if (!await showMallConfirm(
      context,
      title: '取消订单',
      message: '确定取消该订单吗？',
      confirmText: '取消订单',
    )) {
      return;
    }
    await _run(_controller.cancel, '订单已取消');
  }

  Future<void> _confirm() async {
    if (!await showMallConfirm(
      context,
      title: '确认收货',
      message: '确认已经收到商品吗？',
      confirmText: '确认收货',
    )) {
      return;
    }
    await _run(_controller.confirm, '已确认收货');
  }

  Future<void> _pay() async {
    final order = _controller.order;
    if (order == null) return;
    final result = await showPaymentSheet(
      context,
      controller: _paymentController,
      order: order,
    );
    if (!mounted) return;
    if (result != null) {
      showMallMessage(context, result.message, error: !result.paid);
    }
    await _controller.load();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _acting = true);
    try {
      await action();
      if (mounted) showMallMessage(context, success);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Duration? _remainingPaymentTime(ShopOrder order) {
    final createdAt = order.createdAt;
    if (createdAt == null) return null;
    final remaining = createdAt
        .add(const Duration(minutes: 30))
        .difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

Color _statusColor(ShopOrderStatus status) {
  return switch (status) {
    ShopOrderStatus.pending => const Color(0xFFFF8800),
    ShopOrderStatus.paid => const Color(0xFF1677FF),
    ShopOrderStatus.shipped => const Color(0xFF07A85A),
    _ => const Color(0xFF9096A2),
  };
}

IconData _statusIcon(ShopOrderStatus status) {
  return switch (status) {
    ShopOrderStatus.pending => Icons.schedule,
    ShopOrderStatus.paid => Icons.inventory_2_outlined,
    ShopOrderStatus.shipped => Icons.local_shipping_outlined,
    ShopOrderStatus.completed => Icons.check_circle_outline,
    ShopOrderStatus.cancelled => Icons.cancel_outlined,
    _ => Icons.receipt_long_outlined,
  };
}

String _afterSaleLabel(String status) => AfterSaleStatus.fromJson(status).label;

String _formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatCountdown(Duration value) {
  final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
