import '../../../../core/network/api_client.dart';
import '../../catalog/data/catalog_mapper.dart';
import '../../shared/mall_json.dart';
import '../domain/favorite_models.dart';

class FavoriteRepository implements FavoriteGateway {
  FavoriteRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<FavoritePage> loadFavorites({int page = 1, int pageSize = 20}) async {
    final payload = await _apiClient.get(
      '/shop/favorites',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final responseRoot = asJsonMap(payload);
    final pageRoot = _favoritePageRoot(payload);
    final items = asJsonList(_favoriteItemsPayload(payload, pageRoot))
        .map((item) {
          final json = asJsonMap(item);
          final productJson = asJsonMap(json['product']);
          return FavoriteEntry(
            id: jsonInt(json['id']),
            productId: jsonInt(json['productId'] ?? productJson['id']),
            product: catalogProductFromJson(
              productJson,
              baseUrl: _apiClient.baseUrl,
            ),
            createdAt: jsonDateTime(json['createdAt']),
          );
        })
        .toList(growable: false);
    final pagination = _favoritePagination(responseRoot, pageRoot);
    final total = jsonInt(pagination['total'], items.length);
    final actualPageSize = jsonInt(
      pagination['pageSize'] ?? pagination['limit'],
      pageSize,
    );
    return FavoritePage(
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
  Future<bool> toggleFavorite(int productId) async {
    final payload = asJsonMap(
      unwrapData(
        await _apiClient.post(
          '/shop/favorites',
          authenticated: true,
          body: {'productId': productId},
        ),
      ),
    );
    return jsonBool(payload['isFavorited']);
  }

  @override
  Future<bool> isFavorite(int productId) async {
    final payload = asJsonMap(
      unwrapData(
        await _apiClient.get(
          '/shop/favorites/check',
          queryParameters: {'productId': productId},
        ),
      ),
    );
    return jsonBool(payload['isFavorited']);
  }

  @override
  Future<void> removeFavorite(int favoriteId) async {
    await _apiClient.delete('/shop/favorites/$favoriteId');
  }

  @override
  Future<int> loadFavoriteCount() async {
    final payload = asJsonMap(
      unwrapData(await _apiClient.get('/shop/favorites/count')),
    );
    return jsonInt(payload['count']);
  }
}

Map<String, dynamic> _favoritePageRoot(Object? payload) {
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

Object? _favoriteItemsPayload(Object? payload, Map<String, dynamic> pageRoot) {
  if (payload is List) return payload;
  for (final key in const ['data', 'items', 'list']) {
    if (pageRoot[key] is List) return pageRoot[key];
  }
  return const [];
}

Map<String, dynamic> _favoritePagination(
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
