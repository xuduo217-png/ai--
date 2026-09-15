import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/coupons/domain/coupon_models.dart';
import 'package:pet_hospital_flutter/features/coupons/presentation/coupon_center_controller.dart';

void main() {
  test('首屏并发加载列表与统计，并按服务端实际状态去重筛选', () async {
    final gateway = _CouponGateway()
      ..listResponses.add(
        Future.value([
          _coupon(1, UserCouponStatus.available),
          _coupon(1, UserCouponStatus.available),
          _coupon(2, UserCouponStatus.expired),
        ]),
      )
      ..countResponses.add(
        Future.value(const CouponCounts(available: 1, used: 0, expired: 1)),
      );
    final controller = CouponCenterController(gateway);

    await controller.load();

    expect(controller.coupons.map((coupon) => coupon.id), [1]);
    expect(controller.counts?.expired, 1);
    expect(controller.isInitialLoading, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('快速切换状态忽略较晚返回的旧筛选响应', () async {
    final used = Completer<List<UserCoupon>>();
    final gateway = _CouponGateway()
      ..listResponses.add(
        Future.value([_coupon(1, UserCouponStatus.available)]),
      )
      ..listResponses.add(used.future)
      ..listResponses.add(Future.value([_coupon(3, UserCouponStatus.expired)]))
      ..countResponses.add(
        Future.value(const CouponCounts(available: 1, used: 1, expired: 1)),
      );
    final controller = CouponCenterController(gateway);
    await controller.load();

    final usedLoad = controller.selectStatus(UserCouponStatus.used);
    final expiredLoad = controller.selectStatus(UserCouponStatus.expired);
    await expiredLoad;
    used.complete([_coupon(2, UserCouponStatus.used)]);
    await usedLoad;

    expect(controller.selectedStatus, UserCouponStatus.expired);
    expect(controller.coupons.map((coupon) => coupon.id), [3]);
    expect(controller.isLoading, isFalse);
  });

  test('首屏未完成时切换筛选会补拉统计并忽略旧统计', () async {
    final initialList = Completer<List<UserCoupon>>();
    final initialCounts = Completer<CouponCounts>();
    final gateway = _CouponGateway()
      ..listResponses.add(initialList.future)
      ..listResponses.add(Future.value([_coupon(2, UserCouponStatus.used)]))
      ..countResponses.add(initialCounts.future)
      ..countResponses.add(
        Future.value(const CouponCounts(available: 4, used: 2, expired: 1)),
      );
    final controller = CouponCenterController(gateway);

    final initialLoad = controller.load();
    await controller.selectStatus(UserCouponStatus.used);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.countCalls, 2);
    expect(controller.counts?.used, 2);
    initialList.complete([_coupon(1, UserCouponStatus.available)]);
    initialCounts.complete(
      const CouponCounts(available: 99, used: 99, expired: 99),
    );
    await initialLoad;

    expect(controller.selectedStatus, UserCouponStatus.used);
    expect(controller.coupons.map((coupon) => coupon.id), [2]);
    expect(controller.counts?.used, 2);
  });

  test('刷新列表失败保留内容，统计仍可独立成功', () async {
    final failedList = Completer<List<UserCoupon>>();
    final gateway = _CouponGateway()
      ..listResponses.add(
        Future.value([_coupon(1, UserCouponStatus.available)]),
      )
      ..countResponses.add(
        Future.value(const CouponCounts(available: 1, used: 0, expired: 0)),
      );
    final controller = CouponCenterController(gateway);
    await controller.load();

    gateway.listResponses.add(failedList.future);
    gateway.countResponses.add(
      Future.value(const CouponCounts(available: 2, used: 1, expired: 0)),
    );
    final refresh = controller.refresh();
    failedList.completeError(StateError('offline'));
    await refresh;

    expect(controller.coupons.map((coupon) => coupon.id), [1]);
    expect(controller.errorMessage, isNotNull);
    expect(controller.counts?.available, 2);
    expect(controller.isRefreshing, isFalse);
  });

  test('统计刷新失败保留最后有效统计且不覆盖成功列表', () async {
    final failedCounts = Completer<CouponCounts>();
    final gateway = _CouponGateway()
      ..listResponses.add(
        Future.value([_coupon(1, UserCouponStatus.available)]),
      )
      ..countResponses.add(
        Future.value(const CouponCounts(available: 1, used: 0, expired: 0)),
      );
    final controller = CouponCenterController(gateway);
    await controller.load();

    gateway.listResponses.add(
      Future.value([_coupon(2, UserCouponStatus.available)]),
    );
    gateway.countResponses.add(failedCounts.future);
    final refresh = controller.refresh();
    failedCounts.completeError(StateError('count failed'));
    await refresh;

    expect(controller.coupons.map((coupon) => coupon.id), [2]);
    expect(controller.counts?.available, 1);
    expect(controller.countError, isNotNull);
    expect(controller.errorMessage, isNull);
  });

  test('重复刷新折叠请求，dispose 后忽略迟到结果', () async {
    final list = Completer<List<UserCoupon>>();
    final counts = Completer<CouponCounts>();
    final gateway = _CouponGateway()
      ..listResponses.add(list.future)
      ..countResponses.add(counts.future);
    final controller = CouponCenterController(gateway);

    final first = controller.refresh();
    final duplicate = controller.refresh();
    expect(gateway.statuses, [UserCouponStatus.available]);
    expect(gateway.countCalls, 1);

    controller.dispose();
    list.complete([_coupon(9, UserCouponStatus.available)]);
    counts.complete(const CouponCounts(available: 1, used: 0, expired: 0));
    await Future.wait([first, duplicate]);

    expect(controller.coupons, isEmpty);
  });
}

UserCoupon _coupon(int id, UserCouponStatus status) {
  return UserCoupon(
    id: id,
    userId: 7,
    couponId: 10 + id,
    status: status,
    validFrom: DateTime.utc(2026, 7, 1),
    validUntil: DateTime.utc(2026, 7, 31),
    createdAt: DateTime.utc(2026, 6, 25),
    rule: CouponRule(
      id: 10 + id,
      name: '优惠券$id',
      type: CouponType.fullReduction,
      scope: CouponScope.all,
      status: 'ACTIVE',
      discountValue: 20,
      minAmount: 100,
      validFrom: DateTime.utc(2026, 7, 1),
      validUntil: DateTime.utc(2026, 7, 31),
      canStack: false,
      isEnabled: true,
    ),
  );
}

class _CouponGateway implements CouponGateway {
  final List<Future<List<UserCoupon>>> listResponses = [];
  final List<Future<CouponCounts>> countResponses = [];
  final List<UserCouponStatus> statuses = [];
  int countCalls = 0;

  @override
  Future<List<UserCoupon>> loadCoupons(UserCouponStatus status) {
    statuses.add(status);
    return listResponses.removeAt(0);
  }

  @override
  Future<CouponCounts> loadCounts() {
    countCalls += 1;
    return countResponses.removeAt(0);
  }
}
