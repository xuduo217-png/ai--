import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/catalog_models.dart';

class CatalogController extends ChangeNotifier {
  CatalogController({
    required CatalogGateway gateway,
    ProductSource source = ProductSource.admin,
    int? categoryId,
    bool popular = false,
  }) : _gateway = gateway,
       _query = ProductQuery(source: source, categoryId: categoryId),
       _popular = popular;

  final CatalogGateway _gateway;
  final bool _popular;
  ProductQuery _query;

  List<CatalogProduct> products = const [];
  List<CatalogCategory> categories = const [];
  List<String> searchHistory = const [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  String? errorMessage;

  ProductQuery get query => _query;

  Future<void> load({bool includeCategories = false}) async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _loadPage(_query.copyWith(page: 1));
      products = page.items;
      hasMore = page.hasMore;
      _query = _query.copyWith(page: page.page);
      if (includeCategories) {
        categories = await _gateway.loadCategoryTree(source: _query.source);
      }
    } catch (error) {
      errorMessage = '$error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    _query = ProductQuery(
      source: _query.source,
      categoryId: _query.categoryId,
      keyword: normalized.isEmpty ? null : normalized,
    );
    if (normalized.isNotEmpty) await _rememberSearch(normalized);
    await load();
  }

  Future<void> selectCategory(int? categoryId) async {
    _query = ProductQuery(
      source: _query.source,
      categoryId: categoryId,
      keyword: _query.keyword,
    );
    await load();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final nextQuery = _query.copyWith(page: _query.page + 1);
      final page = await _loadPage(nextQuery);
      products = [...products, ...page.items];
      _query = nextQuery.copyWith(page: page.page);
      hasMore = page.hasMore;
    } catch (error) {
      errorMessage = '$error';
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    searchHistory = preferences.getStringList(_historyKey) ?? const [];
    notifyListeners();
  }

  Future<void> clearHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_historyKey);
    searchHistory = const [];
    notifyListeners();
  }

  Future<void> _rememberSearch(String keyword) async {
    final preferences = await SharedPreferences.getInstance();
    final next = [
      keyword,
      ...searchHistory.where((item) => item != keyword),
    ].take(10).toList(growable: false);
    await preferences.setStringList(_historyKey, next);
    searchHistory = next;
  }

  Future<CatalogPage<CatalogProduct>> _loadPage(ProductQuery query) {
    final hasKeyword = query.keyword?.trim().isNotEmpty == true;
    return _popular && !hasKeyword
        ? _gateway.loadPopularProducts(query)
        : _gateway.loadProducts(query);
  }

  static const _historyKey = 'mall_search_history';
}

class ProductDetailController extends ChangeNotifier {
  ProductDetailController({
    required CatalogGateway catalogGateway,
    required this.productId,
    required this.authenticated,
  }) : _catalogGateway = catalogGateway;

  final CatalogGateway _catalogGateway;
  final int productId;
  final bool authenticated;

  CatalogProduct? product;
  ProductSku? selectedSku;
  int quantity = 1;
  bool loading = false;
  String? errorMessage;

  int get availableStock => selectedSku?.stock ?? product?.stock ?? 0;
  double get price => selectedSku?.price ?? product?.price ?? 0;
  bool get canSubmit =>
      product?.available == true &&
      (!product!.hasSku || selectedSku?.available == true) &&
      quantity <= availableStock;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      product = await _catalogGateway.loadProduct(
        productId,
        authenticated: authenticated,
      );
      if (product!.hasSku) {
        selectedSku = product!.skus.where((sku) => sku.available).firstOrNull;
      }
      quantity = 1;
    } catch (error) {
      errorMessage = '$error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectSku(ProductSku sku) {
    if (!sku.available) return;
    selectedSku = sku;
    quantity = quantity.clamp(1, sku.stock);
    notifyListeners();
  }

  void changeQuantity(int delta) {
    final next = (quantity + delta).clamp(1, availableStock);
    if (next == quantity) return;
    quantity = next;
    notifyListeners();
  }

  void setFavorite(bool value) {
    product = product?.copyWith(isFavorited: value);
    notifyListeners();
  }
}
