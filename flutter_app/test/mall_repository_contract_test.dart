import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/mall/address/data/address_repository.dart';
import 'package:pet_hospital_flutter/features/mall/address/domain/address_models.dart';
import 'package:pet_hospital_flutter/features/mall/cart/data/cart_repository.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/data/catalog_repository.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/domain/catalog_models.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/data/checkout_repository.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/domain/checkout_models.dart';
import 'package:pet_hospital_flutter/features/mall/favorite/data/favorite_repository.dart';
import 'package:pet_hospital_flutter/features/mall/order/data/order_repository.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/second_hand/data/second_hand_repository.dart';
import 'package:pet_hospital_flutter/features/mall/second_hand/domain/second_hand_models.dart';

void main() {
  test('CatalogRepository 使用正确公开接口、分页参数并隔离发布来源', () async {
    final requests = <http.Request>[];
    final client = _apiClient(requests, (request) {
      final data = switch (request.url.path) {
        '/shop/products' => [_productJson(1), _productJson(2, source: 'USER')],
        '/shop/products/popular' => [_productJson(3)],
        '/shop/products/batch' => [
          {
            'id': 2,
            'name': '用户分类',
            'sortOrder': 2,
            'products': [_productJson(2, source: 'USER')],
          },
          {
            'id': 1,
            'name': '自营分类',
            'sortOrder': 1,
            'products': [_productJson(1)],
          },
        ],
        '/shop/products/1' || '/shop/products/1/detail' => _productJson(1),
        '/shop/homepage-banners' => {
          'banners': [
            {'id': 1, 'imageUrl': '/uploads/banner.jpg', 'productId': 1},
          ],
        },
        _ => throw StateError('unexpected ${request.method} ${request.url}'),
      };
      final pagination = request.url.path.contains('products') && data is List
          ? const {'total': 2, 'page': 2, 'pageSize': 1, 'totalPages': 2}
          : null;
      return _ok(data, pagination: pagination);
    });
    final repository = CatalogRepository(client);

    final page = await repository.loadProducts(
      const ProductQuery(page: 2, pageSize: 1, keyword: ' 猫粮 '),
    );
    final popular = await repository.loadPopularProducts(
      const ProductQuery(pageSize: 10),
    );
    final categories = await repository.loadCategoryTree();
    final publicDetail = await repository.loadProduct(1, authenticated: false);
    final privateDetail = await repository.loadProduct(1, authenticated: true);
    final banners = await repository.loadBanners();

    expect(page.items.map((item) => item.id), [1]);
    expect(page.page, 2);
    expect(popular.items.single.id, 3);
    expect(categories.map((item) => item.name), ['自营分类']);
    expect(publicDetail.source, ProductSource.admin);
    expect(privateDetail.id, 1);
    expect(
      banners.single.imageUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/banner.jpg',
    );

    final listRequest = requests.first;
    expect(listRequest.url.queryParameters, {
      'page': '2',
      'pageSize': '1',
      'keyword': '猫粮',
      'sortBy': 'createdAt',
      'sortOrder': 'DESC',
      'publishSource': 'ADMIN',
      'isActive': 'true',
    });
    expect(listRequest.headers.containsKey('authorization'), isFalse);
    expect(
      requests
          .singleWhere((item) => item.url.path.endsWith('/detail'))
          .headers['authorization'],
      'Bearer token',
    );
  });

  test('CartRepository 与 AddressRepository 使用完整写接口和鉴权', () async {
    final requests = <http.Request>[];
    final client = _apiClient(requests, (request) {
      final path = request.url.path;
      if (path == '/shop/cart/count') return _ok({'count': 2});
      if (path == '/shop/cart' && request.method == 'GET') {
        return _ok([_cartJson()]);
      }
      if (path == '/shop/cart' && request.method == 'POST') {
        return _ok(_cartJson());
      }
      if (path == '/shop/cart/9' && request.method == 'PUT') {
        return _ok(_cartJson(quantity: 3));
      }
      if (path == '/addresses' && request.method == 'GET') {
        return _ok([_addressJson()]);
      }
      if (path == '/addresses' && request.method == 'POST') {
        return _ok(_addressJson());
      }
      if (path == '/addresses/4' && request.method == 'PUT') {
        return _ok(_addressJson());
      }
      if (request.method == 'DELETE' || request.method == 'PATCH') {
        return _ok(null);
      }
      throw StateError('unexpected ${request.method} ${request.url}');
    });
    final cart = CartRepository(client);
    final addresses = AddressRepository(client);

    expect(await cart.loadCart(), hasLength(1));
    await cart.addItem(productId: 1, skuId: 2, quantity: 3);
    expect((await cart.updateQuantity(9, 3)).quantity, 3);
    await cart.removeItem(9);
    await cart.clear();
    expect(await cart.loadCount(), 2);

    expect(await addresses.loadAddresses(), hasLength(1));
    await addresses.createAddress(_addressInput);
    await addresses.updateAddress(4, _addressInput);
    await addresses.deleteAddress(4);
    await addresses.setDefaultAddress(4);

    expect(_request(requests, 'POST', '/shop/cart').jsonBody, {
      'productId': 1,
      'skuId': 2,
      'quantity': 3,
    });
    expect(_request(requests, 'PUT', '/shop/cart/9').jsonBody, {'quantity': 3});
    expect(_request(requests, 'DELETE', '/shop/cart').body, isEmpty);
    expect(
      _request(requests, 'POST', '/addresses').jsonBody['receiverName'],
      '张三',
    );
    expect(_request(requests, 'PATCH', '/addresses/4/default').body, '{}');
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer token',
      ),
      isTrue,
    );
  });

  test('结算、订单和收藏仓库保持请求与响应契约', () async {
    final requests = <http.Request>[];
    final client = _apiClient(requests, (request) {
      final path = request.url.path;
      if (path == '/shop/orders/preview') {
        return _ok({
          'originalAmount': '100.00',
          'couponDiscount': '10.00',
          'totalAmount': '90.00',
          'coupons': [
            {..._couponJson(), 'isApplicable': true, 'discountAmount': 10},
          ],
          'selectedCoupon': {
            ..._couponJson(),
            'isApplicable': true,
            'discountAmount': 10,
          },
          'containsUserPublishedProducts': true,
          'couponEligibleAmount': 100,
          'couponExcludedAmount': 20,
          'charityDonationRate': 1.5,
          'charityDonationAmount': 1.35,
        });
      }
      if (path == '/shop/orders' && request.method == 'POST') {
        return _ok({
          'success': true,
          'order': _orderJson(),
          'paymentParams': {
            'paymentParams': {'alipayOrderString': 'signed'},
          },
        });
      }
      if (path == '/shop/wallet/balance') return _ok({'balance': '88.50'});
      if (path == '/shop/orders/purchases') {
        return _ok(
          [_orderJson()],
          pagination: const {
            'total': 2,
            'page': 1,
            'limit': 1,
            'totalPages': 2,
          },
        );
      }
      if (path == '/shop/orders/7/pay') {
        return _ok({
          'order': _orderJson(),
          'paymentParams': {'alipayOrderString': 'signed'},
        });
      }
      if (path.startsWith('/shop/orders/7')) return _ok(_orderJson());
      if (path == '/shop/favorites' && request.method == 'GET') {
        return _ok(
          [
            {'id': 5, 'productId': 1, 'product': _productJson(1)},
          ],
          pagination: const {
            'total': 2,
            'page': 1,
            'pageSize': 1,
            'totalPages': 2,
          },
        );
      }
      if (path == '/shop/favorites' && request.method == 'POST') {
        return _ok({'isFavorited': true});
      }
      if (path == '/shop/favorites/check') return _ok({'isFavorited': true});
      if (path == '/shop/favorites/count') return _ok({'count': 4});
      if (path == '/shop/favorites/5') return _ok(null);
      throw StateError('unexpected ${request.method} ${request.url}');
    });
    final checkout = CheckoutRepository(client);
    final orders = OrderRepository(client);
    final favorites = FavoriteRepository(client);
    final item = _checkoutItem;

    final preview = await checkout.preview([item], userCouponId: 6);
    final created = await checkout.createOrder(
      CreateOrderInput(
        items: [item],
        address: _shippingAddress,
        paymentChannel: PaymentChannel.alipay,
        remark: '  请轻放  ',
        userCouponId: 6,
      ),
    );
    expect(await checkout.loadWalletBalance(), 88.5);

    final page = await orders.loadOrders(
      const OrderQuery(status: ShopOrderStatus.pending, pageSize: 1),
    );
    final detail = await orders.loadOrder(7);
    await orders.cancelOrder(7, reason: '不想要了');
    await orders.confirmOrder(7);
    final paid = await orders.payOrder(7, PaymentChannel.alipay);

    final favoritePage = await favorites.loadFavorites(pageSize: 1);
    expect(await favorites.toggleFavorite(1), isTrue);
    expect(await favorites.isFavorite(1), isTrue);
    await favorites.removeFavorite(5);
    expect(await favorites.loadFavoriteCount(), 4);

    expect(preview.selectedCoupon?.id, 6);
    expect(preview.couponExcludedAmount, 20);
    expect(preview.charityDonationRate, 1.5);
    expect(preview.charityDonationAmount, 1.35);
    expect(created.payment?.alipayOrderString, 'signed');
    expect(page.hasMore, isTrue);
    expect(detail.charityDonationAmount, 1.35);
    expect(paid.alipayOrderString, 'signed');
    expect(favoritePage.hasMore, isTrue);
    expect(
      _request(
        requests,
        'POST',
        '/shop/orders/preview',
      ).jsonBody['userCouponId'],
      6,
    );
    expect(
      _request(requests, 'POST', '/shop/orders').jsonBody,
      containsPair('remark', '请轻放'),
    );
    expect(
      _request(
        requests,
        'GET',
        '/shop/orders/purchases',
      ).url.queryParameters['status'],
      'pending',
    );
    expect(_request(requests, 'POST', '/shop/orders/7/pay').jsonBody, {
      'paymentChannel': 'alipay',
    });
  });

  test('结算仓库将服务端 STOCK_OUT 转为可展示库存失败', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'STOCK_OUT',
            'message': '提交库存不足',
            'details': [
              {'productName': '猫粮', 'skuName': '2kg', 'available': 1},
            ],
          }),
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
      tokenProvider: () async => 'token',
    );

    final result = await CheckoutRepository(client).createOrder(
      CreateOrderInput(
        items: [_checkoutItem],
        address: _shippingAddress,
        paymentChannel: PaymentChannel.alipay,
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.stockError, '提交库存不足');
    expect(result.stockDetails.single, '猫粮 (2kg) 库存不足，当前库存：1');
  });

  test('收藏仓库兼容历史双层 data 分页响应', () async {
    final requests = <http.Request>[];
    final client = _apiClient(
      requests,
      (_) => _ok({
        'data': {
          'data': [
            {'id': 5, 'productId': 1, 'product': _productJson(1)},
          ],
          'total': 1,
          'page': 1,
          'pageSize': 20,
          'totalPages': 1,
        },
      }),
    );

    final page = await FavoriteRepository(client).loadFavorites();

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 5);
    expect(page.items.single.product.name, '商品1');
    expect(page.total, 1);
  });

  test('我发布的商品兼容历史双层 data 分页响应', () async {
    final requests = <http.Request>[];
    final client = _apiClient(
      requests,
      (_) => _ok({
        'data': {
          'data': [_pendingJson()],
          'total': 1,
          'page': 1,
          'limit': 10,
          'totalPages': 1,
        },
      }),
    );

    final page = await SecondHandRepository(client).loadMyProducts();

    expect(page.items.single.id, 3);
    expect(page.items.single.status, PendingProductStatus.rejected);
    expect(page.total, 1);
    expect(page.pageSize, 10);
  });

  test('SecondHandRepository 强制 USER 来源并覆盖发布管理完整接口', () async {
    final directory = await Directory.systemTemp.createTemp(
      'second-hand-test-',
    );
    final image = File('${directory.path}/product.jpg');
    await image.writeAsBytes([1, 2, 3]);
    final requests = <http.Request>[];
    final client = _apiClient(requests, (request) {
      final path = request.url.path;
      if (path == '/shop/products' && request.method == 'GET') {
        return _ok([_productJson(8, source: 'USER'), _productJson(9)]);
      }
      if (path == '/shop/products/8/detail') {
        return _ok(_productJson(8, source: 'USER'));
      }
      if (path == '/shop/products/batch') {
        return _ok([
          {
            'id': 4,
            'name': '闲置用品',
            'image': '/uploads/second-category.jpg',
            'sortOrder': 2,
            'children': [
              {
                'id': 5,
                'name': '航空箱',
                'products': [_productJson(8, source: 'USER')],
              },
              {
                'id': 6,
                'name': '猫粮',
                'products': [_productJson(9)],
              },
            ],
          },
          {
            'id': 7,
            'name': '自营用品',
            'sortOrder': 1,
            'children': [
              {
                'id': 8,
                'name': '猫砂',
                'products': [_productJson(10)],
              },
            ],
          },
        ]);
      }
      if (path == '/shop/products/categories/list') {
        return _ok([
          {
            'id': 1,
            'name': '用品',
            'children': [
              {'id': 2, 'name': '航空箱'},
            ],
          },
        ]);
      }
      if (path == '/shop/products/my') {
        return _ok(
          [_pendingJson()],
          pagination: const {
            'total': 1,
            'page': 1,
            'limit': 10,
            'totalPages': 1,
          },
        );
      }
      if (path == '/shop/products/pending/3' && request.method == 'GET') {
        return _ok(_pendingJson());
      }
      if (path == '/shop/products/pending' && request.method == 'POST') {
        return _ok({'id': 3});
      }
      if (path == '/upload/image') return _ok({'url': '/uploads/second.jpg'});
      if (request.method == 'PUT' || request.method == 'POST') return _ok(null);
      throw StateError('unexpected ${request.method} ${request.url}');
    });
    final repository = SecondHandRepository(client);
    const input = PublishProductInput(
      title: ' 航空箱 ',
      description: ' 使用一次 ',
      price: 88,
      stock: 1,
      images: ['/uploads/one.jpg'],
      categoryId: 2,
      condition: ProductCondition.ninety,
    );

    try {
      final page = await repository.loadProducts(
        const ProductQuery(source: ProductSource.admin, categoryId: 2),
      );
      final detail = await repository.loadProduct(8, authenticated: true);
      final categories = await repository.loadCategories();
      final mallCategories = await repository.loadMallCategories();
      final mine = await repository.loadMyProducts(
        statuses: const [
          PendingProductStatus.underReview,
          PendingProductStatus.rejected,
        ],
      );
      await repository.loadPendingProduct(3);
      expect(await repository.publishProduct(input), 3);
      await repository.updateProduct(3, input);
      await repository.updateProductStatus(8, true);
      final imageUrl = await repository.uploadImage(image.path);
      await repository.reportProduct(8, reason: '虚假商品', description: '描述不符');
      await repository.blockUser(12, reason: '骚扰');

      expect(page.items.map((item) => item.id), [8]);
      expect(detail.isSecondHand, isTrue);
      expect(categories.single.children.single.name, '航空箱');
      expect(mallCategories.map((category) => category.name), ['闲置用品']);
      expect(mallCategories.single.children.map((category) => category.name), [
        '航空箱',
      ]);
      expect(
        mallCategories.single.iconUrl,
        'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/second-category.jpg',
      );
      expect(mine.items.single.status, PendingProductStatus.rejected);
      expect(
        imageUrl,
        'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/second.jpg',
      );
      expect(
        _request(
          requests,
          'GET',
          '/shop/products',
        ).url.queryParameters['publishSource'],
        'USER',
      );
      final mallCategoryRequest = _request(
        requests,
        'GET',
        '/shop/products/batch',
      );
      expect(mallCategoryRequest.url.queryParameters, {
        'includeEmpty': 'false',
        'limit': '50',
        'sortBy': 'isTop',
        'sortOrder': 'DESC',
      });
      expect(mallCategoryRequest.headers.containsKey('authorization'), isFalse);
      expect(
        _request(
          requests,
          'GET',
          '/shop/products/categories/list',
        ).headers['authorization'],
        'Bearer token',
      );
      expect(
        _request(
          requests,
          'GET',
          '/shop/products/my',
        ).url.queryParameters['status'],
        'under_review,rejected',
      );
      expect(_request(requests, 'PUT', '/shop/products/8/status').jsonBody, {
        'status': true,
      });
      final upload = _request(requests, 'POST', '/upload/image');
      expect(
        upload.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(upload.body, contains('second-hand-product'));
      expect(_request(requests, 'POST', '/moderation/reports').jsonBody, {
        'targetType': 'SECOND_HAND_PRODUCT',
        'targetId': 8,
        'reason': '虚假商品',
        'description': '描述不符',
      });
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('二手详情拒绝混入自营商品', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => _ok(_productJson(1))),
      tokenProvider: () async => 'token',
    );

    await expectLater(
      SecondHandRepository(client).loadProduct(1, authenticated: true),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '该商品不是二手商品',
        ),
      ),
    );
  });
}

