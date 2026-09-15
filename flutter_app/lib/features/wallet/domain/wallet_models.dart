class WalletStats {
  const WalletStats({
    required this.availableBalance,
    required this.pendingSettlement,
    required this.totalSecondHandIncome,
    required this.withdrawalFrozenBalance,
  });

  final double availableBalance;
  final double pendingSettlement;
  final double totalSecondHandIncome;
  final double withdrawalFrozenBalance;
}

enum WalletTransactionType {
  income('income'),
  expense('expense'),
  freeze('freeze'),
  unfreeze('unfreeze'),
  unknown(null);

  const WalletTransactionType(this.wireValue);
  final String? wireValue;

  static WalletTransactionType fromWire(Object? value) =>
      WalletTransactionType.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => WalletTransactionType.unknown,
      );

  bool get isCredit => this == income || this == unfreeze;
  String get label => switch (this) {
    income => '收入',
    expense => '支出',
    freeze => '冻结',
    unfreeze => '解冻',
    unknown => '其他',
  };
}

enum WalletTransactionStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  unknown(null);

  const WalletTransactionStatus(this.wireValue);
  final String? wireValue;

  static WalletTransactionStatus fromWire(Object? value) =>
      WalletTransactionStatus.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => WalletTransactionStatus.unknown,
      );
}

enum WalletRelatedType {
  order('order', '二手交易'),
  refund('refund', '退款'),
  recharge('recharge', '余额充值'),
  withdraw('withdraw', '支付宝提现'),
  charity('charity', '公益捐款'),
  adjustment('adjustment', '平台调整'),
  unknown(null, '其他');

  const WalletRelatedType(this.wireValue, this.label);
  final String? wireValue;
  final String label;

  static WalletRelatedType fromWire(Object? value) =>
      WalletRelatedType.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => WalletRelatedType.unknown,
      );
}

enum WalletWithdrawalStatus {
  pendingReview('pending_review', '审核中'),
  processing('processing', '转账中'),
  succeeded('succeeded', '已到账'),
  rejected('rejected', '已拒绝'),
  failed('failed', '转账失败'),
  unknown(null, '状态未知');

  const WalletWithdrawalStatus(this.wireValue, this.label);
  final String? wireValue;
  final String label;

  static WalletWithdrawalStatus fromWire(Object? value) =>
      WalletWithdrawalStatus.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => WalletWithdrawalStatus.unknown,
      );

  bool get isActive => this == pendingReview || this == processing;
}

enum WalletRechargeStatus {
  pending('pending', '待确认'),
  succeeded('succeeded', '已到账'),
  failed('failed', '充值失败'),
  closed('closed', '已关闭'),
  unknown(null, '状态未知');

  const WalletRechargeStatus(this.wireValue, this.label);
  final String? wireValue;
  final String label;

  static WalletRechargeStatus fromWire(Object? value) =>
      WalletRechargeStatus.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => WalletRechargeStatus.unknown,
      );

  bool get isTerminal => this == succeeded || this == failed || this == closed;
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.relatedType,
    required this.relatedId,
    required this.status,
    required this.createdAt,
    this.remark,
    this.withdrawalStatus,
    this.withdrawalNo,
    this.historicalAdjustment = false,
  });

  final int id;
  final int userId;
  final WalletTransactionType type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final WalletRelatedType relatedType;
  final int relatedId;
  final WalletTransactionStatus status;
  final String? remark;
  final WalletWithdrawalStatus? withdrawalStatus;
  final String? withdrawalNo;
  final bool historicalAdjustment;
  final DateTime createdAt;

  bool get hasValidOrderLink =>
      relatedType == WalletRelatedType.order && relatedId > 0;
  bool get hasValidWithdrawalLink =>
      relatedType == WalletRelatedType.withdraw &&
      withdrawalNo != null &&
      relatedId > 0;

  String get statusLabel {
    if (withdrawalStatus case final value?) return value.label;
    if (relatedType == WalletRelatedType.order &&
        type == WalletTransactionType.income) {
      return switch (status) {
        WalletTransactionStatus.pending => '待到账',
        WalletTransactionStatus.approved => '已到账',
        WalletTransactionStatus.rejected => '已拒绝',
        WalletTransactionStatus.unknown => '状态未知',
      };
    }
    return switch (status) {
      WalletTransactionStatus.pending => '处理中',
      WalletTransactionStatus.approved => '已完成',
      WalletTransactionStatus.rejected => '已拒绝',
      WalletTransactionStatus.unknown => '状态未知',
    };
  }
}

class WalletTransactionQuery {
  const WalletTransactionQuery({
    this.status,
    this.type,
    this.relatedType,
    this.page = 1,
    this.pageSize = 10,
  }) : assert(page > 0),
       assert(pageSize > 0);

