import 'package:flutter/material.dart';

import '../../../cart/domain/cart_models.dart';
import '../../../catalog/domain/catalog_models.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/favorite_models.dart';
import '../favorite_controller.dart';

class FavoritePageView extends StatefulWidget {
  const FavoritePageView({
    super.key,
    required this.gateway,
    required this.cartGateway,
    required this.onProduct,
    required this.onBrowse,
  });

  final FavoriteGateway gateway;
  final CartGateway cartGateway;
  final ValueChanged<CatalogProduct> onProduct;
  final VoidCallback onBrowse;

  @override
  State<FavoritePageView> createState() => _FavoritePageViewState();
}

class _FavoritePageViewState extends State<FavoritePageView> {
  late final FavoriteController _controller;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _controller = FavoriteController(widget.gateway)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('favorite-gradient-background'),
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
          title: const Text(
            '我的收藏',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_controller.loading && _controller.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF7E97FA)),
            SizedBox(height: 8),
            Text(
              '加载中...',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }
    if (_controller.errorMessage != null && _controller.items.isEmpty) {
      return MallStateView(
        icon: Icons.wifi_off_outlined,
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }
    if (_controller.items.isEmpty) {
      return MallStateView(
        icon: Icons.favorite_border,
        message: '暂无收藏\n快去收藏喜欢的商品吧',
        onRetry: widget.onBrowse,
        actionLabel: '去选商品',
        actionIcon: Icons.shopping_bag_outlined,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 220) _controller.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView.builder(
          key: const ValueKey('favorite-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
          itemCount:
              _controller.items.length + (_controller.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _controller.items.length) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _favoriteCard(_controller.items[index]);
          },
        ),
      ),
    );
  }

  Widget _favoriteCard(FavoriteEntry entry) {
    final product = entry.product;
    final busy = _busyIds.contains(entry.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Material(
        key: ValueKey('favorite-card-${entry.id}'),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onProduct(product),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: MallNetworkImage(
                    url: product.imageUrl,
                    width: 74,
                    height: 74,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (product.canAddToCart) ...[
                            Tooltip(
                              message: '加入购物车',
                              child: SizedBox(
                                height: 32,
                                child: FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _addToCart(entry),
                                  style: _addButtonStyle,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 17,
                                      ),
                                      SizedBox(width: 2),
                                      Text('加购'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              onPressed: busy ? null : () => _remove(entry),
                              style: _removeButtonStyle,
                              child: const Text('取消收藏'),
                            ),
                          ),
                        ],
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

  Future<void> _remove(FavoriteEntry entry) async {
    final confirmed = await showMallConfirm(
      context,
      title: '提示',
      message: '确定取消收藏该商品吗？',
      confirmText: '确定',
    );
    if (!confirmed || !mounted) return;
    try {
      setState(() => _busyIds.add(entry.id));
      await _controller.remove(entry);
      if (mounted) showMallMessage(context, '取消收藏成功');
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(entry.id));
    }
  }

  Future<void> _addToCart(FavoriteEntry entry) async {
    final product = entry.product;
    if (product.hasSku) {
      showMallMessage(context, '请先选择商品规格');
      widget.onProduct(product);
      return;
    }
    try {
      setState(() => _busyIds.add(entry.id));
      await widget.cartGateway.addItem(productId: product.id, quantity: 1);
      if (mounted) showMallMessage(context, '已加入购物车');
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(entry.id));
    }
  }
}

final _addButtonStyle = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF7E97FA),
  foregroundColor: Colors.white,
  minimumSize: Size.zero,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  visualDensity: VisualDensity.compact,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  textStyle: const TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
  ),
);

final _removeButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: const Color(0xFF6B7280),
  minimumSize: Size.zero,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  side: const BorderSide(color: Color(0xFFE5E7EB)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  visualDensity: VisualDensity.compact,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  textStyle: const TextStyle(fontSize: 14, height: 1.3),
);
