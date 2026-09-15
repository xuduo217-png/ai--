import '../../chat/domain/chat_models.dart';
import '../../health/domain/health_models.dart';
import '../../pets/domain/pet_models.dart';

enum DoctorConsultationStatus {
  paid,
  expired,
  unknown;

  String get wireValue => switch (this) {
    DoctorConsultationStatus.paid => 'PAID',
    DoctorConsultationStatus.expired => 'EXPIRED',
    DoctorConsultationStatus.unknown => '',
  };

  String get label => switch (this) {
    DoctorConsultationStatus.paid => '进行中',
    DoctorConsultationStatus.expired => '已结束',
    DoctorConsultationStatus.unknown => '未知状态',
  };

  static DoctorConsultationStatus fromWire(Object? value) {
    return switch ('$value'.toUpperCase()) {
      'PAID' => DoctorConsultationStatus.paid,
      'EXPIRED' => DoctorConsultationStatus.expired,
      _ => DoctorConsultationStatus.unknown,
    };
  }
}

class DoctorConsultation {
  const DoctorConsultation({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.doctorId,
    required this.status,
    required this.serviceItemName,
    this.orderId,
    this.lastMessage,
    this.unreadCount = 0,
    this.petName,
    this.petAvatarUrl,
    this.serviceStartAt,
    this.serviceEndAt,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String conversationId;
  final int userId;
  final String userName;
  final String userAvatarUrl;
  final int doctorId;
  final DoctorConsultationStatus status;
  final int? orderId;
  final String serviceItemName;
  final String? lastMessage;
  final int unreadCount;
  final String? petName;
  final String? petAvatarUrl;
  final DateTime? serviceStartAt;
  final DateTime? serviceEndAt;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive {
    if (status != DoctorConsultationStatus.paid) return false;
    final endAt = serviceEndAt;
    return endAt == null || endAt.isAfter(DateTime.now());
  }

  DateTime get sortTime =>
      lastMessageAt ??
      updatedAt ??
      createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  DoctorConsultation copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    DoctorConsultationStatus? status,
    DateTime? serviceEndAt,
  }) {
    return DoctorConsultation(
      id: id,
      conversationId: conversationId,
      userId: userId,
      userName: userName,
      userAvatarUrl: userAvatarUrl,
      doctorId: doctorId,
      status: status ?? this.status,
      serviceItemName: serviceItemName,
      orderId: orderId,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      petName: petName,
      petAvatarUrl: petAvatarUrl,
      serviceStartAt: serviceStartAt,
      serviceEndAt: serviceEndAt ?? this.serviceEndAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory DoctorConsultation.fromJson(Map<String, dynamic> json) {
    final conversationId = _requiredString(
      json['conversationId'],
      'consultation.conversationId',
    );
    final lastMessage = _optionalMap(json['lastMessage']);
    return DoctorConsultation(
      id: _requiredInt(json['id'], 'consultation.id'),
      conversationId: conversationId,
      userId: _requiredInt(json['userId'], 'consultation.userId'),
      userName: _fallbackString(json['userName'], '用户'),
      userAvatarUrl: _optionalString(
        json['userAvatar'] ?? json['userAvatarUrl'],
      ),
      doctorId: _requiredInt(json['doctorId'], 'consultation.doctorId'),
      status: DoctorConsultationStatus.fromWire(json['status']),
      orderId: _optionalInt(json['orderId']),
      serviceItemName: _fallbackString(json['serviceItemName'], '在线咨询'),
      lastMessage: lastMessage == null
          ? _nullableString(json['lastMessage'])
          : _messagePreview(lastMessage),
      unreadCount: _optionalInt(json['unreadCount']) ?? 0,
      petName: _nullableString(json['petName']),
      petAvatarUrl: _nullableString(json['petAvatar'] ?? json['petAvatarUrl']),
      serviceStartAt: _optionalDate(json['serviceStartAt']),
      serviceEndAt: _optionalDate(json['serviceEndAt']),
      lastMessageAt: _optionalDate(
        lastMessage?['createdAt'] ?? json['lastMessageAt'],
      ),
      createdAt: _optionalDate(json['createdAt']),
      updatedAt: _optionalDate(json['updatedAt']),
    );
  }
}

class DoctorConsultationPage {
  const DoctorConsultationPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    this.totalUnreadCount = 0,
  });

