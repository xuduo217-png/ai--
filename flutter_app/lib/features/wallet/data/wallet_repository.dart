import '../../../core/network/api_client.dart';
import '../domain/wallet_models.dart';

class WalletRepository implements WalletGateway {
  const WalletRepository({required ApiClient apiClient})
    : _apiClient = apiClient;
  final ApiClient _apiClient;

  @override
  Future<WalletStats> loadStats() async {
    final json = _unwrapMap(
      await _apiClient.get('/shop/wallet/stats'),
      'wallet stats',
    );
    return WalletStats(
      availableBalance: _requiredDouble(json['available'], 'available'),
      pendingSettlement: _requiredDouble(json['pending'], 'pending'),
      totalSecondHandIncome: _requiredDouble(json['total'], 'total'),
      withdrawalFrozenBalance: _requiredDouble(json['frozen'], 'frozen'),
    );
  }

  @override
  Future<WalletTransactionPage> loadTransactions(
    WalletTransactionQuery query,
  ) async {
    final root = _asMap(
      await _apiClient.get(
        '/shop/wallet/transactions',
        queryParameters: query.toQueryParameters(),
      ),
      'wallet transactions',
    );
    final itemsValue = root['data'];
    if (itemsValue is! List) {
      throw const FormatException('wallet transactions data must be a list.');
    }
    final pagination = root['pagination'] is Map
        ? _asMap(root['pagination'], 'wallet pagination')
        : root;
    final total = _requiredInt(pagination['total'], 'total');
    final page = _requiredInt(pagination['page'], 'page');
    final pageSize = _requiredInt(
      pagination['pageSize'] ?? pagination['limit'],
      'pageSize',
    );
    final totalPages = pagination['totalPages'] == null
        ? (total / pageSize).ceil()
        : _requiredInt(pagination['totalPages'], 'totalPages');
    if (total < 0 || page < 1 || pageSize < 1 || totalPages < 0) {
      throw const FormatException('wallet pagination is invalid.');
    }
    return WalletTransactionPage(
      items: itemsValue
          .map((item) => _parseTransaction(_asMap(item, 'wallet transaction')))
          .toList(growable: false),
      total: total,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
    );
  }

  @override
  Future<WalletRechargeConfig> loadRechargeConfig() async {
    final json = _unwrapMap(
      await _apiClient.get('/shop/wallet/recharges/config'),
      'recharge config',
    );
    final presetsValue = json['presets'];
    if (presetsValue is! List) {
      throw const FormatException('recharge presets must be a list.');
    }
    return WalletRechargeConfig(
      enabled: _requiredBool(json['enabled'], 'enabled'),
      minAmount: _requiredDouble(json['minAmount'], 'minAmount'),
      maxAmount: _requiredDouble(json['maxAmount'], 'maxAmount'),
      presets: presetsValue
          .map((value) => _requiredDouble(value, 'preset'))
          .toList(growable: false),
      unavailableReason: _optionalString(json['unavailableReason']),
    );
  }

  @override
  Future<WalletRecharge> createRecharge(CreateWalletRecharge request) async {
    final json = _unwrapMap(
      await _apiClient.post(
        '/shop/wallet/recharges',
        authenticated: true,
        additionalHeaders: {'Idempotency-Key': request.idempotencyKey},
        body: {'amount': request.amount},
      ),
      'recharge',
    );
    return _parseRecharge(json);
  }

  @override
  Future<WalletRechargePageResult> loadRecharges({
    int page = 1,
    int pageSize = 10,
    WalletRechargeStatus? status,
  }) async {
    final root = _asMap(
      await _apiClient.get(
        '/shop/wallet/recharges',
        queryParameters: {
          'page': page,
          'limit': pageSize,
          'status': status?.wireValue,
        },
      ),
      'recharges',
    );
    final itemsValue = root['data'];
    if (itemsValue is! List) {
      throw const FormatException('recharges data must be a list.');
    }
    final pagination = root['pagination'] is Map
        ? _asMap(root['pagination'], 'recharge pagination')
        : root;
    return WalletRechargePageResult(
      items: itemsValue
          .map((item) => _parseRecharge(_asMap(item, 'recharge')))
          .toList(growable: false),
      total: _requiredInt(pagination['total'], 'total'),
      page: _requiredInt(pagination['page'], 'page'),
      pageSize: _requiredInt(
        pagination['pageSize'] ?? pagination['limit'],
        'pageSize',
      ),
    );
  }

