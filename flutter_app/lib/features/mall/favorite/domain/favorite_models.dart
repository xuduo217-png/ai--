import '../../catalog/domain/catalog_models.dart';

class FavoriteEntry {
  const FavoriteEntry({
    required this.id,
    required this.productId,
    required this.product,
    this.createdAt,
  });

  final int id;
  final int productId;
  final CatalogProduct product;
  final DateTime? createdAt;
}

class FavoritePage {
  const FavoritePage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.totalPages = 0,
  });

  final List<FavoriteEntry> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  bool get hasMore => totalPages > 0 && page < totalPages;
}

abstract interface class FavoriteGateway {
  Future<FavoritePage> loadFavorites({int page = 1, int pageSize = 20});
  Future<bool> toggleFavorite(int productId);
  Future<bool> isFavorite(int productId);
  Future<void> removeFavorite(int favoriteId);
  Future<int> loadFavoriteCount();
}
