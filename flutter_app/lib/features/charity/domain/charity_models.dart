enum CharityStatus {
  active('ACTIVE', '进行中'),
  expired('EXPIRED', '已结束'),
  draft('DRAFT', '未开始');

  const CharityStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CharityStatus fromWire(Object? value) {
    return CharityStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => CharityStatus.draft,
    );
  }
}

enum CharityListFilter {
  active('进行中', CharityStatus.active),
  expired('已结束', CharityStatus.expired),
  all('全部', null);

  const CharityListFilter(this.label, this.status);

  final String label;
  final CharityStatus? status;
}

enum CharityParticipantType {
  checkIn('checkin'),
  task('task'),
  donation('donation');

  const CharityParticipantType(this.wireValue);

  final String wireValue;

  bool get isDonation => this == donation;
  String get label => isDonation ? '捐款' : '打卡';

  static CharityParticipantType fromWire(Object? value) {
    return CharityParticipantType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => CharityParticipantType.checkIn,
    );
  }
}

class CharityActivity {
  const CharityActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.details,
    required this.coverImageUrl,
    required this.targetCheckIns,
    required this.completedCheckIns,
    required this.donatedAmount,
    required this.participantType,
    required this.status,
    required this.hasCheckedToday,
    this.startTime,
    this.endTime,
    this.isMallAutoDonation = false,
    this.donationRate = 0,
    this.isPinned = false,
  });

  final int id;
  final String title;
  final String description;
  final String details;
  final String coverImageUrl;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isMallAutoDonation;
  final double donationRate;
  final bool isPinned;
  final int targetCheckIns;
  final int completedCheckIns;
  final double donatedAmount;
  final CharityParticipantType participantType;
  final CharityStatus status;
  final bool hasCheckedToday;

  bool get isDonation => participantType.isDonation;
  bool get showProgress =>
      !isDonation &&
      (status == CharityStatus.active || status == CharityStatus.expired);
  bool get isCompleted =>
      targetCheckIns > 0 && completedCheckIns >= targetCheckIns;
  double get progress {
    if (targetCheckIns <= 0) return 0;
    return (completedCheckIns / targetCheckIns).clamp(0, 1).toDouble();
  }
}

class CharityPage {
  const CharityPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<CharityActivity> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class CharityRecord {
  const CharityRecord({
    required this.id,
    required this.charityId,
    required this.userId,
    required this.checkInTime,
    required this.donationAmount,
    required this.userName,
    required this.userAvatarUrl,
    this.checkInDate,
    this.donationSource = 'manual',
    this.donationEntryType = 'credit',
    this.orderId,
    this.orderNo,
    this.donationBaseAmount,
    this.donationRate,
  });

  final int id;
  final int charityId;
  final int userId;
  final String? checkInDate;
  final DateTime checkInTime;
  final double donationAmount;
  final String userName;
  final String userAvatarUrl;
  final String donationSource;
  final String donationEntryType;
  final int? orderId;
  final String? orderNo;
  final double? donationBaseAmount;
  final double? donationRate;
}

class CharityRecordPage {
  const CharityRecordPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<CharityRecord> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class CharityCheckInResult {
  const CharityCheckInResult({
    required this.success,
    required this.alreadyChecked,
    required this.totalCheckIns,
    required this.message,
    required this.isCompleted,
  });

  final bool success;
  final bool alreadyChecked;
  final int totalCheckIns;
  final String message;
  final bool isCompleted;
}

class CharityDonationResult {
  const CharityDonationResult({
    required this.message,
    required this.donationAmount,
    required this.donatedAmount,
    required this.balanceBefore,
    required this.balanceAfter,
  });

  final String message;
  final double donationAmount;
  final double donatedAmount;
  final double balanceBefore;
  final double balanceAfter;
}

class CharityDonationPayment {
  const CharityDonationPayment({
    required this.paymentNo,
    required this.amount,
    required this.alipayOrderString,
  });

  final String paymentNo;
  final double amount;
  final String alipayOrderString;
}

enum CharityDonationPaymentStatus {
  pending,
  processing,
  success,
  failed,
  closed,
  unknown;

  bool get paid => this == success;
  bool get terminal => paid || this == failed || this == closed;

  static CharityDonationPaymentStatus fromWire(Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return CharityDonationPaymentStatus.values.firstWhere(
      (status) => status.name == normalized,
      orElse: () => CharityDonationPaymentStatus.unknown,
    );
  }
}

abstract interface class CharityGateway {
  Future<CharityPage> loadCharities({
    required bool authenticated,
    CharityStatus? status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  });

  Future<CharityActivity> loadCharityDetail(
    int charityId, {
    required bool authenticated,
  });

  Future<CharityRecordPage> loadCharityRecords(
    int charityId, {
    int page = 1,
    int pageSize = 10,
  });

  Future<CharityRecordPage> loadCharityDonations(
    int charityId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  });

  Future<CharityCheckInResult> checkInCharity(int charityId);

  Future<double> loadCharityWalletBalance();

  Future<CharityDonationResult> donateCharity(
    int charityId, {
    required double amount,
  });

  Future<CharityDonationPayment> createCharityDonationPayment(
    int charityId, {
    required double amount,
    required String idempotencyKey,
  });

  Future<CharityDonationPaymentStatus> loadCharityDonationPaymentStatus(
    String paymentNo,
  );
}