  @override
  Future<WalletRecharge> loadRecharge(int id) async => _parseRecharge(
    _unwrapMap(await _apiClient.get('/shop/wallet/recharges/$id'), 'recharge'),
  );

  @override
  Future<WalletWithdrawalConfig> loadWithdrawalConfig() async {
    final json = _unwrapMap(
      await _apiClient.get('/shop/wallet/withdrawals/config'),
      'withdrawal config',
    );
    return WalletWithdrawalConfig(
      enabled: _requiredBool(json['enabled'], 'enabled'),
      availableBalance: _requiredDouble(
        json['availableBalance'],
        'availableBalance',
      ),
      minAmount: _requiredDouble(json['minAmount'], 'minAmount'),
      maxAmountPerRequest: _requiredDouble(
        json['maxAmountPerRequest'],
        'maxAmountPerRequest',
      ),
      remainingDailyAmount: _requiredDouble(
        json['remainingDailyAmount'],
        'remainingDailyAmount',
      ),
      hasActiveWithdrawal: _requiredBool(
        json['hasActiveWithdrawal'],
        'hasActiveWithdrawal',
      ),
      unavailableReason: _optionalString(json['unavailableReason']),
    );
  }

  @override
  Future<WalletWithdrawal> createWithdrawal(
    CreateWalletWithdrawal request,
  ) async {
    final json = _unwrapMap(
      await _apiClient.post(
        '/shop/wallet/withdrawals',
        authenticated: true,
        additionalHeaders: {'Idempotency-Key': request.idempotencyKey},
        body: {
          'amount': request.amount,
          'alipayAccount': request.alipayAccount,
          'payeeRealName': request.payeeRealName,
        },
      ),
      'withdrawal',
    );
    return _parseWithdrawal(json);
  }

  @override
  Future<WalletWithdrawalPageResult> loadWithdrawals({
    int page = 1,
    int pageSize = 10,
    WalletWithdrawalStatus? status,
  }) async {
    final root = _asMap(
      await _apiClient.get(
        '/shop/wallet/withdrawals',
        queryParameters: {
          'page': page,
          'limit': pageSize,
          'status': status?.wireValue,
        },
      ),
      'withdrawals',
    );
    final itemsValue = root['data'];
    if (itemsValue is! List) {
      throw const FormatException('withdrawals data must be a list.');
    }
    final pagination = root['pagination'] is Map
        ? _asMap(root['pagination'], 'withdrawal pagination')
        : root;
    return WalletWithdrawalPageResult(
      items: itemsValue
          .map((item) => _parseWithdrawal(_asMap(item, 'withdrawal')))
          .toList(growable: false),
      total: _requiredInt(pagination['total'], 'total'),
      page: _requiredInt(pagination['page'], 'page'),
      pageSize: _requiredInt(
        pagination['pageSize'] ?? pagination['limit'],
        'pageSize',
      ),
    );
  }

  @override
  Future<WalletWithdrawal> loadWithdrawal(int id) async => _parseWithdrawal(
    _unwrapMap(
      await _apiClient.get('/shop/wallet/withdrawals/$id'),
      'withdrawal',
    ),
  );
}

