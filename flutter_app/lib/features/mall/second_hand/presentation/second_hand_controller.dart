import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/second_hand_models.dart';

enum PublishedProductFilter {
  all('全部', []),
  onSale('在售', [PendingProductStatus.onShelf, PendingProductStatus.offShelf]),
  sold('已售出', [PendingProductStatus.sold]),
  audit('审核', [
    PendingProductStatus.underReview,
    PendingProductStatus.rejected,
  ]);

  const PublishedProductFilter(this.label, this.statuses);
  final String label;
  final List<PendingProductStatus> statuses;
}

class SecondHandMallController extends ChangeNotifier {
  SecondHandMallController(this._gateway);
  final SecondHandGateway _gateway;

  List<SecondHandCategory> categories = const [];
  List<CatalogProduct> products = const [];
  int? categoryId;
  String keyword = '';
  int page = 1;
  bool hasMore = false;
  bool loading = false;
  bool loadingMore = false;
  String? errorMessage;
  String? categoryErrorMessage;
  int _requestRevision = 0;
  bool _disposed = false;

  Future<void> load() => _load(refreshCategories: true);

  Future<void> _load({required bool refreshCategories}) async {
    if (_disposed) return;
    final revision = ++_requestRevision;
    loading = true;
    loadingMore = false;
    errorMessage = null;
    if (refreshCategories) categoryErrorMessage = null;
    _notify();

    if (refreshCategories) {
      final categoryResult = await _capture(_loadMallCategories());
      if (!_isCurrent(revision)) return;
      if (categoryResult.error == null) {
        categories = categoryResult.value!;
        _syncCategorySelection();
      } else {
        categoryErrorMessage = _readableError(
          categoryResult.error!,
          fallback: '分类加载失败，请下拉刷新重试',
        );
      }
    }

    final productResult = await _capture(
      _gateway.loadProducts(
        ProductQuery(
          pageSize: 10,
          categoryId: categoryId,
          keyword: keyword,
          source: ProductSource.user,
        ),
      ),
    );
    if (!_isCurrent(revision)) return;
    if (productResult.error == null) {
      final result = productResult.value!;
      products = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } else {
      errorMessage = _readableError(
        productResult.error!,
        fallback: '商品加载失败，请稍后重试',
      );
    }

    loading = false;
    _notify();
  }

  Future<void> selectCategory(int? value) async {
    if (_disposed || categoryId == value) return;
    categoryId = value;
    await _load(refreshCategories: false);
  }

  Future<void> selectFirstCategory(SecondHandCategory category) {
    final selectedId = category.children.isEmpty
        ? category.id
        : category.children.first.id;
    return selectCategory(selectedId);
  }

  Future<void> search(String value) async {
    final normalized = value.trim();
    if (_disposed || keyword == normalized) return;
    keyword = normalized;
    await _load(refreshCategories: false);
  }

  Future<void> loadMore() async {
    if (_disposed || !hasMore || loading || loadingMore) return;
    final revision = _requestRevision;
    final requestCategoryId = categoryId;
    final requestKeyword = keyword;
    final nextPage = page + 1;
    loadingMore = true;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadProducts(
        ProductQuery(
          page: nextPage,
          pageSize: 10,
          categoryId: requestCategoryId,
          keyword: requestKeyword,
          source: ProductSource.user,
        ),
      );
      if (!_isCurrent(revision) ||
          categoryId != requestCategoryId ||
          keyword != requestKeyword) {
        return;
      }
      final byId = <int, CatalogProduct>{
        for (final product in products) product.id: product,
      };
      for (final product in result.items) {
        byId[product.id] = product;
      }
      products = byId.values.toList(growable: false);
      page = result.page;
      hasMore = result.hasMore;
    } catch (error) {
      if (!_isCurrent(revision) ||
          categoryId != requestCategoryId ||
          keyword != requestKeyword) {
        return;
      }
      errorMessage = _readableError(error, fallback: '加载更多失败，请稍后重试');
    } finally {
      if (_isCurrent(revision) &&
          categoryId == requestCategoryId &&
          keyword == requestKeyword) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<List<SecondHandCategory>> _loadMallCategories() {
    final gateway = _gateway;
    if (gateway is SecondHandMallCategoryGateway) {
      return (gateway as SecondHandMallCategoryGateway).loadMallCategories();
    }
    return gateway.loadCategories();
  }

  void _syncCategorySelection() {
    if (categories.isEmpty) {
      categoryId = null;
      return;
    }
    final currentId = categoryId;
    final currentIsValid =
        currentId != null &&
        categories.any(
          (category) =>
              category.id == currentId ||
              category.children.any((child) => child.id == currentId),
        );
    if (currentIsValid) return;
    final first = categories.first;
    categoryId = first.children.isEmpty ? first.id : first.children.first.id;
  }

  bool _isCurrent(int revision) => !_disposed && revision == _requestRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestRevision += 1;
    super.dispose();
  }
}

