import '../../../core/network/api_client.dart';
import '../../chat/domain/chat_models.dart';
import '../../health/domain/health_models.dart';
import '../domain/doctor_portal_models.dart';

class DoctorPortalRepository
    implements DoctorPortalGateway, DoctorConsultationExtensionGateway {
  DoctorPortalRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<ChatSessionExtension> extendConsultation({
    required String conversationId,
    required int minutes,
    required String idempotencyKey,
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/chat/doctor/sessions/${Uri.encodeComponent(conversationId)}/extensions',
      authenticated: true,
      body: {
        'minutes': minutes,
        'idempotencyKey': idempotencyKey,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return ChatSessionExtension.fromJson(_asMap(response));
  }

  @override
  Future<DoctorConsultationPage> loadConsultations({
    required int doctorId,
    required DoctorConsultationStatus status,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (status == DoctorConsultationStatus.unknown) {
      throw ArgumentError.value(status, 'status', '不能查询未知咨询状态');
    }
    final response = await _apiClient.get(
      '/chat/doctor/sessions',
      queryParameters: {
        'status': status.wireValue,
        'page': page,
        'limit': pageSize,
      },
    );
    final parsed = _parseDoctorConsultationPage(
      response,
      fallbackPageSize: pageSize,
    );
    return DoctorConsultationPage(
      items: parsed.items
          .map(DoctorConsultation.fromJson)
          .toList(growable: false),
      total: parsed.total,
      page: parsed.page,
      pageSize: parsed.pageSize,
      totalPages: parsed.totalPages,
      totalUnreadCount: _doctorConsultationUnreadCount(response),
    );
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    await _apiClient.put(
      '/chat/conversations/${Uri.encodeComponent(conversationId)}/read',
    );
  }

  @override
  Future<DoctorIncomeSnapshot> loadIncome({
    int page = 1,
    int pageSize = 10,
  }) async {
    final responses = await Future.wait<Object?>([
      _apiClient.get('/chat/doctor/income-stats'),
      _apiClient.get(
        '/chat/doctor/income-list',
        queryParameters: {'page': page, 'limit': pageSize},
      ),
    ]);
    return DoctorIncomeSnapshot(
      stats: DoctorIncomeStats.fromJson(_unwrapMap(responses[0])),
      records: _parseIncomePage(responses[1], pageSize),
    );
  }

  @override
  Future<DoctorIncomePage> loadIncomeRecords({
    required int page,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get(
      '/chat/doctor/income-list',
      queryParameters: {'page': page, 'limit': pageSize},
    );
    return _parseIncomePage(response, pageSize);
  }

  @override
  Future<DoctorPortalProfile> loadProfile() async {
    final response = await _apiClient.get('/doctors/profile');
    return DoctorPortalProfile.fromJson(_unwrapMap(response));
  }

  @override
  Future<DoctorPortalProfile> updateOnlineStatus(bool online) async {
    final response = await _apiClient.patch(
      '/doctors/online-status',
      body: {'onlineStatus': online ? 'ONLINE' : 'OFFLINE'},
    );
    return DoctorPortalProfile.fromJson(_unwrapMap(response));
  }

  @override
  Future<ChatBootstrap> loadDoctorChat({
    required DoctorConsultation consultation,
    required int doctorId,
  }) async {
    final response = await _apiClient.get(
      '/chat/messages',
      queryParameters: {
        'conversationId': consultation.conversationId,
        'page': 1,
        'limit': 50,
      },
    );
    final page = _parsePage(response, fallbackPageSize: 50);
    final messages = page.items.map(ChatMessage.fromJson).toList(growable: true)
      ..sort((left, right) {
        final byTime = left.createdAt.compareTo(right.createdAt);
        return byTime == 0 ? left.id.compareTo(right.id) : byTime;
      });
    final active = consultation.isActive;
    return ChatBootstrap(
      session: ChatSession(
        conversationId: consultation.conversationId,
        userId: consultation.userId,
        doctorId: doctorId,
        status: active ? ChatSessionStatus.paid : ChatSessionStatus.expired,
        serviceStartAt: consultation.serviceStartAt,
        serviceEndAt: consultation.serviceEndAt,
      ),
      canSend: active,
      messages: messages,
      doctorOnline: active,
      availablePackages: const [],
    );
  }

  @override
  Future<DoctorPatientRecord> loadPatientRecord(String conversationId) async {
    return DoctorPatientRecord.fromJson(
      _asMap(
        await _apiClient.get('${_doctorSessionPath(conversationId)}/patient'),
      ),
    );
  }

  @override
  Future<DoctorHistoryPage> loadPatientHistory({
    required String conversationId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '${_doctorSessionPath(conversationId)}/history',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final parsed = _parsePage(response, fallbackPageSize: pageSize);
    return DoctorHistoryPage(
      items: parsed.items
          .map(DoctorHistorySession.fromJson)
          .toList(growable: false),
      total: parsed.total,
      page: parsed.page,
      pageSize: parsed.pageSize,
      totalPages: parsed.totalPages,
    );
  }

  @override
  Future<DoctorHistoryMessagePage> loadPatientHistoryMessages({
    required String conversationId,
    required String historyConversationId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiClient.get(
      '${_doctorSessionPath(conversationId)}/history/'
      '${Uri.encodeComponent(historyConversationId)}/messages',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final parsed = _parsePage(response, fallbackPageSize: pageSize);
    return DoctorHistoryMessagePage(
      items: parsed.items.map(ChatMessage.fromJson).toList(growable: false),
      total: parsed.total,
      page: parsed.page,
      pageSize: parsed.pageSize,
      totalPages: parsed.totalPages,
    );
  }

  @override
  Future<AiDiagnosisPage> loadPatientAiReports({
    required String conversationId,
    required int petId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '${_doctorSessionPath(conversationId)}/pets/$petId/ai-reports',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final parsed = _parsePage(response, fallbackPageSize: pageSize);
    return AiDiagnosisPage(
      items: parsed.items
          .map(AiDiagnosisReport.fromJson)
          .toList(growable: false),
      page: parsed.page,
      totalPages: parsed.totalPages,
      total: parsed.total,
    );
  }

  @override
  Future<AiDiagnosisReport> loadPatientAiReport({
    required String conversationId,
    required int reportId,
  }) async {
    return AiDiagnosisReport.fromJson(
      await _apiClient.get(
        '${_doctorSessionPath(conversationId)}/ai-reports/$reportId',
      ),
    );
  }

  @override
  Future<PetCarePlanState> loadPatientCarePlan({
    required String conversationId,
    required int petId,
  }) async {
    return PetCarePlanState.fromJson(
      await _apiClient.get(
        '${_doctorSessionPath(conversationId)}/pets/$petId/care-plan',
      ),
    );
  }

  @override
  Future<AppointmentPage> loadPatientAppointments({
    required String conversationId,
    required int petId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '${_doctorSessionPath(conversationId)}/pets/$petId/appointments',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final parsed = _parsePage(response, fallbackPageSize: pageSize);
    return AppointmentPage(
      items: parsed.items
          .map(HealthAppointment.fromJson)
          .toList(growable: false),
      page: parsed.page,
      totalPages: parsed.totalPages,
      total: parsed.total,
    );
  }

  @override
  Future<HealthAppointment> loadPatientAppointment({
    required String conversationId,
    required int appointmentId,
  }) async {
    return HealthAppointment.fromJson(
      await _apiClient.get(
        '${_doctorSessionPath(conversationId)}/appointments/$appointmentId',
      ),
    );
  }

  DoctorIncomePage _parseIncomePage(Object? response, int fallbackPageSize) {
    final parsed = _parsePage(response, fallbackPageSize: fallbackPageSize);
    return DoctorIncomePage(
      items: parsed.items
          .map(DoctorIncomeRecord.fromJson)
          .toList(growable: false),
      total: parsed.total,
      page: parsed.page,
      pageSize: parsed.pageSize,
      totalPages: parsed.totalPages,
    );
  }
}

String _doctorSessionPath(String conversationId) {
  return '/chat/doctor/sessions/${Uri.encodeComponent(conversationId)}';
}

class _ParsedPage {
  const _ParsedPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
}

_ParsedPage _parsePage(Object? response, {required int fallbackPageSize}) {
  if (response is List) {
    final items = _mapList(response);
    return _ParsedPage(
      items: items,
      total: items.length,
      page: 1,
      pageSize: fallbackPageSize,
      totalPages: items.isEmpty ? 0 : 1,
    );
  }

  var root = _asMap(response);
  final nested = root['data'];
  if (nested is Map && nested['data'] is List) {
    root = Map<String, dynamic>.from(nested);
  }
  final list = root['data'];
  if (list is! List) throw const FormatException('分页响应缺少 data 列表');
  final pagination = root['pagination'] is Map
      ? Map<String, dynamic>.from(root['pagination'] as Map)
      : root;
  final items = _mapList(list);
  final total = _readInt(pagination['total']) ?? items.length;
  final page = _readInt(pagination['page']) ?? 1;
  final pageSize =
      _readInt(pagination['pageSize'] ?? pagination['limit']) ??
      fallbackPageSize;
  final totalPages =
      _readInt(pagination['totalPages']) ??
      (total == 0 ? 0 : (total / pageSize).ceil());
  return _ParsedPage(
    items: items,
    total: total,
    page: page,
    pageSize: pageSize,
    totalPages: totalPages,
  );
}

_ParsedPage _parseDoctorConsultationPage(
  Object? response, {
  required int fallbackPageSize,
}) {
  final root = _asMap(response);
  final sessions = root['sessions'];
  if (sessions is! List) {
    throw const FormatException('医生会话响应缺少 sessions 列表');
  }
  final pagination = root['pagination'] is Map
      ? Map<String, dynamic>.from(root['pagination'] as Map)
      : const <String, dynamic>{};
  final items = _mapList(sessions);
  final total = _readInt(pagination['total']) ?? items.length;
  final page = _readInt(pagination['page']) ?? 1;
  final pageSize = _readInt(pagination['pageSize']) ?? fallbackPageSize;
  return _ParsedPage(
    items: items,
    total: total,
    page: page,
    pageSize: pageSize,
    totalPages:
        _readInt(pagination['totalPages']) ??
        (total == 0 ? 0 : (total / pageSize).ceil()),
  );
}

int _doctorConsultationUnreadCount(Object? response) {
  final root = _asMap(response);
  return _readInt(root['unreadCount']) ?? 0;
}

Map<String, dynamic> _unwrapMap(Object? response) {
  var value = _asMap(response);
  while (value.length <= 3 && value['data'] is Map) {
    value = Map<String, dynamic>.from(value['data'] as Map);
  }
  return value;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('接口响应不是对象');
}

List<Map<String, dynamic>> _mapList(List<dynamic> values) {
  return values
      .map((value) {
        if (value is! Map) throw const FormatException('列表项目不是对象');
        return Map<String, dynamic>.from(value);
      })
      .toList(growable: false);
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return value == null ? null : int.tryParse('$value');
}