  final WalletTransactionStatus? status;
  final WalletTransactionType? type;
  final WalletRelatedType? relatedType;
  final int page;
  final int pageSize;

  Map<String, Object?> toQueryParameters() => {
    'status': ?status?.wireValue,
    'type': ?type?.wireValue,
    'relatedType': ?relatedType?.wireValue,
    'page': page,
    'limit': pageSize,
  };
}

class WalletTransactionPage {
  const WalletTransactionPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
  final List<WalletTransaction> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  bool get hasMore => totalPages > 0 && page < totalPages;
}

class WalletWithdrawalConfig {
  const WalletWithdrawalConfig({
    required this.enabled,
    required this.availableBalance,
    required this.minAmount,
    required this.maxAmountPerRequest,
    required this.remainingDailyAmount,
    required this.hasActiveWithdrawal,
    this.unavailableReason,
  });
  final bool enabled;
  final double availableBalance;
  final double minAmount;
  final double maxAmountPerRequest;
  final double remainingDailyAmount;
  final bool hasActiveWithdrawal;
  final String? unavailableReason;
}

class WalletRechargeConfig {
  const WalletRechargeConfig({
    required this.enabled,
    required this.minAmount,
    required this.maxAmount,
    required this.presets,
    this.unavailableReason,
  });
  final bool enabled;
  final double minAmount;
  final double maxAmount;
  final List<double> presets;
  final String? unavailableReason;
}

class WalletRecharge {
  const WalletRecharge({
    required this.id,
    required this.rechargeNo,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paymentNo,
    this.alipayOrderString,
    this.expiredAt,
    this.paidAt,
    this.failureMessage,
  });
  final int id;
  final String rechargeNo;
  final double amount;
  final WalletRechargeStatus status;
  final String? paymentNo;
  final String? alipayOrderString;
  final DateTime? expiredAt;
  final DateTime? paidAt;
  final String? failureMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class WalletRechargePageResult {
  const WalletRechargePageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<WalletRecharge> items;
  final int total;
  final int page;
  final int pageSize;
  bool get hasMore => page * pageSize < total;
}

class CreateWalletRecharge {
  const CreateWalletRecharge({
    required this.amount,
    required this.idempotencyKey,
  });
  final String amount;
  final String idempotencyKey;
}

class WalletWithdrawal {
  const WalletWithdrawal({
    required this.id,
    required this.withdrawalNo,
    required this.amount,
    required this.status,
    required this.payeeAccountMasked,
    required this.payeeNameMasked,
    required this.createdAt,
    required this.updatedAt,
    this.outBizNo,
    this.alipayStatus,
    this.rejectReason,
    this.failureMessage,
    this.reviewedAt,
    this.processingAt,
    this.completedAt,
    this.failedAt,
  });
  final int id;
  final String withdrawalNo;
  final double amount;
  final WalletWithdrawalStatus status;
  final String payeeAccountMasked;
  final String payeeNameMasked;
  final String? outBizNo;
  final String? alipayStatus;
  final String? rejectReason;
  final String? failureMessage;
  final DateTime? reviewedAt;
  final DateTime? processingAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class WalletWithdrawalPageResult {
  const WalletWithdrawalPageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<WalletWithdrawal> items;
  final int total;
  final int page;
  final int pageSize;
  bool get hasMore => page * pageSize < total;
}

class CreateWalletWithdrawal {
  const CreateWalletWithdrawal({
    required this.amount,
    required this.alipayAccount,
    required this.payeeRealName,
    required this.idempotencyKey,
  });
  final String amount;
  final String alipayAccount;
  final String payeeRealName;
  final String idempotencyKey;
}

abstract interface class WalletSummaryGateway {
  Future<WalletStats> loadStats();
}

abstract interface class WalletGateway implements WalletSummaryGateway {
  Future<WalletTransactionPage> loadTransactions(WalletTransactionQuery query);
  Future<WalletRechargeConfig> loadRechargeConfig();
  Future<WalletRecharge> createRecharge(CreateWalletRecharge request);
  Future<WalletRechargePageResult> loadRecharges({
    int page = 1,
    int pageSize = 10,
    WalletRechargeStatus? status,
  });
  Future<WalletRecharge> loadRecharge(int id);
  Future<WalletWithdrawalConfig> loadWithdrawalConfig();
  Future<WalletWithdrawal> createWithdrawal(CreateWalletWithdrawal request);
  Future<WalletWithdrawalPageResult> loadWithdrawals({
    int page = 1,
    int pageSize = 10,
    WalletWithdrawalStatus? status,
  });
  Future<WalletWithdrawal> loadWithdrawal(int id);
}
