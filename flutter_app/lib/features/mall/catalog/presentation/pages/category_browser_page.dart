import 'package:flutter/material.dart';

import '../../../cart/domain/cart_models.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/catalog_models.dart';
import '../category_browser_controller.dart';

const _categoryHeaderBackgroundColor = Color(0xFFDEE9FF);
const _categoryItemWithImageExtent = 84.0;
const _categoryItemWithoutImageExtent = 56.0;

typedef CategoryPageCallback = Future<void> Function();
typedef CategoryProductCallback = Future<void> Function(CatalogProduct product);

class CategoryBrowserPage extends StatefulWidget {
  const CategoryBrowserPage({
    super.key,
    required this.gateway,
    required this.cartGateway,
    required this.onProduct,
    required this.onSearch,
    required this.onCart,
    required this.onLoginRequired,
    required this.authenticated,
    this.initialFirstCategoryId,
    this.title = '商品分类',
    this.source = ProductSource.admin,
    this.showCartButton = true,
  });

  final CatalogGateway gateway;
  final CartGateway cartGateway;
  final CategoryProductCallback onProduct;
  final CategoryPageCallback onSearch;
  final CategoryPageCallback onCart;
  final VoidCallback onLoginRequired;
  final bool authenticated;
  final int? initialFirstCategoryId;
  final String title;
  final ProductSource source;
  final bool showCartButton;

  @override
  State<CategoryBrowserPage> createState() => _CategoryBrowserPageState();
}

class _CategoryBrowserPageState extends State<CategoryBrowserPage> {
  late final CategoryBrowserController _controller;
  final ScrollController _leftController = ScrollController();
  final ScrollController _rightController = ScrollController();
  final GlobalKey _rightViewportKey = GlobalKey();
  final Map<int, GlobalKey> _categoryKeys = {};
  bool _programmaticScroll = false;
  int _cartCount = 0;
  int? _addingProductId;

