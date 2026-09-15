import '../../../core/network/api_client.dart';
import '../shared/mall_json.dart';
import '../domain/mall_models.dart';

class MallRepository implements MallGateway {
  MallRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<MallSnapshot> loadMall({required bool authenticated}) async {
    final results = await Future.wait<Object>([
      _withFallback(_loadCategories, const <MallCategory>[]),
      _withFallback(_loadPopularProducts, const <MallProduct>[]),
      _withFallback(_loadBanners, const <MallBanner>[]),
      _withFallback(_loadHomePopupImage, ''),
      authenticated
          ? _withFallback(loadCartBadge, false)
          : Future<Object>.value(false),
    ]);
    final banners = results[2] as List<MallBanner>;

    return MallSnapshot(
      categories: results[0] as List<MallCategory>,
      products: results[1] as List<MallProduct>,
      banners: banners.isEmpty
          ? const [MallBanner(id: 'default-store-banner', imageUrl: '')]
          : banners,
      homePopupImageUrl: results[3] as String,
      hasCartItems: results[4] as bool,
    );
  }

  @override
  Future<MallProduct> loadProduct(int productId) async {
    final payload = await _apiClient.get(
      '/shop/products/$productId',
      authenticated: false,
    );
    return _parseProduct(_asMap(payload));
  }

  @override
  Future<void> addToCart({
    required int productId,
    required int? skuId,
    required int quantity,
  }) async {
    await _apiClient.post(
      '/shop/cart',
      authenticated: true,
      body: {'productId': productId, 'skuId': ?skuId, 'quantity': quantity},
    );
  }

  @override
  Future<bool> loadCartBadge() async {
    final payload = _asMap(
      await _apiClient.get('/shop/cart/count', authenticated: true),
    );
    return _toInt(payload['count']) > 0;
  }

  Future<List<MallCategory>> _loadCategories() async {
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

    final categories = <MallCategory>[];
    for (final item in _asList(payload)) {
      final category = _asMap(item);
      final hasAdminProducts = _asList(category['children']).any((child) {
        return _asList(_asMap(child)['products']).any((product) {
          return '${_asMap(product)['publishSource'] ?? ''}' != 'USER';
        });
      });
      if (!hasAdminProducts) {
        continue;
      }
      final image = '${category['icon'] ?? category['image'] ?? ''}';
      categories.add(
        MallCategory(
          id: _toInt(category['id']),
          name: '${category['name'] ?? ''}',
          imageUrl: _imageUrl(image),
          sortOrder: _toInt(category['sortOrder']),
        ),
      );
    }
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories.take(4).toList(growable: false);
  }

  Future<List<MallProduct>> _loadPopularProducts() async {
    final payload = await _apiClient.get(
      '/shop/products/popular',
      authenticated: false,
      queryParameters: const {
        'page': 1,
        'pageSize': 10,
        'sortBy': 'isTop',
        'sortOrder': 'DESC',
        'publishSource': 'ADMIN',
        'isActive': true,
      },
    );
    final productsPayload = payload is Map<String, dynamic>
        ? payload['data']
        : payload;

    return _asList(productsPayload)
        .map((item) => _parseProduct(_asMap(item)))
        .where((product) => product.publishSource != 'USER')
        .toList(growable: false);
  }

  Future<List<MallBanner>> _loadBanners() async {
    final payload = await _apiClient.get(
      '/shop/homepage-banners',
      authenticated: false,
    );
    final bannerPayload = payload is Map<String, dynamic>
        ? payload['banners']
        : payload;

    return _asList(bannerPayload)
        .map(_asMap)
        .where((banner) => '${banner['imageUrl'] ?? ''}'.trim().isNotEmpty)
        .map(
          (banner) => MallBanner(
            id: '${banner['id'] ?? ''}',
            imageUrl: _imageUrl('${banner['imageUrl']}'),
            actionType: banner['actionType']?.toString(),
            productId: _positiveIntOrNull(banner['productId']),
            link: banner['link']?.toString(),
          ),
        )
        .toList(growable: false);
  }

  Future<String> _loadHomePopupImage() async {
    final payload = await _apiClient.get(
      '/system-configs/mall_home_popup_image',
      authenticated: false,
    );
    final configValue = _asMapOrEmpty(_asMap(payload)['configValue']);
    return _imageUrl('${configValue['imageUrl'] ?? ''}');
  }

  MallProduct _parseProduct(Map<String, dynamic> product) {
    final images = _asList(product['images']);
    final image = images.isNotEmpty
        ? '${images.first}'
        : '${product['image'] ?? ''}';
    return MallProduct(
      id: _toInt(product['id']),
      name: '${product['name'] ?? ''}',
      price: _toDouble(product['price']),
      imageUrl: _imageUrl(image),
      stock: _toInt(product['stock']),
      hasSku: _toBool(product['hasSku']),
      isTop: _toBool(product['isTop']),
      publishSource: '${product['publishSource'] ?? 'ADMIN'}',
      skus: _asList(
        product['skus'],
      ).map((item) => _parseSku(_asMap(item))).toList(growable: false),
    );
  }

  MallSku _parseSku(Map<String, dynamic> sku) {
    final originalPrice = sku['originalPrice'];
    return MallSku(
      id: _toInt(sku['id']),
      specs: {
        for (final entry in _asMapOrEmpty(sku['specs']).entries)
          entry.key: '${entry.value}',
      },
      price: _toDouble(sku['price']),
      originalPrice: originalPrice == null ? null : _toDouble(originalPrice),
      stock: _toInt(sku['stock']),
      status: '${sku['status'] ?? ''}'.toUpperCase(),
      imageUrl: _imageUrl('${sku['image'] ?? ''}'),
    );
  }

  Future<T> _withFallback<T>(Future<T> Function() request, T fallback) async {
    try {
      return await request();
    } on Object {
      return fallback;
    }
  }

  String _imageUrl(String path) {
    return resolveMallImage(_apiClient.baseUrl, path);
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}

Map<String, dynamic> _asMapOrEmpty(Object? value) => _asMap(value);

List<dynamic> _asList(Object? value) {
  if (value is List<dynamic>) {
    return value;
  }
  return const [];
}

int _toInt(Object? value) {
  return switch (value) {
    final int result => result,
    final num result => result.toInt(),
    final Object result => int.tryParse('$result') ?? 0,
    null => 0,
  };
}

int? _positiveIntOrNull(Object? value) {
  final result = _toInt(value);
  return result > 0 ? result : null;
}

double _toDouble(Object? value) {
  return switch (value) {
    final num result => result.toDouble(),
    final Object result => double.tryParse('$result') ?? 0,
    null => 0,
  };
}

bool _toBool(Object? value) {
  return value == true || value == 1 || value == '1' || value == 'true';
}
