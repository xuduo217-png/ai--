import 'package:flutter/material.dart';

import '../../../shared/mall_widgets.dart';
import '../../domain/catalog_models.dart';
import '../catalog_controller.dart';

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    super.key,
    required this.gateway,
    required this.onProduct,
  });

  final CatalogGateway gateway;
  final ValueChanged<CatalogProduct> onProduct;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  late final CatalogController _controller;
  final _searchController = TextEditingController();
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _controller = CatalogController(gateway: widget.gateway, popular: true);
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([_controller.loadHistory(), _controller.load()]);
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
        titleSpacing: 0,
        title: TextField(
          key: const ValueKey('mall-search-input'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          autofocus: true,
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: '搜索商品',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: '清空',
              onPressed: () {
                _searchController.clear();
                setState(() => _searched = false);
                _controller.search('');
              },
              icon: const Icon(Icons.close),
            ),
            filled: true,
            fillColor: const Color(0xFFF1F3F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _submit(_searchController.text),
            child: const Text('搜索'),
          ),
          const SizedBox(width: 6),
        ],
      ),
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
              onRetry: _controller.load,
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 280) {
                _controller.loadMore();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: _controller.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (!_searched && _controller.searchHistory.isNotEmpty)
                    SliverToBoxAdapter(child: _history()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                      child: Text(
                        _searched ? '搜索结果' : '热门商品',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (_controller.products.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: MallStateView(
                        icon: Icons.search_off,
                        message: '没有找到相关商品',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.67,
                            ),
                        itemCount: _controller.products.length,
                        itemBuilder: (context, index) {
                          final product = _controller.products[index];
                          return MallProductTile(
                            product: product,
                            onTap: () => widget.onProduct(product),
                          );
                        },
                      ),
                    ),
                  if (_controller.loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _history() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '搜索历史',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '清空搜索历史',
                onPressed: _controller.clearHistory,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _controller.searchHistory
                .map(
                  (keyword) => ActionChip(
                    label: Text(keyword),
                    onPressed: () {
                      _searchController.text = keyword;
                      _submit(keyword);
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  void _submit(String value) {
    FocusScope.of(context).unfocus();
    setState(() => _searched = value.trim().isNotEmpty);
    _controller.search(value);
  }
}
