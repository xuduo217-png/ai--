import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/mall_models.dart';
import 'mall_controller.dart';

class MallHomeView extends StatefulWidget {
  const MallHomeView({
    super.key,
    required this.controller,
    required this.guest,
    required this.onLoginRequired,
    required this.onOpenFeature,
    this.onSearch,
    this.onCart,
    this.onCategory,
    this.onPopular,
    this.onProduct,
  });

  final MallController controller;
  final bool guest;
  final ValueChanged<String> onLoginRequired;
  final ValueChanged<String> onOpenFeature;
  final VoidCallback? onSearch;
  final VoidCallback? onCart;
  final ValueChanged<int>? onCategory;
  final VoidCallback? onPopular;
  final ValueChanged<int>? onProduct;

  @override
  State<MallHomeView> createState() => _MallHomeViewState();
}

class _MallHomeViewState extends State<MallHomeView> {
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _bannerIndex = 0;
  @override
  void initState() {
    super.initState();
    _bannerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final count = widget.controller.snapshot.banners.length;
      if (count < 2 || !_bannerController.hasClients) {
        return;
      }
      final next = (_bannerIndex + 1) % count;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.loading) {
          return const ColoredBox(
            color: Color(0xFFF9FAFB),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF7E97FA)),
            ),
          );
        }

        final snapshot = widget.controller.snapshot;
        if (_bannerIndex >= snapshot.banners.length) {
          _bannerIndex = 0;
        }
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _MallTopBar(
                  hasCartItems: snapshot.hasCartItems,
                  onSearch:
                      widget.onSearch ?? () => widget.onOpenFeature('商品搜索'),
                  onCart: _openCart,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF7E97FA),
                    onRefresh: widget.controller.refresh,
                    child: ListView(
                      key: const ValueKey('mall-home-scroll-view'),
                      padding: EdgeInsets.zero,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _MallBannerCarousel(
                          banners: snapshot.banners,
                          controller: _bannerController,
                          activeIndex: _bannerIndex,
                          onPageChanged: (index) {
                            if (mounted) {
                              setState(() => _bannerIndex = index);
                            }
                          },
                          onTap: _openBanner,
                        ),
                        _MallSection(
                          key: const ValueKey('mall-home-category-section'),
                          title: '商品分类',
                          moreText: '全部分类 >',
                          onMore: widget.onCategory == null
                              ? () => widget.onOpenFeature('全部分类')
                              : () => widget.onCategory!(0),
                          child: _CategoryGrid(
                            categories: snapshot.categories,
                            onTap: (category) {
                              final handler = widget.onCategory;
                              if (handler != null) {
                                handler(category.id);
                              } else {
                                widget.onOpenFeature('商品分类：${category.name}');
                              }
                            },
                          ),
                        ),
                        _MallSection(
                          key: const ValueKey('mall-home-popular-section'),
                          title: '热门商品',
                          moreText: '更多商品 >',
                          onMore:
                              widget.onPopular ??
                              () => widget.onOpenFeature('热门商品'),
                          child: _ProductGrid(
                            products: snapshot.products,
                            onProduct: (product) {
                              final handler = widget.onProduct;
                              if (handler != null) {
                                handler(product.id);
                              } else {
                                widget.onOpenFeature('商品详情：${product.name}');
                              }
                            },
                            onAdd: _addProduct,
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
      },
    );
  }

  void _openCart() {
    if (widget.onCart != null) {
      widget.onCart!();
      return;
    }
    if (widget.guest) {
      widget.onLoginRequired('登录后即可查看购物车');
      return;
    }
    widget.onOpenFeature('购物车');
  }

  void _openBanner(MallBanner banner) {
    final target = banner.target;
    if (target == null) {
      return;
    }
    switch (target.type) {
      case MallBannerTargetType.product:
        final handler = widget.onProduct;
        if (handler != null && target.id != null) {
          handler(target.id!);
        } else {
          widget.onOpenFeature('商品详情：${target.id}');
        }
      case MallBannerTargetType.category:
        final handler = widget.onCategory;
        if (handler != null && target.id != null) {
          handler(target.id!);
        } else {
          widget.onOpenFeature('商品分类：${target.id}');
        }
      case MallBannerTargetType.popular:
        final handler = widget.onPopular;
        if (handler != null) {
          handler();
        } else {
          widget.onOpenFeature('热门商品');
        }
    }
  }

  Future<void> _addProduct(MallProduct product) async {
    if (widget.guest) {
      widget.onLoginRequired('登录后即可加入购物车');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SkuSelectionSheet(
        initialProduct: product,
        loadProduct: widget.controller.loadProduct,
        onConfirm: ({required productId, required skuId, required quantity}) {
          return widget.controller.addToCart(
            productId: productId,
            skuId: skuId,
            quantity: quantity,
          );
        },
      ),
    );
  }
}

