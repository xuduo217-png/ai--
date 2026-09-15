import '../../../core/network/api_client.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../domain/activity_models.dart';

class ActivityRepository implements ActivityGateway {
  const ActivityRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<ActivityPage> loadActivities({
    required bool authenticated,
    required ActivityStatus status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = _map(
      await _apiClient.get(
        '/activities/app',
        authenticated: authenticated,
        queryParameters: {
          'status': status.wireValue,
          'keyword': keyword.trim().isEmpty ? null : keyword.trim(),
          'page': page,
          'pageSize': pageSize,
        },
      ),
    );
    return _activityPage(response, fallbackPage: page, pageSize: pageSize);
  }

  @override
  Future<ActivityItem> loadActivityDetail(
    int activityId, {
    required bool authenticated,
  }) async {
    return _activity(
      _map(
        await _apiClient.get(
          '/activities/app/$activityId',
          authenticated: authenticated,
        ),
      ),
    );
  }

  @override
  Future<ActivityParticipantPage> loadActivityParticipants(
    int activityId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = _map(
      await _apiClient.get(
        '/activities/app/$activityId/participants',
        authenticated: authenticated,
        queryParameters: {'page': page, 'pageSize': pageSize},
      ),
    );
    final items = _list(response['data'])
        .whereType<Map>()
        .map((item) => _participant(_map(item)))
        .where((item) => item.userId > 0)
        .toList(growable: false);
    final pagination = _map(response['pagination']);
    return ActivityParticipantPage(
      items: items,
      total: _int(pagination['total'], items.length),
      page: _int(pagination['page'], page),
      pageSize: _int(pagination['pageSize'] ?? pagination['limit'], pageSize),
      totalPages: _totalPages(pagination, items.length, pageSize),
    );
  }

  @override
  Future<ActivityCommentPage> loadActivityComments(
    int activityId, {
    required bool authenticated,
    int? voteOptionId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final path = voteOptionId == null
        ? '/activities/app/$activityId/comments'
        : '/activities/app/$activityId/vote-options/$voteOptionId/comments';
    try {
      final response = _map(
        await _apiClient.get(
          path,
          authenticated: authenticated,
          queryParameters: {'page': page, 'pageSize': pageSize},
        ),
      );
      final items = _list(response['data'])
          .whereType<Map>()
          .map((item) => _comment(_map(item)))
          .where((item) => item.id > 0)
          .toList(growable: false);
      final pagination = _map(response['pagination']);
      return ActivityCommentPage(
        items: items,
        total: _int(pagination['total'], items.length),
        page: _int(pagination['page'], page),
        pageSize: _int(pagination['pageSize'] ?? pagination['limit'], pageSize),
        totalPages: _totalPages(pagination, items.length, pageSize),
      );
    } on ApiException catch (error) {
      if (error.message.contains('仅投票活动支持评论')) {
        return ActivityCommentPage(
          items: const [],
          total: 0,
          page: page,
          pageSize: pageSize,
          totalPages: 0,
        );
      }
      rethrow;
    }
  }

  @override
  Future<ActivityComment> createActivityComment(
    int activityId, {
    required String content,
    int? voteOptionId,
    int? parentId,
  }) async {
    final path = voteOptionId == null
        ? '/activities/app/$activityId/comments'
        : '/activities/app/$activityId/vote-options/$voteOptionId/comments';
    final response = _map(
      await _apiClient.post(
        path,
        authenticated: true,
        body: {'content': content.trim(), 'parentId': ?parentId},
      ),
    );
    return _comment(_map(response['data'] ?? response));
  }

  @override
  Future<ActivityActionResult<void>> registerActivity(
    int activityId, {
    required String phone,
  }) async {
    return _voidAction(
      await _apiClient.post(
        '/activities/app/$activityId/register',
        authenticated: true,
        body: {'phone': phone.trim()},
      ),
      fallbackMessage: '报名成功',
    );
  }

  @override
  Future<ActivityActionResult<void>> voteActivity(
    int activityId, {
    required int optionId,
  }) async {
    return _voidAction(
      await _apiClient.post(
        '/activities/app/$activityId/vote',
        authenticated: true,
        body: {'optionId': optionId},
      ),
      fallbackMessage: '投票成功',
    );
  }

  @override
  Future<ActivityActionResult<ActivityVoteOption>> createActivityVoteOption(
    int activityId,
    ActivityVoteOptionDraft draft,
  ) async {
    return _optionAction(
      await _apiClient.post(
        '/activities/app/$activityId/vote-options',
        authenticated: true,
        body: draft.toJson(),
      ),
      fallbackMessage: '报名成功',
    );
  }

  @override
  Future<ActivityActionResult<ActivityVoteOption>> updateActivityVoteOption(
    int activityId,
    int optionId,
    ActivityVoteOptionDraft draft,
  ) async {
    return _optionAction(
      await _apiClient.put(
        '/activities/app/$activityId/vote-options/$optionId',
        authenticated: true,
        body: draft.toJson(),
      ),
      fallbackMessage: '保存成功',
    );
  }

  @override
  Future<ActivityActionResult<void>> deleteActivityVoteOption(
    int activityId,
    int optionId,
  ) async {
    return _voidAction(
      await _apiClient.delete(
        '/activities/app/$activityId/vote-options/$optionId',
        authenticated: true,
      ),
      fallbackMessage: '删除成功',
    );
  }

  @override
  Future<ActivityMediaUpload> uploadActivityImage({
    required String filePath,
    String? filename,
  }) async {
    final response = _map(
      await _apiClient.uploadFile(
        '/upload/image',
        filePath: filePath,
        filename: filename,
        fields: const {'category': 'activity-vote-option'},
      ),
    );
    return ActivityMediaUpload(url: _asset(_string(response['url'])));
  }

  @override
  Future<ActivityMediaUpload> uploadActivityVideo({
    required String filePath,
    String? filename,
  }) async {
    final response = _map(
      await _apiClient.uploadVideo(
        '/upload/file',
        filePath: filePath,
        filename: filename,
        fields: const {'category': 'activity-vote-option-video'},
      ),
    );
    return ActivityMediaUpload(
      url: _asset(_string(response['url'])),
      thumbnailUrl: _asset(
        _string(response['thumbnail'] ?? response['videoCover']),
      ),
    );
  }

  @override
  Future<void> reportActivityContent({
    required String targetType,
    required int targetId,
    required String reason,
    String description = '',
  }) async {
    await _apiClient.post(
      '/moderation/reports',
      authenticated: true,
      body: {
        'targetType': targetType,
        'targetId': '$targetId',
        'reason': reason,
        if (description.trim().isNotEmpty) 'description': description.trim(),
      },
    );
  }

  @override
  Future<void> blockActivityUser(int userId, {String reason = ''}) async {
    await _apiClient.post(
      '/moderation/blocks',
      authenticated: true,
      body: {
        'blockedUserId': userId,
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  ActivityPage _activityPage(
    Map<String, Object?> response, {
    required int fallbackPage,
    required int pageSize,
  }) {
    final items = _list(response['data'])
        .whereType<Map>()
        .map((item) => _activity(_map(item)))
        .where((item) => item.id > 0)
        .toList(growable: false);
    final pagination = _map(response['pagination']);
    return ActivityPage(
      items: items,
      total: _int(pagination['total'], items.length),
      page: _int(pagination['page'], fallbackPage),
      pageSize: _int(pagination['pageSize'] ?? pagination['limit'], pageSize),
      totalPages: _totalPages(pagination, items.length, pageSize),
    );
  }

  ActivityItem _activity(Map<String, Object?> json) {
    final hospitalJson = _map(json['hospital']);
    final options =
        _list(json['voteOptions'])
            .whereType<Map>()
            .map((item) => _voteOption(_map(item)))
            .where((item) => item.id > 0)
            .toList(growable: false)
          ..sort((left, right) {
            final order = left.sortOrder.compareTo(right.sortOrder);
            return order == 0 ? left.id.compareTo(right.id) : order;
          });
    return ActivityItem(
      id: _int(json['id']),
      title: _string(json['title']),
      startTime: _dateTime(json['startTime']),
      endTime: _dateTime(json['endTime']),
      location: _string(json['location']),
      summary: _string(json['summary']),
      description: _string(json['description']),
      coverImageUrl: _asset(_string(json['coverImage'])),
      sharePosterImageUrl: _asset(_string(json['sharePosterImage'])),
      sharePosterTitle: _string(json['sharePosterTitle']),
      sharePosterDescription: _string(json['sharePosterDescription']),
      hospitalId: _int(json['hospitalId']),
      hospitalName: _string(
        json['hospitalName'],
        _string(hospitalJson['name']),
      ),
      registrationCount: _int(json['registrationCount']),
      status: ActivityStatus.fromWire(json['status']),
      activityType: ActivityType.fromWire(json['activityType']),
      voteOptions: options,
      isRegistered: _bool(json['isRegistered']),
      canRegister: json.containsKey('canRegister')
          ? _bool(json['canRegister'])
          : !_bool(json['isRegistered']),
      createdAt: _dateTime(json['createdAt']),
      updatedAt: _dateTime(json['updatedAt']),
      hospital: hospitalJson.isEmpty
          ? null
          : ActivityHospital(
              id: _int(hospitalJson['id']),
              name: _string(hospitalJson['name']),
              logoUrl: _asset(_string(hospitalJson['logo'])),
              address: _string(hospitalJson['address']),
              phone: _string(hospitalJson['phone']),
            ),
    );
  }

  ActivityVoteOption _voteOption(Map<String, Object?> json) {
    return ActivityVoteOption(
      id: _int(json['id']),
      activityId: _int(json['activityId']),
      imageUrl: _asset(_string(json['image'])),
      videoUrl: _asset(_string(json['video'])),
      videoCoverUrl: _asset(_string(json['videoCover'])),
      title: _string(json['title']),
      description: _string(json['description']),
      voteCount: _int(json['voteCount']),
      sortOrder: _int(json['sortOrder']),
      ownerUserId: _nullableInt(json['ownerUserId']),
    );
  }

  ActivityParticipant _participant(Map<String, Object?> json) {
    return ActivityParticipant(
      userId: _int(json['userId']),
      userName: _string(json['userName'], '匿名用户'),
      userAvatarUrl: _asset(_string(json['userAvatar'])),
      registeredAt: _dateTime(json['registeredAt']),
    );
  }

  ActivityComment _comment(Map<String, Object?> json) {
    final user = _map(json['user']);
    return ActivityComment(
      id: _int(json['id']),
      activityId: _int(json['activityId']),
      voteOptionId: _nullableInt(json['voteOptionId']),
      userId: _int(json['userId']),
      content: _string(json['content']),
      parentId: _nullableInt(json['parentId']),
      likeCount: _int(json['likeCount']),
      createdAt: _dateTime(json['createdAt']),
      user: user.isEmpty
          ? null
          : ActivityCommentUser(
              id: _int(user['id']),
              nickname: _string(user['nickname'], '匿名用户'),
              avatarUrl: _asset(_string(user['avatar'])),
            ),
      replies: _list(json['replies'])
          .whereType<Map>()
          .map((item) => _comment(_map(item)))
          .toList(growable: false),
    );
  }

  ActivityActionResult<void> _voidAction(
    Object? response, {
    required String fallbackMessage,
  }) {
    final json = _map(response);
    return ActivityActionResult<void>(
      success: json['success'] == null || _bool(json['success']),
      message: _string(json['message'], fallbackMessage),
    );
  }

  ActivityActionResult<ActivityVoteOption> _optionAction(
    Object? response, {
    required String fallbackMessage,
  }) {
    final json = _map(response);
    final data = _map(json['data']);
    return ActivityActionResult<ActivityVoteOption>(
      success: json['success'] == null || _bool(json['success']),
      message: _string(json['message'], fallbackMessage),
      data: data.isEmpty ? null : _voteOption(data),
    );
  }

  String _asset(String value) =>
      resolveAssetUrl(value, assetBaseUrl: _apiClient.baseUrl);
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

String _string(Object? value, [String fallback = '']) {
  final normalized = value == null ? '' : '$value'.trim();
  return normalized.isEmpty ? fallback : normalized;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  final parsed = _int(value);
  return parsed > 0 ? parsed : null;
}

bool _bool(Object? value) {
  return value == true || value == 1 || value == '1' || value == 'true';
}

DateTime? _dateTime(Object? value) {
  if (value == null) return null;
  if (value is num) {
    final milliseconds = value.abs() < 1000000000000
        ? value.toInt() * 1000
        : value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
  final numeric = int.tryParse('$value');
  if (numeric != null) return _dateTime(numeric);
  return DateTime.tryParse('$value')?.toLocal();
}

int _totalPages(Map<String, Object?> pagination, int itemCount, int pageSize) {
  final explicit = _int(pagination['totalPages']);
  if (explicit > 0) return explicit;
  final total = _int(pagination['total'], itemCount);
  return total == 0 ? 0 : (total / pageSize).ceil();
}
