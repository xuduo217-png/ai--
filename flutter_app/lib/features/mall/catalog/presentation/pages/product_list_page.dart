import 'package:flutter/material.dart';

import '../../../shared/mall_widgets.dart';
import '../../domain/catalog_models.dart';
import '../catalog_controller.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({
    super.key,
    required this.gateway,
    required this.onProduct,
    this.title = '全部商品',
    this.categoryId,
    this.popular = false,
  });

  final CatalogGateway gateway;
  final ValueChanged<CatalogProduct> onProduct;
  final String title;
  final int? categoryId;
  final bool popular;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late final CatalogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CatalogController(
      gateway: widget.gateway,
      categoryId: widget.categoryId,
      popular: widget.popular,
    )..load(includeCategories: !widget.popular);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mallBackground,
      appBar: AppBar(title: Text(widget.title)),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loading && _controller.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.errorMessage != null &&
              _controller.products.isEmpty) {
            return MallStateView(
              icon: Icons.wifi_off_outlined,
              message: _controller.errorMessage!,
              onRetry: () => _controller.load(includeCategories: true),
            );
          }
          return Column(
            children: [
              if (!widget.popular && _controller.categories.isNotEmpty)
                _categoryBar(),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 240) {
                      _controller.loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: _controller.load,
                    child: _controller.products.isEmpty
                        ? const CustomScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: MallStateView(
                                  icon: Icons.inventory_2_outlined,
                                  message: '暂无商品',
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            key: const ValueKey('mall-product-grid'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.67,
                                ),
                            itemCount:
                                _controller.products.length +
                                (_controller.loadingMore ? 2 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _controller.products.length) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final product = _controller.products[index];
                              return MallProductTile(
                                product: product,
                                onTap: () => widget.onProduct(product),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryBar() {
    final children = _controller.categories
        .expand(
          (category) =>
              category.children.isEmpty ? [category] : category.children,
        )
        .toList(growable: false);
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('全部'),
                selected: _controller.query.categoryId == null,
                showCheckmark: false,
                onSelected: (_) => _controller.selectCategory(null),
              ),
            ),
            ...children.map(
              (category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category.name),
                  selected: _controller.query.categoryId == category.id,
                  showCheckmark: false,
                  onSelected: (_) => _controller.selectCategory(category.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