ApiClient _apiClient(
  List<http.Request> requests,
  http.Response Function(http.Request request) handler,
) {
  return ApiClient(
    baseUrl: 'https://example.test',
    client: MockClient((request) async {
      requests.add(request);
      return handler(request);
    }),
    tokenProvider: () async => 'token',
  );
}

http.Response _ok(Object? data, {Map<String, Object?>? pagination}) {
  return http.Response(
    jsonEncode({'code': 0, 'data': data, 'pagination': ?pagination}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

http.Request _request(List<http.Request> requests, String method, String path) {
  return requests.singleWhere(
    (request) => request.method == method && request.url.path == path,
  );
}

extension on http.Request {
  Map<String, dynamic> get jsonBody =>
      Map<String, dynamic>.from(jsonDecode(body) as Map);
}

Map<String, Object?> _productJson(int id, {String source = 'ADMIN'}) => {
  'id': id,
  'name': '商品$id',
  'price': '20.50',
  'stock': 5,
  'images': ['/uploads/$id.jpg'],
  'publishSource': source,
  'isActive': true,
};

Map<String, Object?> _cartJson({int quantity = 2}) => {
  'id': 9,
  'productId': 1,
  'quantity': quantity,
  'product': _productJson(1),
};

Map<String, Object?> _addressJson() => {
  'id': 4,
  'receiverName': '张三',
  'receiverPhone': '13800138000',
  'provinceCode': '110000',
  'provinceName': '北京市',
  'cityCode': '110100',
  'cityName': '北京市',
  'districtCode': '110101',
  'districtName': '东城区',
  'detailAddress': '测试路 1 号',
  'isDefault': true,
};

Map<String, Object?> _orderJson() => {
  'id': 7,
  'orderNo': 'ORDER-7',
  'status': 'pending',
  'totalAmount': 90,
  'originalAmount': 100,
  'couponDiscount': 10,
  'charityDonationAmount': '1.35',
  'trackingNumber': 'SF123',
  'logistics': {'id': 1, 'name': '顺丰', 'code': 'SF'},
  'items': [
    {
      'productId': 1,
      'productName': '猫粮',
      'productImage': '/uploads/1.jpg',
      'quantity': 1,
      'price': 90,
    },
  ],
};

Map<String, Object?> _couponJson() => {
  'id': 6,
  'userId': 12,
  'couponId': 16,
  'status': 'AVAILABLE',
  'validFrom': '2026-07-01T00:00:00.000Z',
  'validUntil': '2026-07-31T23:59:59.000Z',
  'createdAt': '2026-06-25T00:00:00.000Z',
  'usedAt': null,
  'orderId': null,
  'coupon': {
    'id': 16,
    'name': '满减券',
    'type': 'FULL_REDUCTION',
    'scope': 'ALL',
    'description': '',
    'status': 'ACTIVE',
    'discountValue': 10,
    'minAmount': 100,
    'minOrderAmount': 100,
    'maxDiscount': null,
    'validFrom': '2026-07-01T00:00:00.000Z',
    'validUntil': '2026-07-31T23:59:59.000Z',
    'canStack': false,
    'isEnabled': true,
  },
};

Map<String, Object?> _pendingJson() => {
  'id': 3,
  'userId': 12,
  'productId': 8,
  'title': '航空箱',
  'description': '使用一次',
  'price': 88,
  'stock': 1,
  'images': ['/uploads/second.jpg'],
  'categoryId': 2,
  'category': {'name': '航空箱'},
  'condition': '90%',
  'status': 'rejected',
  'rejectReason': '图片不清晰',
  'isActive': false,
};

const _addressInput = AddressInput(
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

const _shippingAddress = ShippingAddress(
  id: 4,
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

const _checkoutItem = CheckoutItem(
  productId: 1,
  productName: '猫粮',
  price: 100,
  quantity: 1,
  source: ProductSource.admin,
);
