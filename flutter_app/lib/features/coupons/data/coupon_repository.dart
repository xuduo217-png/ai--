import '../../../core/network/api_client.dart';
import '../domain/coupon_models.dart';

class CouponRepository implements CouponGateway, CouponScanGateway {
  CouponRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<UserCoupon>> loadCoupons(UserCouponStatus status) async {
    final wireStatus = status.wireValue;
    if (wireStatus == null) {
      throw ArgumentError.value(
        status,
        'status',
        'Unknown status is not queryable.',
      );
    }
    final payload = await _apiClient.get(
      '/shop/coupons/my',
      authenticated: true,
      queryParameters: {'status': wireStatus},
    );
    final coupons = _unwrapNestedData(payload);
    if (coupons is! List) {
      throw const FormatException('Coupon list must be an array.');
    }
    return coupons
        .map((item) => UserCoupon.fromJson(_requiredMap(item, 'coupon item')))
        .toList(growable: false);
  }

  @override
  Future<CouponCounts> loadCounts() async {
    final payload = await _apiClient.get(
      '/shop/coupons/my/count',
      authenticated: true,
    );
    return CouponCounts.fromJson(
      _requiredMap(_unwrapNestedData(payload), 'coupon counts'),
    );
  }

  @override
  Future<CouponScanDetail> loadScanDetail(String claimCode) async {
    final normalizedCode = claimCode.trim();
    if (normalizedCode.isEmpty) {
      throw ArgumentError.value(claimCode, 'claimCode', '领取码不能为空');
    }
    final payload = await _apiClient.get(
      '/shop/coupons/scan/${Uri.encodeComponent(normalizedCode)}',
      authenticated: true,
    );
    return CouponScanDetail.fromJson(
      _requiredMap(_unwrapNestedData(payload), 'coupon scan detail'),
    );
  }

  @override
  Future<void> claimByScanCode(String claimCode) async {
    final normalizedCode = claimCode.trim();
    if (normalizedCode.isEmpty) {
      throw ArgumentError.value(claimCode, 'claimCode', '领取码不能为空');
    }
    await _apiClient.post(
      '/shop/coupons/claim',
      body: {'claimCode': normalizedCode},
      authenticated: true,
    );
  }
}

Object? _unwrapNestedData(Object? value) {
  var current = value;
  for (var depth = 0; depth < 4; depth += 1) {
    if (current is! Map || !current.containsKey('data')) return current;
    current = current['data'];
  }
  return current;
}

Map<String, Object?> _requiredMap(Object? value, String label) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('$label must be an object.');
}