Future<_RequestResult<T>> _capture<T>(Future<T> request) async {
  try {
    return _RequestResult.success(await request);
  } catch (error) {
    return _RequestResult.failure(error);
  }
}

String _readableError(Object error, {required String fallback}) {
  if (error is ApiException) {
    final message = error.message.trim();
    if (error.statusCode == 401 || message.toLowerCase() == 'unauthorized') {
      return '登录状态已失效，请重新登录';
    }
    return message.isEmpty ? fallback : message;
  }
  final message = '$error'
      .replaceFirst(RegExp(r'^Bad state:\s*'), '')
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .trim();
  if (message.toLowerCase() == 'unauthorized') {
    return '登录状态已失效，请重新登录';
  }
  return message.isEmpty ? fallback : message;
}

class _RequestResult<T> {
  const _RequestResult.success(this.value) : error = null;
  const _RequestResult.failure(this.error) : value = null;

  final T? value;
  final Object? error;
}

class PublishedProductController extends ChangeNotifier {
  PublishedProductController(this._gateway);
  final SecondHandGateway _gateway;

  PublishedProductFilter filter = PublishedProductFilter.all;
  List<PendingProduct> products = const [];
  int page = 1;
  bool hasMore = false;
  bool loading = false;
  bool loadingMore = false;
  String? errorMessage;
  int _requestRevision = 0;
  bool _disposed = false;

  Future<void> load({PublishedProductFilter? nextFilter}) async {
    if (_disposed) return;
    if (nextFilter != null && filter != nextFilter) {
      filter = nextFilter;
      products = const [];
    }
    final revision = ++_requestRevision;
    final requestFilter = filter;
    loading = true;
    loadingMore = false;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadMyProducts(
        statuses: requestFilter.statuses,
      );
      if (!_isCurrent(revision)) return;
      products = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      errorMessage = '$error';
    } finally {
      if (_isCurrent(revision)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || !hasMore || loading || loadingMore) return;
    final revision = ++_requestRevision;
    final requestFilter = filter;
    final nextPage = page + 1;
    loadingMore = true;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadMyProducts(
        page: nextPage,
        statuses: requestFilter.statuses,
      );
      if (!_isCurrent(revision)) return;
      final byId = <int, PendingProduct>{
        for (final product in products) product.id: product,
      };
      for (final product in result.items) {
        byId[product.id] = product;
      }
      products = byId.values.toList(growable: false);
      page = result.page;
      hasMore = result.hasMore;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      errorMessage = '$error';
    } finally {
      if (_isCurrent(revision)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> toggleShelf(PendingProduct product) async {
    if (_disposed) return;
    final id = product.productId;
    if (id == null) return;
    await _gateway.updateProductStatus(id, product.isActive != true);
    if (!_disposed) await load();
  }

  bool _isCurrent(int revision) => !_disposed && revision == _requestRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestRevision += 1;
    super.dispose();
  }
}

class PublishProductController extends ChangeNotifier {
  PublishProductController(this._gateway, {this.pendingId});
  final SecondHandGateway _gateway;
  final int? pendingId;

  List<SecondHandCategory> categories = const [];
  PendingProduct? product;
  bool loading = false;
  bool uploading = false;
  bool submitting = false;
  String? errorMessage;
  bool _disposed = false;

  bool get editing => pendingId != null;

  Future<void> load() async {
    if (_disposed) return;
    loading = true;
    errorMessage = null;
    _notify();
    try {
      final loadedCategories = await _gateway.loadCategories();
      if (_disposed) return;
      categories = loadedCategories;
      if (pendingId != null) {
        final loadedProduct = await _gateway.loadPendingProduct(pendingId!);
        if (_disposed) return;
        product = loadedProduct;
      }
    } catch (error) {
      if (_disposed) return;
      errorMessage = '$error';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<String?> upload(String filePath) async {
    if (_disposed) return null;
    uploading = true;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.uploadImage(filePath);
      return _disposed ? null : result;
    } catch (error) {
      if (_disposed) return null;
      errorMessage = '$error';
      return null;
    } finally {
      if (!_disposed) {
        uploading = false;
        _notify();
      }
    }
  }

  Future<bool> submit(PublishProductInput input) async {
    if (_disposed) return false;
    final validation = input.validate();
    if (validation != null) {
      errorMessage = validation;
      _notify();
      return false;
    }
    submitting = true;
    errorMessage = null;
    _notify();
    try {
      if (pendingId == null) {
        await _gateway.publishProduct(input);
      } else {
        await _gateway.updateProduct(pendingId!, input);
      }
      return !_disposed;
    } catch (error) {
      if (_disposed) return false;
      errorMessage = '$error';
      return false;
    } finally {
      if (!_disposed) {
        submitting = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
