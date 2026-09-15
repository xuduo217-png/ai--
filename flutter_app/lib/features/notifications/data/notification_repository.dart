import '../../../core/network/api_client.dart';
import '../domain/notification_models.dart';

class NotificationRepository implements NotificationGateway {
  const NotificationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<NotificationPage> loadNotifications([
    NotificationQuery query = const NotificationQuery(),
  ]) async {
    final response = await _apiClient.get(
      '/notifications',
      queryParameters: query.toQueryParameters(),
    );
    final responseRoot = _asMap(response, 'notifications response');
    final pageRoot = _notificationPageRoot(responseRoot);
    final data = pageRoot['data'];
    final pagination = _notificationPagination(responseRoot, pageRoot);
    if (data is! List) {
      throw const FormatException('notifications data must be a list.');
    }
    final total = _requiredInt(pagination['total'], 'total');
    final page = _requiredInt(pagination['page'], 'page');
    final pageSize = _requiredInt(
      pagination['pageSize'] ?? pagination['limit'],
      'pageSize',
    );
    final totalPages = _requiredInt(pagination['totalPages'], 'totalPages');
    if (total < 0 || page < 1 || pageSize < 1 || totalPages < 0) {
      throw const FormatException('notifications pagination is invalid.');
    }
    return NotificationPage(
      items: data
          .map(
            (item) =>
                UserNotification.fromJson(_asMap(item, 'notification item')),
          )
          .toList(growable: false),
      total: total,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
    );
  }

  @override
  Future<int> loadUnreadCount() async {
    final response = _asMap(
      await _apiClient.get('/notifications/unread-count'),
      'notification unread count',
    );
    final count = _requiredInt(response['count'], 'count');
    if (count < 0) {
      throw const FormatException('notification unread count is invalid.');
    }
    return count;
  }

  @override
  Future<UserNotification> loadNotificationDetail(int id) async {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'must be positive');
    final response = _asMap(
      await _apiClient.get('/notifications/$id'),
      'notification detail',
    );
    return UserNotification.fromJson(response);
  }

  @override
  Future<void> markRead(int id) async {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'must be positive');
    final response = _asMap(
      await _apiClient.put('/notifications/$id/read'),
      'mark notification read',
    );
    if (response['success'] != true) {
      throw const FormatException('mark notification read was not successful.');
    }
  }

  @override
  Future<int> markAllRead() async {
    final response = _asMap(
      await _apiClient.put('/notifications/read-all'),
      'mark all notifications read',
    );
    if (response['success'] != true) {
      throw const FormatException(
        'mark all notifications read was not successful.',
      );
    }
    final updatedCount = _requiredInt(response['updatedCount'], 'updatedCount');
    if (updatedCount < 0) {
      throw const FormatException('updatedCount must not be negative.');
    }
    return updatedCount;
  }
}

Map<String, Object?> _notificationPageRoot(Map<String, Object?> responseRoot) {
  var current = responseRoot;
  for (var depth = 0; depth < 4; depth += 1) {
    if (current['data'] is List) return current;
    final nested = current['data'];
    if (nested is! Map) return current;
    current = nested.map((key, item) => MapEntry('$key', item));
  }
  return current;
}

Map<String, Object?> _notificationPagination(
  Map<String, Object?> responseRoot,
  Map<String, Object?> pageRoot,
) {
  for (final value in [
    pageRoot['pagination'],
    pageRoot['meta'],
    pageRoot,
    responseRoot['pagination'],
    responseRoot['meta'],
    responseRoot,
  ]) {
    if (value is! Map) continue;
    final candidate = value.map((key, item) => MapEntry('$key', item));
    if (candidate.keys.any(_paginationFields.contains)) return candidate;
  }
  throw const FormatException('notifications pagination must be an object.');
}

const _paginationFields = {'total', 'page', 'pageSize', 'limit', 'totalPages'};

Map<String, Object?> _asMap(Object? value, String label) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('$label must be an object.');
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
