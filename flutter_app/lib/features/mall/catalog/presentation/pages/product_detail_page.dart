import 'package:flutter/material.dart';

import '../../../../../core/media/route_aware_video_surface.dart';
import '../../../cart/domain/cart_models.dart';
import '../../../checkout/domain/checkout_models.dart';
import '../../../favorite/domain/favorite_models.dart';
import '../../../second_hand/domain/second_hand_models.dart';
import '../../../shared/mall_rich_text.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/catalog_models.dart';
import '../catalog_controller.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.productId,
    required this.catalogGateway,
    required this.cartGateway,
    required this.favoriteGateway,
    required this.secondHandGateway,
    required this.authenticated,
    required this.onLoginRequired,
    required this.onCheckout,
    this.currentUserId,
    this.onContactSeller,
  });

  final int productId;
  final CatalogGateway catalogGateway;
  final CartGateway cartGateway;
  final FavoriteGateway favoriteGateway;
  final SecondHandGateway secondHandGateway;
  final bool authenticated;
  final VoidCallback onLoginRequired;
  final ValueChanged<CheckoutRouteArgs> onCheckout;
  final int? currentUserId;
  final Future<void> Function()? onContactSeller;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final ProductDetailController _controller;
  final _imageController = PageController();
  int _imageIndex = 0;
  bool _favoriteLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = ProductDetailController(
      catalogGateway: widget.catalogGateway,
      productId: widget.productId,
      authenticated: widget.authenticated,
    )..load();
  }

  @override
  void dispose() {
    _imageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final product = _controller.product;
          return Scaffold(
            backgroundColor: mallBackground,
            appBar: AppBar(
              title: const Text('商品详情'),
              actions: [
                if (product?.isSecondHand == true)
                  PopupMenuButton<String>(
                    tooltip: '更多',
                    onSelected: (value) {
                      if (value == 'report') _report();
                      if (value == 'block') _blockSeller();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('举报商品')),
                      PopupMenuItem(value: 'block', child: Text('屏蔽卖家')),
                    ],
                  ),
              ],
            ),
            body: _body(),
            bottomNavigationBar: product == null ? null : _bottomBar(product),
          );
        },
      ),
    );
  }

  Widget _body() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null || _controller.product == null) {
      return MallStateView(
        icon: Icons.error_outline,
        message: _controller.errorMessage ?? '商品不存在',
        onRetry: _controller.load,
      );
    }
    final product = _controller.product!;
    final images = product.images.isEmpty ? [product.imageUrl] : product.images;
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _imageController,
                  itemCount: images.length,
                  onPageChanged: (value) => setState(() => _imageIndex = value),
                  itemBuilder: (_, index) =>
                      MallNetworkImage(url: images[index]),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      child: Text(
                        '${_imageIndex + 1}/${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '¥${_controller.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFE94F4F),
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: product.isFavorited ? '取消收藏' : '收藏',
                      onPressed: _favoriteLoading ? null : _toggleFavorite,
                      icon: Icon(
                        product.isFavorited
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: product.isFavorited
                            ? const Color(0xFFE94F4F)
                            : const Color(0xFF687081),
                      ),
                    ),
                  ],
                ),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '库存 ${_controller.availableStock}  ·  已售 ${product.sells}',
                  style: const TextStyle(color: Color(0xFF8A909D)),
                ),
                if (product.isSecondHand) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 17,
                        child: Icon(Icons.person_outline, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(product.sellerLabel)),
                      if (product.condition != null)
                        Chip(
                          label: Text(_conditionLabel(product.condition!)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (product.hasSku) ...[
            const SizedBox(height: 10),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择规格',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.skus
                        .map(
                          (sku) => ChoiceChip(
                            label: Text(
                              sku.specification.isEmpty
                                  ? sku.name
                                  : sku.specification,
                            ),
                            selected: _controller.selectedSku?.id == sku.id,
                            showCheckmark: false,
                            onSelected: sku.available
                                ? (_) => _controller.selectSku(sku)
                                : null,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '购买数量',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '减少数量',
                  onPressed: () => _controller.changeQuantity(-1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${_controller.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  tooltip: '增加数量',
                  onPressed: () => _controller.changeQuantity(1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '商品详情',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                MallRichText(content: product.description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(CatalogProduct product) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    const buttonTextStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE9EBF1))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: SizedBox(
          height: 52,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (product.isSecondHand &&
                  widget.onContactSeller != null &&
                  _sellerId(product) != widget.currentUserId) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mallPrimary,
                      side: const BorderSide(color: mallPrimary, width: 1.2),
                      shape: buttonShape,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: buttonTextStyle,
                    ),
                    onPressed: _contactSeller,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 19,
                    ),
                    label: const Text('联系卖家'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (product.canAddToCart) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mallPrimary,
                      disabledForegroundColor: const Color(0xFFB7BDC9),
                      side: const BorderSide(color: mallPrimary, width: 1.2),
                      shape: buttonShape,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: buttonTextStyle,
                    ),
                    onPressed: _controller.canSubmit ? _addToCart : null,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                    label: const Text('加入购物车'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    backgroundColor: mallPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD8DDEA),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: buttonShape,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: buttonTextStyle,
                  ),
                  onPressed: _controller.canSubmit ? _buyNow : null,
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text('立即购买'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contactSeller() async {
    if (!widget.authenticated) {
      widget.onLoginRequired();
      return;
    }
    final callback = widget.onContactSeller;
    if (callback == null) return;
    try {
      await callback();
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  int? _sellerId(CatalogProduct product) =>
      product.publisher?.id ?? product.publishedBy;

  Future<void> _toggleFavorite() async {
    if (!widget.authenticated) {
      widget.onLoginRequired();
      return;
    }
    setState(() => _favoriteLoading = true);
    try {
      final favorite = await widget.favoriteGateway.toggleFavorite(
        widget.productId,
      );
      _controller.setFavorite(favorite);
      if (mounted) showMallMessage(context, favorite ? '已收藏' : '已取消收藏');
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _favoriteLoading = false);
    }
  }

  Future<void> _addToCart() async {
    if (!widget.authenticated) {
      widget.onLoginRequired();
      return;
    }
    try {
      await widget.cartGateway.addItem(
        productId: widget.productId,
        skuId: _controller.selectedSku?.id,
        quantity: _controller.quantity,
      );
      if (mounted) showMallMessage(context, '已加入购物车');
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  void _buyNow() {
    if (!widget.authenticated) {
      widget.onLoginRequired();
      return;
    }
    final product = _controller.product!;
    final sku = _controller.selectedSku;
    widget.onCheckout(
      CheckoutRouteArgs([
        CheckoutItem(
          productId: product.id,
          skuId: sku?.id,
          productName: product.name,
          skuName: sku?.name,
          imageUrl: sku?.imageUrl.isNotEmpty == true
              ? sku!.imageUrl
              : product.imageUrl,
          price: _controller.price,
          quantity: _controller.quantity,
          source: product.source,
        ),
      ]),
    );
  }

  Future<void> _report() async {
    if (!widget.authenticated) {
      widget.onLoginRequired();
      return;
    }
    const reasons = {
      'FRAUD': '欺诈信息',
      'ILLEGAL': '违规商品',
      'SPAM': '垃圾信息',
      'OTHER': '其他原因',
    };
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('选择举报原因')),
            ...reasons.entries.map(
              (entry) => ListTile(
                title: Text(entry.value),
                onTap: () => Navigator.pop(sheetContext, entry.key),
              ),
            ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await widget.secondHandGateway.reportProduct(
        widget.productId,
        reason: reason,
      );
      if (mounted) showMallMessage(context, '举报已提交');
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  Future<void> _blockSeller() async {
    if (!widget.authenticated) {
      widget.onLoginRequired();
      return;
    }
    final publisherId = _controller.product?.publisher?.id;
    if (publisherId == null || publisherId <= 0) {
      showMallMessage(context, '卖家信息不完整', error: true);
      return;
    }
    final confirmed = await showMallConfirm(
      context,
      title: '屏蔽卖家',
      message: '屏蔽后将减少看到该卖家的内容，确定继续吗？',
    );
    if (!confirmed) return;
    try {
      await widget.secondHandGateway.blockUser(publisherId, reason: '二手商城屏蔽');
      if (mounted) showMallMessage(context, '已屏蔽该卖家');
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  String _conditionLabel(String value) {
    return switch (value) {
      'new' => '全新',
      '90%' => '九成新',
      '80%' => '八成新',
      '70%' => '七成新',
      _ => '六成新及以下',
    };
  }
}
