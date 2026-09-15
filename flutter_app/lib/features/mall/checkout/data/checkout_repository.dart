import '../../../../core/network/api_client.dart';
import '../../../coupons/domain/coupon_models.dart';
import '../../order/data/order_repository.dart';
import '../../order/domain/order_models.dart';
import '../../shared/mall_json.dart';
import '../domain/checkout_models.dart';

class CheckoutRepository implements CheckoutGateway {
  CheckoutRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<OrderPreview> preview(
    List<CheckoutItem> items, {
    int? userCouponId,
  }) async {
    final payload = asJsonMap(
      unwrapData(
        await _apiClient.post(
          '/shop/orders/preview',
          authenticated: true,
          body: {
            'items': items
                .map((item) => item.toOrderJson())
                .toList(growable: false),
            'userCouponId': ?userCouponId,
          },
        ),
      ),
    );
    return _parsePreview(payload);
  }

  @override
  Future<CheckoutResult> createOrder(CreateOrderInput input) async {
    try {
      final payload = asJsonMap(
        unwrapData(
          await _apiClient.post(
            '/shop/orders',
            authenticated: true,
            body: input.toJson(),
          ),
        ),
      );
      if (payload['success'] == false) {
        return CheckoutResult.stockFailure(
          stockError: jsonString(payload['message'], '库存不足'),
          stockDetails: _stockDetails(payload['details']),
        );
      }
      return CheckoutResult.success(
        OrderPayment(
          order: parseShopOrder(asJsonMap(payload['order'])),
          paymentParams: asJsonMap(payload['paymentParams']),
        ),
      );
    } on ApiException catch (error) {
      if ('${error.code}' == 'STOCK_OUT') {
        return CheckoutResult.stockFailure(
          stockError: error.message,
          stockDetails: error.validationErrors,
        );
      }
      rethrow;
    }
  }

  @override
  Future<double> loadWalletBalance() async {
    final payload = asJsonMap(
      unwrapData(await _apiClient.get('/shop/wallet/balance')),
    );
    return jsonDouble(payload['balance']);
  }

  OrderPreview _parsePreview(Map<String, dynamic> json) {
    final coupons = asJsonList(
      json['coupons'],
    ).map((item) => _parseCoupon(asJsonMap(item))).toList(growable: false);
    final selectedJson = asJsonMap(json['selectedCoupon']);
    return OrderPreview(
      originalAmount: jsonDouble(json['originalAmount']),
      couponDiscount: jsonDouble(json['couponDiscount']),
      totalAmount: jsonDouble(json['totalAmount']),
      coupons: coupons,
      selectedCoupon: selectedJson.isEmpty ? null : _parseCoupon(selectedJson),
      containsUserPublishedProducts: jsonBool(
        json['containsUserPublishedProducts'],
      ),
      couponEligibleAmount: jsonDouble(json['couponEligibleAmount']),
      couponExcludedAmount: jsonDouble(json['couponExcludedAmount']),
      charityDonationRate: json['charityDonationRate'] == null
          ? null
          : jsonDouble(json['charityDonationRate']),
      charityDonationAmount: json['charityDonationAmount'] == null
          ? null
          : jsonDouble(json['charityDonationAmount']),
    );
  }

  CheckoutCoupon _parseCoupon(Map<String, dynamic> json) {
    final userCoupon = UserCoupon.fromJson(json);
    final rule = userCoupon.rule;
    return CheckoutCoupon(
      id: userCoupon.id,
      name: rule.name,
      type: rule.type.wireValue ?? 'UNKNOWN',
      discount: rule.discountValue,
      minAmount: rule.minAmount,
      isApplicable: jsonBool(json['isApplicable']),
      discountAmount: jsonDouble(json['discountAmount']),
      unavailableReason: jsonNullableString(json['unavailableReason']),
      validUntil: userCoupon.validUntil,
    );
  }

  List<String> _stockDetails(Object? value) {
    return asJsonList(value)
        .map((item) {
          final detail = asJsonMap(item);
          if (detail.isEmpty) return '$item';
          final product = jsonString(detail['productName'], '商品');
          final sku = jsonNullableString(detail['skuName']);
          return '$product${sku == null ? '' : ' ($sku)'} 库存不足'
              '，当前库存：${jsonInt(detail['available'])}';
        })
        .toList(growable: false);
  }
}