  final List<DoctorConsultation> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final int totalUnreadCount;

  bool get hasMore => page < totalPages;
}

class DoctorHistorySession {
  const DoctorHistorySession({
    required this.id,
    required this.conversationId,
    required this.status,
    required this.serviceItemName,
    required this.messageCount,
    required this.lastMessage,
    this.orderId,
    this.serviceStartAt,
    this.serviceEndAt,
    this.lastMessageAt,
    this.createdAt,
  });

  factory DoctorHistorySession.fromJson(Map<String, dynamic> json) {
    final lastMessage = _optionalMap(json['lastMessage']);
    return DoctorHistorySession(
      id: _requiredInt(json['id'], 'history.id'),
      conversationId: _requiredString(
        json['conversationId'],
        'history.conversationId',
      ),
      status: DoctorConsultationStatus.fromWire(json['status']),
      serviceItemName: _fallbackString(json['serviceItemName'], '在线咨询'),
      messageCount: _optionalInt(json['messageCount']) ?? 0,
      lastMessage: lastMessage == null ? null : _messagePreview(lastMessage),
      orderId: _optionalInt(json['orderId']),
      serviceStartAt: _optionalDate(json['serviceStartAt']),
      serviceEndAt: _optionalDate(json['serviceEndAt']),
      lastMessageAt: _optionalDate(
        lastMessage?['createdAt'] ?? json['lastMessageAt'],
      ),
      createdAt: _optionalDate(json['createdAt']),
    );
  }

  final int id;
  final String conversationId;
  final DoctorConsultationStatus status;
  final String serviceItemName;
  final int messageCount;
  final String? lastMessage;
  final int? orderId;
  final DateTime? serviceStartAt;
  final DateTime? serviceEndAt;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
}

