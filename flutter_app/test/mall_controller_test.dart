import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/mall/address/domain/address_models.dart';
import 'package:pet_hospital_flutter/features/mall/address/presentation/address_controller.dart';
import 'package:pet_hospital_flutter/features/mall/cart/domain/cart_models.dart';
import 'package:pet_hospital_flutter/features/mall/cart/presentation/cart_controller.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/domain/catalog_models.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/presentation/catalog_controller.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/domain/checkout_models.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/presentation/checkout_controller.dart';
import 'package:pet_hospital_flutter/features/mall/favorite/domain/favorite_models.dart';
import 'package:pet_hospital_flutter/features/mall/favorite/presentation/favorite_controller.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/order/presentation/order_controller.dart';
import 'package:pet_hospital_flutter/features/mall/second_hand/domain/second_hand_models.dart';
import 'package:pet_hospital_flutter/features/mall/second_hand/presentation/second_hand_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatalogController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('默认加载热门，输入关键词后改用普通搜索并继续分页', () async {
      final gateway = _CatalogGateway();
      final controller = CatalogController(gateway: gateway, popular: true);

      await controller.load();
      expect(gateway.popularQueries, hasLength(1));
      expect(gateway.productQueries, isEmpty);
      expect(controller.products.single.id, 1);

      await controller.search('  猫粮  ');
      expect(gateway.productQueries.single.keyword, '猫粮');
      expect(controller.searchHistory, ['猫粮']);
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(gateway.productQueries.last.page, 2);
      expect(controller.products.map((item) => item.id), [2, 3]);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList('mall_search_history'), ['猫粮']);
    });

    test('搜索历史去重、限制十条并支持清空', () async {
      final gateway = _CatalogGateway();
      final controller = CatalogController(gateway: gateway, popular: true);

      for (var index = 0; index < 12; index += 1) {
        await controller.search('关键词$index');
      }
      await controller.search('关键词5');

      expect(controller.searchHistory, hasLength(10));
      expect(controller.searchHistory.first, '关键词5');
      expect(
        controller.searchHistory.where((item) => item == '关键词5'),
        hasLength(1),
      );

      await controller.clearHistory();
      expect(controller.searchHistory, isEmpty);
    });
  });

  group('SecondHandMallController', () {
    test('分类失败时保留已成功加载的二手商品', () async {
      final gateway = _SecondHandMallGateway(
        categoryError: StateError('分类服务暂不可用'),
      );
      final controller = SecondHandMallController(gateway);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.products.map((product) => product.id), [1]);
      expect(controller.errorMessage, isNull);
      expect(controller.categoryErrorMessage, '分类服务暂不可用');
    });

    test('分页按商品 ID 去重', () async {
      final gateway = _SecondHandMallGateway();
      final controller = SecondHandMallController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.loadMore();

      expect(controller.products.map((product) => product.id), [1, 2]);
      expect(controller.page, 2);
      expect(controller.hasMore, isFalse);
      expect(gateway.queries.first.categoryId, 1);
      expect(gateway.queries.last.page, 2);
    });

    test('二手商城搜索保留当前分类并传递关键词', () async {
      final gateway = _SecondHandMallGateway();
      final controller = SecondHandMallController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.search('  航空箱  ');

      expect(controller.keyword, '航空箱');
      expect(gateway.queries.last.categoryId, 1);
      expect(gateway.queries.last.keyword, '航空箱');
    });
  });

  test('商品详情自动匹配首个可售 SKU，并限制购买数量', () async {
    const disabledSku = ProductSku(
      id: 10,
      name: '缺货款',
      specs: {'重量': '1kg'},
      price: 30,
      stock: 0,
      status: 'ACTIVE',
    );
    const availableSku = ProductSku(
      id: 11,
      name: '现货款',
      specs: {'重量': '2kg'},
      price: 50,
      stock: 2,
      status: 'ACTIVE',
    );
    final gateway = _CatalogGateway(
      detail: _product(
        id: 8,
        stock: 100,
        hasSku: true,
        skus: const [disabledSku, availableSku],
      ),
    );
    final controller = ProductDetailController(
      catalogGateway: gateway,
      productId: 8,
      authenticated: true,
    );

    await controller.load();
    expect(controller.selectedSku?.id, 11);
    expect(controller.price, 50);

    controller.changeQuantity(99);
    expect(controller.quantity, 2);
    expect(controller.canSubmit, isTrue);

    controller.selectSku(disabledSku);
    expect(controller.selectedSku?.id, 11);
  });

  group('CartController', () {
    test('选择、全选、合计和数量更新遵守库存限制', () async {
      final gateway = _CartGateway([
        _cartItem(id: 1, price: 12, quantity: 2, stock: 3),
        _cartItem(id: 2, price: 30, quantity: 1, stock: 0),
      ]);
      final controller = CartController(gateway);

      await controller.load();
      expect(controller.selectedItems.map((item) => item.id), [1]);
      expect(controller.total, 24);
      expect(controller.allSelected, isTrue);

      controller.toggleAll();
      expect(controller.selectedItems, isEmpty);
      controller.toggleAll();
      expect(controller.selectedItems.map((item) => item.id), [1]);

      await controller.updateQuantity(controller.items.first, 99);
      expect(gateway.updatedQuantities, [3]);
      expect(controller.items.first.quantity, 3);
      expect(controller.items.first.selected, isTrue);
    });

    test('批量删除会尝试全部 ID、重新同步，并透传首个错误', () async {
      final gateway = _CartGateway([_cartItem(id: 1), _cartItem(id: 2)])
        ..removeFailureId = 1;
      final controller = CartController(gateway);
      await controller.load();

      await expectLater(controller.removeByIds([1, 2]), throwsStateError);

      expect(gateway.removedIds, [1, 2]);
      expect(gateway.loadCalls, 2);
    });
  });

  group('CheckoutController', () {
    test('优惠券失效时回退无券试算并清除选中项', () async {
      final addressGateway = _AddressGateway();
      final checkoutGateway = _CheckoutGateway()..failCouponId = 7;
      final controller = CheckoutController(
        checkoutGateway: checkoutGateway,
        addressController: AddressController(addressGateway),
        items: [_checkoutItem(productId: 1)],
      );
      await controller.load();

      const coupon = CheckoutCoupon(
        id: 7,
        name: '已失效优惠券',
        type: 'FULL_REDUCTION',
        discount: 10,
        minAmount: 20,
        isApplicable: true,
        discountAmount: 10,
      );
      await expectLater(controller.selectCoupon(coupon), throwsStateError);

      expect(checkoutGateway.previewCouponIds, [null, 7, null]);
      expect(controller.selectedCoupon, isNull);
      expect(controller.preview?.totalAmount, 20);
    });

    test('仅在订单创建成功后清理明确的购物车项', () async {
      final cartGateway = _CartGateway([_cartItem(id: 4), _cartItem(id: 5)]);
      final cartController = CartController(cartGateway);
      final checkoutGateway = _CheckoutGateway();
      final controller = CheckoutController(
        checkoutGateway: checkoutGateway,
        addressController: AddressController(_AddressGateway()),
        cartController: cartController,
        items: [
          _checkoutItem(productId: 1, cartItemId: 4),
          _checkoutItem(productId: 2, cartItemId: 5),
          _checkoutItem(productId: 3),
        ],
      );
      await controller.load();

      final result = await controller.submit('  请轻放  ');

      expect(result.isSuccess, isTrue);
      expect(checkoutGateway.lastInput?.remark, '  请轻放  ');
      expect(checkoutGateway.lastInput?.toJson()['remark'], '请轻放');
      expect(cartGateway.removedIds, [4, 5]);
    });

    test('库存失败保留购物车项', () async {
      final cartGateway = _CartGateway([_cartItem(id: 9)]);
      final checkoutGateway = _CheckoutGateway()..stockFailure = true;
      final controller = CheckoutController(
        checkoutGateway: checkoutGateway,
        addressController: AddressController(_AddressGateway()),
        cartController: CartController(cartGateway),
        items: [_checkoutItem(productId: 1, cartItemId: 9)],
      );
      await controller.load();

      final result = await controller.submit('');

      expect(result.isSuccess, isFalse);
      expect(cartGateway.removedIds, isEmpty);
    });
  });

  group('个人中心商城列表控制器', () {
    test('地址页销毁后忽略迟到请求', () async {
      final gateway = _DeferredAddressGateway();
      final controller = AddressController(gateway);

      final request = controller.load();
      controller.dispose();
      gateway.result.complete(const [_address]);

      await expectLater(request, completes);
    });

    test('订单列表和详情页销毁后忽略迟到请求', () async {
      final listGateway = _DeferredOrderGateway();
      final listController = OrderListController(listGateway);
      final listRequest = listController.load();
      listController.dispose();
      listGateway.complete(
        null,
        OrderPage(items: [_order()], total: 1, totalPages: 1),
      );
      await expectLater(listRequest, completes);

      final detailGateway = _DeferredOrderDetailGateway();
      final detailController = OrderDetailController(detailGateway, 100);
      final detailRequest = detailController.load();
      detailController.dispose();
      detailGateway.result.complete(_order());
      await expectLater(detailRequest, completes);
    });

    test('收藏页销毁后忽略迟到请求', () async {
      final gateway = _DeferredFavoriteGateway();
      final controller = FavoriteController(gateway);

      final request = controller.load();
      controller.dispose();
      gateway.result.complete(
        FavoritePage(items: const [], total: 0, page: 1, totalPages: 0),
      );

      await expectLater(request, completes);
    });

    test('我发布和发布编辑页销毁后忽略迟到请求', () async {
      final publishedGateway = _DeferredSecondHandGateway();
      final publishedController = PublishedProductController(publishedGateway);
      final publishedRequest = publishedController.load();
      publishedController.dispose();
      publishedGateway.complete(
        const [],
        PendingProductPage(items: const [], total: 0, totalPages: 0),
      );
      await expectLater(publishedRequest, completes);

      final publishGateway = _DeferredPublishGateway();
      final publishController = PublishProductController(publishGateway);
      final publishRequest = publishController.load();
      publishController.dispose();
      publishGateway.categories.complete(const []);
      await expectLater(publishRequest, completes);
    });

    test('地址管理串联新增、编辑、删除和设默认，并在每次成功后刷新', () async {
      final gateway = _RecordingAddressGateway();
      final controller = AddressController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.save(input: _addressInput());
      await controller.save(existing: _address, input: _addressInput());
      await controller.setDefault(_address.id);
      await controller.remove(_address.id);

      expect(gateway.created, 1);
      expect(gateway.updatedIds, [_address.id]);
      expect(gateway.defaultIds, [_address.id]);
      expect(gateway.removedIds, [_address.id]);
      expect(gateway.loadCalls, 5);
    });

    test('订单快速切换筛选时忽略旧请求，并在分页时按订单 ID 去重', () async {
      final gateway = _DeferredOrderGateway();
      final controller = OrderListController(gateway);
      addTearDown(controller.dispose);

      final allRequest = controller.load();
      final paidRequest = controller.load(
        filter: ShopOrderStatus.paid,
        replaceFilter: true,
      );
      gateway.complete(
        ShopOrderStatus.paid,
        OrderPage(
          items: [_order(id: 2, status: ShopOrderStatus.paid)],
          total: 2,
          page: 1,
          totalPages: 2,
        ),
      );
      await paidRequest;
      gateway.complete(
        null,
        OrderPage(items: [_order(id: 1)], total: 1, totalPages: 1),
      );
      await allRequest;

      expect(controller.status, ShopOrderStatus.paid);
      expect(controller.orders.map((order) => order.id), [2]);

      gateway.completeNextPage(
        OrderPage(
          items: [
            _order(id: 2, status: ShopOrderStatus.paid),
            _order(id: 3, status: ShopOrderStatus.paid),
          ],
          total: 2,
          page: 2,
          totalPages: 2,
        ),
      );
      await controller.loadMore();

      expect(controller.orders.map((order) => order.id), [2, 3]);
    });

    test('订单取消和确认成功后均重新同步当前列表', () async {
      final gateway = _OrderActionGateway();
      final controller = OrderListController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.cancel(_order());
      await controller.confirm(_order(id: 2, status: ShopOrderStatus.shipped));

      expect(gateway.cancelledIds, [100]);
      expect(gateway.confirmedIds, [2]);
      expect(gateway.loadCalls, 3);
    });

    test('收藏分页按收藏 ID 去重，取消失败保留原列表', () async {
      final gateway = _FavoriteControllerGateway();
      final controller = FavoriteController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.loadMore();
      expect(controller.items.map((item) => item.id), [1, 2]);

      gateway.removeFailureId = 1;
      await expectLater(
        controller.remove(controller.items.first),
        throwsStateError,
      );
      expect(controller.items.map((item) => item.id), [1, 2]);

      gateway.removeFailureId = null;
      await controller.remove(controller.items.first);
      expect(controller.items.map((item) => item.id), [2]);
    });

    test('我发布商品快速切换筛选时忽略旧请求并与 RN 使用相同在售状态', () async {
      final gateway = _DeferredSecondHandGateway();
      final controller = PublishedProductController(gateway);
      addTearDown(controller.dispose);

      final allRequest = controller.load();
      final auditRequest = controller.load(
        nextFilter: PublishedProductFilter.audit,
      );
      gateway.complete(
        PublishedProductFilter.audit.statuses,
        PendingProductPage(
          items: [
            _pendingProduct(id: 2, status: PendingProductStatus.rejected),
          ],
          total: 2,
          totalPages: 2,
        ),
      );
      await auditRequest;
      gateway.complete(
        const [],
        PendingProductPage(
          items: [_pendingProduct(id: 1)],
          total: 1,
          totalPages: 1,
        ),
      );
      await allRequest;

      expect(controller.filter, PublishedProductFilter.audit);
      expect(controller.products.map((product) => product.id), [2]);
      expect(PublishedProductFilter.onSale.statuses, [
        PendingProductStatus.onShelf,
        PendingProductStatus.offShelf,
      ]);

      final nextPageRequest = controller.loadMore();
      gateway.complete(
        PublishedProductFilter.audit.statuses,
        PendingProductPage(
          items: [
            _pendingProduct(id: 2, status: PendingProductStatus.rejected),
            _pendingProduct(id: 3, status: PendingProductStatus.underReview),
          ],
          total: 2,
          page: 2,
          totalPages: 2,
        ),
        page: 2,
      );
      await nextPageRequest;
      expect(controller.products.map((product) => product.id), [2, 3]);
    });
  });

  test('地址、二手发布和订单状态边界保持强校验', () {
    expect(_addressInput(phone: '123').validate(), '请输入正确的手机号码');
    expect(_addressInput(districtCode: '').validate(), '请选择所在地区');
    expect(_addressInput().validate(), isNull);

    final tooManyImages = PublishProductInput(
      title: '闲置航空箱',
      description: '仅使用一次',
      price: 80,
      stock: 1,
      images: List.generate(10, (index) => '/$index.jpg'),
      categoryId: 12,
      condition: ProductCondition.ninety,
    );
    expect(tooManyImages.validate(), '最多上传9张商品图片');
    expect(PublishedProductFilter.audit.statuses, [
      PendingProductStatus.underReview,
      PendingProductStatus.rejected,
    ]);

    expect(ShopOrderStatus.fromJson('PENDING').canPayStatus, isTrue);
    expect(ShopOrderStatus.fromJson('unexpected'), ShopOrderStatus.unknown);
    expect(_product(source: ProductSource.user).canAddToCart, isFalse);
  });
}

