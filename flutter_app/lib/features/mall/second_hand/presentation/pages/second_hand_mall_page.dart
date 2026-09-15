import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../catalog/domain/catalog_models.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/second_hand_models.dart';
import '../second_hand_controller.dart';

const _secondHandHeaderBackgroundColor = Color(0xFFDEE9FF);

class SecondHandMallPage extends StatefulWidget {
  const SecondHandMallPage({
    super.key,
    required this.gateway,
    required this.onProduct,
  });

  final SecondHandGateway gateway;
  final ValueChanged<CatalogProduct> onProduct;

  @override
  State<SecondHandMallPage> createState() => _SecondHandMallPageState();
}

class _SecondHandMallPageState extends State<SecondHandMallPage> {
  late final SecondHandMallController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = SecondHandMallController(widget.gateway)..load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mallBackground,
      appBar: AppBar(
        key: const ValueKey('second-hand-header'),
        backgroundColor: _secondHandHeaderBackgroundColor,
        surfaceTintColor: _secondHandHeaderBackgroundColor,
        foregroundColor: AppColors.ink,
        centerTitle: true,
        title: const Text('二手商城'),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _body(),
      ),
    );
  }

  Widget _body() {
    if (_controller.loading && _controller.products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('加载中...', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    if (_controller.errorMessage != null &&
        _controller.products.isEmpty &&
        _controller.categories.isEmpty) {
      return MallStateView(
        icon: Icons.wifi_off_outlined,
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }
    final selectedFirstCategory = _selectedFirstCategory;
    return Column(
      children: [
        _SecondHandSearchBar(
          controller: _searchController,
          onSubmitted: _submitSearch,
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_controller.categories.isEmpty) {
                return _productPane(null);
              }
              final leftWidth = constraints.maxWidth <= 340 ? 84.0 : 94.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: leftWidth, child: _firstCategoryList()),
                  Expanded(child: _productPane(selectedFirstCategory)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _firstCategoryList() {
    final selectedId = _selectedFirstCategory?.id;
    return ColoredBox(
      color: const Color(0xFFF0F2F6),
      child: ListView.builder(
        key: const ValueKey('second-hand-first-category-list'),
        padding: EdgeInsets.zero,
        itemCount: _controller.categories.length,
        itemBuilder: (context, index) {
          final category = _controller.categories[index];
          final hasImage = category.iconUrl.isNotEmpty;
          final selected = selectedId == category.id;
          return SizedBox(
            height: hasImage ? 84 : 56,
            child: Material(
              color: selected ? Colors.white : Colors.transparent,
              child: InkWell(
                key: ValueKey('second-hand-first-category-${category.id}'),
                onTap: () => _controller.selectFirstCategory(category),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (selected)
                      Positioned(
                        key: ValueKey(
                          'second-hand-selected-first-category-${category.id}',
                        ),
                        left: 0,
                        top: hasImage ? 18 : 12,
                        bottom: hasImage ? 18 : 12,
                        child: const DecoratedBox(
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
                          children: [
                            if (hasImage) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: MallNetworkImage(
                                  url: category.iconUrl,
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

  Widget _productPane(SecondHandCategory? category) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          _controller.loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _controller.load,
        child: CustomScrollView(
          key: const ValueKey('second-hand-product-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (category != null)
              SliverToBoxAdapter(child: _CategoryHeader(category: category)),
            if (category?.children.isNotEmpty == true)
              SliverToBoxAdapter(
                child: _SecondCategoryChips(
                  category: category!,
                  selectedId: _controller.categoryId,
                  onSelected: _controller.selectCategory,
                ),
              ),
            if (_controller.categoryErrorMessage != null)
              SliverToBoxAdapter(
                child: _InlineError(
                  message: _controller.categoryErrorMessage!,
                  onRetry: _controller.load,
                  warning: true,
                ),
              ),
            if (_controller.errorMessage != null &&
                _controller.products.isNotEmpty)
              SliverToBoxAdapter(
                child: _InlineError(
                  message: _controller.errorMessage!,
                  onRetry: _controller.load,
                ),
              ),
            if (_controller.loading && _controller.products.isNotEmpty)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_controller.products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MallStateView(
                  icon: Icons.inventory_2_outlined,
                  message: _controller.keyword.isEmpty ? '暂无二手商品' : '未找到相关二手商品',
                ),
              )
            else
              SliverList.builder(
                key: const ValueKey('second-hand-product-list'),
                itemCount: _controller.products.length,
                itemBuilder: (context, index) {
                  final product = _controller.products[index];
                  return _SecondHandProductRow(
                    product: product,
                    onTap: () => widget.onProduct(product),
                  );
                },
              ),
            if (_controller.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  SecondHandCategory? get _selectedFirstCategory {
    final selectedId = _controller.categoryId;
    for (final category in _controller.categories) {
      if (category.id == selectedId ||
          category.children.any((child) => child.id == selectedId)) {
        return category;
      }
    }
    return _controller.categories.firstOrNull;
  }

  void _submitSearch(String value) {
    FocusScope.of(context).unfocus();
    _controller.search(value);
  }
}

class _SecondHandSearchBar extends StatelessWidget {
  const _SecondHandSearchBar({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('second-hand-search-area'),
      color: _secondHandHeaderBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: SizedBox(
          height: 42,
          child: TextField(
            key: const ValueKey('second-hand-search-input'),
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: '搜索二手商品',
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 21,
                color: Color(0xFF9299A6),
              ),
              filled: true,
              fillColor: const Color(0xFFF3F5F8),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E8EE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E8EE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: mallPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final SecondHandCategory category;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
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
    );
  }
}

class _SecondCategoryChips extends StatelessWidget {
  const _SecondCategoryChips({
    required this.category,
    required this.selectedId,
    required this.onSelected,
  });

  final SecondHandCategory category;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 2, 12, 10),
        child: Row(
          children: [
            for (final child in category.children)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  key: ValueKey(
                    'second-hand-second-category-${category.id}-${child.id}',
                  ),
                  label: Text(child.name),
                  selected: selectedId == child.id,
                  onSelected: (_) => onSelected(child.id),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  backgroundColor: const Color(0xFFF1F3F6),
                  selectedColor: const Color(0xFFE9EDFF),
                  labelStyle: TextStyle(
                    color: selectedId == child.id
                        ? mallPrimary
                        : const Color(0xFF666D7A),
                    fontSize: 12,
                    fontWeight: selectedId == child.id
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SecondHandProductRow extends StatelessWidget {
  const _SecondHandProductRow({required this.product, required this.onTap});

  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        key: ValueKey('second-hand-product-${product.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0F1F4))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (product.sellerLabel.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.sellerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8A909C),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
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
                        SizedBox(
                          width: 72,
                          height: 32,
                          child: FilledButton(
                            key: ValueKey(
                              'buy-second-hand-product-${product.id}',
                            ),
                            onPressed: product.available ? onTap : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              minimumSize: const Size(72, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Text(product.available ? '立即购买' : '已售罄'),
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
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.onRetry,
    this.warning = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final foreground = warning
        ? const Color(0xFF92400E)
        : const Color(0xFFB42318);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: warning ? const Color(0xFFFFF7ED) : const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                warning ? Icons.info_outline : Icons.error_outline,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}
