import '../../../core/network/api_client.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../../pets/domain/pet_models.dart';
import '../domain/health_models.dart';

class HealthRepository implements HealthGateway {
  const HealthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<Pet>> loadHealthPets() async {
    final response = await _apiClient.get('/pets/my');
    return healthJsonList(response)
        .map((item) => Pet.fromJson(healthJsonMap(item, 'pet list item')))
        .toList(growable: false);
  }

  @override
  Future<PetHealthStats> loadPetHealthStats(int petId) async {
    return PetHealthStats.fromJson(
      await _apiClient.get('/pets/$petId/health-stats'),
    );
  }

  @override
  Future<AppointmentPage> loadAppointments({
    required int petId,
    int page = 1,
    int pageSize = 20,
    HealthAppointmentType? type,
    HealthAppointmentStatus? status,
  }) async {
    final response = await _apiClient.get(
      '/health-appointments/pet/$petId',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'type': type?.wireValue,
        'status': status?.wireValue,
      },
    );
    return AppointmentPage(
      items: healthJsonList(
        response,
      ).map(HealthAppointment.fromJson).toList(growable: false),
      page: _paginationInt(response, 'page', page),
      totalPages: _paginationInt(response, 'totalPages', 1),
      total: _paginationInt(response, 'total', healthJsonList(response).length),
    );
  }

  @override
  Future<HealthAppointment> loadAppointment(int appointmentId) async {
    return HealthAppointment.fromJson(
      await _apiClient.get('/health-appointments/$appointmentId'),
    );
  }

  @override
  Future<HealthAppointment> createAppointment({
    required int petId,
    required int hospitalId,
    required HealthAppointmentType type,
    required String appointmentDate,
    required String timeSlot,
    String notes = '',
  }) async {
    return HealthAppointment.fromJson(
      await _apiClient.post(
        '/health-appointments',
        authenticated: true,
        body: {
          'petId': petId,
          'hospitalId': hospitalId,
          'type': type.wireValue,
          'appointmentDate': appointmentDate,
          'timeSlot': timeSlot,
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      ),
    );
  }

  @override
  Future<void> cancelAppointment(int appointmentId) async {
    await _apiClient.patch('/health-appointments/$appointmentId/cancel');
  }

  @override
  Future<List<HealthHospital>> loadHealthHospitals() async {
    final response = await _apiClient.get(
      '/hospitals',
      authenticated: false,
      queryParameters: const {'page': 1, 'pageSize': 100},
    );
    return healthJsonList(
      response,
    ).map(HealthHospital.fromJson).toList(growable: false);
  }

  @override
  Future<PetCarePlanState> loadCarePlan(int petId) async {
    return PetCarePlanState.fromJson(await _apiClient.get('/pets/$petId'));
  }

  @override
  Future<void> generateCarePlan(int petId) async {
    await _apiClient.post('/pets/$petId/care-plan', authenticated: true);
  }

  @override
  Future<List<SelfCheckList>> loadSelfCheckLists(int petId) async {
    final response = await _apiClient.get('/ai-self-check/lists/by-pet/$petId');
    return healthJsonList(
      response,
    ).map(SelfCheckList.fromJson).toList(growable: false);
  }

  @override
  Future<AiDiagnosisConfig> loadAiDiagnosisConfig() async {
    try {
      return AiDiagnosisConfig.fromJson(
        await _apiClient.get(
          '/system-configs/ai_diagnosis_config',
          authenticated: false,
        ),
      );
    } on Object {
      return AiDiagnosisConfig.fallback;
    }
  }

  @override
  Future<String> uploadDiagnosisImage(String filePath) async {
    final response = healthJsonMap(
      await _apiClient.uploadFile(
        '/upload/image',
        filePath: filePath,
        fields: const {'category': 'ai-diagnosis'},
      ),
      'diagnosis image upload',
    );
    final url = healthString(response['url']);
    if (url.isEmpty) throw const FormatException('upload url is empty.');
    return _imageUrl(url);
  }

  @override
  Future<AiDiagnosisReport> createAiDiagnosisReport(
    AiDiagnosisDraft draft,
  ) async {
    return AiDiagnosisReport.fromJson(
      await _apiClient.post(
        '/ai-diagnosis-reports',
        authenticated: true,
        body: draft.toJson(),
      ),
    );
  }

  @override
  Future<AiDiagnosisPage> loadAiDiagnosisReports({
    int? petId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/ai-diagnosis-reports',
      queryParameters: {'petId': petId, 'page': page, 'pageSize': pageSize},
    );
    final items = healthJsonList(
      response,
    ).map(AiDiagnosisReport.fromJson).toList(growable: false);
    return AiDiagnosisPage(
      items: items,
      page: _paginationInt(response, 'page', page),
      totalPages: _paginationInt(response, 'totalPages', 1),
      total: _paginationInt(response, 'total', items.length),
    );
  }

  @override
  Future<AiDiagnosisReport> loadAiDiagnosisReport(int reportId) async {
    return AiDiagnosisReport.fromJson(
      await _apiClient.get('/ai-diagnosis-reports/$reportId'),
    );
  }

  @override
  Future<List<HealthArticleCategory>> loadHealthArticleCategories() async {
    final response = await _apiClient.get(
      '/health-articles/categories',
      queryParameters: const {'isActive': true},
    );
    return healthJsonList(
      response,
    ).map(HealthArticleCategory.fromJson).toList(growable: false);
  }

  @override
  Future<HealthArticlePage> loadHealthArticles({
    int? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/health-articles',
      queryParameters: {
        'categoryId': categoryId,
        'page': page,
        'pageSize': pageSize,
        'status': 'PUBLISHED',
      },
    );
    final items = healthJsonList(
      response,
    ).map(HealthArticle.fromJson).toList(growable: false);
    return HealthArticlePage(
      items: items,
      page: _paginationInt(response, 'page', page),
      totalPages: _paginationInt(response, 'totalPages', 1),
      total: _paginationInt(response, 'total', items.length),
    );
  }

  @override
  Future<HealthArticle> loadHealthArticle(int articleId) async {
    return HealthArticle.fromJson(
      await _apiClient.get('/health-articles/$articleId'),
    );
  }

  @override
  Future<ConsultationPage> loadHealthConsultations({
    int? doctorId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final doctorFilter = doctorId == null
        ? const <String, Object?>{}
        : <String, Object?>{'doctorId': doctorId};
    final response = await _apiClient.get(
      '/chat/history-consultations',
      queryParameters: {'page': page, 'limit': pageSize, ...doctorFilter},
    );
    final items = healthJsonList(response)
        .map((item) {
          final consultation = HealthConsultation.fromJson(item);
          return HealthConsultation(
            id: consultation.id,
            doctorId: consultation.doctorId,
            doctorName: consultation.doctorName,
            doctorAvatarUrl: _imageUrl(consultation.doctorAvatarUrl),
            status: consultation.status,
            paidAt: consultation.paidAt,
            serviceStartAt: consultation.serviceStartAt,
            serviceEndAt: consultation.serviceEndAt,
            lastMessage: consultation.lastMessage,
            lastMessageAt: consultation.lastMessageAt,
          );
        })
        .toList(growable: false);
    return ConsultationPage(
      items: items,
      page: _paginationInt(response, 'page', page),
      totalPages: _paginationInt(response, 'totalPages', 1),
      total: _paginationInt(response, 'total', items.length),
    );
  }

  int _paginationInt(Object? response, String key, int fallback) {
    final root = healthJsonMapOrEmpty(response);
    final pagination = healthJsonMapOrEmpty(root['pagination']);
    return healthNullableInt(pagination[key] ?? root[key]) ?? fallback;
  }

  String _imageUrl(String value) {
    return resolveAssetUrl(value, assetBaseUrl: _apiClient.baseUrl);
  }
}
