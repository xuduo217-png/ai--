import 'package:flutter/material.dart';

import '../../../address/domain/address_models.dart';
import '../../../address/presentation/address_controller.dart';
import '../../../address/presentation/pages/address_list_page.dart';
import '../../../cart/presentation/cart_controller.dart';
import '../../../order/domain/order_models.dart';
import '../../../payment/domain/payment_models.dart';
import '../../../payment/presentation/payment_controller.dart';
import '../../../payment/presentation/widgets/payment_sheet.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/checkout_models.dart';
import '../checkout_controller.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.args,
    required this.checkoutGateway,
    required this.addressGateway,
    required this.orderGateway,
    required this.paymentGateway,
    required this.onOrderDetail,
    this.cartController,
  });

  final CheckoutRouteArgs args;
  final CheckoutGateway checkoutGateway;
  final AddressGateway addressGateway;
  final OrderGateway orderGateway;
  final PaymentGateway paymentGateway;
  final ValueChanged<int> onOrderDetail;
  final CartController? cartController;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage>
    with WidgetsBindingObserver {
  late final AddressController _addressController;
  late final CheckoutController _controller;
  late final PaymentController _paymentController;
  final _remark = TextEditingController();
  final _remarkFocusNode = FocusNode();
  final _scrollController = ScrollController();
  double _lastKeyboardInset = 0;
  bool _keyboardEnsureScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _addressController = AddressController(widget.addressGateway);
    _controller = CheckoutController(
      checkoutGateway: widget.checkoutGateway,
      addressController: _addressController,
      cartController: widget.cartController,
      items: widget.args.items,
    )..load();
    _paymentController = PaymentController(
      checkoutGateway: widget.checkoutGateway,
      orderGateway: widget.orderGateway,
      paymentGateway: widget.paymentGateway,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _remark.dispose();
    _remarkFocusNode.dispose();
    _scrollController.dispose();
    _paymentController.dispose();
    _controller.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final inset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    if (inset <= 0) {
      _lastKeyboardInset = 0;
      _keyboardEnsureScheduled = false;
      return;
    }
    if (!_remarkFocusNode.hasFocus || !mounted) return;
    if (inset == _lastKeyboardInset) return;
    _lastKeyboardInset = inset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_remarkFocusNode.hasFocus) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      final context = _remarkFocusNode.context;
      if (context == null) return;
      Scrollable.ensureVisible(context, alignment: 0.85);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: mallBackground,
        appBar: AppBar(title: const Text('确认订单')),
        body: _body(),
        bottomNavigationBar: _controller.loading ? null : _bottomBar(),
      ),
    );
  }

  Widget _body() {
    _scheduleRemarkVisibility(MediaQuery.viewInsetsOf(context).bottom);
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null) {
      return MallStateView(
        icon: Icons.error_outline,
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }
    return ListView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(12),
      children: [
        _addressCard(),
        const SizedBox(height: 10),
        _productsCard(),
        const SizedBox(height: 10),
        _couponCard(),
        const SizedBox(height: 10),
        if ((_controller.preview?.charityDonationRate ?? 0) > 0 &&
            (_controller.preview?.charityDonationAmount ?? 0) > 0) ...[
          _charityNoticeCard(
            _controller.preview!.charityDonationRate!,
            _controller.preview!.charityDonationAmount!,
          ),
          const SizedBox(height: 10),
        ],
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _remark,
              focusNode: _remarkFocusNode,
              maxLength: 200,
              maxLines: 3,
              textAlignVertical: TextAlignVertical.top,
              scrollPadding: const EdgeInsets.only(bottom: 160),
              decoration: const InputDecoration(
                labelText: '订单备注',
                hintText: '选填，请先和商家协商一致',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _amountCard(),
      ],
    );
  }

  void _scheduleRemarkVisibility(double inset) {
    if (inset <= 0) {
      _keyboardEnsureScheduled = false;
      return;
    }
    if (_keyboardEnsureScheduled || !_remarkFocusNode.hasFocus) return;
    _keyboardEnsureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_remarkFocusNode.hasFocus) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      final context = _remarkFocusNode.context;
      if (context == null) return;
      Scrollable.ensureVisible(context, alignment: 0.85);
    });
  }

  Widget _addressCard() {
    final address = _controller.address;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: _selectAddress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: mallPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: address == null
                    ? const Text('请选择收货地址')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${address.receiverName}  ${address.receiverPhone}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(address.fullAddress),
                        ],
                      ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productsCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: _controller.items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: MallNetworkImage(url: item.imageUrl),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                          if (item.skuName != null)
                            Text(
                              item.skuName!,
                              style: const TextStyle(color: Color(0xFF8A909D)),
                            ),
                          Text(
                            '¥${item.price.toStringAsFixed(2)} × ${item.quantity}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _couponCard() {
    final preview = _controller.preview;
    final applicable =
        preview?.coupons.where((coupon) => coupon.isApplicable).length ?? 0;
    final selected = _controller.selectedCoupon;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        onTap: _chooseCoupon,
        title: const Text('优惠券'),
        subtitle: preview?.containsUserPublishedProducts == true
            ? Text(
                '二手商品不参与抵扣，可抵扣金额 ¥${preview!.couponEligibleAmount.toStringAsFixed(2)}',
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected == null
                  ? (applicable > 0 ? '$applicable 张可用' : '不可用')
                  : '-¥${preview!.couponDiscount.toStringAsFixed(2)}',
              style: TextStyle(
                color: selected == null
                    ? const Color(0xFF7C8390)
                    : const Color(0xFFE94F4F),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _amountCard() {
    final preview = _controller.preview;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _amountRow(
              '商品金额',
              preview?.originalAmount ?? _controller.fallbackTotal,
            ),
            const SizedBox(height: 8),
            _amountRow('优惠券', -(preview?.couponDiscount ?? 0)),
            const Divider(height: 22),
            _amountRow('应付金额', _controller.payableAmount, strong: true),
          ],
        ),
      ),
    );
  }

  Widget _charityNoticeCard(double rate, double donationAmount) {
    return Container(
      key: const ValueKey('checkout-charity-notice'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF6D98B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE7A8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 18,
              color: Color(0xFFE39A16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  key: const ValueKey('checkout-charity-copy'),
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF6F5A2B),
                      fontSize: 13,
                      height: 1.45,
                    ),
                    children: [
                      const TextSpan(text: '您每成功完成一笔有效订单，成交金额的'),
                      TextSpan(
                        text: '${_formatRate(rate)}%',
                        style: const TextStyle(
                          color: Color(0xFFD48600),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '将用于捐赠流浪动物公益基金。'),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '您本单预计捐赠 ¥${donationAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFD48600),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double value, {bool strong = false}) {
    final amount = value < 0
        ? '-¥${(-value).toStringAsFixed(2)}'
        : '¥${value.toStringAsFixed(2)}';
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          amount,
          style: TextStyle(
            fontSize: strong ? 18 : 14,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
            color: strong ? const Color(0xFFE94F4F) : null,
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '合计 ¥${_controller.payableAmount.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: Size.zero),
                onPressed: _controller.submitting ? null : _submit,
                child: _controller.submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交订单'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAddress() async {
    final selected = await Navigator.of(context).push<ShippingAddress>(
      MaterialPageRoute(
        builder: (_) => AddressListPage(
          gateway: widget.addressGateway,
          selectionMode: true,
        ),
      ),
    );
    if (selected != null) _controller.selectAddress(selected);
  }

  Future<void> _chooseCoupon() async {
    final coupons = _controller.preview?.coupons ?? const <CheckoutCoupon>[];
    if (coupons.isEmpty) return;
    final selected = await showModalBottomSheet<CheckoutCoupon?>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('不使用优惠券'),
            trailing: _controller.selectedCoupon == null
                ? const Icon(Icons.check)
                : null,
            onTap: () => Navigator.pop(sheetContext),
          ),
          ...coupons.map(
            (coupon) => ListTile(
              enabled: coupon.isApplicable,
              title: Text(coupon.name),
              subtitle: Text(
                coupon.isApplicable
                    ? '预计优惠 ¥${coupon.discountAmount.toStringAsFixed(2)}'
                    : (coupon.unavailableReason ?? '当前订单不可用'),
              ),
              trailing: _controller.selectedCoupon?.id == coupon.id
                  ? const Icon(Icons.check)
                  : null,
              onTap: coupon.isApplicable
                  ? () => Navigator.pop(sheetContext, coupon)
                  : null,
            ),
          ),
        ],
      ),
    );
    try {
      await _controller.selectCoupon(selected);
    } catch (error) {
      if (mounted) {
        showMallMessage(context, '优惠券已失效，已恢复为不使用优惠券：$error', error: true);
      }
    }
  }

  Future<void> _submit() async {
    try {
      final result = await _controller.submit(_remark.text);
      if (!mounted) return;
      if (!result.isSuccess) {
        showMallMessage(
          context,
          result.stockDetails.isEmpty
              ? (result.stockError ?? '库存不足')
              : result.stockDetails.join('；'),
          error: true,
        );
        return;
      }
      final payment = result.payment!;
      try {
        final flow = await showPaymentSheet(
          context,
          controller: _paymentController,
          order: payment.order,
          initialPayment: payment,
        );
        if (mounted && flow != null) {
          showMallMessage(context, flow.message, error: !flow.paid);
        }
      } catch (error) {
        if (mounted) showMallMessage(context, '$error', error: true);
      } finally {
        if (mounted) widget.onOrderDetail(payment.order.id);
      }
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }
}

String _formatRate(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
