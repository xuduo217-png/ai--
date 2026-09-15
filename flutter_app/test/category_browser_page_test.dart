import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/mall/cart/domain/cart_models.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/domain/catalog_models.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/presentation/pages/category_browser_page.dart';

void main() {
  for (final width in [320.0, 390.0, 402.0]) {
    testWidgets('一级二级分类页在 ${width.toInt()} 宽度下无溢出', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: _buildPage(_CategoryGateway())),
      );
      await tester.pumpAndSettle();

      final header = tester.widget<AppBar>(
        find.byKey(const ValueKey('category-header')),
      );
      expect(header.backgroundColor, const Color(0xFFDEE9FF));
      expect(header.surfaceTintColor, const Color(0xFFDEE9FF));
      expect(header.centerTitle, isTrue);
      expect(
        tester
            .widget<Material>(
              find.byKey(const ValueKey('category-search-area')),
            )
            .color,
        const Color(0xFFDEE9FF),
      );
      expect(find.byKey(const ValueKey('first-category-list')), findsOneWidget);
      expect(find.text('宠物食品'), findsNWidgets(2));
      expect(find.text('主粮'), findsOneWidget);
      expect(find.text('清洁护理'), findsNWidgets(2));
      for (final category in const [(10, '宠物食品'), (20, '清洁护理')]) {
        final item = find.byKey(ValueKey('first-category-${category.$1}'));
        final label = find.descendant(
          of: item,
          matching: find.text(category.$2),
        );
        expect(tester.getSize(item).height, 56);
        expect(
          tester.getCenter(label).dx,
          closeTo(tester.getCenter(item).dx, 0.5),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('二级分类切换商品且搜索、购物车、详情入口可用', (tester) async {
    final gateway = _CategoryGateway();
    var searchCalls = 0;
    var cartCalls = 0;
    int? selectedProductId;

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBrowserPage(
          gateway: gateway,
          cartGateway: gateway,
          authenticated: true,
          initialFirstCategoryId: 20,
          onLoginRequired: () {},
          onSearch: () async => searchCalls++,
          onCart: () async => cartCalls++,
          onProduct: (product) async {
            selectedProductId = product.id;
            gateway.cartCount = 4;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全价猫粮'), findsOneWidget);
    expect(find.text('鸡肉冻干'), findsNothing);
    expect(
      find.byKey(const ValueKey('selected-first-category-20')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('first-category-10')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('selected-first-category-10')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('second-category-10-12')));
    await tester.pumpAndSettle();
    expect(find.text('全价猫粮'), findsNothing);
    expect(find.text('鸡肉冻干'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('category-search-entry')));
    await tester.tap(find.byKey(const ValueKey('category-cart-button')));
    await tester.tap(find.byKey(const ValueKey('category-product-2')));
    await tester.pumpAndSettle();

    expect(searchCalls, 1);
    expect(cartCalls, 1);
    expect(selectedProductId, 2);
    expect(find.text('4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无 SKU 商品直接加购并刷新购物车角标', (tester) async {
    final gateway = _CategoryGateway();
    await tester.pumpWidget(MaterialApp(home: _buildPage(gateway)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('second-category-10-12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-category-product-2')));
    await tester.pumpAndSettle();

    expect(gateway.addedProductId, 2);
    expect(gateway.addedSkuId, isNull);
    expect(gateway.addedQuantity, 1);
    expect(find.text('已加入购物车'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('有 SKU 商品选择规格和数量后按契约加购', (tester) async {
    final gateway = _CategoryGateway();
    await tester.pumpWidget(MaterialApp(home: _buildPage(gateway)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-category-product-1')));
    await tester.pumpAndSettle();
    expect(find.text('选择规格'), findsOneWidget);
    expect(find.text('2kg / 鸡肉'), findsOneWidget);

    await tester.tap(find.byTooltip('增加'));
    await tester.tap(find.widgetWithText(FilledButton, '加入购物车'));
    await tester.pumpAndSettle();

    expect(gateway.addedProductId, 1);
    expect(gateway.addedSkuId, 101);
    expect(gateway.addedQuantity, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分类失败态可重试并恢复内容', (tester) async {
    final gateway = _CategoryGateway(failure: StateError('网络异常'));
    await tester.pumpWidget(MaterialApp(home: _buildPage(gateway)));
    await tester.pumpAndSettle();

    expect(find.textContaining('网络异常'), findsOneWidget);
    gateway.failure = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('宠物食品'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

CategoryBrowserPage _buildPage(_CategoryGateway gateway) {
  return CategoryBrowserPage(
    gateway: gateway,
    cartGateway: gateway,
    authenticated: true,
    onLoginRequired: () {},
    onSearch: () async {},
    onCart: () async {},
    onProduct: (_) async {},
  );
}

const _stapleProduct = CatalogProduct(
  id: 1,
  name: '全价猫粮',
  price: 89,
  stock: 8,
  source: ProductSource.admin,
  hasSku: true,
  skus: [
    ProductSku(
      id: 101,
      name: '鸡肉 2kg',
      specs: {'重量': '2kg', '口味': '鸡肉'},
      price: 89,
      stock: 8,
      status: 'ACTIVE',
    ),
  ],
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

class _CategoryGateway implements CatalogGateway, CartGateway {
  _CategoryGateway({this.failure});

  Object? failure;
  int cartCount = 0;
  int? addedProductId;
  int? addedSkuId;
  int? addedQuantity;

  void _throwIfNeeded() {
    if (failure case final error?) throw error;
  }

  @override
  Future<List<CatalogCategory>> loadCategoryTree({
    ProductSource source = ProductSource.admin,
  }) async {
    _throwIfNeeded();
    return _categories;
  }

  @override
  Future<CatalogProduct> loadProduct(
    int productId, {
    required bool authenticated,
  }) async {
    _throwIfNeeded();
    return switch (productId) {
      1 => _stapleProduct,
      2 => _snackProduct,
      _ => _cleaningProduct,
    };
  }

  @override
  Future<CartItem> addItem({
    required int productId,
    int? skuId,
    required int quantity,
  }) async {
    addedProductId = productId;
    addedSkuId = skuId;
    addedQuantity = quantity;
    cartCount++;
    final product = await loadProduct(productId, authenticated: true);
    final sku = product.skus.where((item) => item.id == skuId).firstOrNull;
    return CartItem(
      id: cartCount,
      productId: productId,
      skuId: skuId,
      quantity: quantity,
      product: product,
      sku: sku,
    );
  }

  @override
  Future<int> loadCount() async => cartCount;

  @override
  Future<List<CartItem>> loadCart() async => const [];

  @override
  Future<void> clear() async {}

  @override
  Future<void> removeItem(int cartItemId) async {}

  @override
  Future<CartItem> updateQuantity(int cartItemId, int quantity) async =>
      throw UnimplementedError();

  @override
  Future<List<CatalogBanner>> loadBanners() async => const [];

  @override
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query) async =>
      const CatalogPage();

  @override
  Future<CatalogPage<CatalogProduct>> loadPopularProducts(
    ProductQuery query,
  ) async => const CatalogPage();
}
