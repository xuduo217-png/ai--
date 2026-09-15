import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/domain/catalog_models.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/presentation/category_browser_controller.dart';

void main() {
  test('分类浏览按初始一级分类定位，并为每组独立保存二级分类', () async {
    final gateway = _CatalogGateway(categories: _categories);
    final controller = CategoryBrowserController(
      gateway: gateway,
      initialFirstCategoryId: 20,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.selectedFirstCategoryId, 20);
    expect(controller.selectedSecondCategoryIds, {10: 11, 20: 21});
    expect(controller.productsFor(_categories.first), [_stapleProduct]);

    controller.selectSecondCategory(10, 12);
    expect(controller.selectedSecondCategoryIds, {10: 12, 20: 21});
    expect(controller.productsFor(_categories.first), [_snackProduct]);
    expect(controller.productsFor(_categories.last), [_cleaningProduct]);
  });

  test('分类刷新保留仍然有效的选择，失效选择回退到第一项', () async {
    final gateway = _CatalogGateway(categories: _categories);
    final controller = CategoryBrowserController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.load();
    controller.selectFirstCategory(20);
    controller.selectSecondCategory(10, 12);

    gateway.categories = [
      _categories.first,
      const CatalogCategory(
        id: 30,
        name: '出行用品',
        children: [CatalogCategory(id: 31, name: '航空箱')],
      ),
    ];
    await controller.refresh();

    expect(controller.selectedFirstCategoryId, 10);
    expect(controller.selectedSecondCategoryIds, {10: 12, 30: 31});
  });

  test('分类加载失败可观察，空数据保持稳定空态', () async {
    final gateway = _CatalogGateway(failure: StateError('网络异常'));
    final controller = CategoryBrowserController(gateway: gateway);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.loading, isFalse);
    expect(controller.errorMessage, contains('网络异常'));
    expect(controller.categories, isEmpty);

    gateway.failure = null;
    await controller.load();
    expect(controller.errorMessage, isNull);
    expect(controller.selectedFirstCategoryId, isNull);
  });
}

const _stapleProduct = CatalogProduct(
  id: 1,
  name: '全价猫粮',
  price: 89,
  stock: 8,
  source: ProductSource.admin,
);

const _snackProduct = CatalogProduct(
  id: 2,
  name: '鸡肉冻干',
  price: 29,
  stock: 6,
  source: ProductSource.admin,
);

const _cleaningProduct = CatalogProduct(
  id: 3,
  name: '宠物湿巾',
  price: 19,
  stock: 12,
  source: ProductSource.admin,
);

const _categories = [
  CatalogCategory(
    id: 10,
    name: '宠物食品',
    children: [
      CatalogCategory(id: 11, name: '主粮', products: [_stapleProduct]),
      CatalogCategory(id: 12, name: '零食', products: [_snackProduct]),
    ],
  ),
  CatalogCategory(
    id: 20,
    name: '清洁护理',
    children: [
      CatalogCategory(id: 21, name: '日常清洁', products: [_cleaningProduct]),
    ],
  ),
];

class _CatalogGateway implements CatalogGateway {
  _CatalogGateway({this.categories = const [], this.failure});

  List<CatalogCategory> categories;
  Object? failure;

  @override
  Future<List<CatalogCategory>> loadCategoryTree({
    ProductSource source = ProductSource.admin,
  }) async {
    if (failure case final error?) throw error;
    return categories;
  }

  @override
  Future<List<CatalogBanner>> loadBanners() async => const [];

  @override
  Future<CatalogProduct> loadProduct(
    int productId, {
    required bool authenticated,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query) async =>
      const CatalogPage();

  @override
  Future<CatalogPage<CatalogProduct>> loadPopularProducts(
    ProductQuery query,
  ) async => const CatalogPage();
}
