enum UserCouponStatus {
  available('AVAILABLE', '可使用'),
  used('USED', '已使用'),
  expired('EXPIRED', '已过期'),
  unknown(null, '状态未知');

  const UserCouponStatus(this.wireValue, this.label);

  final String? wireValue;
  final String label;

  static UserCouponStatus fromWire(Object? value) {
    final wire = value is String ? value.trim().toUpperCase() : null;
    return UserCouponStatus.values.firstWhere(
      (status) => status.wireValue != null && status.wireValue == wire,
      orElse: () => UserCouponStatus.unknown,
    );
  }
}

enum CouponType {
  fullReduction('FULL_REDUCTION'),
  discount('DISCOUNT'),
  directDiscount('DIRECT_DISCOUNT'),
  unknown(null);

  const CouponType(this.wireValue);

  final String? wireValue;

  static CouponType fromWire(Object? value) {
    final wire = value is String ? value.trim().toUpperCase() : null;
    return CouponType.values.firstWhere(
      (type) => type.wireValue != null && type.wireValue == wire,
      orElse: () => CouponType.unknown,
    );
  }
}

enum CouponScope {
  all('ALL', '全场通用'),
  specific('SPECIFIC', '指定商品'),
  unknown(null, '适用范围未知');

  const CouponScope(this.wireValue, this.label);

  final String? wireValue;
  final String label;

  static CouponScope fromWire(Object? value) {
    final wire = value is String ? value.trim().toUpperCase() : null;
    return CouponScope.values.firstWhere(
      (scope) => scope.wireValue != null && scope.wireValue == wire,
      orElse: () => CouponScope.unknown,
    );
  }
}

class CouponRule {
  const CouponRule({
    required this.id,
    required this.name,
    required this.type,
    required this.scope,
    required this.status,
    required this.discountValue,
    required this.minAmount,
    required this.validFrom,
    required this.validUntil,
    required this.canStack,
    required this.isEnabled,
    this.description,
    this.maxDiscount,
  });

  factory CouponRule.fromJson(Map<String, Object?> json) {
    final minAmount = _requiredDouble(json['minAmount'], 'coupon.minAmount');
    final minOrderAmount = _optionalDouble(
      json['minOrderAmount'],
      'coupon.minOrderAmount',
    );
    return CouponRule(
      id: _requiredPositiveInt(json['id'], 'coupon.id'),
      name: _requiredString(json['name'], 'coupon.name'),
      type: CouponType.fromWire(json['type']),
      scope: CouponScope.fromWire(json['scope']),
      description: _optionalString(json['description'], 'coupon.description'),
      status: _requiredString(json['status'], 'coupon.status'),
      discountValue: _requiredNonNegativeDouble(
        json['discountValue'] ?? json['discount'],
        'coupon.discountValue',
      ),
      minAmount: minOrderAmount == null
          ? minAmount
          : _max(minAmount, minOrderAmount),
      maxDiscount: _optionalNonNegativeDouble(
        json['maxDiscount'],
        'coupon.maxDiscount',
      ),
      validFrom: _requiredDateTime(json['validFrom'], 'coupon.validFrom'),
      validUntil: _requiredDateTime(
        json['validUntil'] ?? json['validAt'],
        'coupon.validUntil',
      ),
      canStack: _requiredBool(json['canStack'], 'coupon.canStack'),
      isEnabled: _requiredBool(json['isEnabled'], 'coupon.isEnabled'),
    );
  }

  final int id;
  final String name;
  final CouponType type;
  final CouponScope scope;
  final String? description;
  final String status;
  final double discountValue;
  final double minAmount;
  final double? maxDiscount;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool canStack;
  final bool isEnabled;
}

class UserCoupon {
  const UserCoupon({
    required this.id,
    required this.userId,
    required this.couponId,
    required this.status,
    required this.validFrom,
    required this.validUntil,
    required this.createdAt,
    required this.rule,
    this.usedAt,
    this.orderId,
  });

  factory UserCoupon.fromJson(Map<String, Object?> json) {
    return UserCoupon(
      id: _requiredPositiveInt(json['id'], 'id'),
      userId: _requiredPositiveInt(json['userId'], 'userId'),
      couponId: _requiredPositiveInt(json['couponId'], 'couponId'),
      status: UserCouponStatus.fromWire(json['status']),
      validFrom: _requiredDateTime(json['validFrom'], 'validFrom'),
      validUntil: _requiredDateTime(
        json['validUntil'] ?? json['expiresAt'] ?? json['expiredAt'],
        'validUntil',
      ),
      usedAt: _optionalDateTime(json['usedAt'], 'usedAt'),
      orderId: _optionalPositiveInt(json['orderId'], 'orderId'),
      createdAt: _requiredDateTime(json['createdAt'], 'createdAt'),
      rule: CouponRule.fromJson(_requiredMap(json['coupon'], 'coupon')),
    );
  }

