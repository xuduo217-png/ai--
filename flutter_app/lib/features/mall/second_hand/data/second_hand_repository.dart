import '../../../../core/network/api_client.dart';
import '../../catalog/data/catalog_mapper.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../shared/mall_json.dart';
import '../domain/second_hand_models.dart';

class SecondHandRepository
    implements SecondHandGateway, SecondHandMallCategoryGateway {
  SecondHandRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query) async {
    final effectiveQuery = ProductQuery(
      page: query.page,
      pageSize: query.pageSize,
      categoryId: query.categoryId,
      keyword: query.keyword,
      sortBy: query.sortBy,
      sortOrder: query.sortOrder,
      source: ProductSource.user,
    );
    final payload = await _apiClient.get(
      '/shop/products',
      authenticated: false,
      queryParameters: effectiveQuery.toQueryParameters(),
    );
    final root = asJsonMap(payload);
    final items = asJsonList(root.containsKey('data') ? root['data'] : payload)
        .map(
          (item) => catalogProductFromJson(
            asJsonMap(item),
            baseUrl: _apiClient.baseUrl,
          ),
        )
        .where((product) => product.source == ProductSource.user)
        .toList(growable: false);
    final pagination = asJsonMap(root['pagination']);
    final total = jsonInt(pagination['total'], items.length);
    final pageSize = jsonInt(
      pagination['pageSize'] ?? pagination['limit'],
      query.pageSize,
    );
    return CatalogPage(
      items: items,
      total: total,
      page: jsonInt(pagination['page'], query.page),
      pageSize: pageSize,
      totalPages: jsonInt(
        pagination['totalPages'],
        pageSize == 0 ? 0 : (total / pageSize).ceil(),
      ),
    );
  }

  @override
  Future<CatalogProduct> loadProduct(
    int productId, {
    required bool authenticated,
  }) async {
    final payload = await _apiClient.get(
      authenticated
          ? '/shop/products/$productId/detail'
          : '/shop/products/$productId',
      authenticated: authenticated,
    );
    final product = catalogProductFromJson(
      asJsonMap(unwrapData(payload)),
      baseUrl: _apiClient.baseUrl,
    );
    if (product.source != ProductSource.user) {
      throw const ApiException('该商品不是二手商品');
    }
    return product;
  }

  @override
  Future<List<SecondHandCategory>> loadCategories() async {
    final payload = await _apiClient.get(
      '/shop/products/categories/list',
      authenticated: true,
    );
    return asJsonList(
      unwrapData(payload),
    ).map((item) => _parseCategory(asJsonMap(item))).toList(growable: false);
  }

  @override
  Future<List<SecondHandCategory>> loadMallCategories() async {
    final payload = await _apiClient.get(
      '/shop/products/batch',
      authenticated: false,
      queryParameters: const {
        'includeEmpty': false,
        'limit': 50,
        'sortBy': 'isTop',
        'sortOrder': 'DESC',
      },
    );
    final categories = <SecondHandCategory>[];
    for (final item in asJsonList(unwrapData(payload))) {
      final json = asJsonMap(item);
      final children = asJsonList(json['children'])
          .map(asJsonMap)
          .where(_containsSecondHandProduct)
          .map(_parseCategory)
          .toList(growable: false);
      if (children.isEmpty) continue;
      categories.add(_parseCategory(json, children: children));
    }
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories.take(4).toList(growable: false);
  }

  @override
  Future<PendingProductPage> loadMyProducts({
    int page = 1,
    int pageSize = 10,
    List<PendingProductStatus> statuses = const [],
  }) async {
    final payload = await _apiClient.get(
      '/shop/products/my',
      queryParameters: {
        'page': page,
        'limit': pageSize,
        'status': statuses.isEmpty
            ? null
            : statuses.map((status) => status.wireValue).join(','),
      },
    );
    final responseRoot = asJsonMap(payload);
    final pageRoot = _myProductPageRoot(payload);
    final items = asJsonList(
      _myProductItemsPayload(payload, pageRoot),
    ).map((item) => _parsePending(asJsonMap(item))).toList(growable: false);
    final pagination = _myProductPagination(responseRoot, pageRoot);
    final total = jsonInt(pagination['total'], items.length);
    final actualPageSize = jsonInt(
      pagination['pageSize'] ?? pagination['limit'],
      pageSize,
    );
    return PendingProductPage(
      items: items,
      total: total,
      page: jsonInt(pagination['page'], page),
      pageSize: actualPageSize,
      totalPages: jsonInt(
        pagination['totalPages'],
        actualPageSize == 0 ? 0 : (total / actualPageSize).ceil(),
      ),
    );
  }

  @override
  Future<PendingProduct> loadPendingProduct(int pendingId) async {
    return _parsePending(
      asJsonMap(
        unwrapData(await _apiClient.get('/shop/products/pending/$pendingId')),
      ),
    );
  }

  @override
  Future<int> publishProduct(PublishProductInput input) async {
    final payload = asJsonMap(
      unwrapData(
        await _apiClient.post(
          '/shop/products/pending',
          authenticated: true,
          body: input.toJson(),
        ),
      ),
    );
    return jsonInt(payload['id']);
  }

  @override
  Future<void> updateProduct(int pendingId, PublishProductInput input) async {
    await _apiClient.put(
      '/shop/products/pending/$pendingId',
      body: input.toJson(),
    );
  }

  @override
  Future<void> updateProductStatus(int productId, bool active) async {
    await _apiClient.put(
      '/shop/products/$productId/status',
      body: {'status': active},
    );
  }

  @override
  Future<String> uploadImage(String filePath) async {
    final payload = asJsonMap(
      unwrapData(
        await _apiClient.uploadFile(
          '/upload/image',
          filePath: filePath,
          fields: const {'category': 'second-hand-product'},
        ),
      ),
    );
    final url = jsonString(payload['url']).trim();
    if (url.isEmpty) throw const ApiException('图片上传成功但未返回地址');
    return resolveMallImage(_apiClient.baseUrl, url);
  }

  @override
  Future<void> reportProduct(
    int productId, {
    required String reason,
    String? description,
  }) async {
    await _apiClient.post(
      '/moderation/reports',
      authenticated: true,
      body: compactJson({
        'targetType': 'SECOND_HAND_PRODUCT',
        'targetId': productId,
        'reason': reason,
        'description': description,
      }),
    );
  }

  @override
  Future<void> blockUser(int userId, {String? reason}) async {
    await _apiClient.post(
      '/moderation/blocks',
      authenticated: true,
      body: compactJson({'blockedUserId': userId, 'reason': reason}),
    );
  }

  bool _containsSecondHandProduct(Map<String, dynamic> json) {
    return asJsonList(json['products']).any(
      (product) =>
          jsonString(asJsonMap(product)['publishSource']).toUpperCase() ==
          ProductSource.user.wireValue,
    );
  }

  SecondHandCategory _parseCategory(
    Map<String, dynamic> json, {
    List<SecondHandCategory>? children,
  }) {
    return SecondHandCategory(
      id: jsonInt(json['id']),
      name: jsonString(json['name']),
      iconUrl: resolveMallImage(
        _apiClient.baseUrl,
        json['icon'] ?? json['image'],
      ),
      sortOrder: jsonInt(json['sortOrder']),
      children:
          children ??
          asJsonList(json['children'])
              .map((item) => _parseCategory(asJsonMap(item)))
              .toList(growable: false),
    );
  }

  PendingProduct _parsePending(Map<String, dynamic> json) {
    final category = asJsonMap(json['category']);
    return PendingProduct(
      id: jsonInt(json['id']),
      userId: jsonInt(json['userId']),
      productId: jsonInt(json['productId']) > 0
          ? jsonInt(json['productId'])
          : null,
      title: jsonString(json['title']),
      description: jsonString(json['description']),
      price: jsonDouble(json['price']),
      stock: jsonInt(json['stock'], 1),
      negotiable: jsonBool(json['negotiable']),
      images: asJsonList(json['images'])
          .map((item) => resolveMallImage(_apiClient.baseUrl, item))
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      categoryId: jsonInt(json['categoryId']),
      categoryName: jsonString(category['name']),
      condition: ProductCondition.fromJson(json['condition']),
      shippingFee: jsonDouble(json['shippingFee']),
      status: PendingProductStatus.fromJson(json['status']),
      rejectReason: jsonNullableString(json['rejectReason']),
      isActive: json['isActive'] == null ? null : jsonBool(json['isActive']),
      createdAt: jsonDateTime(json['createdAt']),
      updatedAt: jsonDateTime(json['updatedAt']),
    );
  }
}

