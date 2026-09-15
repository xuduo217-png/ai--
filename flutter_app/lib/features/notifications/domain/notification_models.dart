import 'dart:convert';

enum NotificationType {
  system('system'),
  announcement('announcement'),
  interaction('interaction'),
  unknown(null);

  const NotificationType(this.wireValue);

  final String? wireValue;

  static NotificationType fromWire(Object? value) {
    final wire = value is String ? value.trim().toLowerCase() : null;
    return NotificationType.values.firstWhere(
      (type) => type.wireValue != null && type.wireValue == wire,
      orElse: () => NotificationType.unknown,
    );
  }
}

enum NotificationActionType {
  none('none'),
  page('page'),
  url('url'),
  order('order'),
  appointment('appointment'),
  unknown(null);

  const NotificationActionType(this.wireValue);

  final String? wireValue;

  static NotificationActionType fromWire(Object? value) {
    final wire = value is String ? value.trim().toLowerCase() : null;
    return NotificationActionType.values.firstWhere(
      (type) => type.wireValue != null && type.wireValue == wire,
      orElse: () => NotificationActionType.unknown,
    );
  }
}

class NotificationAction {
  const NotificationAction({required this.type, this.data});

  factory NotificationAction.fromWire(Object? type, Object? data) {
    return NotificationAction(
      type: NotificationActionType.fromWire(type),
      data: _optionalActionData(data),
    );
  }

  final NotificationActionType type;
  final Map<String, Object?>? data;
}

class UserNotification {
  const UserNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.content,
    required this.isRead,
    required this.action,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    required this.readAt,
  });

  factory UserNotification.fromJson(Map<String, Object?> json) {
    return UserNotification(
      id: _requiredInt(json['id'], 'id'),
      userId: _requiredInt(json['userId'], 'userId'),
      type: NotificationType.fromWire(json['type']),
      title: _requiredString(json['title'], 'title'),
      content: _requiredString(json['content'], 'content'),
      isRead: _requiredBool(json['isRead'], 'isRead'),
      action: NotificationAction.fromWire(
        json['actionType'],
        json['actionData'],
      ),
      priority: _requiredInt(json['priority'], 'priority'),
      createdAt: _requiredTimestamp(json['createdAt'], 'createdAt'),
      updatedAt: _requiredTimestamp(json['updatedAt'], 'updatedAt'),
      readAt: _optionalTimestamp(json['readAt'], 'readAt'),
    );
  }

  final int id;
  final int userId;
  final NotificationType type;
  final String title;
  final String content;
  final bool isRead;
  final NotificationAction action;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;

  UserNotification withReadState({
    required bool isRead,
    required DateTime? readAt,
  }) {
    return UserNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      content: content,
      isRead: isRead,
      action: action,
      priority: priority,
      createdAt: createdAt,
      updatedAt: updatedAt,
      readAt: readAt,
    );
  }
}

class NotificationQuery {
  const NotificationQuery({this.page = 1, this.pageSize = 20, this.type})
    : assert(page > 0),
      assert(pageSize > 0);

  final int page;
  final int pageSize;
  final NotificationType? type;

  Map<String, Object?> toQueryParameters() => {
    'page': page,
    'pageSize': pageSize,
    'type': ?type?.wireValue,
  };
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<UserNotification> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => totalPages > 0 && page < totalPages;
}

abstract interface class NotificationGateway {
  Future<NotificationPage> loadNotifications([
    NotificationQuery query = const NotificationQuery(),
  ]);

  Future<int> loadUnreadCount();

  Future<UserNotification> loadNotificationDetail(int id);

  Future<void> markRead(int id);

  Future<int> markAllRead();
}

String formatNotificationTime(DateTime value, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = current.difference(value).isNegative
      ? Duration.zero
      : current.difference(value);
  final seconds = difference.inSeconds;
  final minutes = difference.inMinutes;
  final hours = difference.inHours;
  final days = difference.inDays;
  if (seconds < 60) return '刚刚';
  if (minutes < 60) return '$minutes分钟前';
  if (hours < 24) return '$hours小时前';
  if (days == 1) return '昨天';
  if (days < 7) return '$days天前';
  final local = value.toLocal();
  return '${local.month}月${local.day}日';
}

Map<String, Object?>? _optionalActionData(Object? value) {
  Object? decoded = value;
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    try {
      decoded = jsonDecode(normalized);
    } on FormatException {
      return null;
    }
  }
  if (decoded is! Map) return null;
  return decoded.map((key, item) => MapEntry('$key', item));
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

String _requiredString(Object? value, String label) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$label must be a non-empty string.');
}

bool _requiredBool(Object? value, String label) {
  if (value is bool) return value;
  throw FormatException('$label must be a boolean.');
}

DateTime _requiredTimestamp(Object? value, String label) {
  final milliseconds = _timestampMilliseconds(value);
  if (milliseconds == null) {
    throw FormatException('$label must be a timestamp.');
  }
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

DateTime? _optionalTimestamp(Object? value, String label) {
  if (value == null) return null;
  return _requiredTimestamp(value, label);
}

int? _timestampMilliseconds(Object? value) {
  final numeric = switch (value) {
    final int number => number,
    final num number when number.isFinite && number == number.roundToDouble() =>
      number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };
  if (numeric != null) {
    return numeric.abs() > 1000000000000 ? numeric : numeric * 1000;
  }
  if (value is String) {
    return DateTime.tryParse(value.trim())?.millisecondsSinceEpoch;
  }
  return null;
}
