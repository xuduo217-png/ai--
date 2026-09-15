import '../../../../core/network/api_client.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../shared/mall_json.dart';
import '../domain/cart_models.dart';

class CartRepository implements CartGateway {
  CartRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<CartItem>> loadCart() async {
    final payload = await _apiClient.get('/shop/cart');
    return asJsonList(
      unwrapData(payload),
    ).map((item) => _parseCartItem(asJsonMap(item))).toList(growable: false);
  }

  @override
  Future<CartItem> addItem({
    required int productId,
    int? skuId,
    required int quantity,
  }) async {
    final payload = await _apiClient.post(
      '/shop/cart',
      authenticated: true,
      body: compactJson({
        'productId': productId,
        'skuId': skuId,
        'quantity': quantity,
      }),
    );
    final cart = _parseCartItem(asJsonMap(unwrapData(payload)));
    if (cart.id > 0 && cart.product.id > 0) return cart;
    return CartItem(
      id: cart.id,
      productId: productId,
      skuId: skuId,
      quantity: quantity,
      product: CatalogProduct(
        id: productId,
        name: '',
        price: 0,
        stock: 0,
        source: ProductSource.admin,
      ),
    );
  }

  @override
  Future<CartItem> updateQuantity(int cartItemId, int quantity) async {
    final payload = await _apiClient.put(
      '/shop/cart/$cartItemId',
      body: {'quantity': quantity},
    );
    return _parseCartItem(asJsonMap(unwrapData(payload)));
  }

  @override
  Future<void> removeItem(int cartItemId) async {
    await _apiClient.delete('/shop/cart/$cartItemId');
  }

  @override
  Future<void> clear() async {
    await _apiClient.delete('/shop/cart');
  }

  @override
  Future<int> loadCount() async {
    final payload = asJsonMap(
      unwrapData(await _apiClient.get('/shop/cart/count')),
    );
    return jsonInt(payload['count']);
  }

  CartItem _parseCartItem(Map<String, dynamic> json) {
    final productJson = asJsonMap(json['product']);
    final skuJson = asJsonMap(json['sku']);
    return CartItem(
      id: jsonInt(json['id']),
      productId: jsonInt(json['productId'] ?? productJson['id']),
      skuId: jsonInt(json['skuId']) > 0 ? jsonInt(json['skuId']) : null,
      quantity: jsonInt(json['quantity'], 1),
      product: _parseProduct(productJson),
      sku: skuJson.isEmpty ? null : _parseSku(skuJson),
    );
  }

  CatalogProduct _parseProduct(Map<String, dynamic> json) {
    final images = asJsonList(json['images'])
        .map((item) => resolveMallImage(_apiClient.baseUrl, item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final imageUrl = images.isNotEmpty
        ? images.first
        : resolveMallImage(_apiClient.baseUrl, json['image']);
    return CatalogProduct(
      id: jsonInt(json['id']),
      name: jsonString(json['name']),
      description: jsonString(json['description']),
      price: jsonDouble(json['price']),
      stock: jsonInt(json['stock']),
      imageUrl: imageUrl,
      images: images,
      isActive: jsonBool(json['isActive'], true),
      hasSku: jsonBool(json['hasSku']),
      source: ProductSource.fromJson(json['publishSource']),
    );
  }

  ProductSku _parseSku(Map<String, dynamic> json) {
    return ProductSku(
      id: jsonInt(json['id']),
      name: jsonString(json['name']),
      specs: asJsonMap(
        json['specs'],
      ).map((key, value) => MapEntry(key, jsonString(value))),
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
