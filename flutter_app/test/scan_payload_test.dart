import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/scanner/domain/scan_payload.dart';

void main() {
  test('解析 RN 优惠券和活动二维码协议', () {
    final coupon = parseScanPayload(
      '{"type":"coupons","value":" CLAIM_1001 "}',
    );
    final activity = parseScanPayload('{"type":"activities","value":"42"}');

    expect(coupon, isA<CouponScanPayload>());
    expect((coupon as CouponScanPayload).claimCode, 'CLAIM_1001');
    expect(activity, isA<ActivityScanPayload>());
    expect((activity as ActivityScanPayload).activityId, 42);
  });

  test('拒绝非 JSON、未知类型、空领取码和无效活动 ID', () {
    expect(
      () => parseScanPayload('not-json'),
      throwsA(
        isA<ScanPayloadException>().having(
          (error) => error.message,
          'message',
          '二维码内容格式错误',
        ),
      ),
    );
    expect(
      () => parseScanPayload('{"type":"products","value":"1"}'),
      throwsA(
        isA<ScanPayloadException>().having(
          (error) => error.message,
          'message',
          '暂不支持该二维码类型',
        ),
      ),
    );
    expect(
      () => parseScanPayload('{"type":"coupons","value":" "}'),
      throwsA(
        isA<ScanPayloadException>().having(
          (error) => error.message,
          'message',
          '优惠券二维码无效',
        ),
      ),
    );
    expect(
      () => parseScanPayload('{"type":"activities","value":"0"}'),
      throwsA(
        isA<ScanPayloadException>().having(
          (error) => error.message,
          'message',
          '活动二维码无效',
        ),
      ),
    );
  });
}
