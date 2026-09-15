import 'dart:convert';

sealed class ScanPayload {
  const ScanPayload();
}

class CouponScanPayload extends ScanPayload {
  const CouponScanPayload(this.claimCode);

  final String claimCode;
}

class ActivityScanPayload extends ScanPayload {
  const ActivityScanPayload(this.activityId);

  final int activityId;
}

class ScanPayloadException implements Exception {
  const ScanPayloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

ScanPayload parseScanPayload(String rawValue) {
  final Object? decoded;
  try {
    decoded = jsonDecode(rawValue);
  } on FormatException {
    throw const ScanPayloadException('二维码内容格式错误');
  }

  if (decoded is! Map) {
    throw const ScanPayloadException('二维码内容格式错误');
  }
  final payload = decoded.map((key, value) => MapEntry('$key', value));
  final type = payload['type'];
  if (type is! String || type.trim().isEmpty) {
    throw const ScanPayloadException('识别失败');
  }

  final value = payload['value'];
  if (value is! String || value.trim().isEmpty) {
    throw ScanPayloadException(type == 'coupons' ? '优惠券二维码无效' : '活动二维码无效');
  }
  final normalizedValue = value.trim();

  return switch (type.trim()) {
    'coupons' => CouponScanPayload(normalizedValue),
    'activities' => ActivityScanPayload(_parseActivityId(normalizedValue)),
    _ => throw const ScanPayloadException('暂不支持该二维码类型'),
  };
}

int _parseActivityId(String value) {
  final activityId = int.tryParse(value);
  if (activityId == null || activityId <= 0) {
    throw const ScanPayloadException('活动二维码无效');
  }
  return activityId;
}