class DoctorHistoryPage {
  const DoctorHistoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<DoctorHistorySession> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class DoctorHistoryMessagePage {
  const DoctorHistoryMessagePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<ChatMessage> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

String? _messagePreview(Map<String, dynamic> message) {
  final type = ChatMessageType.fromWire(message['type']);
  return switch (type) {
    ChatMessageType.image => '[图片]',
    ChatMessageType.video => '[视频]',
    ChatMessageType.paymentSuccess => '[支付成功]',
    ChatMessageType.paymentPrompt => '[待支付]',
    _ => _nullableString(message['content']),
  };
}

class DoctorIncomeStats {
  const DoctorIncomeStats({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.total,
    required this.consultationCount,
  });

  final double today;
  final double thisWeek;
  final double thisMonth;
  final double total;
  final int consultationCount;

  factory DoctorIncomeStats.fromJson(Map<String, dynamic> json) {
    return DoctorIncomeStats(
      today: _requiredDouble(json['today'], 'income.today'),
      thisWeek: _requiredDouble(json['thisWeek'], 'income.thisWeek'),
      thisMonth: _requiredDouble(json['thisMonth'], 'income.thisMonth'),
      total: _requiredDouble(json['total'], 'income.total'),
      consultationCount: _requiredInt(
        json['consultationCount'],
        'income.consultationCount',
      ),
    );
  }
}

class DoctorIncomeRecord {
  const DoctorIncomeRecord({
    required this.id,
    required this.consultationId,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.userName,
    required this.serviceName,
  });

  final String id;
  final String consultationId;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String userName;
  final String serviceName;

  bool get isPaid => status.toLowerCase() == 'paid';

  factory DoctorIncomeRecord.fromJson(Map<String, dynamic> json) {
    return DoctorIncomeRecord(
      id: _requiredString(json['id'], 'incomeRecord.id'),
      consultationId: _requiredString(
        json['consultationId'],
        'incomeRecord.consultationId',
      ),
      amount: _requiredDouble(json['amount'], 'incomeRecord.amount'),
      status: _requiredString(json['status'], 'incomeRecord.status'),
      createdAt: _requiredDate(json['createdAt'], 'incomeRecord.createdAt'),
      userName: _fallbackString(json['userName'], '未知用户'),
      serviceName: _fallbackString(json['serviceName'], '咨询服务'),
    );
  }
}

class DoctorIncomePage {
  const DoctorIncomePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<DoctorIncomeRecord> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class DoctorIncomeSnapshot {
  const DoctorIncomeSnapshot({required this.stats, required this.records});

  final DoctorIncomeStats stats;
  final DoctorIncomePage records;
}

class DoctorPortalProfile {
  const DoctorPortalProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.avatarUrl,
    required this.specialty,
    required this.experienceYears,
    required this.consultationCount,
    required this.isActive,
    required this.isGoldDoctor,
    required this.isOnline,
    required this.hospitalName,
    required this.departmentName,
  });

  final int id;
  final String name;
  final String phone;
  final String avatarUrl;
  final String specialty;
  final int experienceYears;
  final int consultationCount;
  final bool isActive;
  final bool isGoldDoctor;
  final bool isOnline;
  final String hospitalName;
  final String departmentName;

  String get workplace {
    final parts = [
      hospitalName,
      departmentName,
    ].where((part) => part.trim().isNotEmpty).toList(growable: false);
    return parts.isEmpty ? '暂未设置执业机构' : parts.join(' · ');
  }

  DoctorPortalProfile copyWith({bool? isOnline}) {
    return DoctorPortalProfile(
      id: id,
      name: name,
      phone: phone,
      avatarUrl: avatarUrl,
      specialty: specialty,
      experienceYears: experienceYears,
      consultationCount: consultationCount,
      isActive: isActive,
      isGoldDoctor: isGoldDoctor,
      isOnline: isOnline ?? this.isOnline,
      hospitalName: hospitalName,
      departmentName: departmentName,
    );
  }

  factory DoctorPortalProfile.fromJson(Map<String, dynamic> json) {
    final hospital = _optionalMap(json['hospital']);
    final department = _optionalMap(json['department']);
    return DoctorPortalProfile(
      id: _requiredInt(json['id'], 'doctor.id'),
      name: _fallbackString(json['name'] ?? json['username'], '医生'),
      phone: _optionalString(json['phone']),
      avatarUrl: _optionalString(json['avatar'] ?? json['avatarUrl']),
      specialty: _fallbackString(json['specialty'], '暂未填写擅长领域'),
      experienceYears: _optionalInt(json['experience']) ?? 0,
      consultationCount: _optionalInt(json['consultationCount']) ?? 0,
      isActive: json['isActive'] != false,
      isGoldDoctor: json['isGoldDoctor'] == true,
      isOnline: '${json['onlineStatus']}'.toUpperCase() == 'ONLINE',
      hospitalName: _optionalString(hospital?['name'] ?? json['hospitalName']),
      departmentName: _optionalString(
        department?['name'] ?? json['departmentName'],
      ),
    );
  }
}

class DoctorPatientRecord {
  const DoctorPatientRecord({
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.petCount,
    required this.pets,
  });

  factory DoctorPatientRecord.fromJson(Map<String, dynamic> json) {
    final user = _optionalMap(json['user']) ?? const <String, dynamic>{};
    final petValues = json['pets'];
    final pets = petValues is List
        ? petValues
              .map(
                (value) => DoctorPatientPet.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              )
              .toList(growable: false)
        : const <DoctorPatientPet>[];
    return DoctorPatientRecord(
      userId: _requiredInt(user['id'], 'patient.user.id'),
      userName: _fallbackString(user['name'], '用户'),
      userAvatarUrl: _optionalString(user['avatar']),
      petCount: _optionalInt(json['petCount']) ?? pets.length,
      pets: pets,
    );
  }

  final int userId;
  final String userName;
  final String userAvatarUrl;
  final int petCount;
  final List<DoctorPatientPet> pets;
}

class DoctorPatientPet {
  const DoctorPatientPet({
    required this.pet,
    required this.vaccination,
    this.healthStats = PetHealthStats.empty,
  });

  factory DoctorPatientPet.fromJson(Map<String, dynamic> json) {
    final vaccination = DoctorVaccination.fromJson(json['vaccination']);
    final healthStatsValue = json['healthStats'];
    return DoctorPatientPet(
      pet: Pet.fromJson(Map<String, Object?>.from(json)),
      vaccination: vaccination,
      healthStats: healthStatsValue is Map
          ? PetHealthStats.fromJson(healthStatsValue)
          : PetHealthStats(
              vaccine: HealthMetric(
                count: vaccination.count,
                lastAt: vaccination.lastAt,
                nextAt: vaccination.nextAt,
              ),
              deworming: const HealthMetric(),
              checkup: const HealthMetric(),
            ),
    );
  }