extension on ShopOrderStatus {
  bool get canPayStatus => this == ShopOrderStatus.pending;
}

CatalogProduct _product({
  int id = 1,
  double price = 20,
  int stock = 5,
  ProductSource source = ProductSource.admin,
  bool hasSku = false,
  List<ProductSku> skus = const [],
}) {
  return CatalogProduct(
    id: id,
    name: '商品$id',
    price: price,
    stock: stock,
    source: source,
    hasSku: hasSku,
    skus: skus,
  );
}

CartItem _cartItem({
  required int id,
  double price = 20,
  int quantity = 1,
  int stock = 5,
}) {
  return CartItem(
    id: id,
    productId: id,
    quantity: quantity,
    product: _product(id: id, price: price, stock: stock),
  );
}

CheckoutItem _checkoutItem({required int productId, int? cartItemId}) {
  return CheckoutItem(
    productId: productId,
    productName: '商品$productId',
    price: 20,
    quantity: 1,
    source: ProductSource.admin,
    cartItemId: cartItemId,
  );
}

AddressInput _addressInput({
  String phone = '13800138000',
  String districtCode = '110101',
}) {
  return AddressInput(
    receiverName: '张三',
    receiverPhone: phone,
    provinceCode: '110000',
    provinceName: '北京市',
    cityCode: '110100',
    cityName: '北京市',
    districtCode: districtCode,
    districtName: '东城区',
    detailAddress: '测试路 1 号',
  );
}

