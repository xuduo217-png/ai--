import '../../../core/network/api_client.dart';
import '../../pets/domain/pet_models.dart';
import '../domain/lost_found_models.dart';

class LostFoundRepository implements LostFoundGateway {
  const LostFoundRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<LostFoundPage> loadLostFoundRecords({
    required bool authenticated,
    LostFoundRecordType? recordType,
    bool? isFound,
    int? publisherId,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    final payload = _map(
      await _apiClient.get(
        '/lost-found',
        authenticated: authenticated,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (recordType != null) 'recordType': recordType.wireValue,
          'isFound': ?isFound,
          'publisherId': ?publisherId,
          if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        },
      ),
    );
    return _recordPage(payload, fallbackPage: page, pageSize: pageSize);
  }

  @override
  Future<LostFoundRecord> loadLostFoundRecord(
    int id, {
    required bool authenticated,
  }) async {
    final payload = await _apiClient.get(
      '/lost-found/$id',
      authenticated: authenticated,
    );
    return LostFoundRecord.fromJson(_map(payload));
  }

  @override
  Future<List<Pet>> loadLostFoundPets() async {
    final payload = await _apiClient.get('/pets/my');
    return _list(payload)
        .whereType<Map>()
        .map((item) => Pet.fromJson(_map(item)))
        .toList(growable: false);
  }

  @override
  Future<LostFoundRecord> createLostFoundRecord(LostFoundDraft draft) async {
    final payload = await _apiClient.post(
      '/lost-found',
      authenticated: true,
      body: draft.toJson(),
    );
    return LostFoundRecord.fromJson(_map(payload));
  }

  @override
  Future<LostFoundRecord> updateLostFoundRecord(
    int id,
    LostFoundDraft draft,
  ) async {
    final payload = await _apiClient.put(
      '/lost-found/$id',
      body: draft.toJson(),
    );
    return LostFoundRecord.fromJson(_map(payload));
  }

  @override
  Future<LostFoundRecord> markLostFoundRecordFound(int id) async {
    final payload = await _apiClient.patch('/lost-found/$id/found');
    return LostFoundRecord.fromJson(_map(payload));
  }

  @override
  Future<void> deleteLostFoundRecord(int id) async {
    await _apiClient.delete('/lost-found/$id');
  }

  @override
  Future<LostFoundCommentPage> loadLostFoundComments(
    int lostFoundId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) async {
    final payload = _map(
      await _apiClient.get(
        '/lost-found/$lostFoundId/comments',
        authenticated: authenticated,
        queryParameters: {'page': page, 'pageSize': pageSize},
      ),
    );
    final items = _list(payload['data'])
        .whereType<Map>()
        .map((item) => LostFoundComment.fromJson(_map(item)))
        .toList(growable: false);
    final pagination = _map(payload['pagination']);
    return LostFoundCommentPage(
      items: items,
      total: _int(pagination['total'], items.length),
      page: _int(pagination['page'], page),
      pageSize: _int(pagination['pageSize'] ?? pagination['limit'], pageSize),
      totalPages: _totalPages(pagination, items.length, pageSize),
    );
  }

  @override
  Future<LostFoundComment> createLostFoundComment(
    int lostFoundId, {
    required String content,
    int? parentId,
  }) async {
    final payload = await _apiClient.post(
      '/lost-found/$lostFoundId/comments',
      authenticated: true,
      body: {'content': content.trim(), 'parentId': ?parentId},
    );
    return LostFoundComment.fromJson(_map(payload));
  }

  @override
  Future<LostFoundMediaUpload> uploadLostFoundImage({
    required String filePath,
    String? filename,
  }) async {
    final payload = _map(
      await _apiClient.uploadFile(
        '/upload/image',
        filePath: filePath,
        filename: filename,
        fields: const {'category': 'lost-found'},
      ),
    );
    return LostFoundMediaUpload(url: _string(payload['url']));
  }

  @override
  Future<LostFoundMediaUpload> uploadLostFoundVideo({
    required String filePath,
    String? filename,
  }) async {
    final payload = _map(
      await _apiClient.uploadVideo(
        '/upload/file',
        filePath: filePath,
        filename: filename,
        fields: const {'category': 'lost-found-video'},
      ),
    );
    return LostFoundMediaUpload(
      url: _string(payload['url']),
      thumbnailUrl: _string(payload['thumbnail'] ?? payload['videoCover']),
    );
  }

  @override
  Future<void> reportLostFoundContent({
    required String targetType,
    required int targetId,
    required LostFoundReportReason reason,
    String description = '',
  }) async {
    await _apiClient.post(
      '/moderation/reports',
      authenticated: true,
      body: {
        'targetType': targetType,
        'targetId': '$targetId',
        'reason': reason.wireValue,
        if (description.trim().isNotEmpty) 'description': description.trim(),
      },
    );
  }

  @override
  Future<void> blockLostFoundUser(int userId, {String reason = ''}) async {
    await _apiClient.post(
      '/moderation/blocks',
      authenticated: true,
      body: {
        'blockedUserId': userId,
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }
}

LostFoundPage _recordPage(
  Map<String, Object?> payload, {
  required int fallbackPage,
  required int pageSize,
}) {
  final items = _list(payload['data'])
      .whereType<Map>()
      .map((item) => LostFoundRecord.fromJson(_map(item)))
      .toList(growable: false);
  final pagination = _map(payload['pagination']);
  return LostFoundPage(
    items: items,
    total: _int(pagination['total'], items.length),
    page: _int(pagination['page'], fallbackPage),
    pageSize: _int(pagination['pageSize'] ?? pagination['limit'], pageSize),
    totalPages: _totalPages(pagination, items.length, pageSize),
  );
}

int _totalPages(Map<String, Object?> pagination, int itemCount, int pageSize) {
  final explicit = _int(pagination['totalPages'], 0);
  if (explicit > 0) return explicit;
  final total = _int(pagination['total'], itemCount);
  return total == 0 ? 1 : (total / pageSize).ceil();
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _list(Object? value) {
  return value is List ? value.cast<Object?>() : const <Object?>[];
}

int _int(Object? value, int fallback) {
  return switch (value) {
    final int current => current,
    final num current => current.toInt(),
    _ => int.tryParse('$value') ?? fallback,
  };
}

String _string(Object? value) => value == null ? '' : '$value'.trim();
