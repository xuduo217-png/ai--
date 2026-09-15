import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/coupons/data/coupon_repository.dart';
import 'package:pet_hospital_flutter/features/coupons/domain/coupon_models.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/domain/catalog_models.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/data/checkout_repository.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/domain/checkout_models.dart';

void main() {
  test('优惠券列表和统计使用固定 GET、status 查询与鉴权', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) {
      requests.add(request);
      return switch (request.url.path) {
        '/shop/coupons/my' => _ok([_couponJson()]),
        '/shop/coupons/my/count' => _ok({
          'available': 3,
          'used': 1,
          'expired': 2,
        }),
        _ => throw StateError('unexpected ${request.url.path}'),
      };
    });

    final coupons = await repository.loadCoupons(UserCouponStatus.available);
    final counts = await repository.loadCounts();

    expect(coupons.single.id, 41);
    expect(counts.available, 3);
    expect(requests.map((request) => request.method), ['GET', 'GET']);
    expect(requests.first.url.queryParameters, {'status': 'AVAILABLE'});
    expect(requests.last.url.queryParameters, isEmpty);
    expect(
      requests.map((request) => request.headers['authorization']),
      everyElement('Bearer coupon-token'),
    );
  });

  test('券中心与 checkout 对同一服务端 fixture 解析一致', () async {
    final fixture = _couponJson(
      type: 'DISCOUNT',
      discountValue: '8.5',
      minAmount: '80',
      minOrderAmount: '100',
    );
    final apiClient = _apiClient((request) {
      return switch (request.url.path) {
        '/shop/coupons/my' => _ok([fixture]),
        '/shop/orders/preview' => _ok({
          'originalAmount': 120,
          'couponDiscount': 10.2,
          'totalAmount': 109.8,
          'containsUserPublishedProducts': false,
          'couponEligibleAmount': 120,
          'couponExcludedAmount': 0,
          'coupons': [
            {...fixture, 'isApplicable': true, 'discountAmount': 10.2},
          ],
          'selectedCoupon': null,
        }),
        _ => throw StateError('unexpected ${request.url.path}'),
      };
    });
    final center = CouponRepository(apiClient: apiClient);
    final checkout = CheckoutRepository(apiClient);

    final centerCoupon = (await center.loadCoupons(
      UserCouponStatus.available,
    )).single;
    final checkoutCoupon = (await checkout.preview([
      const CheckoutItem(
        productId: 1,
        productName: '商品',
        price: 120,
        quantity: 1,
        source: ProductSource.admin,
      ),
    ])).coupons.single;

    expect(checkoutCoupon.id, centerCoupon.id);
    expect(checkoutCoupon.name, centerCoupon.rule.name);
    expect(checkoutCoupon.type, centerCoupon.rule.type.wireValue);
    expect(checkoutCoupon.discount, centerCoupon.rule.discountValue);
    expect(checkoutCoupon.minAmount, centerCoupon.rule.minAmount);
    expect(checkoutCoupon.validUntil, centerCoupon.validUntil);
  });

  test('优惠券列表与统计兼容历史双层 data 响应', () async {
    final repository = _repository((request) {
      return switch (request.url.path) {
        '/shop/coupons/my' => _ok({
          'data': {
            'data': [_couponJson()],
            'total': 1,
            'page': 1,
            'pageSize': 20,
          },
        }),
        '/shop/coupons/my/count' => _ok({
          'data': {'available': 3, 'used': 1, 'expired': 2},
        }),
        _ => throw StateError('unexpected ${request.url.path}'),
      };
    });

    final coupons = await repository.loadCoupons(UserCouponStatus.available);
    final counts = await repository.loadCounts();

    expect(coupons.single.id, 41);
    expect(counts.available, 3);
    expect(counts.used, 1);
    expect(counts.expired, 2);
  });

  test('列表或统计响应漂移时抛出格式异常', () async {
    final invalidList = _repository((_) => _ok({'id': 1}));
    final invalidCount = _repository(
      (_) => _ok({'available': -1, 'used': 0, 'expired': 0}),
    );

    await expectLater(
      invalidList.loadCoupons(UserCouponStatus.available),
      throwsFormatException,
    );
    await expectLater(invalidCount.loadCounts(), throwsFormatException);
  });

  test('扫码详情与领取使用 claimCode、固定路径和鉴权', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) {
      requests.add(request);
      return switch ((request.method, request.url.path)) {
        ('GET', '/shop/coupons/scan/CLAIM_1001') => _ok({
          'claimCode': 'CLAIM_1001',
          'claimType': 'SCAN_CODE',
          'claimed': false,
          'canClaim': true,
          'unavailableReason': null,
          'coupon': _couponJson()['coupon'],
          'userCoupon': null,
        }),
        ('POST', '/shop/coupons/claim') => _ok({'id': 88}),
        _ => throw StateError(
          'unexpected ${request.method} ${request.url.path}',
        ),
      };
    });

    final detail = await repository.loadScanDetail(' CLAIM_1001 ');
    await repository.claimByScanCode(' CLAIM_1001 ');

    expect(detail.canClaim, isTrue);
    expect(requests.map((request) => request.method), ['GET', 'POST']);
    expect(
      requests.map((request) => request.headers['authorization']),
      everyElement('Bearer coupon-token'),
    );
    expect(jsonDecode(requests.last.body), {'claimCode': 'CLAIM_1001'});
  });
}

CouponRepository _repository(
  http.Response Function(http.Request request) handler,
) => CouponRepository(apiClient: _apiClient(handler));

ApiClient _apiClient(http.Response Function(http.Request request) handler) {
  return ApiClient(
    baseUrl: 'https://example.test',
    client: MockClient((request) async => handler(request)),
    tokenProvider: () async => 'coupon-token',
  );
}

http.Response _ok(Object? data) {
  return http.Response(
    jsonEncode({'code': 0, 'data': data, 'message': 'Success'}),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, Object?> _couponJson({
  String type = 'FULL_REDUCTION',
  Object discountValue = 20,
  Object minAmount = 100,
  Object minOrderAmount = 80,
}) => {
  'id': 41,
  'userId': 7,
  'couponId': 11,
  'status': 'AVAILABLE',
  'validFrom': '2026-07-01T12:00:00.000Z',
  'validUntil': '2026-07-31T12:00:00.000Z',
  'expiresAt': '2026-07-31T12:00:00.000Z',
  'usedAt': null,
  'orderId': null,
  'createdAt': '2026-06-25T12:00:00.000Z',
  'coupon': {
    'id': 11,
    'name': '夏日优惠券',
    'type': type,
    'scope': 'ALL',
    'description': '测试规则',
    'status': 'ACTIVE',
    'discountValue': discountValue,
    'minAmount': minAmount,
    'minOrderAmount': minOrderAmount,
    'maxDiscount': null,
    'validFrom': '2026-07-01T12:00:00.000Z',
    'validUntil': '2026-07-31T12:00:00.000Z',
    'canStack': false,
    'isEnabled': true,
  },
};
