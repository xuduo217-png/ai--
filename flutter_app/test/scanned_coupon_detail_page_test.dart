import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/coupons/domain/coupon_models.dart';
import 'package:pet_hospital_flutter/features/coupons/presentation/pages/scanned_coupon_detail_page.dart';

void main() {
  testWidgets('扫码优惠券详情展示领取状态并在领取后刷新', (tester) async {
    final gateway = _ScanCouponGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: ScannedCouponDetailPage(
          gateway: gateway,
          claimCode: 'CLAIM_1001',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('扫码立减券'), findsOneWidget);
    expect(find.text('¥30'), findsOneWidget);
    expect(find.text('立即领取'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('scanned-coupon-primary-action')),
    );
    await tester.pumpAndSettle();

    expect(gateway.claimedCodes, ['CLAIM_1001']);
    expect(gateway.loadCount, 2);
    expect(find.text('已领取'), findsOneWidget);
    expect(find.text('查看我的优惠券'), findsOneWidget);
  });

  testWidgets('扫码优惠券加载失败显示真实错误并允许重试', (tester) async {
    final gateway = _ScanCouponGateway(failFirstLoad: true);

    await tester.pumpWidget(
      MaterialApp(
        home: ScannedCouponDetailPage(
          gateway: gateway,
          claimCode: 'CLAIM_1001',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('优惠券不存在'), findsOneWidget);
    expect(find.byKey(const ValueKey('scanned-coupon-retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scanned-coupon-retry')));
    await tester.pumpAndSettle();

    expect(find.text('扫码立减券'), findsOneWidget);
    expect(gateway.loadCount, 2);
  });
}

class _ScanCouponGateway implements CouponScanGateway {
  _ScanCouponGateway({this.failFirstLoad = false});

  final bool failFirstLoad;
  final List<String> claimedCodes = [];
  int loadCount = 0;

  @override
  Future<void> claimByScanCode(String claimCode) async {
    claimedCodes.add(claimCode);
  }

  @override
  Future<CouponScanDetail> loadScanDetail(String claimCode) async {
    loadCount += 1;
    if (failFirstLoad && loadCount == 1) throw Exception('优惠券不存在');
    final claimed = claimedCodes.isNotEmpty;
    return CouponScanDetail(
      claimCode: claimCode,
      claimType: 'SCAN_CODE',
      claimed: claimed,
      canClaim: !claimed,
      unavailableReason: claimed ? '您已领取过该优惠券' : null,
      coupon: CouponRule(
        id: 9,
        name: '扫码立减券',
        type: CouponType.fullReduction,
        scope: CouponScope.all,
        description: '扫码领取后可在商城使用',
        status: 'ACTIVE',
        discountValue: 30,
        minAmount: 199,
        validFrom: DateTime.utc(2026, 3),
        validUntil: DateTime.utc(2026, 3, 31, 23, 59, 59),
        canStack: false,
        isEnabled: true,
      ),
    );
  }
}
