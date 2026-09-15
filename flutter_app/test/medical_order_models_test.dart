import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/medical_orders/domain/medical_order_models.dart';

void main() {
  test('医疗订单状态覆盖五种已知值和未知 fallback', () {
    const cases = <String, MedicalOrderStatus>{
      'PENDING': MedicalOrderStatus.pending,
      'PAID': MedicalOrderStatus.paid,
      'REFUNDED': MedicalOrderStatus.refunded,
      'EXPIRED': MedicalOrderStatus.expired,
      'CANCELLED': MedicalOrderStatus.cancelled,
    };

    for (final entry in cases.entries) {
      expect(MedicalOrderStatus.fromWire(entry.key), entry.value);
    }
    expect(
      MedicalOrderStatus.fromWire('NEW_STATE'),
      MedicalOrderStatus.unknown,
    );
    expect(MedicalOrderStatus.fromWire(null), MedicalOrderStatus.unknown);
    expect(MedicalOrderStatus.unknown.label, '状态未知');
  });

  test('订单兼容数字字符串、decimal 字符串和空头像', () {
    final order = MedicalServiceOrder.fromJson(
      _orderJson(
        id: '12',
        amount: '39.90',
        doctorAvatar: null,
        servicePrice: '42.50',
      ),
    );

    expect(order.id, 12);
    expect(order.amount, 39.9);
    expect(order.status, MedicalOrderStatus.paid);
    expect(order.doctor.name, '李医生');
    expect(order.doctor.avatarUrl, isNull);
    expect(order.serviceItem.price, 42.5);
    expect(order.createdAt, DateTime.parse('2026-07-25T09:05:00+08:00'));
  });

  test('订单缺少必需关联或非法金额时明确失败', () {
    expect(
      () => MedicalServiceOrder.fromJson({..._orderJson(), 'doctor': null}),
      throwsFormatException,
    );
    expect(
      () => MedicalServiceOrder.fromJson({..._orderJson(), 'amount': 'NaN'}),
      throwsFormatException,
    );
  });

  test('查询参数和 RN 时间格式保持固定', () {
    const query = MedicalOrderQuery(page: 2, pageSize: 20);

    expect(query.toQueryParameters(), {'page': 2, 'pageSize': 20});
    expect(formatMedicalOrderTime(DateTime(2026, 7, 25, 9, 5)), '07-25 09:05');
  });
}

Map<String, Object?> _orderJson({
  Object id = 1,
  Object amount = 39.9,
  Object? doctorAvatar = '/doctor.png',
  Object servicePrice = 42.5,
}) {
  return {
    'id': id,
    'orderNo': 'CHAT202607250001',
    'userId': '7',
    'doctorId': 3,
    'serviceItemId': '5',
    'durationMinutes': 30,
    'amount': amount,
    'status': 'PAID',
    'paidAt': null,
    'serviceStartAt': null,
    'serviceEndAt': null,
    'expiredAt': null,
    'remark': null,
    'createdAt': '2026-07-25T09:05:00+08:00',
    'updatedAt': '2026-07-25T09:06:00+08:00',
    'doctor': {'id': 3, 'name': '李医生', 'avatar': doctorAvatar},
    'serviceItem': {
      'id': 5,
      'name': '图文咨询',
      'duration': 30,
      'price': servicePrice,
    },
  };
}
