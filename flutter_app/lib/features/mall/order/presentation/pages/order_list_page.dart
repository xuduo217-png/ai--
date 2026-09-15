import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/mall_widgets.dart';
import '../../domain/order_models.dart';
import '../order_controller.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({
    super.key,
    required this.gateway,
    required this.onOrder,
    this.viewRole = OrderViewRole.buyer,
  });

  final OrderGateway gateway;
  final Future<void> Function(int orderId) onOrder;
  final OrderViewRole viewRole;

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  late final OrderListController _controller;
  int _selectedTabIndex = 0;
  int _pendingReceiptCount = 0;

  List<(String, ShopOrderStatus?, String?)> get _tabs =>
      widget.viewRole == OrderViewRole.seller
      ? const [
          ('全部', null, null),
          ('待发货', ShopOrderStatus.paid, null),
          ('待收货', ShopOrderStatus.shipped, null),
          ('售后中', null, 'active'),
          ('已完成', ShopOrderStatus.completed, null),
        ]
      : const [
          ('全部', null, null),
          ('待付款', ShopOrderStatus.pending, null),
          ('待发货', ShopOrderStatus.paid, null),
          ('待收货', ShopOrderStatus.shipped, null),
          ('售后', null, 'any'),
          ('已完成', ShopOrderStatus.completed, null),
        ];

  @override
  void initState() {
    super.initState();
    _controller = OrderListController(widget.gateway, viewRole: widget.viewRole)
      ..load();
    unawaited(_loadActionSummary());
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
      key: const ValueKey('order-gradient-background'),
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
          centerTitle: true,
          title: Text(
            widget.viewRole == OrderViewRole.seller ? '我卖出的' : '我买到的',
            style: TextStyle(
              color: primary,
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
              _filterTabs(primary),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterTabs(Color primary) {
    return Container(
      key: const ValueKey('order-filter-tabs'),
      height: 44,
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E8F2)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final filter = _tabs[index];
          final selected = index == _selectedTabIndex;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label:
                  _showsPendingReceiptBadge(filter) && _pendingReceiptCount > 0
                  ? '${filter.$1}，$_pendingReceiptCount 笔待处理'
                  : filter.$1,
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  key: ValueKey('order-filter-tab-$index'),
                  onTap: () => _selectTab(index),
                  borderRadius: BorderRadius.circular(7),
                  child: AnimatedContainer(
                    key: ValueKey('order-filter-tab-surface-$index'),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            filter.$1,
                            maxLines: 1,
                            style: TextStyle(
                              color: selected
                                  ? primary
                                  : const Color(0xFF6B7280),
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (_showsPendingReceiptBadge(filter) &&
                              _pendingReceiptCount > 0) ...[
                            const SizedBox(width: 4),
                            _OrderTabBadge(count: _pendingReceiptCount),
                          ],
                        ],
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
  }

  void _selectTab(int index) {
    if (index == _selectedTabIndex) return;
    setState(() => _selectedTabIndex = index);
    unawaited(
      _controller.load(
        filter: _tabs[index].$2,
        afterSaleFilter: _tabs[index].$3,
        replaceFilter: true,
      ),
    );
  }

  bool _showsPendingReceiptBadge((String, ShopOrderStatus?, String?) filter) =>
      widget.viewRole == OrderViewRole.buyer &&
      filter.$2 == ShopOrderStatus.shipped;

  Future<void> _loadActionSummary() async {
    if (widget.viewRole != OrderViewRole.buyer) return;
    final gateway = widget.gateway;
    if (gateway is! SecondHandOrderGateway) return;
    final actionGateway = gateway as SecondHandOrderGateway;
    try {
      final summary = await actionGateway.loadActionSummary();
      if (mounted && _pendingReceiptCount != summary.pendingReceipt) {
        setState(() => _pendingReceiptCount = summary.pendingReceipt);
      }
    } catch (_) {
      // 待办提示失败不阻塞订单列表。
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_controller.load(), _loadActionSummary()]);
  }

  Widget _body() {
    if (_controller.loading && _controller.orders.isEmpty) {
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
    if (_controller.errorMessage != null && _controller.orders.isEmpty) {
      return MallStateView(
        icon: Icons.wifi_off_outlined,
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) _controller.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: _controller.orders.isEmpty
            ? const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _OrderEmptyState(),
                  ),
                ],
              )
            : ListView.builder(
                key: const ValueKey('order-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 16),
                itemCount:
                    _controller.orders.length +
                    (_controller.loadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _controller.orders.length) {
                    return const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _orderCard(_controller.orders[index]);
                },
              ),
      ),
    );
  }

  Widget _orderCard(ShopOrder order) {
    final firstItem = order.items.firstOrNull;
    final statusColor = _statusColor(order.status);
    final skuName = firstItem?.skuName?.trim();
    final quantity = firstItem?.quantity ?? order.items.length;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: ValueKey('order-card-${order.id}'),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openOrder(order.id),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '订单号：${order.orderNo}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: order.isSecondHand
                            ? const Color(0xFFFFF0D9)
                            : const Color(0xFFE8F1FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.isSecondHand ? '二手商品' : '平台商品',
                        style: TextStyle(
                          color: order.isSecondHand
                              ? const Color(0xFFB66500)
                              : const Color(0xFF376996),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.status.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFEFEFEF)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: MallNetworkImage(
                        url: firstItem?.productImage ?? '',
                        width: 64,
                        height: 64,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstItem?.productName ?? '商品',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${skuName == null || skuName.isEmpty || skuName == '默认规格' ? '' : '$skuName  '}x $quantity',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '¥${order.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: primary,
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (order.afterSaleSummary case final afterSale?) ...[
                  const SizedBox(height: 8),
                  Text(
                    '售后：${_afterSaleLabel(afterSale.status)}',
                    style: const TextStyle(
                      color: Color(0xFFC87516),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_primaryAction(order) case final action?) ...[
                  const Divider(height: 20, color: Color(0xFFEFEFEF)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (order.canCancel)
                        OutlinedButton(
                          onPressed: () => _cancel(order),
                          style: _outlinedActionStyle(),
                          child: const Text('取消订单'),
                        ),
                      if (order.canCancel) const SizedBox(width: 8),
                      if (action.$1.isNotEmpty)
                        FilledButton(
                          onPressed: action.$2 == 'confirm_receipt'
                              ? () => _confirm(order)
                              : () => _openOrder(order.id),
                          style: _filledActionStyle(primary),
                          child: Text(action.$1),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _outlinedActionStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF6B7280),
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  ButtonStyle _filledActionStyle(Color backgroundColor) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<void> _openOrder(int orderId) async {
    await widget.onOrder(orderId);
    if (mounted) await _refresh();
  }

  Future<void> _cancel(ShopOrder order) async {
    final confirmed = await showMallConfirm(
      context,
      title: '取消订单',
      message: '确定取消该订单吗？',
      confirmText: '取消订单',
    );
    if (!confirmed || !mounted) return;
    try {
      await _controller.cancel(order);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  Future<void> _confirm(ShopOrder order) async {
    final confirmed = await showMallConfirm(
      context,
      title: '确认收货',
      message: '确认已经收到商品吗？',
      confirmText: '确认收货',
    );
    if (!confirmed || !mounted) return;
    try {
      await _controller.confirm(order);
      await _loadActionSummary();
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }
}

class _OrderTabBadge extends StatelessWidget {
  const _OrderTabBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('order-pending-receipt-badge'),
      height: 16,
      constraints: const BoxConstraints(minWidth: 16),
      width: count < 10 ? 16 : null,
      padding: count < 10
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4D4D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

(String, String)? _primaryAction(ShopOrder order) {
  const actions = <String, String>{
    'pay': '去支付',
    'ship': '确认发货',
    'handle_after_sale': '处理售后',
    'confirm_return': '确认退货',
    'confirm_receipt': '确认收货',
    'request_arbitration': '申请仲裁',
    'view_after_sale': '售后进度',
    'update_tracking': '补充单号',
  };
  for (final entry in actions.entries) {
    if (order.hasAction(entry.key)) return (entry.value, entry.key);
  }
  return null;
}

String _afterSaleLabel(String status) =>
    const {
      'pending_handler': '等待处理',
      'handler_rejected': '申请已拒绝',
      'handler_timeout': '处理已超时',
      'waiting_handler_receipt': '等待确认收货',
      'pending_seller': '待卖家处理',
      'seller_rejected': '卖家已拒绝',
      'seller_timeout': '卖家处理超时',
      'waiting_buyer_return': '等待退货',
      'waiting_seller_receipt': '等待卖家收货',
      'arbitration_pending': '平台仲裁中',
      'refunding': '退款处理中',
      'refunded': '已退款',
      'closed': '已关闭',
    }[status] ??
    status;

class _OrderEmptyState extends StatelessWidget {
  const _OrderEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('order-empty-icon-surface'),
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5FC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3E8F2)),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Color(0xFFAAB4C6),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '暂无订单',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