Map<String, dynamic> _myProductPageRoot(Object? payload) {
  var current = asJsonMap(payload);
  for (var depth = 0; depth < 4; depth += 1) {
    if (current['data'] is List ||
        current['items'] is List ||
        current['list'] is List) {
      return current;
    }
    final nested = asJsonMap(current['data']);
    if (nested.isEmpty) return current;
    current = nested;
  }
  return current;
}

Object? _myProductItemsPayload(Object? payload, Map<String, dynamic> pageRoot) {
  if (payload is List) return payload;
  for (final key in const ['data', 'items', 'list']) {
    if (pageRoot[key] is List) return pageRoot[key];
  }
  return const [];
}

Map<String, dynamic> _myProductPagination(
  Map<String, dynamic> responseRoot,
  Map<String, dynamic> pageRoot,
) {
  final candidates = [
    asJsonMap(pageRoot['pagination']),
    asJsonMap(pageRoot['meta']),
    pageRoot,
    asJsonMap(responseRoot['pagination']),
    asJsonMap(responseRoot['meta']),
    responseRoot,
  ];
  const fields = {'total', 'page', 'pageSize', 'limit', 'totalPages'};
  for (final candidate in candidates) {
    if (candidate.keys.any(fields.contains)) return candidate;
  }
  return const {};
}