  @override
  void initState() {
    super.initState();
    _controller = CategoryBrowserController(
      gateway: widget.gateway,
      source: widget.source,
      initialFirstCategoryId: widget.initialFirstCategoryId,
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _controller.load(),
      if (widget.authenticated && widget.showCartButton) _loadCartCount(),
    ]);
    if (!mounted || _controller.categories.isEmpty) return;
    _syncCategoryKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToSelectedCategory(animated: false);
    });
  }

  Future<void> _loadCartCount() async {
    try {
      final count = await widget.cartGateway.loadCount();
      if (mounted) setState(() => _cartCount = count);
    } catch (_) {
      // 分类浏览不应因购物车角标失败而不可用。
    }
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mallBackground,
      appBar: AppBar(
        key: const ValueKey('category-header'),
        backgroundColor: _categoryHeaderBackgroundColor,
        surfaceTintColor: _categoryHeaderBackgroundColor,
        foregroundColor: const Color(0xFF1F2937),
        centerTitle: true,
        title: Text(widget.title),
        actions: [
          if (widget.showCartButton)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _CartButton(count: _cartCount, onPressed: _openCart),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loading && _controller.categories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.errorMessage != null &&
              _controller.categories.isEmpty) {
            return MallStateView(
              icon: Icons.wifi_off_outlined,
              message: _controller.errorMessage!,
              onRetry: _retryCategories,
            );
          }
          if (_controller.categories.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshCategories,
              child: const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MallStateView(
                      icon: Icons.category_outlined,
                      message: '暂无商品分类',
                    ),
                  ),
                ],
              ),
            );
          }
          _syncCategoryKeys();
          return Column(
            children: [
              _SearchEntry(onTap: _openSearch),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final leftWidth = constraints.maxWidth <= 340 ? 84.0 : 94.0;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: leftWidth,
                          child: _buildFirstCategories(),
                        ),
                        Expanded(child: _buildCategoryGroups()),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFirstCategories() {
    return ColoredBox(
      color: const Color(0xFFF0F2F6),
      child: ListView.builder(
        key: const ValueKey('first-category-list'),
        controller: _leftController,
        padding: EdgeInsets.zero,
        itemCount: _controller.categories.length,
        itemBuilder: (context, index) {
          final category = _controller.categories[index];
          final hasImage = _hasCategoryImage(category);
          final selected = _controller.selectedFirstCategoryId == category.id;
          return SizedBox(
            height: _firstCategoryExtent(category),
            child: Material(
              color: selected ? Colors.white : Colors.transparent,
              child: InkWell(
                key: ValueKey('first-category-${category.id}'),
                onTap: () => _selectFirstCategory(category, index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (selected)
                      Positioned(
                        key: ValueKey('selected-first-category-${category.id}'),
                        left: 0,
                        top: hasImage ? 18 : 12,
                        bottom: hasImage ? 18 : 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: mallPrimary,
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(3),
                            ),
                          ),
                          child: SizedBox(width: 4),
                        ),
                      ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (hasImage) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: MallNetworkImage(
                                  url: category.iconUrl.isNotEmpty
                                      ? category.iconUrl
                                      : category.imageUrl,
                                  width: 34,
                                  height: 34,
                                ),
                              ),
                              const SizedBox(height: 5),
                            ],
                            Text(
                              category.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? mallPrimary
                                    : const Color(0xFF4E5562),
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryGroups() {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleRightScroll,
      child: RefreshIndicator(
        onRefresh: _refreshCategories,
        child: ListView(
          key: _rightViewportKey,
          controller: _rightController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            for (final category in _controller.categories)
              _CategoryGroup(
                key: _categoryKeys[category.id],
                category: category,
                selectedSecondCategory: _controller.selectedSecondCategory(
                  category,
                ),
                products: _controller.productsFor(category),
                addingProductId: _addingProductId,
                onSecondCategory: (secondCategoryId) => _controller
                    .selectSecondCategory(category.id, secondCategoryId),
                onProduct: _openProduct,
                onAdd: _addToCart,
              ),
          ],
        ),
      ),
    );
  }

  bool _handleRightScroll(ScrollNotification notification) {
    if (!_programmaticScroll &&
        (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification)) {
      _syncFirstCategoryFromScroll();
    }
    return false;
  }

  void _syncCategoryKeys() {
    final ids = _controller.categories.map((item) => item.id).toSet();
    _categoryKeys.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      _categoryKeys.putIfAbsent(id, GlobalKey.new);
    }
  }

  Future<void> _retryCategories() async {
    await _controller.load();
    if (!mounted || _controller.categories.isEmpty) return;
    _syncCategoryKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelectedCategory(animated: false);
    });
  }

  Future<void> _refreshCategories() async {
    await _controller.refresh();
    if (!mounted) return;
    _syncCategoryKeys();
    final error = _controller.errorMessage;
    if (error != null) showMallMessage(context, error, error: true);
  }

  void _selectFirstCategory(CatalogCategory category, int index) {
    _controller.selectFirstCategory(category.id);
    _scrollLeftTo(index, animated: true);
    _scrollToCategory(category.id, animated: true);
  }

  void _scrollToSelectedCategory({required bool animated}) {
    final selectedId = _controller.selectedFirstCategoryId;
    if (selectedId == null) return;
    final index = _controller.categories.indexWhere(
      (item) => item.id == selectedId,
    );
    if (index >= 0) _scrollLeftTo(index, animated: animated);
    _scrollToCategory(selectedId, animated: animated);
  }

  bool _hasCategoryImage(CatalogCategory category) {
    return category.iconUrl.isNotEmpty || category.imageUrl.isNotEmpty;
  }

  double _firstCategoryExtent(CatalogCategory category) {
    return _hasCategoryImage(category)
        ? _categoryItemWithImageExtent
        : _categoryItemWithoutImageExtent;
  }

  void _scrollLeftTo(int index, {required bool animated}) {
    if (!_leftController.hasClients) return;
    final viewport = _leftController.position.viewportDimension;
    final maxOffset = _leftController.position.maxScrollExtent;
    final itemExtent = _firstCategoryExtent(_controller.categories[index]);
    final itemOffset = _controller.categories
        .take(index)
        .fold<double>(0, (offset, item) => offset + _firstCategoryExtent(item));
    final target = (itemOffset - (viewport - itemExtent) / 2).clamp(
      0.0,
      maxOffset,
    );
    if (animated) {
      _leftController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _leftController.jumpTo(target);
    }
  }

  Future<void> _scrollToCategory(
    int categoryId, {
    required bool animated,
  }) async {
    final targetContext = _categoryKeys[categoryId]?.currentContext;
    if (targetContext == null) return;
    _programmaticScroll = true;
    await Scrollable.ensureVisible(
      targetContext,
      duration: animated ? const Duration(milliseconds: 320) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: 0,
    );
    if (!mounted) return;
    _programmaticScroll = false;
  }

  void _syncFirstCategoryFromScroll() {
    final viewportContext = _rightViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.attached) return;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    var selectedIndex = 0;
    for (var index = 0; index < _controller.categories.length; index++) {
      final category = _controller.categories[index];
      final box =
          _categoryKeys[category.id]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= viewportTop + 72) selectedIndex = index;
    }
    final selected = _controller.categories[selectedIndex];
    if (_controller.selectedFirstCategoryId == selected.id) return;
    _controller.selectFirstCategory(selected.id);
    _scrollLeftTo(selectedIndex, animated: false);
  }

  Future<void> _openCart() async {
    await widget.onCart();
    if (widget.authenticated) await _loadCartCount();
  }

  Future<void> _openSearch() async {
    await widget.onSearch();
    if (widget.authenticated && widget.showCartButton) await _loadCartCount();
  }

  Future<void> _openProduct(CatalogProduct product) async {
    await widget.onProduct(product);
    if (widget.authenticated && widget.showCartButton) await _loadCartCount();
  }

  Future<void> _addToCart(CatalogProduct summaryProduct) async {
    if (!summaryProduct.canAddToCart) {
      showMallMessage(context, '二手商品只能立即购买', error: true);
      return;
    }
    if (!widget.authenticated) {
      widget.onLoginRequired();
      return;
    }
    if (_addingProductId != null) return;
    setState(() => _addingProductId = summaryProduct.id);
    try {
      final product = await widget.gateway.loadProduct(
        summaryProduct.id,
        authenticated: true,
      );
      if (!mounted) return;
      if (!product.available) {
        showMallMessage(context, '商品库存不足或已下架', error: true);
        return;
      }

      var quantity = 1;
      ProductSku? sku;
      if (product.hasSku) {
        setState(() => _addingProductId = null);
        final selection = await showModalBottomSheet<_CartSelection>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => _SkuSelectionSheet(product: product),
        );
        if (selection == null || !mounted) return;
        sku = selection.sku;
        quantity = selection.quantity;
        setState(() => _addingProductId = product.id);
      }

      await widget.cartGateway.addItem(
        productId: product.id,
        skuId: sku?.id,
        quantity: quantity,
      );
      await _loadCartCount();
      if (mounted) showMallMessage(context, '已加入购物车');
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _addingProductId = null);
    }
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final CategoryPageCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('category-search-area'),
      color: _categoryHeaderBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: InkWell(
          key: const ValueKey('category-search-entry'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E8EE)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.search_rounded, size: 21, color: Color(0xFF9299A6)),
                SizedBox(width: 8),
                Text(
                  '搜索商品',
                  style: TextStyle(color: Color(0xFF9299A6), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('category-cart-button'),
      tooltip: '购物车',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_cart_outlined),
          if (count > 0)
            Positioned(
              right: -8,
              top: -7,
              child: Container(
                height: 17,
                constraints: const BoxConstraints(minWidth: 17),
                width: count < 10 ? 17 : null,
                padding: count < 10
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE95656),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
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
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    super.key,
    required this.category,
    required this.selectedSecondCategory,
    required this.products,
    required this.addingProductId,
    required this.onSecondCategory,
    required this.onProduct,
    required this.onAdd,
  });

  final CatalogCategory category;
  final CatalogCategory? selectedSecondCategory;
  final List<CatalogProduct> products;
  final int? addingProductId;
  final ValueChanged<int> onSecondCategory;
  final ValueChanged<CatalogProduct> onProduct;
  final ValueChanged<CatalogProduct> onAdd;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 15, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: mallPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      color: Color(0xFF20242D),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (category.children.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 2, 12, 10),
              child: Row(
                children: [
                  for (final child in category.children)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        key: ValueKey(
                          'second-category-${category.id}-${child.id}',
                        ),
                        label: Text(child.name),
                        selected: selectedSecondCategory?.id == child.id,
                        onSelected: (_) => onSecondCategory(child.id),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        backgroundColor: const Color(0xFFF1F3F6),
                        selectedColor: const Color(0xFFE9EDFF),
                        labelStyle: TextStyle(
                          color: selectedSecondCategory?.id == child.id
                              ? mallPrimary
                              : const Color(0xFF666D7A),
                          fontSize: 12,
                          fontWeight: selectedSecondCategory?.id == child.id
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (products.isEmpty)
            const SizedBox(
              height: 104,
              child: Center(
                child: Text(
                  '暂无商品',
                  style: TextStyle(color: Color(0xFF9AA1AD), fontSize: 13),
                ),
              ),
            )
          else
            for (final product in products)
              _CategoryProductRow(
                product: product,
                adding: addingProductId == product.id,
                onTap: () => onProduct(product),
                onAdd: product.canAddToCart ? () => onAdd(product) : null,
              ),
          const SizedBox(height: 12, child: ColoredBox(color: mallBackground)),
        ],
      ),
    );
  }
}