class _MallTopBar extends StatelessWidget {
  const _MallTopBar({
    required this.hasCartItems,
    required this.onSearch,
    required this.onCart,
  });

  final bool hasCartItems;
  final VoidCallback onSearch;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('mall-home-top-bar'),
      padding: EdgeInsets.fromLTRB(
        _mallScale(context, 16),
        _mallScale(context, 12),
        _mallScale(context, 16),
        _mallScale(context, 12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_mallScale(context, 32)),
                side: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: _mallScale(context, 1),
                ),
              ),
              child: InkWell(
                key: const ValueKey('mall-home-search-entry'),
                onTap: onSearch,
                borderRadius: BorderRadius.circular(_mallScale(context, 32)),
                child: SizedBox(
                  height: _mallScale(context, 85),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _mallScale(context, 12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: _mallScale(context, 44),
                          color: const Color(0xFF9CA3AF),
                        ),
                        SizedBox(width: _mallScale(context, 8)),
                        Text(
                          '热门搜索',
                          style: TextStyle(
                            fontSize: _mallScale(context, 30),
                            color: const Color(0xFF9CA3AF),
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: _mallScale(context, 12)),
          Tooltip(
            message: '购物车',
            child: InkResponse(
              key: const ValueKey('mall-cart-button'),
              onTap: onCart,
              radius: _mallScale(context, 32),
              child: SizedBox(
                width: _mallScale(context, 48),
                height: _mallScale(context, 48),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Icon(
                        Icons.shopping_cart,
                        size: _mallScale(context, 48),
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    if (hasCartItems)
                      Positioned(
                        key: const ValueKey('mall-cart-badge'),
                        right: _mallScale(context, 5),
                        top: _mallScale(context, 5),
                        child: Container(
                          width: _mallScale(context, 14),
                          height: _mallScale(context, 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MallBannerCarousel extends StatelessWidget {
  const _MallBannerCarousel({
    required this.banners,
    required this.controller,
    required this.activeIndex,
    required this.onPageChanged,
    required this.onTap,
  });

  final List<MallBanner> banners;
  final PageController controller;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<MallBanner> onTap;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const ValueKey('mall-home-banner'),
      height: _mallScale(context, 340),
      margin: EdgeInsets.fromLTRB(
        _mallScale(context, 16),
        _mallScale(context, 8),
        _mallScale(context, 16),
        _mallScale(context, 20),
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFB3D8FD),
        borderRadius: BorderRadius.circular(_mallScale(context, 12)),
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: banners.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return GestureDetector(
                key: ValueKey('mall-home-banner-${banner.id}'),
                onTap: banner.target == null ? null : () => onTap(banner),
                child: _MallImage(
                  imageUrl: banner.imageUrl,
                  fallbackAsset: 'assets/images/store/store_banner.png',
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          if (banners.length > 1)
            Positioned(
              right: _mallScale(context, 16),
              bottom: _mallScale(context, 8),
              child: Row(
                children: [
                  for (var index = 0; index < banners.length; index++)
                    Container(
                      width: _mallScale(context, 10),
                      height: _mallScale(context, 10),
                      margin: EdgeInsets.symmetric(
                        horizontal: _mallScale(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: index == activeIndex ? 1 : 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MallSection extends StatelessWidget {
  const _MallSection({
    super.key,
    required this.title,
    required this.moreText,
    required this.onMore,
    required this.child,
  });

  final String title;
  final String moreText;
  final VoidCallback onMore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: _mallScale(context, 20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              _mallScale(context, 16),
              0,
              _mallScale(context, 16),
              _mallScale(context, 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _mallScale(context, 36),
                    height: 44 / 36,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                    letterSpacing: 0,
                  ),
                ),
                InkWell(
                  onTap: onMore,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: _mallScale(context, 8),
                    ),
                    child: Text(
                      moreText,
                      style: TextStyle(
                        fontSize: _mallScale(context, 28),
                        height: 30 / 28,
                        color: const Color(0xFF7E97FA),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.onTap});

  final List<MallCategory> categories;
  final ValueChanged<MallCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _mallScale(context, 16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final category in categories)
            Expanded(
              child: InkWell(
                key: ValueKey('mall-category-${category.id}'),
                onTap: () => onTap(category),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        _mallScale(context, 8),
                      ),
                      child: SizedBox(
                        width: _mallScale(context, 73),
                        height: _mallScale(context, 73),
                        child: _MallImage(
                          imageUrl: category.imageUrl,
                          fallbackAsset: 'assets/images/store/store_food.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: _mallScale(context, 20)),
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _mallScale(context, 24),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1F2937),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.onProduct,
    required this.onAdd,
  });

  final List<MallProduct> products;
  final ValueChanged<MallProduct> onProduct;
  final ValueChanged<MallProduct> onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: _mallScale(context, 100)),
        child: Center(
          child: Text(
            '暂无商品',
            style: TextStyle(
              fontSize: _mallScale(context, 24),
              color: const Color(0xFF9CA3AF),
              letterSpacing: 0,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * 0.46;
        final horizontalGap = constraints.maxWidth * 0.03;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            _mallScale(context, 5),
            _mallScale(context, 20),
            _mallScale(context, 5),
            _mallScale(context, 20),
          ),
          child: Wrap(
            spacing: horizontalGap,
            runSpacing: _mallScale(context, 20),
            children: [
              for (final product in products)
                SizedBox(
                  width: cardWidth,
                  child: _ProductCard(
                    product: product,
                    onTap: () => onProduct(product),
                    onAdd: () => onAdd(product),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  final MallProduct product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('mall-product-${product.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_mallScale(context, 12)),
        side: BorderSide(
          color: const Color(0xFFE5E7EB),
          width: _mallScale(context, 1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xFFF3F4F6),
                      child: _MallImage(
                        imageUrl: product.imageUrl,
                        fallbackAsset:
                            'assets/images/store/store_item_default.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (product.isTop)
                    Positioned(
                      left: _mallScale(context, 8),
                      top: _mallScale(context, 8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _mallScale(context, 8),
                          vertical: _mallScale(context, 4),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(
                            _mallScale(context, 4),
                          ),
                        ),
                        child: Text(
                          '热销',
                          style: TextStyle(
                            fontSize: _mallScale(context, 20),
                            height: 24 / 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(_mallScale(context, 10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: _mallScale(context, 64),
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _mallScale(context, 24),
                        height: 32 / 24,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  SizedBox(height: _mallScale(context, 14)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '¥${product.price.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _mallScale(context, 26),
                            height: 34 / 26,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (product.canAddToCart)
                        GestureDetector(
                          key: ValueKey('mall-add-product-${product.id}'),
                          onTap: onAdd,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: _mallScale(context, 12),
                              vertical: _mallScale(context, 6),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E97FA),
                              borderRadius: BorderRadius.circular(
                                _mallScale(context, 8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  size: _mallScale(context, 36),
                                  color: Colors.white,
                                ),
                                SizedBox(width: _mallScale(context, 4)),
                                Text(
                                  '加购',
                                  style: TextStyle(
                                    fontSize: _mallScale(context, 20),
                                    height: 28 / 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}

typedef _AddToCart =
    Future<void> Function({
      required int productId,
      required int? skuId,
      required int quantity,
    });

class _SkuSelectionSheet extends StatefulWidget {
  const _SkuSelectionSheet({
    required this.initialProduct,
    required this.loadProduct,
    required this.onConfirm,
  });

  final MallProduct initialProduct;
  final Future<MallProduct> Function(int productId) loadProduct;
  final _AddToCart onConfirm;

  @override
  State<_SkuSelectionSheet> createState() => _SkuSelectionSheetState();
}

class _SkuSelectionSheetState extends State<_SkuSelectionSheet> {
  late MallProduct _product = widget.initialProduct;
  MallSku? _selectedSku;
  Map<String, String> _selectedSpecs = const {};
  int _quantity = 1;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initializeProduct(_product);
    _load();
  }

  Future<void> _load() async {
    try {
      final product = await widget.loadProduct(widget.initialProduct.id);
      if (!mounted) return;
      setState(() {
        _product = product;
        _initializeProduct(product);
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取商品信息失败：$error')));
    }
  }

  void _initializeProduct(MallProduct product) {
    _selectedSku = product.skus.where((sku) => sku.available).firstOrNull;
    _selectedSpecs = _selectedSku?.specs ?? const {};
    _quantity = 1;
  }

  @override
  Widget build(BuildContext context) {
    final selectedSku = _selectedSku;
    final currentPrice = selectedSku?.price ?? _product.price;
    final currentStock = _product.hasSku
        ? selectedSku?.stock ?? 0
        : _product.stock;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: _loading
          ? const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6480F9)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: _MallImage(
                            imageUrl: selectedSku?.imageUrl.isNotEmpty == true
                                ? selectedSku!.imageUrl
                                : _product.imageUrl,
                            fallbackAsset:
                                'assets/images/store/store_item_default.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1F2937),
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '关闭',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '¥${currentPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF4444),
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '库存: $currentStock',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in _specGroups.entries) ...[
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final value in entry.value)
                                _SpecButton(
                                  text: value,
                                  selected: _selectedSpecs[entry.key] == value,
                                  enabled: _specAvailable(entry.key, value),
                                  onTap: () => _selectSpec(entry.key, value),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '购买数量',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1F2937),
                                letterSpacing: 0,
                              ),
                            ),
                            _QuantitySelector(
                              quantity: _quantity,
                              max: currentStock,
                              onChanged: (quantity) {
                                setState(() => _quantity = quantity);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _canConfirm && !_submitting
                            ? _confirm
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7E97FA),
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('确认'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Map<String, List<String>> get _specGroups {
    final groups = <String, List<String>>{};
    for (final sku in _product.skus) {
      for (final entry in sku.specs.entries) {
        final values = groups.putIfAbsent(entry.key, () => <String>[]);
        if (!values.contains(entry.value)) {
          values.add(entry.value);
        }
      }
    }
    return groups;
  }

  bool _specAvailable(String name, String value) {
    return _product.skus.any(
      (sku) => sku.available && sku.specs[name] == value,
    );
  }

  void _selectSpec(String name, String value) {
    final selected = {..._selectedSpecs, name: value};
    MallSku? matched;
    for (final sku in _product.skus) {
      if (sku.available &&
          sku.specs.length == selected.length &&
          selected.entries.every(
            (entry) => sku.specs[entry.key] == entry.value,
          )) {
        matched = sku;
        break;
      }
    }
    setState(() {
      _selectedSpecs = selected;
      _selectedSku = matched;
      _quantity = 1;
    });
  }

  bool get _canConfirm {
    if (_product.hasSku) {
      return _selectedSku?.available == true;
    }
    return _product.stock > 0;
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      await widget.onConfirm(
        productId: _product.id,
        skuId: _selectedSku?.id ?? _product.skus.firstOrNull?.id,
        quantity: _quantity,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('已加入购物车')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加入购物车失败：$error')));
      setState(() => _submitting = false);
    }
  }
}

class _SpecButton extends StatelessWidget {
  const _SpecButton({
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 60),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7E97FA)
              : enabled
              ? Colors.white
              : const Color(0xFFF9FAFB),
          border: Border.all(
            color: selected ? const Color(0xFF7E97FA) : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? Colors.white
                : enabled
                ? const Color(0xFF6B7280)
                : const Color(0xFF9CA3AF),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '减少',
            visualDensity: VisualDensity.compact,
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 0),
            ),
          ),
          IconButton(
            tooltip: '增加',
            visualDensity: VisualDensity.compact,
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MallImage extends StatelessWidget {
  const _MallImage({
    required this.imageUrl,
    required this.fallbackAsset,
    required this.fit,
  });

  final String imageUrl;
  final String fallbackAsset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Image.asset(fallbackAsset, fit: fit);
    }
    return Image.network(
      imageUrl,
      fit: fit,
      errorBuilder: (_, _, _) => Image.asset(fallbackAsset, fit: fit),
    );
  }
}

double _mallScale(BuildContext context, num designPixels) {
  final size = MediaQuery.sizeOf(context);
  final referenceWidth = size.width < size.height ? size.width : size.height;
  return (designPixels * referenceWidth / 750).roundToDouble();
}
