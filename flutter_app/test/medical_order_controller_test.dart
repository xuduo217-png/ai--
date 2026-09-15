import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/medical_orders/domain/medical_order_models.dart';
import 'package:pet_hospital_flutter/features/medical_orders/presentation/medical_order_controller.dart';

void main() {
  test('首屏成功和失败均结束 loading，并保留明确状态', () async {
    final successGateway = _MedicalOrderGateway()
      ..responses.add(Future.value(_page(ids: const [1], totalPages: 1)));
    final success = MedicalOrderController(successGateway);
    await success.load();

    expect(success.orders.map((order) => order.id), [1]);
    expect(success.isInitialLoading, isFalse);
    expect(success.errorMessage, isNull);

    final failedGateway = _MedicalOrderGateway()
      ..responses.add(Future.error(StateError('offline')));
    final failed = MedicalOrderController(failedGateway);
    await failed.load();

    expect(failed.orders, isEmpty);
    expect(failed.isInitialLoading, isFalse);
    expect(failed.errorMessage, isNotNull);
  });

  test('重复刷新折叠为一个请求，失败保留最后有效列表', () async {
    final refresh = Completer<MedicalOrderPage>();
    final gateway = _MedicalOrderGateway()
      ..responses.add(Future.value(_page(ids: const [1], totalPages: 1)))
      ..responses.add(refresh.future);
    final controller = MedicalOrderController(gateway);
    await controller.load();

    final first = controller.refresh();
    final duplicate = controller.refresh();
    expect(gateway.queries, hasLength(2));
    refresh.completeError(StateError('refresh failed'));
    await Future.wait([first, duplicate]);

    expect(controller.orders.map((order) => order.id), [1]);
    expect(controller.errorMessage, isNotNull);
    expect(controller.isRefreshing, isFalse);
  });

  test('加载更多防重复，失败保留当前页且可重试', () async {
    final gateway = _MedicalOrderGateway()
      ..responses.add(Future.value(_page(ids: const [1], totalPages: 2)));
    final controller = MedicalOrderController(gateway);
    await controller.load();

    final failedPage = Completer<MedicalOrderPage>();
    gateway.responses.add(failedPage.future);
    final first = controller.loadMore();
    final duplicate = controller.loadMore();
    expect(gateway.queries.where((query) => query.page == 2), hasLength(1));
    failedPage.completeError(StateError('page failed'));
    await Future.wait([first, duplicate]);

    expect(controller.orders.map((order) => order.id), [1]);
    expect(controller.hasMore, isTrue);
    expect(controller.loadMoreError, isNotNull);

    gateway.responses.add(
      Future.value(_page(ids: const [2], page: 2, totalPages: 2)),
    );
    await controller.loadMore();

    expect(controller.orders.map((order) => order.id), [1, 2]);
    expect(controller.hasMore, isFalse);
    expect(controller.loadMoreError, isNull);
  });

  test('刷新完成后忽略较晚返回的旧分页响应', () async {
    final stalePage = Completer<MedicalOrderPage>();
    final gateway = _MedicalOrderGateway()
      ..responses.add(Future.value(_page(ids: const [1], totalPages: 2)))
      ..responses.add(stalePage.future)
      ..responses.add(Future.value(_page(ids: const [9], totalPages: 1)));
    final controller = MedicalOrderController(gateway);
    await controller.load();

    final loadMore = controller.loadMore();
    await controller.refresh();

    expect(controller.isLoadingMore, isFalse);
    stalePage.complete(_page(ids: const [2], page: 2, totalPages: 2));
    await loadMore;

    expect(controller.orders.map((order) => order.id), [9]);
    expect(controller.page, 1);
    expect(controller.hasMore, isFalse);
  });

  test('刷新后可立即发起新分页，不受未返回的旧分页阻塞', () async {
    final stalePage = Completer<MedicalOrderPage>();
    final freshPage = Completer<MedicalOrderPage>();
    final gateway = _MedicalOrderGateway()
      ..responses.add(Future.value(_page(ids: const [1], totalPages: 2)))
      ..responses.add(stalePage.future)
      ..responses.add(Future.value(_page(ids: const [9], totalPages: 2)))
      ..responses.add(freshPage.future);
    final controller = MedicalOrderController(gateway);
    await controller.load();

    final staleLoadMore = controller.loadMore();
    await controller.refresh();
    final freshLoadMore = controller.loadMore();

    expect(gateway.queries.map((query) => query.page), [1, 2, 1, 2]);
    freshPage.complete(_page(ids: const [10], page: 2, totalPages: 2));
    await freshLoadMore;
    stalePage.complete(_page(ids: const [2], page: 2, totalPages: 2));
    await staleLoadMore;

    expect(controller.orders.map((order) => order.id), [9, 10]);
    expect(controller.isLoadingMore, isFalse);
  });
}

MedicalOrderPage _page({
  required List<int> ids,
  int page = 1,
  required int totalPages,
}) {
  return MedicalOrderPage(
    items: ids.map(_order).toList(growable: false),
    total: totalPages * 20,
    page: page,
    pageSize: 20,
    totalPages: totalPages,
  );
}

MedicalServiceOrder _order(int id) {
  return MedicalServiceOrder(
    id: id,
    orderNo: 'CHAT$id',
    userId: 7,
    doctorId: 3,
    serviceItemId: 5,
    durationMinutes: 30,
    amount: 39.9,
    status: MedicalOrderStatus.paid,
    createdAt: DateTime(2026, 7, 25, 9, 5),
    updatedAt: DateTime(2026, 7, 25, 9, 6),
    doctor: const MedicalOrderDoctor(id: 3, name: '李医生'),
    serviceItem: const MedicalOrderServiceItem(
      id: 5,
      name: '图文咨询',
      durationMinutes: 30,
      price: 42.5,
    ),
  );
}

class _MedicalOrderGateway implements MedicalOrderGateway {
  final List<Future<MedicalOrderPage>> responses = [];
  final List<MedicalOrderQuery> queries = [];

  @override
  Future<MedicalOrderPage> loadOrders([
    MedicalOrderQuery query = const MedicalOrderQuery(),
  ]) {
    queries.add(query);
    return responses.removeAt(0);
  }
}
