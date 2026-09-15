enum MedicalOrderStatus {
  pending('PENDING', '待支付'),
  paid('PAID', '已支付'),
  refunded('REFUNDED', '已退款'),
  expired('EXPIRED', '已过期'),
  cancelled('CANCELLED', '已取消'),
  unknown(null, '状态未知');

  const MedicalOrderStatus(this.wireValue, this.label);

  final String? wireValue;
  final String label;

  static MedicalOrderStatus fromWire(Object? value) {
    final wire = value is String ? value.trim().toUpperCase() : null;
    return MedicalOrderStatus.values.firstWhere(
      (status) => status.wireValue != null && status.wireValue == wire,
      orElse: () => MedicalOrderStatus.unknown,
    );
  }
}

class MedicalOrderDoctor {
  const MedicalOrderDoctor({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory MedicalOrderDoctor.fromJson(Map<String, Object?> json) {
    return MedicalOrderDoctor(
      id: _requiredInt(json['id'], 'doctor.id'),
      name: _requiredString(json['name'], 'doctor.name'),
      avatarUrl: _optionalString(json['avatar'], 'doctor.avatar'),
    );
  }

  final int id;
  final String name;
  final String? avatarUrl;
}

class MedicalOrderServiceItem {
  const MedicalOrderServiceItem({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
  });

  factory MedicalOrderServiceItem.fromJson(Map<String, Object?> json) {
    return MedicalOrderServiceItem(
      id: _requiredInt(json['id'], 'serviceItem.id'),
      name: _requiredString(json['name'], 'serviceItem.name'),
      durationMinutes: _requiredInt(json['duration'], 'serviceItem.duration'),
      price: _requiredDouble(json['price'], 'serviceItem.price'),
    );
  }

  final int id;
  final String name;
  final int durationMinutes;
  final double price;
}

class MedicalServiceOrder {
  const MedicalServiceOrder({
    required this.id,
    required this.orderNo,
    required this.userId,
    required this.doctorId,
    required this.serviceItemId,
    required this.durationMinutes,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.doctor,
    required this.serviceItem,
    this.paidAt,
    this.serviceStartAt,
    this.serviceEndAt,
    this.expiredAt,
    this.remark,
  });

  factory MedicalServiceOrder.fromJson(Map<String, Object?> json) {
    return MedicalServiceOrder(
      id: _requiredInt(json['id'], 'id'),
      orderNo: _requiredString(json['orderNo'], 'orderNo'),
      userId: _requiredInt(json['userId'], 'userId'),
      doctorId: _requiredInt(json['doctorId'], 'doctorId'),
      serviceItemId: _requiredInt(json['serviceItemId'], 'serviceItemId'),
      durationMinutes: _requiredInt(json['durationMinutes'], 'durationMinutes'),
      amount: _requiredDouble(json['amount'], 'amount'),
      status: MedicalOrderStatus.fromWire(json['status']),
      paidAt: _optionalDateTime(json['paidAt'], 'paidAt'),
      serviceStartAt: _optionalDateTime(
        json['serviceStartAt'],
        'serviceStartAt',
      ),
      serviceEndAt: _optionalDateTime(json['serviceEndAt'], 'serviceEndAt'),
      expiredAt: _optionalDateTime(json['expiredAt'], 'expiredAt'),
      remark: _optionalString(json['remark'], 'remark'),
      createdAt: _requiredDateTime(json['createdAt'], 'createdAt'),
      updatedAt: _requiredDateTime(json['updatedAt'], 'updatedAt'),
      doctor: MedicalOrderDoctor.fromJson(_asMap(json['doctor'], 'doctor')),
      serviceItem: MedicalOrderServiceItem.fromJson(
        _asMap(json['serviceItem'], 'serviceItem'),
      ),
    );
  }

  final int id;
  final String orderNo;
  final int userId;
  final int doctorId;
  final int serviceItemId;
  final int durationMinutes;
  final double amount;
  final MedicalOrderStatus status;
  final DateTime? paidAt;
  final DateTime? serviceStartAt;
  final DateTime? serviceEndAt;
  final DateTime? expiredAt;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MedicalOrderDoctor doctor;
  final MedicalOrderServiceItem serviceItem;
}

class MedicalOrderQuery {
  const MedicalOrderQuery({this.page = 1, this.pageSize = 20})
    : assert(page > 0),
      assert(pageSize > 0);

  final int page;
  final int pageSize;

  Map<String, Object?> toQueryParameters() => {
    'page': page,
    'pageSize': pageSize,
  };
}

class MedicalOrderPage {
  const MedicalOrderPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<MedicalServiceOrder> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => totalPages > 0 && page < totalPages;
}

abstract interface class MedicalOrderGateway {
  Future<MedicalOrderPage> loadOrders([
    MedicalOrderQuery query = const MedicalOrderQuery(),
  ]);
}

String formatMedicalOrderTime(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

Map<String, Object?> _asMap(Object? value, String label) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('$label must be an object.');
}

int _requiredInt(Object? value, String label) {
  final parsed = switch (value) {
    final int number => number,
    final num number when number.isFinite && number == number.roundToDouble() =>
      number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null) throw FormatException('$label must be an integer.');
  return parsed;
}

double _requiredDouble(Object? value, String label) {
  final parsed = switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('$label must be a finite number.');
  }
  return parsed;
}

String _requiredString(Object? value, String label) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$label must be a non-empty string.');
}

String? _optionalString(Object? value, String label) {
  if (value == null) return null;
  if (value is! String) throw FormatException('$label must be a string.');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDateTime(Object? value, String label) {
  final parsed = value is String ? DateTime.tryParse(value.trim()) : null;
  if (parsed == null) {
    throw FormatException('$label must be an ISO-8601 date time.');
  }
  return parsed;
}

DateTime? _optionalDateTime(Object? value, String label) {
  if (value == null) return null;
  return _requiredDateTime(value, label);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