const _address = ShippingAddress(
  id: 1,
  receiverName: '张三',
  receiverPhone: '13800138000',
  provinceCode: '110000',
  provinceName: '北京市',
  cityCode: '110100',
  cityName: '北京市',
  districtCode: '110101',
  districtName: '东城区',
  detailAddress: '测试路 1 号',
  isDefault: true,
);

ShopOrder _order({
  int id = 100,
  ShopOrderStatus status = ShopOrderStatus.pending,
}) {
  return ShopOrder(
    id: id,
    orderNo: 'O$id',
    status: status,
    totalAmount: 20,
    originalAmount: 20,
    couponDiscount: 0,
    items: const [],
  );
}

PendingProduct _pendingProduct({
  required int id,
  PendingProductStatus status = PendingProductStatus.underReview,
}) {
  return PendingProduct(
    id: id,
    userId: 7,
    title: '商品$id',
    description: '描述$id',
    price: 20,
    stock: 1,
    images: const [],
    categoryId: 1,
    condition: ProductCondition.ninety,
    status: status,
  );
}

class _CatalogGateway implements CatalogGateway {
  _CatalogGateway({CatalogProduct? detail}) : detail = detail ?? _product();

  final CatalogProduct detail;
  final List<ProductQuery> productQueries = [];
  final List<ProductQuery> popularQueries = [];

