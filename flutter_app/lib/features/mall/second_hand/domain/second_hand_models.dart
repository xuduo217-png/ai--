import '../../catalog/domain/catalog_models.dart';

enum ProductCondition {
  brandNew('new', '全新'),
  ninety('90%', '九成新'),
  eighty('80%', '八成新'),
  seventy('70%', '七成新'),
  sixtyOrBelow('60%', '六成新及以下');

  const ProductCondition(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static ProductCondition fromJson(Object? value) {
    return ProductCondition.values.firstWhere(
      (condition) => condition.wireValue == '$value',
      orElse: () => ProductCondition.brandNew,
    );
  }
}

enum PendingProductStatus {
  underReview('under_review', '审核中'),
  approved('approved', '已上架'),
  onShelf('on_shelf', '在售'),
  offShelf('off_shelf', '已下架'),
  rejected('rejected', '审核未通过'),
  sold('sold', '已售出'),
  unknown('unknown', '未知');

  const PendingProductStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static PendingProductStatus fromJson(Object? value) {
    final normalized = '$value'.toLowerCase();
    return PendingProductStatus.values.firstWhere(
      (status) => status.wireValue == normalized,
      orElse: () => PendingProductStatus.unknown,
    );
  }
}

class SecondHandCategory {
  const SecondHandCategory({
    required this.id,
    required this.name,
    this.iconUrl = '',
    this.sortOrder = 0,
    this.children = const [],
  });

  final int id;
  final String name;
  final String iconUrl;
  final int sortOrder;
  final List<SecondHandCategory> children;
}

class PendingProduct {
  const PendingProduct({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.price,
    required this.stock,
    required this.images,
    required this.categoryId,
    required this.condition,
    required this.status,
    this.productId,
    this.categoryName = '',
    this.negotiable = false,
    this.shippingFee = 0,
    this.rejectReason,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final int? productId;
  final String title;
  final String description;
  final double price;
  final int stock;
  final bool negotiable;
  final List<String> images;
  final int categoryId;
  final String categoryName;
  final ProductCondition condition;
  final double shippingFee;
  final PendingProductStatus status;
  final String? rejectReason;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canEdit => status != PendingProductStatus.sold;
  bool get canChangeShelf =>
      productId != null &&
      const {
        PendingProductStatus.approved,
        PendingProductStatus.onShelf,
        PendingProductStatus.offShelf,
      }.contains(status);
}

class PendingProductPage {
  const PendingProductPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 10,
    this.totalPages = 0,
  });

  final List<PendingProduct> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  bool get hasMore => totalPages > 0 && page < totalPages;
}

class PublishProductInput {
  const PublishProductInput({
    required this.title,
    required this.description,
    required this.price,
    required this.stock,
    required this.images,
    required this.categoryId,
    required this.condition,
  });

  final String title;
  final String description;
  final double price;
  final int stock;
  final List<String> images;
  final int categoryId;
  final ProductCondition condition;

  String? validate() {
    if (images.isEmpty) return '请至少上传一张商品图片';
    if (images.length > 9) return '最多上传9张商品图片';
    if (title.trim().isEmpty) return '请输入商品标题';
    if (title.trim().length > 50) return '商品标题最多50个字符';
    if (description.trim().isEmpty) return '请输入商品描述';
    if (price <= 0) return '商品价格必须大于0';
    if (stock < 1) return '库存最小为1';
    if (categoryId <= 0) return '请选择二级分类';
    return null;
  }

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'price': price,
    'stock': stock,
    'images': images,
    'categoryId': categoryId,
    'condition': condition.wireValue,
    'negotiable': false,
    'shippingFee': 0,
  };
}

abstract interface class SecondHandGateway {
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query);
  Future<CatalogProduct> loadProduct(
    int productId, {
    required bool authenticated,
  });
  Future<List<SecondHandCategory>> loadCategories();
  Future<PendingProductPage> loadMyProducts({
    int page = 1,
    int pageSize = 10,
    List<PendingProductStatus> statuses = const [],
  });
  Future<PendingProduct> loadPendingProduct(int pendingId);
  Future<int> publishProduct(PublishProductInput input);
  Future<void> updateProduct(int pendingId, PublishProductInput input);
  Future<void> updateProductStatus(int productId, bool active);
  Future<String> uploadImage(String filePath);
  Future<void> reportProduct(
    int productId, {
    required String reason,
    String? description,
  });
  Future<void> blockUser(int userId, {String? reason});
}

/// 二手商城首页的公开分类数据源。
///
/// 发布页仍通过 [SecondHandGateway.loadCategories] 获取完整可发布分类；商城页只需要
/// 已包含在售二手商品的分类，避免依赖受保护的发布分类接口。
abstract interface class SecondHandMallCategoryGateway {
  Future<List<SecondHandCategory>> loadMallCategories();
}