  final Pet pet;
  final DoctorVaccination vaccination;
  final PetHealthStats healthStats;
}

class DoctorVaccination {
  const DoctorVaccination({
    required this.count,
    required this.lastAt,
    required this.nextAt,
  });

  factory DoctorVaccination.fromJson(Object? value) {
    final json = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    return DoctorVaccination(
      count: _optionalInt(json['count']) ?? 0,
      lastAt: _optionalDate(json['lastAt']),
      nextAt: _optionalDate(json['nextAt']),
    );
  }

  final int count;
  final DateTime? lastAt;
  final DateTime? nextAt;
}

abstract interface class DoctorPortalGateway {
  Future<DoctorConsultationPage> loadConsultations({
    required int doctorId,
    required DoctorConsultationStatus status,
    int page = 1,
    int pageSize = 20,
  });

  Future<void> markConversationRead(String conversationId);

  Future<DoctorIncomeSnapshot> loadIncome({int page = 1, int pageSize = 10});

  Future<DoctorIncomePage> loadIncomeRecords({
    required int page,
    int pageSize = 10,
  });

  Future<DoctorPortalProfile> loadProfile();

  Future<DoctorPortalProfile> updateOnlineStatus(bool online);

  Future<ChatBootstrap> loadDoctorChat({
    required DoctorConsultation consultation,
    required int doctorId,
  });

  Future<DoctorPatientRecord> loadPatientRecord(String conversationId);

  Future<DoctorHistoryPage> loadPatientHistory({
    required String conversationId,
    int page = 1,
    int pageSize = 20,
  });

  Future<DoctorHistoryMessagePage> loadPatientHistoryMessages({
    required String conversationId,
    required String historyConversationId,
    int page = 1,
    int pageSize = 50,
  });

  Future<AiDiagnosisPage> loadPatientAiReports({
    required String conversationId,
    required int petId,
    int page = 1,
    int pageSize = 20,
  });

  Future<AiDiagnosisReport> loadPatientAiReport({
    required String conversationId,
    required int reportId,
  });

  Future<PetCarePlanState> loadPatientCarePlan({
    required String conversationId,
    required int petId,
  });

  Future<AppointmentPage> loadPatientAppointments({
    required String conversationId,
    required int petId,
    int page = 1,
    int pageSize = 20,
  });

  Future<HealthAppointment> loadPatientAppointment({
    required String conversationId,
    required int appointmentId,
  });
}

abstract interface class DoctorConsultationExtensionGateway {
  Future<ChatSessionExtension> extendConsultation({
    required String conversationId,
    required int minutes,
    required String idempotencyKey,
    String? reason,
  });
}

Map<String, dynamic>? _optionalMap(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

String _requiredString(Object? value, String field) {
  final text = '$value'.trim();
  if (value == null || text.isEmpty) {
    throw FormatException('$field 缺失');
  }
  return text;
}

String _optionalString(Object? value) => value == null ? '' : '$value'.trim();

String? _nullableString(Object? value) {
  final text = _optionalString(value);
  return text.isEmpty ? null : text;
}

String _fallbackString(Object? value, String fallback) {
  final text = _optionalString(value);
  return text.isEmpty ? fallback : text;
}

int _requiredInt(Object? value, String field) {
  final parsed = _optionalInt(value);
  if (parsed == null) throw FormatException('$field 不是有效整数');
  return parsed;
}

int? _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return value == null ? null : int.tryParse('$value');
}

double _requiredDouble(Object? value, String field) {
  final parsed = switch (value) {
    final num number => number.toDouble(),
    final Object raw => double.tryParse('$raw'),
    null => null,
  };
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('$field 不是有效金额');
  }
  return parsed;
}

DateTime _requiredDate(Object? value, String field) {
  final parsed = _optionalDate(value);
  if (parsed == null) throw FormatException('$field 不是有效时间');
  return parsed;
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.tryParse('$value');
}
