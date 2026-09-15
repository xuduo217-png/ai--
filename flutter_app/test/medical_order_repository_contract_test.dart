import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/medical_orders/data/medical_order_repository.dart';
import 'package:pet_hospital_flutter/features/medical_orders/domain/medical_order_models.dart';

void main() {
  test('医疗订单固定使用 GET /chat/orders、page/pageSize 和鉴权', () async {
    late http.Request captured;
    final repository = MedicalOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          captured = request;
          return _ok({
            'data': [_orderJson(id: '12', amount: '39.90')],
            'total': '21',
            'page': '2',
            'pageSize': 20,
            'totalPages': '2',
          });
        }),
        tokenProvider: () async => 'medical-token',
      ),
    );

    final page = await repository.loadOrders(
      const MedicalOrderQuery(page: 2, pageSize: 20),
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/chat/orders');
    expect(captured.url.queryParameters, {'page': '2', 'pageSize': '20'});
    expect(captured.headers['authorization'], 'Bearer medical-token');
    expect(page.items.single.id, 12);
    expect(page.items.single.amount, 39.9);
    expect(page.total, 21);
    expect(page.page, 2);
    expect(page.pageSize, 20);
    expect(page.totalPages, 2);
    expect(page.hasMore, isFalse);
  });

  test('空列表允许 totalPages 为 0', () async {
    final repository = _repositoryFor({
      'data': <Object?>[],
      'total': 0,
      'page': 1,
      'pageSize': 20,
      'totalPages': 0,
    });

    final page = await repository.loadOrders();

    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('列表或分页字段形状漂移时抛出 FormatException', () async {
    final badList = _repositoryFor({
      'data': {'id': 1},
      'total': 1,
      'page': 1,
      'pageSize': 20,
      'totalPages': 1,
    });
    final badPagination = _repositoryFor({
      'data': <Object?>[],
      'total': -1,
      'page': 0,
      'pageSize': 0,
      'totalPages': -1,
    });

    await expectLater(badList.loadOrders(), throwsFormatException);
    await expectLater(badPagination.loadOrders(), throwsFormatException);
  });
}

MedicalOrderRepository _repositoryFor(Map<String, Object?> data) {
  return MedicalOrderRepository(
    apiClient: ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => _ok(data)),
      tokenProvider: () async => 'medical-token',
    ),
  );
}

http.Response _ok(Object? data) {
  return http.Response(
    jsonEncode({'code': 0, 'data': data, 'message': 'Success'}),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, Object?> _orderJson({Object id = 1, Object amount = 39.9}) {
  return {
    'id': id,
    'orderNo': 'CHAT202607250001',
    'userId': 7,
    'doctorId': 3,
    'serviceItemId': 5,
    'durationMinutes': 30,
    'amount': amount,
    'status': 'PAID',
    'createdAt': '2026-07-25T09:05:00+08:00',
    'updatedAt': '2026-07-25T09:06:00+08:00',
    'doctor': {'id': 3, 'name': '李医生', 'avatar': null},
    'serviceItem': {'id': 5, 'name': '图文咨询', 'duration': 30, 'price': '42.50'},
  };
}
