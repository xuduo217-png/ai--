import '../../../core/network/api_client.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../../activity/data/activity_repository.dart';
import '../../activity/domain/activity_models.dart';
import '../../agent/domain/agent_models.dart';
import '../../charity/data/charity_repository.dart';
import '../../charity/domain/charity_models.dart';
import '../../community/data/community_repository.dart';
import '../../community/domain/community_models.dart';
import '../../coupons/data/coupon_repository.dart';
import '../../coupons/domain/coupon_models.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../doctors/domain/doctor_models.dart';
import '../../emergency/data/emergency_repository.dart';
import '../../emergency/domain/emergency_models.dart';
import '../../health/data/health_repository.dart';
import '../../health/domain/health_models.dart';
import '../../lost_found/data/lost_found_repository.dart';
import '../../lost_found/domain/lost_found_models.dart';
import '../../nearby/data/nearby_repository.dart';
import '../../nearby/domain/nearby_models.dart';
import '../../pets/domain/pet_models.dart';
import '../domain/home_models.dart';

class HomeRepository
    implements
        HomeGateway,
        DoctorDirectoryGateway,
        EmergencyGateway,
        HealthGateway,
        NearbyGateway,
        CharityGateway,
        ActivityGateway,
        LostFoundGateway,
        CommunityGateway,
        CouponScanGateway,
        AgentGateway {
  HomeRepository(this._apiClient)
    : _activityRepository = ActivityRepository(_apiClient),
      _charityRepository = CharityRepository(_apiClient),
      _communityRepository = CommunityRepository(_apiClient),
      _couponRepository = CouponRepository(apiClient: _apiClient),
      _doctorRepository = DoctorRepository(_apiClient),
      _healthRepository = HealthRepository(_apiClient),
      _lostFoundRepository = LostFoundRepository(_apiClient),
      _nearbyRepository = NearbyRepository(_apiClient);

  final ApiClient _apiClient;
  final ActivityRepository _activityRepository;
  final CharityRepository _charityRepository;
  final CommunityRepository _communityRepository;
  final CouponRepository _couponRepository;
  final DoctorRepository _doctorRepository;
  final HealthRepository _healthRepository;
  final LostFoundRepository _lostFoundRepository;
  final NearbyRepository _nearbyRepository;

  EmergencyRepository get _emergencyRepository {
    return EmergencyRepository(_apiClient);
  }

  @override
  Future<AgentHomeContext> loadAgentHome() async {
    final response = await _apiClient.get('/agent/home');
    return AgentHomeContext.fromJson(_asMap(response));
  }

  @override
  Future<AgentRouteResult> routeAgentMessage(
    String message, {
    int? petId,
    String? sessionId,
  }) async {
    final response = await _apiClient.post(
      '/agent/route',
      authenticated: true,
      body: <String, Object?>{
        'message': message,
        'petId': ?petId,
        'sessionId': ?sessionId,
      },
    );
    return AgentRouteResult.fromJson(_asMap(response));
  }

  @override
  Future<CouponScanDetail> loadScanDetail(String claimCode) =>
      _couponRepository.loadScanDetail(claimCode);

  @override
  Future<void> claimByScanCode(String claimCode) =>
      _couponRepository.claimByScanCode(claimCode);

  @override
  Future<DoctorDirectoryPage> loadDoctors({
    required int page,
    required bool goldOnly,
  }) => _doctorRepository.loadDoctors(page: page, goldOnly: goldOnly);

  @override
  Future<DoctorProfile> loadDoctor(int doctorId) =>
      _doctorRepository.loadDoctor(doctorId);

  @override
  Future<EmergencyCenterConfig> loadEmergencyConfig() =>
      _emergencyRepository.loadEmergencyConfig();

  @override
  Future<List<AidGuide>> loadAidGuides({int? categoryId}) =>
      _emergencyRepository.loadAidGuides(categoryId: categoryId);

  @override
  Future<List<AidGuideCategory>> loadAidGuideCategories() =>
      _emergencyRepository.loadAidGuideCategories();

  @override
  Future<AidGuide> loadAidGuide(int guideId) =>
      _emergencyRepository.loadAidGuide(guideId);

  @override
  Future<List<NearbyHospital>> loadNearbyHospitals({
    required double latitude,
    required double longitude,
    int limit = 10,
  }) => _emergencyRepository.loadNearbyHospitals(
    latitude: latitude,
    longitude: longitude,
    limit: limit,
  );

  @override
  Future<List<Pet>> loadHealthPets() => _healthRepository.loadHealthPets();

  @override
  Future<PetHealthStats> loadPetHealthStats(int petId) =>
      _healthRepository.loadPetHealthStats(petId);

  @override
  Future<AppointmentPage> loadAppointments({
    required int petId,
    int page = 1,
    int pageSize = 20,
    HealthAppointmentType? type,
    HealthAppointmentStatus? status,
  }) => _healthRepository.loadAppointments(
    petId: petId,
    page: page,
    pageSize: pageSize,
    type: type,
    status: status,
  );

  @override
  Future<HealthAppointment> loadAppointment(int appointmentId) =>
      _healthRepository.loadAppointment(appointmentId);

  @override
  Future<HealthAppointment> createAppointment({
    required int petId,
    required int hospitalId,
    required HealthAppointmentType type,
    required String appointmentDate,
    required String timeSlot,
    String notes = '',
  }) => _healthRepository.createAppointment(
    petId: petId,
    hospitalId: hospitalId,
    type: type,
    appointmentDate: appointmentDate,
    timeSlot: timeSlot,
    notes: notes,
  );

  @override
  Future<void> cancelAppointment(int appointmentId) =>
      _healthRepository.cancelAppointment(appointmentId);

  @override
  Future<List<HealthHospital>> loadHealthHospitals() =>
      _healthRepository.loadHealthHospitals();

  @override
  Future<PetCarePlanState> loadCarePlan(int petId) =>
      _healthRepository.loadCarePlan(petId);

  @override
  Future<void> generateCarePlan(int petId) =>
      _healthRepository.generateCarePlan(petId);

  @override
  Future<List<SelfCheckList>> loadSelfCheckLists(int petId) =>
      _healthRepository.loadSelfCheckLists(petId);

  @override
  Future<AiDiagnosisConfig> loadAiDiagnosisConfig() =>
      _healthRepository.loadAiDiagnosisConfig();

  @override
  Future<String> uploadDiagnosisImage(String filePath) =>
      _healthRepository.uploadDiagnosisImage(filePath);

  @override
  Future<AiDiagnosisReport> createAiDiagnosisReport(AiDiagnosisDraft draft) =>
      _healthRepository.createAiDiagnosisReport(draft);

  @override
  Future<AiDiagnosisPage> loadAiDiagnosisReports({
    int? petId,
    int page = 1,
    int pageSize = 20,
  }) => _healthRepository.loadAiDiagnosisReports(
    petId: petId,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<AiDiagnosisReport> loadAiDiagnosisReport(int reportId) =>
      _healthRepository.loadAiDiagnosisReport(reportId);

  @override
  Future<List<HealthArticleCategory>> loadHealthArticleCategories() =>
      _healthRepository.loadHealthArticleCategories();

  @override
  Future<HealthArticlePage> loadHealthArticles({
    int? categoryId,
    int page = 1,
    int pageSize = 20,
  }) => _healthRepository.loadHealthArticles(
    categoryId: categoryId,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<HealthArticle> loadHealthArticle(int articleId) =>
      _healthRepository.loadHealthArticle(articleId);

  @override
  Future<ConsultationPage> loadHealthConsultations({
    int? doctorId,
    int page = 1,
    int pageSize = 20,
  }) => _healthRepository.loadHealthConsultations(
    doctorId: doctorId,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<NearbyLocationSettings> loadNearbySettings() =>
      _nearbyRepository.loadNearbySettings();

  @override
  Future<void> updateNearbyLocation(NearbyCoordinate location) =>
      _nearbyRepository.updateNearbyLocation(location);

  @override
  Future<NearbyUserPage> loadNearbyUsers({
    required NearbyCoordinate location,
    required NearbyDistanceRange distance,
    required int page,
    int pageSize = 20,
  }) => _nearbyRepository.loadNearbyUsers(
    location: location,
    distance: distance,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<bool> updateNearbyDiscovery(bool enabled) =>
      _nearbyRepository.updateNearbyDiscovery(enabled);

  @override
  Future<CharityPage> loadCharities({
    required bool authenticated,
    CharityStatus? status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) => _charityRepository.loadCharities(
    authenticated: authenticated,
    status: status,
    keyword: keyword,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<CharityActivity> loadCharityDetail(
    int charityId, {
    required bool authenticated,
  }) => _charityRepository.loadCharityDetail(
    charityId,
    authenticated: authenticated,
  );

  @override
  Future<CharityRecordPage> loadCharityRecords(
    int charityId, {
    int page = 1,
    int pageSize = 10,
  }) => _charityRepository.loadCharityRecords(
    charityId,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<CharityRecordPage> loadCharityDonations(
    int charityId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) => _charityRepository.loadCharityDonations(
    charityId,
    authenticated: authenticated,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<CharityCheckInResult> checkInCharity(int charityId) =>
      _charityRepository.checkInCharity(charityId);

  @override
  Future<double> loadCharityWalletBalance() =>
      _charityRepository.loadCharityWalletBalance();

  @override
  Future<CharityDonationResult> donateCharity(
    int charityId, {
    required double amount,
  }) => _charityRepository.donateCharity(charityId, amount: amount);

  @override
  Future<CharityDonationPayment> createCharityDonationPayment(
    int charityId, {
    required double amount,
    required String idempotencyKey,
  }) => _charityRepository.createCharityDonationPayment(
    charityId,
    amount: amount,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<CharityDonationPaymentStatus> loadCharityDonationPaymentStatus(
    String paymentNo,
  ) => _charityRepository.loadCharityDonationPaymentStatus(paymentNo);

  @override
  Future<ActivityPage> loadActivities({
    required bool authenticated,
    required ActivityStatus status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) => _activityRepository.loadActivities(
    authenticated: authenticated,
    status: status,
    keyword: keyword,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<ActivityItem> loadActivityDetail(
    int activityId, {
    required bool authenticated,
  }) => _activityRepository.loadActivityDetail(
    activityId,
    authenticated: authenticated,
  );

  @override
  Future<ActivityParticipantPage> loadActivityParticipants(
    int activityId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) => _activityRepository.loadActivityParticipants(
    activityId,
    authenticated: authenticated,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<ActivityCommentPage> loadActivityComments(
    int activityId, {
    required bool authenticated,
    int? voteOptionId,
    int page = 1,
    int pageSize = 20,
  }) => _activityRepository.loadActivityComments(
    activityId,
    authenticated: authenticated,
    voteOptionId: voteOptionId,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<ActivityComment> createActivityComment(
    int activityId, {
    required String content,
    int? voteOptionId,
    int? parentId,
  }) => _activityRepository.createActivityComment(
    activityId,
    content: content,
    voteOptionId: voteOptionId,
    parentId: parentId,
  );

  @override
  Future<ActivityActionResult<void>> registerActivity(
    int activityId, {
    required String phone,
  }) => _activityRepository.registerActivity(activityId, phone: phone);

  @override
  Future<ActivityActionResult<void>> voteActivity(
    int activityId, {
    required int optionId,
  }) => _activityRepository.voteActivity(activityId, optionId: optionId);

  @override
  Future<ActivityActionResult<ActivityVoteOption>> createActivityVoteOption(
    int activityId,
    ActivityVoteOptionDraft draft,
  ) => _activityRepository.createActivityVoteOption(activityId, draft);

  @override
  Future<ActivityActionResult<ActivityVoteOption>> updateActivityVoteOption(
    int activityId,
    int optionId,
    ActivityVoteOptionDraft draft,
  ) =>
      _activityRepository.updateActivityVoteOption(activityId, optionId, draft);

  @override
  Future<ActivityActionResult<void>> deleteActivityVoteOption(
    int activityId,
    int optionId,
  ) => _activityRepository.deleteActivityVoteOption(activityId, optionId);

  @override
  Future<ActivityMediaUpload> uploadActivityImage({
    required String filePath,
    String? filename,
  }) => _activityRepository.uploadActivityImage(
    filePath: filePath,
    filename: filename,
  );

  @override
  Future<ActivityMediaUpload> uploadActivityVideo({
    required String filePath,
    String? filename,
  }) => _activityRepository.uploadActivityVideo(
    filePath: filePath,
    filename: filename,
  );

  @override
  Future<void> reportActivityContent({
    required String targetType,
    required int targetId,
    required String reason,
    String description = '',
  }) => _activityRepository.reportActivityContent(
    targetType: targetType,
    targetId: targetId,
    reason: reason,
    description: description,
  );

  @override
  Future<void> blockActivityUser(int userId, {String reason = ''}) =>
      _activityRepository.blockActivityUser(userId, reason: reason);

  @override
  Future<LostFoundPage> loadLostFoundRecords({
    required bool authenticated,
    LostFoundRecordType? recordType,
    bool? isFound,
    int? publisherId,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) => _lostFoundRepository.loadLostFoundRecords(
    authenticated: authenticated,
    recordType: recordType,
    isFound: isFound,
    publisherId: publisherId,
    keyword: keyword,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<LostFoundRecord> loadLostFoundRecord(
    int id, {
    required bool authenticated,
  }) => _lostFoundRepository.loadLostFoundRecord(
    id,
    authenticated: authenticated,
  );

  @override
  Future<List<Pet>> loadLostFoundPets() =>
      _lostFoundRepository.loadLostFoundPets();

  @override
  Future<LostFoundRecord> createLostFoundRecord(LostFoundDraft draft) =>
      _lostFoundRepository.createLostFoundRecord(draft);

  @override
  Future<LostFoundRecord> updateLostFoundRecord(int id, LostFoundDraft draft) =>
      _lostFoundRepository.updateLostFoundRecord(id, draft);

  @override
  Future<LostFoundRecord> markLostFoundRecordFound(int id) =>
      _lostFoundRepository.markLostFoundRecordFound(id);

  @override
  Future<void> deleteLostFoundRecord(int id) =>
      _lostFoundRepository.deleteLostFoundRecord(id);

  @override
  Future<LostFoundCommentPage> loadLostFoundComments(
    int lostFoundId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) => _lostFoundRepository.loadLostFoundComments(
    lostFoundId,
    authenticated: authenticated,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<LostFoundComment> createLostFoundComment(
    int lostFoundId, {
    required String content,
    int? parentId,
  }) => _lostFoundRepository.createLostFoundComment(
    lostFoundId,
    content: content,
    parentId: parentId,
  );

  @override
  Future<LostFoundMediaUpload> uploadLostFoundImage({
    required String filePath,
    String? filename,
  }) => _lostFoundRepository.uploadLostFoundImage(
    filePath: filePath,
    filename: filename,
  );

  @override
  Future<LostFoundMediaUpload> uploadLostFoundVideo({
    required String filePath,
    String? filename,
  }) => _lostFoundRepository.uploadLostFoundVideo(
    filePath: filePath,
    filename: filename,
  );

  @override
  Future<void> reportLostFoundContent({
    required String targetType,
    required int targetId,
    required LostFoundReportReason reason,
    String description = '',
  }) => _lostFoundRepository.reportLostFoundContent(
    targetType: targetType,
    targetId: targetId,
    reason: reason,
    description: description,
  );

  @override
  Future<void> blockLostFoundUser(int userId, {String reason = ''}) =>
      _lostFoundRepository.blockLostFoundUser(userId, reason: reason);

  @override
  Future<CommunityPage<CommunityPost>> loadCommunityPosts({
    required bool authenticated,
    required CommunityFeedType type,
    int page = 1,
    int pageSize = 10,
    String tag = '',
  }) => _communityRepository.loadCommunityPosts(
    authenticated: authenticated,
    type: type,
    page: page,
    pageSize: pageSize,
    tag: tag,
  );

  @override
  Future<CommunityPost> loadCommunityPost(
    int postId, {
    required bool authenticated,
  }) => _communityRepository.loadCommunityPost(
    postId,
    authenticated: authenticated,
  );

  @override
  Future<CommunityPost> createCommunityPost(CommunityPostDraft draft) =>
      _communityRepository.createCommunityPost(draft);

  @override
  Future<CommunityPost> updateCommunityPost(
    int postId,
    CommunityPostDraft draft,
  ) => _communityRepository.updateCommunityPost(postId, draft);

  @override
  Future<void> deleteCommunityPost(int postId) =>
      _communityRepository.deleteCommunityPost(postId);

  @override
  Future<List<CommunityPost>> loadCommunityUserPosts(
    int userId, {
    required bool authenticated,
  }) => _communityRepository.loadCommunityUserPosts(
    userId,
    authenticated: authenticated,
  );

  @override
  Future<CommunityProfile> loadCommunityProfile(
    int userId, {
    required bool authenticated,
  }) => _communityRepository.loadCommunityProfile(
    userId,
    authenticated: authenticated,
  );

  @override
  Future<CommunityProfile> updateCommunityProfile({
    required String bio,
    String coverImageUrl = '',
  }) => _communityRepository.updateCommunityProfile(
    bio: bio,
    coverImageUrl: coverImageUrl,
  );

  @override
  Future<CommunityRelationship> followCommunityUser(int userId) =>
      _communityRepository.followCommunityUser(userId);

  @override
  Future<CommunityRelationship> unfollowCommunityUser(int userId) =>
      _communityRepository.unfollowCommunityUser(userId);

  @override
  Future<CommunityPage<CommunityRelationUser>> loadCommunityConnections({
    required int userId,
    required CommunityConnectionType type,
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
    String keyword = '',
  }) => _communityRepository.loadCommunityConnections(
    userId: userId,
    type: type,
    authenticated: authenticated,
    page: page,
    pageSize: pageSize,
    keyword: keyword,
  );

  @override
  Future<void> likeCommunityPost(int postId) =>
      _communityRepository.likeCommunityPost(postId);

  @override
  Future<void> unlikeCommunityPost(int postId) =>
      _communityRepository.unlikeCommunityPost(postId);

  @override
  Future<CommunityPage<CommunityComment>> loadCommunityComments(
    int postId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
  }) => _communityRepository.loadCommunityComments(
    postId,
    authenticated: authenticated,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<CommunityComment> createCommunityComment(
    int postId, {
    required String content,
    int? parentId,
  }) => _communityRepository.createCommunityComment(
    postId,
    content: content,
    parentId: parentId,
  );

  @override
  Future<void> deleteCommunityComment(int commentId) =>
      _communityRepository.deleteCommunityComment(commentId);

  @override
  Future<void> likeCommunityComment(int commentId) =>
      _communityRepository.likeCommunityComment(commentId);

  @override
  Future<void> unlikeCommunityComment(int commentId) =>
      _communityRepository.unlikeCommunityComment(commentId);

  @override
  Future<List<CommunityTag>> loadCommunityHotTags() =>
      _communityRepository.loadCommunityHotTags();

  @override
  Future<List<CommunityTag>> searchCommunityTags(String keyword) =>
      _communityRepository.searchCommunityTags(keyword);

  @override
  Future<CommunityMediaUpload> uploadCommunityImage({
    required String filePath,
    String? filename,
    String category = 'community-post',
  }) => _communityRepository.uploadCommunityImage(
    filePath: filePath,
    filename: filename,
    category: category,
  );

  @override
  Future<CommunityMediaUpload> uploadCommunityVideo({
    required String filePath,
    String? filename,
  }) => _communityRepository.uploadCommunityVideo(
    filePath: filePath,
    filename: filename,
  );

  @override
  Future<void> reportCommunityContent({
    required String targetType,
    required int targetId,
    required String reason,
    String description = '',
  }) => _communityRepository.reportCommunityContent(
    targetType: targetType,
    targetId: targetId,
    reason: reason,
    description: description,
  );

  @override
  Future<void> blockCommunityUser(int userId, {String reason = ''}) =>
      _communityRepository.blockCommunityUser(userId, reason: reason);

  @override
  Future<List<CommunityBlockItem>> loadCommunityBlockedUsers() =>
      _communityRepository.loadCommunityBlockedUsers();

  @override
  Future<void> unblockCommunityUser(int userId) =>
      _communityRepository.unblockCommunityUser(userId);

  @override
  Future<HomeSnapshot> loadHome({required bool authenticated}) async {
    final results = await Future.wait<Object>([
      _withFallback(_loadMenuIcons, const <String, String>{}),
      _withFallback(_loadBannerImage, ''),
      _withFallback(_loadScrollingAnnouncement, ''),
      _withFallback(_loadDoctors, const <HomeDoctor>[]),
      _withFallback(_loadActivities, const <HomeActivity>[]),
    ]);

    return HomeSnapshot(
      menuIcons: results[0] as Map<String, String>,
      bannerImageUrl: results[1] as String,
      scrollingAnnouncement: results[2] as String,
      doctors: results[3] as List<HomeDoctor>,
      activities: results[4] as List<HomeActivity>,
    );
  }

  Future<T> _withFallback<T>(Future<T> Function() request, T fallback) async {
    try {
      return await request();
    } on Object {
      return fallback;
    }
  }

  Future<Map<String, String>> _loadMenuIcons() async {
    final payload = _asMap(
      await _apiClient.get(
        '/system-configs/home_menu_icons',
        authenticated: false,
      ),
    );
    final configValue = _asMapOrEmpty(payload['configValue']);
    final icons = _asMapOrEmpty(configValue['icons']);

    return {
      for (final entry in icons.entries)
        if (entry.key.trim().isNotEmpty && '${entry.value}'.trim().isNotEmpty)
          entry.key: _imageUrl('${entry.value}'),
    };
  }

  Future<String> _loadBannerImage() async {
    final payload = _asMap(
      await _apiClient.get(
        '/system-configs/home_ai_diagnosis_banner',
        authenticated: false,
      ),
    );
    final configValue = _asMapOrEmpty(payload['configValue']);
    return _imageUrl('${configValue['imageUrl'] ?? ''}');
  }

  Future<String> _loadScrollingAnnouncement() async {
    final payload = _asMap(
      await _apiClient.get(
        '/system-configs/scrolling_announcement',
        authenticated: false,
      ),
    );
    final configValue = _asMapOrEmpty(payload['configValue']);
    final source = '${configValue['source'] ?? 'fixed'}'.trim().toLowerCase();
    if (source == 'disabled') return '';
    if (source == 'donation') return _loadLatestDonationAnnouncement();

    return _normalizeSingleLineText('${configValue['announcementText'] ?? ''}');
  }

  Future<String> _loadLatestDonationAnnouncement() async {
    final payload = await _apiClient.get(
      '/charity/latest-donations',
      authenticated: false,
    );
    final records = _asList(payload);
    final announcements = records
        .map((item) {
          final record = _asMap(item);
          final userName = _normalizeSingleLineText(
            '${record['userName'] ?? '爱心人士'}',
          );
          final amount = _formatDonationAmount(record['donationAmount']);
          final sourceText = record['donationSource'] == 'mall_order'
              ? '在商城下单公益捐赠'
              : '公益捐赠';
          return '${userName.isEmpty ? '爱心人士' : userName}$sourceText$amount元';
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return announcements.join('    ');
  }

  Future<List<HomeDoctor>> _loadDoctors() async {
    final payload = await _apiClient.get(
      '/doctors',
      authenticated: false,
      queryParameters: const {
        'isGoldDoctor': 1,
        'isActive': 1,
        'pageSize': 3,
        'sortBy': 'rating',
        'sortOrder': 'DESC',
      },
    );

    return _asList(payload)
        .map((item) {
          final doctor = _asMap(item);
          final serviceItems = _asList(doctor['serviceItems']);
          final firstService = serviceItems.isEmpty
              ? const <String, dynamic>{}
              : _asMap(serviceItems.first);
          final price =
              firstService['price'] ?? doctor['consultationPrice'] ?? 0;

          return HomeDoctor(
            id: _toInt(doctor['id']),
            name: '${doctor['name'] ?? ''}',
            avatarUrl: _imageUrl('${doctor['avatar'] ?? ''}'),
            specialty: '${doctor['specialty'] ?? ''}',
            experience: _toInt(doctor['experience']),
            price: '$price',
            isGold: _toBool(doctor['isGoldDoctor']),
            username: '${doctor['username'] ?? ''}',
          );
        })
        .toList(growable: false);
  }

  Future<List<HomeActivity>> _loadActivities() async {
    final payload = await _apiClient.get(
      '/activities/app',
      authenticated: false,
      queryParameters: const {'showOnHome': true, 'page': 1, 'pageSize': 5},
    );

    return _asList(payload)
        .map((item) {
          final activity = _asMap(item);
          return HomeActivity(
            id: _toInt(activity['id']),
            title: '${activity['title'] ?? ''}',
            coverImageUrl: _imageUrl('${activity['coverImage'] ?? ''}'),
            status: '${activity['status'] ?? 'UPCOMING'}',
            activityType: '${activity['activityType'] ?? 'OFFLINE'}',
          );
        })
        .where((activity) => activity.id > 0)
        .toList(growable: false);
  }

  String _imageUrl(String value) {
    return resolveAssetUrl(value, assetBaseUrl: _apiClient.baseUrl);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('服务器返回的数据格式不正确');
  }

  Map<String, dynamic> _asMapOrEmpty(Object? value) {
    try {
      return _asMap(value);
    } on FormatException {
      return const {};
    }
  }

  List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    if (value is Map) {
      final data = value['data'];
      if (data is List) return data;
    }
    return const [];
  }

  int _toInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  String _formatDonationAmount(Object? value) {
    final amount = double.tryParse('$value');
    if (amount == null || !amount.isFinite || amount <= 0) return '0';
    final formatted = amount.toStringAsFixed(2);
    if (formatted.endsWith('.00')) {
      return formatted.substring(0, formatted.length - 3);
    }
    if (formatted.endsWith('0')) {
      return formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  String _normalizeSingleLineText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _toBool(Object? value) =>
      value == true || value == 1 || value == '1' || value == 'true';
}
