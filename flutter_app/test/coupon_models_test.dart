import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/coupons/domain/coupon_models.dart';

void main() {
  test('用户券解析服务端规则快照、数字字符串和有效期', () {
    final coupon = UserCoupon.fromJson(
      _couponJson(
        type: 'DISCOUNT',
        discountValue: '8.5',
        minAmount: '80',
        minOrderAmount: '100',
      ),
    );

    expect(coupon.id, 41);
    expect(coupon.status, UserCouponStatus.available);
    expect(coupon.rule.type, CouponType.discount);
    expect(coupon.rule.discountValue, 8.5);
    expect(coupon.rule.minAmount, 100);
    expect(coupon.rule.canStack, isFalse);
    expect(coupon.rule.isEnabled, isTrue);
    expect(coupon.validUntil, DateTime.parse('2026-07-31T12:00:00.000Z'));
  });

  test('券面、门槛和有效期文案覆盖满减、折扣、直减与无门槛', () {
    final fullReduction = UserCoupon.fromJson(_couponJson());
    final discount = UserCoupon.fromJson(
      _couponJson(type: 'DISCOUNT', discountValue: 8.5),
    );
    final direct = UserCoupon.fromJson(
      _couponJson(
        type: 'DIRECT_DISCOUNT',
        discountValue: 5,
        minAmount: 0,
        minOrderAmount: 0,
      ),
    );

    expect(formatCouponFaceValue(fullReduction.rule), '¥20');
    expect(formatCouponFaceValue(discount.rule), '8.5折');
    expect(formatCouponFaceValue(direct.rule), '¥5');
    expect(formatCouponCondition(fullReduction.rule), '满100元可用');
    expect(formatCouponCondition(direct.rule), '无门槛');
    expect(formatCouponValidity(fullReduction), '07.01 - 2026.07.31');
  });

  test('客户端保留服务端状态，不根据本地过期边界猜测可用性', () {
    final coupon = UserCoupon.fromJson(
      _couponJson(status: 'AVAILABLE', validUntil: '2020-01-01T00:00:00.000Z'),
    );

    expect(coupon.status, UserCouponStatus.available);
    expect(coupon.validUntil.isBefore(DateTime.now()), isTrue);
  });

  test('未知枚举稳定降级，缺失关键字段明确失败', () {
    final unknown = UserCoupon.fromJson(
      _couponJson(status: 'FUTURE', type: 'FUTURE', scope: 'FUTURE'),
    );
    final invalid = _couponJson()..remove('id');

    expect(unknown.status, UserCouponStatus.unknown);
    expect(unknown.rule.type, CouponType.unknown);
    expect(unknown.rule.scope, CouponScope.unknown);
    expect(() => UserCoupon.fromJson(invalid), throwsFormatException);
  });

  test('优惠券统计拒绝负数并按状态取值', () {
    final counts = CouponCounts.fromJson({
      'available': '3',
      'used': 2,
      'expired': 1,
    });

    expect(counts.forStatus(UserCouponStatus.available), 3);
    expect(counts.forStatus(UserCouponStatus.used), 2);
    expect(counts.forStatus(UserCouponStatus.expired), 1);
    expect(
      () => CouponCounts.fromJson({'available': -1, 'used': 0, 'expired': 0}),
      throwsFormatException,
    );
  });

  test('扫码优惠券详情复用券规则并保留服务端领取状态', () {
    final detail = CouponScanDetail.fromJson({
      'claimCode': 'CLAIM_1001',
      'claimType': 'SCAN_CODE',
      'claimed': false,
      'canClaim': true,
      'unavailableReason': null,
      'coupon': _couponJson()['coupon'],
    });

    expect(detail.claimCode, 'CLAIM_1001');
    expect(detail.claimed, isFalse);
    expect(detail.canClaim, isTrue);
    expect(detail.coupon.name, '夏日优惠券');
    expect(formatCouponRuleValidity(detail.coupon), '2026.07.01 - 2026.07.31');
  });
}

Map<String, Object?> _couponJson({
  String status = 'AVAILABLE',
  String type = 'FULL_REDUCTION',
  String scope = 'ALL',
  Object discountValue = 20,
  Object minAmount = 100,
  Object minOrderAmount = 80,
  String validUntil = '2026-07-31T12:00:00.000Z',
}) => {
  'id': '41',
  'userId': 7,
  'couponId': 11,
  'status': status,
  'validFrom': '2026-07-01T12:00:00.000Z',
  'validUntil': validUntil,
  'expiresAt': validUntil,
  'usedAt': null,
  'orderId': null,
  'createdAt': '2026-06-25T12:00:00.000Z',
  'coupon': {
    'id': 11,
    'name': '夏日优惠券',
    'type': type,
    'scope': scope,
    'description': '测试规则',
    'status': 'ACTIVE',
    'discountValue': discountValue,
    'minAmount': minAmount,
    'minOrderAmount': minOrderAmount,
    'maxDiscount': null,
    'validFrom': '2026-07-01T12:00:00.000Z',
    'validUntil': validUntil,
    'canStack': false,
    'isEnabled': true,
  },
};
