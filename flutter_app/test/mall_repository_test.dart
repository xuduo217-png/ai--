import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/mall/data/mall_repository.dart';

void main() {
  test('商城仓库解析轮播、过滤自营分类和热门商品', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requests.add(request);
        final data = switch (request.url.path) {
          '/shop/products/batch' => [
            {
              'id': 2,
              'name': '宠物食品',
              'sortOrder': 2,
              'children': [
                {
                  'products': [
                    {'publishSource': 'ADMIN'},
                  ],
                },
              ],
            },
            {
              'id': 1,
              'name': '宠物用品',
              'icon': '/uploads/category.jpg',
              'sortOrder': 1,
              'children': [
                {
                  'products': [
                    {'publishSource': 'ADMIN'},
                  ],
                },
              ],
            },
            {
              'id': 3,
              'name': '用户闲置',
              'sortOrder': 3,
              'children': [
                {
                  'products': [
                    {'publishSource': 'USER'},
                  ],
                },
              ],
            },
          ],
          '/shop/products/popular' => {
            'data': [
              {
                'id': 47,
                'name': '全价猫粮',
                'price': '89.90',
                'images': ['/uploads/product.jpg'],
                'stock': 20,
                'hasSku': true,
                'isTop': 1,
                'publishSource': 'ADMIN',
                'skus': [
                  {
                    'id': 91,
                    'specs': {'重量': '2kg'},
                    'price': '89.90',
                    'stock': 20,
                    'status': 'ACTIVE',
                  },
                ],
              },
              {'id': 48, 'name': '用户商品', 'price': 12, 'publishSource': 'USER'},
            ],
          },
          '/shop/homepage-banners' => {
            'banners': [
              {
                'id': 'banner-1',
                'imageUrl': '/uploads/banner.jpg',
                'actionType': 'product',
                'productId': 47,
              },
            ],
          },
          '/system-configs/mall_home_popup_image' => {
            'configValue': {'imageUrl': '/uploads/popup.jpg'},
          },
          '/shop/cart/count' => {'count': 2},
          _ => throw StateError('unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({'code': 0, 'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async => 'test-token',
    );

    final snapshot = await MallRepository(client).loadMall(authenticated: true);

    expect(snapshot.categories.map((item) => item.name), ['宠物用品', '宠物食品']);
    expect(
      snapshot.categories.first.imageUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/category.jpg',
    );
    expect(snapshot.products, hasLength(1));
    expect(snapshot.products.single.name, '全价猫粮');
    expect(snapshot.products.single.price, 89.9);
    expect(snapshot.products.single.skus.single.specs, {'重量': '2kg'});
    expect(snapshot.banners.single.productId, 47);
    expect(
      snapshot.banners.single.imageUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/banner.jpg',
    );
    expect(
      snapshot.homePopupImageUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/popup.jpg',
    );
    expect(snapshot.hasCartItems, isTrue);
    expect(requests, hasLength(5));
    expect(
      requests.map((request) => request.url.path),
      contains('/system-configs/mall_home_popup_image'),
    );

    final publicRequests = requests.where(
      (request) => request.url.path != '/shop/cart/count',
    );
    expect(
      publicRequests.every(
        (request) => !request.headers.containsKey('authorization'),
      ),
      isTrue,
    );
    expect(
      requests
          .singleWhere((request) => request.url.path == '/shop/cart/count')
          .headers['authorization'],
      'Bearer test-token',
    );
  });

  test('商品详情和加购使用正确接口及鉴权', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requests.add(request);
        final data = request.method == 'GET'
            ? {
                'id': 47,
                'name': '全价猫粮',
                'price': 89.9,
                'stock': 8,
                'hasSku': false,
                'publishSource': 'ADMIN',
                'skus': [
                  {
                    'id': 91,
                    'specs': <String, String>{},
                    'price': 89.9,
                    'stock': 8,
                    'status': 'ACTIVE',
                  },
                ],
              }
            : {'id': 7};
        return http.Response(
          jsonEncode({'code': 0, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      tokenProvider: () async => 'test-token',
    );
    final repository = MallRepository(client);

    final product = await repository.loadProduct(47);
    await repository.addToCart(productId: 47, skuId: 91, quantity: 2);

    expect(product.name, '全价猫粮');
    expect(requests.first.url.path, '/shop/products/47');
    expect(requests.first.headers.containsKey('authorization'), isFalse);
    expect(requests.last.url.path, '/shop/cart');
    expect(requests.last.method, 'POST');
    expect(requests.last.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(requests.last.body), {
      'productId': 47,
      'skuId': 91,
      'quantity': 2,
    });
  });
}