WalletTransaction _parseTransaction(Map<String, Object?> json) =>
    WalletTransaction(
      id: _requiredInt(json['id'], 'id'),
      userId: _requiredInt(json['userId'], 'userId'),
      type: WalletTransactionType.fromWire(json['type']),
      amount: _requiredDouble(json['amount'], 'amount'),
      balanceBefore: _requiredDouble(json['balanceBefore'], 'balanceBefore'),
      balanceAfter: _requiredDouble(json['balanceAfter'], 'balanceAfter'),
      relatedType: WalletRelatedType.fromWire(json['relatedType']),
      relatedId: _requiredInt(json['relatedId'], 'relatedId'),
      status: WalletTransactionStatus.fromWire(json['status']),
      remark: _optionalString(json['remark']),
      withdrawalStatus: json['withdrawalStatus'] == null
          ? null
          : WalletWithdrawalStatus.fromWire(json['withdrawalStatus']),
      withdrawalNo: _optionalString(json['withdrawalNo']),
      historicalAdjustment: json['historicalAdjustment'] == null
          ? false
          : _requiredBool(json['historicalAdjustment'], 'historicalAdjustment'),
      createdAt: _requiredDateTime(json['createdAt'], 'createdAt'),
    );

WalletRecharge _parseRecharge(Map<String, Object?> json) => WalletRecharge(
  id: _requiredInt(json['id'], 'id'),
  rechargeNo: _requiredString(json['rechargeNo'], 'rechargeNo'),
  amount: _requiredDouble(json['amount'], 'amount'),
  status: WalletRechargeStatus.fromWire(json['status']),
  paymentNo: _optionalString(json['paymentNo']),
  alipayOrderString: _optionalString(json['alipayOrderString']),
  expiredAt: _optionalDateTime(json['expiredAt'], 'expiredAt'),
  paidAt: _optionalDateTime(json['paidAt'], 'paidAt'),
  failureMessage: _optionalString(json['failureMessage']),
  createdAt: _requiredDateTime(json['createdAt'], 'createdAt'),
  updatedAt: _requiredDateTime(json['updatedAt'], 'updatedAt'),
);

WalletWithdrawal _parseWithdrawal(Map<String, Object?> json) =>
    WalletWithdrawal(
      id: _requiredInt(json['id'], 'id'),
      withdrawalNo: _requiredString(json['withdrawalNo'], 'withdrawalNo'),
      amount: _requiredDouble(json['amount'], 'amount'),
      status: WalletWithdrawalStatus.fromWire(json['status']),
      payeeAccountMasked: _requiredString(
        json['payeeAccountMasked'],
        'payeeAccountMasked',
      ),
      payeeNameMasked: _requiredString(
        json['payeeNameMasked'],
        'payeeNameMasked',
      ),
      outBizNo: _optionalString(json['outBizNo']),
      alipayStatus: _optionalString(json['alipayStatus']),
      rejectReason: _optionalString(json['rejectReason']),
      failureMessage: _optionalString(json['failureMessage']),
      reviewedAt: _optionalDateTime(json['reviewedAt'], 'reviewedAt'),
      processingAt: _optionalDateTime(json['processingAt'], 'processingAt'),
      completedAt: _optionalDateTime(json['completedAt'], 'completedAt'),
      failedAt: _optionalDateTime(json['failedAt'], 'failedAt'),
      createdAt: _requiredDateTime(json['createdAt'], 'createdAt'),
      updatedAt: _requiredDateTime(json['updatedAt'], 'updatedAt'),
    );

Map<String, Object?> _unwrapMap(Object? value, String label) {
  final root = _asMap(value, label);
  return root.containsKey('data') ? _asMap(root['data'], '$label data') : root;
}

Map<String, Object?> _asMap(Object? value, String label) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$label must be an object.');
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

bool _requiredBool(Object? value, String label) {
  if (value is bool) return value;
  throw FormatException('$label must be a boolean.');
}

String _requiredString(Object? value, String label) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$label must be a non-empty string.');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('optional text must be a string.');
  }
  return value.trim().isEmpty ? null : value.trim();
}

DateTime _requiredDateTime(Object? value, String label) {
  final parsed = value is String ? DateTime.tryParse(value.trim()) : null;
  if (parsed == null) {
    throw FormatException('$label must be an ISO-8601 date time.');
  }
  return parsed;
}

DateTime? _optionalDateTime(Object? value, String label) =>
    value == null ? null : _requiredDateTime(value, label);