class _CategoryProductRow extends StatelessWidget {
  const _CategoryProductRow({
    required this.product,
    required this.adding,
    required this.onTap,
    this.onAdd,
  });

  final CatalogProduct product;
  final bool adding;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        key: ValueKey('category-product-${product.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: MallNetworkImage(
                  url: product.imageUrl,
                  width: 76,
                  height: 76,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 76,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF282D36),
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '¥${product.price.toStringAsFixed(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE95656),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (onAdd != null)
                            SizedBox.square(
                              dimension: 34,
                              child: IconButton.filled(
                                key: ValueKey(
                                  'add-category-product-${product.id}',
                                ),
                                tooltip: '加入购物车',
                                onPressed: adding ? null : onAdd,
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  backgroundColor: mallPrimary,
                                  disabledBackgroundColor: const Color(
                                    0xFFD8DDEA,
                                  ),
                                ),
                                icon: adding
                                    ? const SizedBox.square(
                                        dimension: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded, size: 21),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartSelection {
  const _CartSelection(this.sku, this.quantity);

  final ProductSku sku;
  final int quantity;
}

class _SkuSelectionSheet extends StatefulWidget {
  const _SkuSelectionSheet({required this.product});

  final CatalogProduct product;

  @override
  State<_SkuSelectionSheet> createState() => _SkuSelectionSheetState();
}

class _SkuSelectionSheetState extends State<_SkuSelectionSheet> {
  ProductSku? _selectedSku;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _selectedSku = widget.product.skus
        .where((sku) => sku.available)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final sku = _selectedSku;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MallNetworkImage(
                  url: sku?.imageUrl.isNotEmpty == true
                      ? sku!.imageUrl
                      : widget.product.imageUrl,
                  width: 68,
                  height: 68,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '¥${(sku?.price ?? widget.product.price).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFE95656),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('选择规格', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in widget.product.skus)
                ChoiceChip(
                  key: ValueKey('category-sku-${item.id}'),
                  label: Text(
                    item.specification.isEmpty ? item.name : item.specification,
                  ),
                  selected: sku?.id == item.id,
                  onSelected: item.available
                      ? (_) => setState(() {
                          _selectedSku = item;
                          _quantity = _quantity.clamp(1, item.stock);
                        })
                      : null,
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '购买数量',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton.outlined(
                tooltip: '减少',
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '$_quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton.outlined(
                tooltip: '增加',
                onPressed: sku != null && _quantity < sku.stock
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: sku == null
                ? null
                : () => Navigator.pop(context, _CartSelection(sku, _quantity)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('加入购物车'),
          ),
        ],
      ),
    );
  }
}
