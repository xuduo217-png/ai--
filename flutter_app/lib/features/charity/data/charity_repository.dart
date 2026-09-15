import '../../../core/network/api_client.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../domain/charity_models.dart';

class CharityRepository implements CharityGateway {
  const CharityRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CharityPage> loadCharities({
    required bool authenticated,
    CharityStatus? status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get(
      '/charity',
      authenticated: authenticated,
      queryParameters: {
        'status': status?.wireValue,
        'keyword': keyword.trim().isEmpty ? null : keyword.trim(),
        'page': page,
        'pageSize': pageSize,
      },
    );
    return _charityPage(response, fallbackPage: page, fallbackSize: pageSize);
  }

  @override
  Future<CharityActivity> loadCharityDetail(
    int charityId, {
    required bool authenticated,
  }) async {
    return _charity(
      _asMap(
        await _apiClient.get(
          '/charity/$charityId',
          authenticated: authenticated,
        ),
        'charity detail',
      ),
    );
  }

  @override
  Future<CharityRecordPage> loadCharityRecords(
    int charityId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get(
      '/charity/$charityId/records',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return _recordPage(response, fallbackPage: page, fallbackSize: pageSize);
  }

  @override
  Future<CharityRecordPage> loadCharityDonations(
    int charityId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get(
      '/charity/$charityId/donations',
      authenticated: authenticated,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return _recordPage(response, fallbackPage: page, fallbackSize: pageSize);
  }

  @override
  Future<CharityCheckInResult> checkInCharity(int charityId) async {
    final json = _asMap(
      await _apiClient.post(
        '/charity/$charityId/checkin',
        authenticated: true,
        allowBusinessFailure: true,
      ),
      'charity check-in',
    );
    return CharityCheckInResult(
      success: _bool(json['success']),
      alreadyChecked: _bool(json['alreadyChecked']),
      totalCheckIns: _int(json['totalCheckIns']),
      message: _string(json['message'], fallback: '签到成功'),
      isCompleted: _bool(json['isCompleted']),
    );
  }

  @override
  Future<double> loadCharityWalletBalance() async {
    final envelope = _asMap(
      await _apiClient.get('/shop/wallet/balance'),
      'charity wallet balance',
    );
    final json = envelope.containsKey('data')
        ? _asMap(envelope['data'], 'charity wallet balance data')
        : envelope;
    final balance = _double(json['balance'], fallback: double.nan);
    if (!balance.isFinite) {
      throw const FormatException('Invalid charity wallet balance response');
    }
    return balance;
  }

  @override
  Future<CharityDonationResult> donateCharity(
    int charityId, {
    required double amount,
  }) async {
    final json = _asMap(
      await _apiClient.post(
        '/charity/$charityId/donate',
        authenticated: true,
        body: {'amount': amount, 'paymentMethod': 'balance'},
      ),
      'charity donation',
    );
    return CharityDonationResult(
      message: _string(json['message'], fallback: '捐款成功'),
      donationAmount: _double(json['donationAmount']),
      donatedAmount: _double(json['donatedAmount']),
      balanceBefore: _double(json['balanceBefore']),
      balanceAfter: _double(json['balanceAfter']),
    );
  }

  @override
  Future<CharityDonationPayment> createCharityDonationPayment(
    int charityId, {
    required double amount,
    required String idempotencyKey,
  }) async {
    final json = _asMap(
      await _apiClient.post(
        '/charity/$charityId/donations/payment',
        authenticated: true,
        additionalHeaders: {'idempotency-key': idempotencyKey},
        body: {'amount': amount},
      ),
      'charity donation payment',
    );
    final paymentParams = _asMap(
      json['paymentParams'],
      'charity donation payment params',
    );
    final paymentNo = _string(json['paymentNo']);
    final orderString = _string(paymentParams['alipayOrderString']);
    if (paymentNo.isEmpty || orderString.isEmpty) {
      throw const FormatException('Invalid charity donation payment response');
    }
    return CharityDonationPayment(
      paymentNo: paymentNo,
      amount: _double(json['amount']),
      alipayOrderString: orderString,
    );
  }

  @override
  Future<CharityDonationPaymentStatus> loadCharityDonationPaymentStatus(
    String paymentNo,
  ) async {
    final json = _asMap(
      await _apiClient.get('/payment/query/$paymentNo'),
      'charity donation payment status',
    );
    return CharityDonationPaymentStatus.fromWire(json['status']);
  }

  CharityPage _charityPage(
    Object? response, {
    required int fallbackPage,
    required int fallbackSize,
  }) {
    final root = _asMap(response, 'charity page');
    final items = _asList(root['data'])
        .map((item) => _charity(_asMap(item, 'charity item')))
        .where((item) => item.id > 0)
        .toList(growable: false);
    final pagination = _pagination(root);
    return CharityPage(
      items: items,
      total: _int(pagination['total'], fallback: items.length),
      page: _int(pagination['page'], fallback: fallbackPage),
      pageSize: _int(
        pagination['pageSize'] ?? pagination['limit'],
        fallback: fallbackSize,
      ),
      totalPages: _int(
        pagination['totalPages'],
        fallback: items.isEmpty ? 0 : 1,
      ),
    );
  }

  CharityRecordPage _recordPage(
    Object? response, {
    required int fallbackPage,
    required int fallbackSize,
  }) {
    final root = _asMap(response, 'charity record page');
    final items = _asList(root['data'])
        .map((item) => _record(_asMap(item, 'charity record')))
        .where((item) => item.id > 0)
        .toList(growable: false);
    final pagination = _pagination(root);
    return CharityRecordPage(
      items: items,
      total: _int(pagination['total'], fallback: items.length),
      page: _int(pagination['page'], fallback: fallbackPage),
      pageSize: _int(
        pagination['pageSize'] ?? pagination['limit'],
        fallback: fallbackSize,
      ),
      totalPages: _int(
        pagination['totalPages'],
        fallback: items.isEmpty ? 0 : 1,
      ),
    );
  }

  CharityActivity _charity(Map<String, Object?> json) {
    return CharityActivity(
      id: _int(json['id']),
      title: _string(json['title']),
      description: _string(json['description']),
      details: _string(json['details']),
      coverImageUrl: resolveAssetUrl(
        _string(json['coverImage']),
        assetBaseUrl: _apiClient.baseUrl,
      ),
      startTime: _dateTime(json['startTime']),
      endTime: _dateTime(json['endTime']),
      isMallAutoDonation: _bool(json['isMallAutoDonation']),
      donationRate: _double(json['donationRate']),
      isPinned: _bool(json['isPinned']),
      targetCheckIns: _int(json['targetCheckIns']),
      completedCheckIns: _int(json['completedCheckIns']),
      donatedAmount: _double(json['donatedAmount']),
      participantType: CharityParticipantType.fromWire(json['participantType']),
      status: CharityStatus.fromWire(json['status']),
      hasCheckedToday: _bool(json['hasCheckedToday']),
    );
  }

  CharityRecord _record(Map<String, Object?> json) {
    return CharityRecord(
      id: _int(json['id']),
      charityId: _int(json['charityId']),
      userId: _int(json['userId']),
      checkInDate: _nullableString(json['checkInDate']),
      checkInTime:
          _dateTime(json['checkInTime']) ??
          _dateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      donationAmount: _double(json['donationAmount']),
      donationSource: _string(json['donationSource'], fallback: 'manual'),
      donationEntryType: _string(json['donationEntryType'], fallback: 'credit'),
      orderId: _nullableInt(json['orderId']),
      orderNo: _nullableString(json['orderNo']),
      donationBaseAmount: _nullableDouble(json['donationBaseAmount']),
      donationRate: _nullableDouble(json['donationRate']),
      userName: _string(json['userName'], fallback: '爱心人士'),
      userAvatarUrl: resolveAssetUrl(
        _string(json['userAvatar']),
        assetBaseUrl: _apiClient.baseUrl,
      ),
    );
  }
}

Map<String, Object?> _pagination(Map<String, Object?> root) {
  final value = root['pagination'];
  return value is Map ? _asMap(value, 'charity pagination') : root;
}

Map<String, Object?> _asMap(Object? value, String label) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('$label must be an object.');
}

List<Object?> _asList(Object? value) {
  if (value is List) return value.cast<Object?>();
  return const [];
}

String _string(Object? value, {String fallback = ''}) {
  final normalized = value == null ? '' : '$value'.trim();
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableString(Object? value) {
  final normalized = _string(value);
  return normalized.isEmpty ? null : normalized;
}

int _int(Object? value, {int fallback = 0}) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text.trim()) ?? fallback,
    _ => fallback,
  };
}

int? _nullableInt(Object? value) {
  final normalized = _int(value, fallback: -1);
  return normalized < 0 ? null : normalized;
}

double _double(Object? value, {double fallback = 0}) {
  final parsed = switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text.trim()),
    _ => null,
  };
  return parsed?.isFinite == true ? parsed! : fallback;
}

double? _nullableDouble(Object? value) {
  final parsed = _double(value, fallback: double.nan);
  return parsed.isFinite ? parsed : null;
}

bool _bool(Object? value) {
  return value == true || value == 1 || value == '1' || value == 'true';
}

DateTime? _dateTime(Object? value) {
  return value is String ? DateTime.tryParse(value.trim()) : null;
}