  final int id;
  final int userId;
  final int couponId;
  final UserCouponStatus status;
  final DateTime validFrom;
  final DateTime validUntil;
  final DateTime? usedAt;
  final int? orderId;
  final DateTime createdAt;
  final CouponRule rule;
}

class CouponCounts {
  const CouponCounts({
    required this.available,
    required this.used,
    required this.expired,
  });

  factory CouponCounts.fromJson(Map<String, Object?> json) {
    return CouponCounts(
      available: _requiredNonNegativeInt(json['available'], 'available'),
      used: _requiredNonNegativeInt(json['used'], 'used'),
      expired: _requiredNonNegativeInt(json['expired'], 'expired'),
    );
  }

  final int available;
  final int used;
  final int expired;

  int forStatus(UserCouponStatus status) => switch (status) {
    UserCouponStatus.available => available,
    UserCouponStatus.used => used,
    UserCouponStatus.expired => expired,
    UserCouponStatus.unknown => 0,
  };
}

class CouponScanDetail {
  const CouponScanDetail({
    required this.claimCode,
    required this.claimType,
    required this.claimed,
    required this.canClaim,
    required this.coupon,
    this.unavailableReason,
  });

  factory CouponScanDetail.fromJson(Map<String, Object?> json) {
    return CouponScanDetail(
      claimCode: _requiredString(json['claimCode'], 'claimCode'),
      claimType: _requiredString(json['claimType'], 'claimType'),
      claimed: _requiredBool(json['claimed'], 'claimed'),
      canClaim: _requiredBool(json['canClaim'], 'canClaim'),
      unavailableReason: _optionalString(
        json['unavailableReason'],
        'unavailableReason',
      ),
      coupon: CouponRule.fromJson(_requiredMap(json['coupon'], 'coupon')),
    );
  }

  final String claimCode;
  final String claimType;
  final bool claimed;
  final bool canClaim;
  final String? unavailableReason;
  final CouponRule coupon;
}

abstract interface class CouponGateway {
  Future<List<UserCoupon>> loadCoupons(UserCouponStatus status);

  Future<CouponCounts> loadCounts();
}

abstract interface class CouponScanGateway {
  Future<CouponScanDetail> loadScanDetail(String claimCode);

  Future<void> claimByScanCode(String claimCode);
}

String formatCouponFaceValue(CouponRule rule) {
  final value = _compactNumber(rule.discountValue);
  return rule.type == CouponType.discount ? '$value折' : '¥$value';
}

String formatCouponCondition(CouponRule rule) {
  if (rule.minAmount <= 0) return '无门槛';
  return '满${_compactNumber(rule.minAmount)}元可用';
}

String formatCouponValidity(UserCoupon coupon) {
  final from = coupon.validFrom.toLocal();
  final until = coupon.validUntil.toLocal();
  return '${_twoDigits(from.month)}.${_twoDigits(from.day)} - '
      '${until.year}.${_twoDigits(until.month)}.${_twoDigits(until.day)}';
}

String formatCouponRuleValidity(CouponRule rule) {
  final from = rule.validFrom.toLocal();
  final until = rule.validUntil.toLocal();
  return '${from.year}.${_twoDigits(from.month)}.${_twoDigits(from.day)} - '
      '${until.year}.${_twoDigits(until.month)}.${_twoDigits(until.day)}';
}

Map<String, Object?> _requiredMap(Object? value, String label) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('$label must be an object.');
}

int _requiredPositiveInt(Object? value, String label) {
  final parsed = _integer(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('$label must be a positive integer.');
  }
  return parsed;
}

int _requiredNonNegativeInt(Object? value, String label) {
  final parsed = _integer(value);
  if (parsed == null || parsed < 0) {
    throw FormatException('$label must be a non-negative integer.');
  }
  return parsed;
}

int? _optionalPositiveInt(Object? value, String label) {
  if (value == null) return null;
  return _requiredPositiveInt(value, label);
}

int? _integer(Object? value) {
  return switch (value) {
    final int number => number,
    final num number when number.isFinite && number == number.roundToDouble() =>
      number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };
}

double _requiredDouble(Object? value, String label) {
  final parsed = _double(value);
  if (parsed == null) {
    throw FormatException('$label must be a finite number.');
  }
  return parsed;
}

double _requiredNonNegativeDouble(Object? value, String label) {
  final parsed = _requiredDouble(value, label);
  if (parsed < 0) {
    throw FormatException('$label must be non-negative.');
  }
  return parsed;
}

double? _optionalDouble(Object? value, String label) {
  if (value == null) return null;
  return _requiredDouble(value, label);
}

double? _optionalNonNegativeDouble(Object? value, String label) {
  if (value == null) return null;
  return _requiredNonNegativeDouble(value, label);
}

double? _double(Object? value) {
  final parsed = switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text.trim()),
    _ => null,
  };
  return parsed == null || !parsed.isFinite ? null : parsed;
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

bool _requiredBool(Object? value, String label) {
  if (value is bool) return value;
  throw FormatException('$label must be a boolean.');
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

double _max(double left, double right) => left > right ? left : right;

String _compactNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
