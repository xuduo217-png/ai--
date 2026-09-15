import 'package:flutter/material.dart';

import '../../../checkout/domain/checkout_models.dart';
import '../../../checkout/presentation/checkout_controller.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/cart_models.dart';
import '../cart_controller.dart';

typedef OpenCartCheckout =
    void Function(CheckoutRouteArgs args, CartController controller);

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.gateway,
    required this.onProduct,
    required this.onCheckout,
  });

  final CartGateway gateway;
  final ValueChanged<int> onProduct;
  final OpenCartCheckout onCheckout;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final CartController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CartController(widget.gateway)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        backgroundColor: mallBackground,
        appBar: AppBar(
          title: const Text('购物车'),
          actions: [
            TextButton(
              onPressed: _controller.items.isEmpty
                  ? null
                  : _controller.toggleManaging,
              child: Text(_controller.managing ? '完成' : '管理'),
            ),
          ],
        ),
        body: _body(),
        bottomNavigationBar: _controller.items.isEmpty ? null : _bottomBar(),
      ),
    );
  }

  Widget _body() {
    if (_controller.loading && _controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null && _controller.items.isEmpty) {
      return MallStateView(
        icon: Icons.wifi_off_outlined,
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }
    if (_controller.items.isEmpty) {
      return const MallStateView(
        icon: Icons.remove_shopping_cart_outlined,
        message: '购物车还是空的',
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _controller.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _cartItem(_controller.items[index]),
      ),
    );
  }

  Widget _cartItem(CartItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Checkbox(
              value: item.selected,
              onChanged: item.available
                  ? (_) => _controller.toggleItem(item.id)
                  : null,
            ),
            InkWell(
              onTap: () => widget.onProduct(item.productId),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: MallNetworkImage(
                    url: item.sku?.imageUrl.isNotEmpty == true
                        ? item.sku!.imageUrl
                        : item.product.imageUrl,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 88),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        if (item.specification.isNotEmpty)
                          Text(
                            item.specification,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8A909D),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '¥${item.unitPrice.toStringAsFixed(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE94F4F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _quantityButton(
                            icon: Icons.remove,
                            onTap: item.quantity > 1
                                ? () => _updateQuantity(item, item.quantity - 1)
                                : null,
                          ),
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          _quantityButton(
                            icon: Icons.add,
                            onTap: item.quantity < item.stock
                                ? () => _updateQuantity(item, item.quantity + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: icon == Icons.add ? '增加数量' : '减少数量',
        onPressed: onTap,
        icon: Icon(icon, size: 17),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            Checkbox(
              value: _controller.allSelected,
              onChanged: (_) => _controller.toggleAll(),
            ),
            const Text('全选'),
            const Spacer(),
            if (!_controller.managing) ...[
              Flexible(
                child: Text(
                  '合计 ¥${_controller.total.toStringAsFixed(2)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: _controller.selectedItems.isEmpty ? null : _checkout,
                child: Text('结算(${_controller.selectedItems.length})'),
              ),
            ] else
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: _controller.selectedItems.isEmpty
                    ? null
                    : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateQuantity(CartItem item, int quantity) async {
    try {
      await _controller.updateQuantity(item, quantity);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showMallConfirm(
      context,
      title: '删除商品',
      message: '确定删除选中的购物车商品吗？',
    );
    if (!confirmed) return;
    try {
      await _controller.removeSelected();
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  void _checkout() {
    final args = CheckoutRouteArgs(
      _controller.selectedItems
          .map(checkoutItemFromCart)
          .toList(growable: false),
    );
    widget.onCheckout(args, _controller);
  }
}
