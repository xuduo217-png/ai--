class MallSnapshot {
  const MallSnapshot({
    this.banners = const [],
    this.categories = const [],
    this.products = const [],
    this.hasCartItems = false,
    this.homePopupImageUrl = '',
  });

  final List<MallBanner> banners;
  final List<MallCategory> categories;
  final List<MallProduct> products;
  final bool hasCartItems;
  final String homePopupImageUrl;

  MallSnapshot copyWith({bool? hasCartItems, String? homePopupImageUrl}) {
    return MallSnapshot(
      banners: banners,
      categories: categories,
      products: products,
      hasCartItems: hasCartItems ?? this.hasCartItems,
      homePopupImageUrl: homePopupImageUrl ?? this.homePopupImageUrl,
    );
  }
}

class MallBanner {
  const MallBanner({
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

  MallBannerTarget? get target {
    if (actionType == 'product') {
      return productId != null && productId! > 0
          ? MallBannerTarget.product(productId!)
          : null;
    }
    if (actionType == 'none') {
      return null;
    }
    if (productId != null && productId! > 0) {
      return MallBannerTarget.product(productId!);
    }

    final value = link?.trim() ?? '';
    if (value.isEmpty) {
      return const MallBannerTarget.popular();
    }
    final productMatch = RegExp(
      r'(?:product:|/product/)(\d+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (productMatch != null) {
      return MallBannerTarget.product(int.parse(productMatch.group(1)!));
    }
    final categoryMatch = RegExp(
      r'(?:category:|/category/)(\d+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (categoryMatch != null) {
      return MallBannerTarget.category(int.parse(categoryMatch.group(1)!));
    }
    final numericId = int.tryParse(value);
    if (numericId != null && numericId > 0) {
      return MallBannerTarget.product(numericId);
    }
    return const MallBannerTarget.popular();
  }
}

enum MallBannerTargetType { product, category, popular }

class MallBannerTarget {
  const MallBannerTarget.product(int productId)
    : type = MallBannerTargetType.product,
      id = productId;

  const MallBannerTarget.category(int categoryId)
    : type = MallBannerTargetType.category,
      id = categoryId;

  const MallBannerTarget.popular()
    : type = MallBannerTargetType.popular,
      id = null;

  final MallBannerTargetType type;
  final int? id;
}

class MallCategory {
  const MallCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String imageUrl;
  final int sortOrder;
}

class MallProduct {
  const MallProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.stock,
    required this.hasSku,
    required this.isTop,
    required this.publishSource,
    this.skus = const [],
  });

  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final int stock;
  final bool hasSku;
  final bool isTop;
  final String publishSource;
  final List<MallSku> skus;

  bool get canAddToCart => publishSource != 'USER';
}

class MallSku {
  const MallSku({
    required this.id,
    required this.specs,
    required this.price,
    required this.stock,
    required this.status,
    this.originalPrice,
    this.imageUrl = '',
  });

  final int id;
  final Map<String, String> specs;
  final double price;
  final double? originalPrice;
  final int stock;
  final String status;
  final String imageUrl;

  bool get available => stock > 0 && status == 'ACTIVE';
}

abstract interface class MallGateway {
  Future<MallSnapshot> loadMall({required bool authenticated});

  Future<MallProduct> loadProduct(int productId);

  Future<void> addToCart({
    required int productId,
    required int? skuId,
    required int quantity,
  });

  Future<bool> loadCartBadge();
}