  @override
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query) async {
    productQueries.add(query);
    return CatalogPage(
      items: [_product(id: query.page == 1 ? 2 : 3)],
      total: 2,
      page: query.page,
      pageSize: 1,
      totalPages: 2,
    );
  }

  @override
  Future<CatalogPage<CatalogProduct>> loadPopularProducts(
    ProductQuery query,
  ) async {
    popularQueries.add(query);
    return CatalogPage(items: [_product()], total: 1, page: 1, totalPages: 1);
  }

  @override
  Future<CatalogProduct> loadProduct(
    int productId, {
    required bool authenticated,
  }) async => detail;

  @override
  Future<List<CatalogBanner>> loadBanners() async => const [];

  @override
  Future<List<CatalogCategory>> loadCategoryTree({
    ProductSource source = ProductSource.admin,
  }) async => const [];
}

class _SecondHandMallGateway implements SecondHandGateway {
  _SecondHandMallGateway({this.categoryError});

  final Object? categoryError;
  final List<ProductQuery> queries = [];

  @override
  Future<List<SecondHandCategory>> loadCategories() async {
    final error = categoryError;
    if (error != null) throw error;
    return const [SecondHandCategory(id: 1, name: '闲置用品')];
  }

  @override
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query) async {
    queries.add(query);
    if (query.page == 1) {
      return CatalogPage(
        items: [_product(source: ProductSource.user)],
        total: 2,
        page: 1,
        pageSize: 1,
        totalPages: 2,
      );
    }
    return CatalogPage(
      items: [
        _product(source: ProductSource.user),
        _product(id: 2, source: ProductSource.user),
      ],
      total: 2,
      page: 2,
      pageSize: 1,
      totalPages: 2,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CartGateway implements CartGateway {
  _CartGateway(this.items);

  List<CartItem> items;
  int loadCalls = 0;
  int? removeFailureId;
  final List<int> removedIds = [];
  final List<int> updatedQuantities = [];

  @override
  Future<List<CartItem>> loadCart() async {
    loadCalls += 1;
    return items;
  }

  @override
  Future<CartItem> updateQuantity(int cartItemId, int quantity) async {
    updatedQuantities.add(quantity);
    final current = items.singleWhere((item) => item.id == cartItemId);
    final updated = current.copyWith(quantity: quantity);
    items = items
        .map((item) => item.id == cartItemId ? updated : item)
        .toList();
    return updated;
  }

  @override
  Future<void> removeItem(int cartItemId) async {
    removedIds.add(cartItemId);
    if (cartItemId == removeFailureId) throw StateError('删除失败');
    items = items.where((item) => item.id != cartItemId).toList();
  }

  @override
  Future<CartItem> addItem({
    required int productId,
    int? skuId,
    required int quantity,
  }) async => throw UnimplementedError();

  @override
  Future<void> clear() async => items = [];

  @override
  Future<int> loadCount() async => items.length;
}

class _AddressGateway implements AddressGateway {
  @override
  Future<List<ShippingAddress>> loadAddresses() async => const [_address];

  @override
  Future<ShippingAddress> createAddress(AddressInput input) async => _address;

  @override
  Future<ShippingAddress> updateAddress(int id, AddressInput input) async =>
      _address;

  @override
  Future<void> deleteAddress(int id) async {}

  @override
  Future<void> setDefaultAddress(int id) async {}
}

class _CheckoutGateway implements CheckoutGateway {
  int? failCouponId;
  bool stockFailure = false;
  final List<int?> previewCouponIds = [];
  CreateOrderInput? lastInput;

  @override
  Future<OrderPreview> preview(
    List<CheckoutItem> items, {
    int? userCouponId,
  }) async {
    previewCouponIds.add(userCouponId);
    if (userCouponId == failCouponId) throw StateError('优惠券已失效');
    return const OrderPreview(
      originalAmount: 20,
      couponDiscount: 0,
      totalAmount: 20,
      containsUserPublishedProducts: false,
      couponEligibleAmount: 20,
      couponExcludedAmount: 0,
    );
  }

  @override
  Future<CheckoutResult> createOrder(CreateOrderInput input) async {
    lastInput = input;
    return stockFailure
        ? const CheckoutResult.stockFailure(stockError: '库存不足')
        : CheckoutResult.success(OrderPayment(order: _order()));
  }

  @override
  Future<double> loadWalletBalance() async => 100;
}

class _DeferredOrderGateway implements OrderGateway {
  final Map<ShopOrderStatus?, Completer<OrderPage>> _firstPages = {};
  final Completer<OrderPage> _nextPage = Completer<OrderPage>();

  void complete(ShopOrderStatus? status, OrderPage page) {
    _firstPages[status]!.complete(page);
  }

  void completeNextPage(OrderPage page) => _nextPage.complete(page);

  @override
  Future<OrderPage> loadOrders(OrderQuery query) {
    if (query.page > 1) return _nextPage.future;
    return (_firstPages[query.status] ??= Completer<OrderPage>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredOrderDetailGateway implements OrderGateway {
  final Completer<ShopOrder> result = Completer<ShopOrder>();

  @override
  Future<ShopOrder> loadOrder(int orderId) => result.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OrderActionGateway implements OrderGateway {
  int loadCalls = 0;
  final List<int> cancelledIds = [];
  final List<int> confirmedIds = [];

  @override
  Future<OrderPage> loadOrders(OrderQuery query) async {
    loadCalls += 1;
    return OrderPage(items: [_order()], total: 1, totalPages: 1);
  }

  @override
  Future<ShopOrder> cancelOrder(int orderId, {String? reason}) async {
    cancelledIds.add(orderId);
    return _order(id: orderId, status: ShopOrderStatus.cancelled);
  }

  @override
  Future<ShopOrder> confirmOrder(int orderId) async {
    confirmedIds.add(orderId);
    return _order(id: orderId, status: ShopOrderStatus.completed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAddressGateway implements AddressGateway {
  int loadCalls = 0;
  int created = 0;
  final List<int> updatedIds = [];
  final List<int> defaultIds = [];
  final List<int> removedIds = [];

  @override
  Future<List<ShippingAddress>> loadAddresses() async {
    loadCalls += 1;
    return const [_address];
  }

  @override
  Future<ShippingAddress> createAddress(AddressInput input) async {
    created += 1;
    return _address;
  }

  @override
  Future<ShippingAddress> updateAddress(int id, AddressInput input) async {
    updatedIds.add(id);
    return _address;
  }

  @override
  Future<void> deleteAddress(int id) async => removedIds.add(id);

  @override
  Future<void> setDefaultAddress(int id) async => defaultIds.add(id);
}

class _DeferredAddressGateway implements AddressGateway {
  final Completer<List<ShippingAddress>> result =
      Completer<List<ShippingAddress>>();

  @override
  Future<List<ShippingAddress>> loadAddresses() => result.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FavoriteControllerGateway implements FavoriteGateway {
  int? removeFailureId;

  @override
  Future<FavoritePage> loadFavorites({int page = 1, int pageSize = 20}) async {
    final first = FavoriteEntry(id: 1, productId: 1, product: _product(id: 1));
    final second = FavoriteEntry(id: 2, productId: 2, product: _product(id: 2));
    return page == 1
        ? FavoritePage(items: [first], total: 2, page: 1, totalPages: 2)
        : FavoritePage(
            items: [first, second],
            total: 2,
            page: 2,
            totalPages: 2,
          );
  }

  @override
  Future<void> removeFavorite(int favoriteId) async {
    if (favoriteId == removeFailureId) throw StateError('取消收藏失败');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredFavoriteGateway implements FavoriteGateway {
  final Completer<FavoritePage> result = Completer<FavoritePage>();

  @override
  Future<FavoritePage> loadFavorites({int page = 1, int pageSize = 20}) =>
      result.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredSecondHandGateway implements SecondHandGateway {
  final Map<String, Completer<PendingProductPage>> _requests = {};

  String _key(Iterable<PendingProductStatus> statuses, int page) =>
      '$page:${statuses.map((status) => status.wireValue).join(',')}';

  void complete(
    List<PendingProductStatus> statuses,
    PendingProductPage result, {
    int page = 1,
  }) {
    _requests[_key(statuses, page)]!.complete(result);
  }

  @override
  Future<PendingProductPage> loadMyProducts({
    int page = 1,
    int pageSize = 10,
    List<PendingProductStatus> statuses = const [],
  }) {
    return (_requests[_key(statuses, page)] ??= Completer<PendingProductPage>())
        .future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredPublishGateway implements SecondHandGateway {
  final Completer<List<SecondHandCategory>> categories =
      Completer<List<SecondHandCategory>>();

  @override
  Future<List<SecondHandCategory>> loadCategories() => categories.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
