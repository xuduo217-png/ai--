import '../../../../core/network/api_client.dart';
import '../../shared/mall_json.dart';
import '../domain/catalog_models.dart';

class CatalogRepository implements CatalogGateway {
  CatalogRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query) async {
    final payload = await _apiClient.get(
      '/shop/products',
      authenticated: false,
      queryParameters: query.toQueryParameters(),
    );
    return _parsePage(payload, query);
  }

  @override
  Future<CatalogPage<CatalogProduct>> loadPopularProducts(
    ProductQuery query,
  ) async {
    final payload = await _apiClient.get(
      '/shop/products/popular',
      authenticated: false,
      queryParameters: query.toQueryParameters(),
    );
    return _parsePage(payload, query);
  }

  @override
  Future<List<CatalogCategory>> loadCategoryTree({
    ProductSource source = ProductSource.admin,
  }) async {
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
    final categories = asJsonList(unwrapData(payload))
        .map((item) => _parseCategory(asJsonMap(item)))
        .where((category) => category.containsSource(source))
        .map((category) => _filterCategory(category, source))
        .toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
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
    return _parseProduct(asJsonMap(unwrapData(payload)));
  }

  @override
  Future<List<CatalogBanner>> loadBanners() async {
    final payload = await _apiClient.get(
      '/shop/homepage-banners',
      authenticated: false,
    );
    final unwrapped = unwrapData(payload);
    final list = unwrapped is List
        ? unwrapped
        : asJsonList(asJsonMap(unwrapped)['banners']);
    return list
        .map((item) => asJsonMap(item))
        .where((item) => jsonString(item['imageUrl']).trim().isNotEmpty)
        .map(
          (item) => CatalogBanner(
            id: jsonString(item['id']),
            imageUrl: resolveMallImage(_apiClient.baseUrl, item['imageUrl']),
            actionType: jsonNullableString(item['actionType']),
            productId: jsonInt(item['productId']) > 0
                ? jsonInt(item['productId'])
                : null,
            link: jsonNullableString(item['link']),
          ),
        )
        .toList(growable: false);
  }

  CatalogPage<CatalogProduct> _parsePage(Object? payload, ProductQuery query) {
    final root = asJsonMap(payload);
    final data = root.containsKey('data') ? root['data'] : payload;
    final items = asJsonList(data)
        .map((item) => _parseProduct(asJsonMap(item)))
        .where((product) => product.source == query.source)
        .toList(growable: false);
    final pagination = asJsonMap(root['pagination']);
    final total = jsonInt(pagination['total'], items.length);
    final page = jsonInt(pagination['page'], query.page);
    final pageSize = jsonInt(
      pagination['pageSize'] ?? pagination['limit'],
      query.pageSize,
    );
    return CatalogPage(
      items: items,
      total: total,
      page: page,
      pageSize: pageSize,
      totalPages: jsonInt(
        pagination['totalPages'],
        pageSize > 0 ? (total / pageSize).ceil() : 0,
      ),
    );
  }

  CatalogCategory _parseCategory(Map<String, dynamic> json) {
    return CatalogCategory(
      id: jsonInt(json['id']),
      name: jsonString(json['name']),
      iconUrl: resolveMallImage(_apiClient.baseUrl, json['icon']),
      imageUrl: resolveMallImage(_apiClient.baseUrl, json['image']),
      description: jsonString(json['description']),
      status: jsonString(json['status'], 'ACTIVE'),
      sortOrder: jsonInt(json['sortOrder']),
      parentId: jsonInt(json['parentId']) > 0
          ? jsonInt(json['parentId'])
          : null,
      children: asJsonList(
        json['children'],
      ).map((item) => _parseCategory(asJsonMap(item))).toList(growable: false),
      products: asJsonList(
        json['products'],
      ).map((item) => _parseProduct(asJsonMap(item))).toList(growable: false),
    );
  }

  CatalogCategory _filterCategory(
    CatalogCategory category,
    ProductSource source,
  ) {
    return CatalogCategory(
      id: category.id,
      name: category.name,
      iconUrl: category.iconUrl,
      imageUrl: category.imageUrl,
      description: category.description,
      status: category.status,
      sortOrder: category.sortOrder,
      parentId: category.parentId,
      products: category.products
          .where((product) => product.source == source)
          .toList(growable: false),
      children: category.children
          .where((child) => child.containsSource(source))
          .map((child) => _filterCategory(child, source))
          .toList(growable: false),
    );
  }

  CatalogProduct _parseProduct(Map<String, dynamic> json) {
    final imageValues = asJsonList(json['images'])
        .map((image) => resolveMallImage(_apiClient.baseUrl, image))
        .where((image) => image.isNotEmpty)
        .toList(growable: false);
    final primaryImage = imageValues.isNotEmpty
        ? imageValues.first
        : resolveMallImage(_apiClient.baseUrl, json['image']);
    final publisherJson = asJsonMap(json['publisher']);
    final originalPrice = json['originalPrice'];
    return CatalogProduct(
      id: jsonInt(json['id']),
      name: jsonString(json['name']),
      description: jsonString(json['description']),
      price: jsonDouble(json['price']),
      originalPrice: originalPrice == null ? null : jsonDouble(originalPrice),
      stock: jsonInt(json['stock']),
      imageUrl: primaryImage,
      images: imageValues.isEmpty && primaryImage.isNotEmpty
          ? [primaryImage]
          : imageValues,
      isActive: jsonBool(json['isActive'], true),
      categoryId: jsonInt(json['categoryId']) > 0
          ? jsonInt(json['categoryId'])
          : null,
      hasSku: jsonBool(json['hasSku']),
      skus: asJsonList(
        json['skus'],
      ).map((item) => _parseSku(asJsonMap(item))).toList(growable: false),
      sells: jsonInt(json['sells']),
      isHot: jsonBool(json['isHot']),
      isTop: jsonBool(json['isTop']),
      isFavorited: jsonBool(json['isFavorited']),
      source: ProductSource.fromJson(json['publishSource']),
      publishedBy: jsonInt(json['publishedBy']) > 0
          ? jsonInt(json['publishedBy'])
          : null,
      publisher: publisherJson.isEmpty
          ? null
          : ProductPublisher(
              id: jsonInt(publisherJson['id']),
              nickname: jsonString(publisherJson['nickname']),
              username: jsonString(publisherJson['username']),
              phone: jsonString(publisherJson['phone']),
            ),
      condition: jsonNullableString(json['condition']),
      negotiable: jsonBool(json['negotiable']),
      shippingFee: jsonDouble(json['shippingFee']),
    );
  }

  ProductSku _parseSku(Map<String, dynamic> json) {
    final specs = asJsonMap(
      json['specs'],
    ).map((key, value) => MapEntry(key, jsonString(value)));
    return ProductSku(
      id: jsonInt(json['id']),
      name: jsonString(json['name']),
      specs: specs,
      price: jsonDouble(json['price']),
      originalPrice: json['originalPrice'] == null
          ? null
          : jsonDouble(json['originalPrice']),
      stock: jsonInt(json['stock']),
      status: jsonString(json['status']).toUpperCase(),
      imageUrl: resolveMallImage(_apiClient.baseUrl, json['image']),
      skuCode: jsonString(json['skuCode']),
    );
  }
}
