enum ProductSource {
  admin('ADMIN'),
  user('USER');

  const ProductSource(this.wireValue);
  final String wireValue;

  static ProductSource fromJson(Object? value) {
    return '$value'.toUpperCase() == 'USER'
        ? ProductSource.user
        : ProductSource.admin;
  }
}

class CatalogPage<T> {
  const CatalogPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.totalPages = 0,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore =>
      totalPages > 0 ? page < totalPages : items.length >= pageSize;
}

class ProductPublisher {
  const ProductPublisher({
    required this.id,
    this.nickname = '',
    this.username = '',
    this.phone = '',
  });

  final int id;
  final String nickname;
  final String username;
  final String phone;

  String get displayName {
    if (nickname.trim().isNotEmpty) return nickname.trim();
    if (username.trim().isNotEmpty) return username.trim();
    if (phone.length >= 7) {
      return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
    }
    return id > 0 ? '用户$id' : '用户';
  }
}

class ProductSku {
  const ProductSku({
    required this.id,
    required this.name,
    required this.specs,
    required this.price,
    required this.stock,
    required this.status,
    this.originalPrice,
    this.imageUrl = '',
    this.skuCode = '',
  });

  final int id;
  final String name;
  final Map<String, String> specs;
  final double price;
  final double? originalPrice;
  final int stock;
  final String status;
  final String imageUrl;
  final String skuCode;

  bool get available => stock > 0 && status.toUpperCase() == 'ACTIVE';

  String get specification => specs.values.join(' / ');
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.source,
    this.description = '',
    this.originalPrice,
    this.imageUrl = '',
    this.images = const [],
    this.isActive = true,
    this.categoryId,
    this.hasSku = false,
    this.skus = const [],
    this.sells = 0,
    this.isHot = false,
    this.isTop = false,
    this.isFavorited = false,
    this.publishedBy,
    this.publisher,
    this.condition,
    this.negotiable = false,
    this.shippingFee = 0,
  });

  final int id;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final int stock;
  final String imageUrl;
  final List<String> images;
  final bool isActive;
  final int? categoryId;
  final bool hasSku;
  final List<ProductSku> skus;
  final int sells;
  final bool isHot;
  final bool isTop;
  final bool isFavorited;
  final ProductSource source;
  final int? publishedBy;
  final ProductPublisher? publisher;
  final String? condition;
  final bool negotiable;
  final double shippingFee;

  bool get isSecondHand => source == ProductSource.user;
  bool get canAddToCart => !isSecondHand;
  bool get available => isActive && effectiveStock > 0;
  int get effectiveStock => hasSku
      ? skus
            .where((sku) => sku.available)
            .fold(0, (sum, sku) => sum + sku.stock)
      : stock;

  String get sellerLabel => isSecondHand
      ? '${publisher?.displayName ?? (publishedBy == null ? '用户' : '用户$publishedBy')} 发布的商品'
      : '';

  CatalogProduct copyWith({bool? isFavorited}) {
    return CatalogProduct(
      id: id,
      name: name,
      description: description,
      price: price,
      originalPrice: originalPrice,
      stock: stock,
      imageUrl: imageUrl,
      images: images,
      isActive: isActive,
      categoryId: categoryId,
      hasSku: hasSku,
      skus: skus,
      sells: sells,
      isHot: isHot,
      isTop: isTop,
      isFavorited: isFavorited ?? this.isFavorited,
      source: source,
      publishedBy: publishedBy,
      publisher: publisher,
      condition: condition,
      negotiable: negotiable,
      shippingFee: shippingFee,
    );
  }
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    this.iconUrl = '',
    this.imageUrl = '',
    this.description = '',
    this.status = 'ACTIVE',
    this.sortOrder = 0,
    this.parentId,
    this.children = const [],
    this.products = const [],
  });

  final int id;
  final String name;
  final String iconUrl;
  final String imageUrl;
  final String description;
  final String status;
  final int sortOrder;
  final int? parentId;
  final List<CatalogCategory> children;
  final List<CatalogProduct> products;

  bool containsSource(ProductSource source) {
    return products.any((product) => product.source == source) ||
        children.any((child) => child.containsSource(source));
  }
}

class CatalogBanner {
  const CatalogBanner({
    required this.id,
    required this.imageUrl,
    this.actionType,
    this.productId,
    this.link,
  });

  final String id;
  final String imageUrl;
  final String? actionType;
  final int? productId;
  final String? link;
}

class ProductQuery {
  const ProductQuery({
    this.page = 1,
    this.pageSize = 20,
    this.categoryId,
    this.keyword,
    this.sortBy = 'createdAt',
    this.sortOrder = 'DESC',
    this.source = ProductSource.admin,
  });

  final int page;
  final int pageSize;
  final int? categoryId;
  final String? keyword;
  final String sortBy;
  final String sortOrder;
  final ProductSource source;

  Map<String, Object?> toQueryParameters() => {
    'page': page,
    'pageSize': pageSize,
    'categoryId': categoryId,
    'keyword': keyword?.trim().isEmpty == true ? null : keyword?.trim(),
    'sortBy': sortBy,
    'sortOrder': sortOrder,
    'publishSource': source.wireValue,
    'isActive': true,
  };

  ProductQuery copyWith({int? page, String? keyword, int? categoryId}) {
    return ProductQuery(
      page: page ?? this.page,
      pageSize: pageSize,
      categoryId: categoryId ?? this.categoryId,
      keyword: keyword ?? this.keyword,
      sortBy: sortBy,
      sortOrder: sortOrder,
      source: source,
    );
  }
}

abstract interface class CatalogGateway {
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query);
  Future<CatalogPage<CatalogProduct>> loadPopularProducts(ProductQuery query);
  Future<List<CatalogCategory>> loadCategoryTree({
    ProductSource source = ProductSource.admin,
  });
  Future<CatalogProduct> loadProduct(
    int productId, {
    required bool authenticated,
  });
  Future<List<CatalogBanner>> loadBanners();
}
