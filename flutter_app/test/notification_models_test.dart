import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/notifications/domain/notification_models.dart';

void main() {
  group('UserNotification', () {
    for (final testCase in const [
      ('system', NotificationType.system),
      ('announcement', NotificationType.announcement),
      ('interaction', NotificationType.interaction),
      ('future_type', NotificationType.unknown),
    ]) {
      test('解析通知类型 ${testCase.$1}', () {
        final notification = UserNotification.fromJson(
          _notificationJson(type: testCase.$1),
        );
        expect(notification.type, testCase.$2);
      });
    }

    for (final testCase in const [
      ('none', NotificationActionType.none),
      ('page', NotificationActionType.page),
      ('url', NotificationActionType.url),
      ('order', NotificationActionType.order),
      ('appointment', NotificationActionType.appointment),
      ('future_action', NotificationActionType.unknown),
    ]) {
      test('解析 action 类型 ${testCase.$1}', () {
        final notification = UserNotification.fromJson(
          _notificationJson(actionType: testCase.$1),
        );
        expect(notification.action.type, testCase.$2);
      });
    }

    test('解析三类通知、毫秒时间戳和 Map actionData', () {
      final notification = UserNotification.fromJson(
        _notificationJson(
          type: 'interaction',
          actionType: 'order',
          actionData: {'orderId': '47'},
        ),
      );

      expect(notification.id, 12);
      expect(notification.type, NotificationType.interaction);
      expect(notification.action.type, NotificationActionType.order);
      expect(notification.action.data, {'orderId': '47'});
      expect(notification.createdAt.millisecondsSinceEpoch, 1784941200000);
      expect(notification.readAt, isNull);
    });

    test('actionData 兼容 JSON 字符串，畸形值安全降级为空', () {
      final jsonAction = UserNotification.fromJson(
        _notificationJson(
          actionType: 'page',
          actionData: '{"path":"ProductDetail","id":9}',
        ),
      );
      final malformedAction = UserNotification.fromJson(
        _notificationJson(actionType: 'mystery', actionData: '[1,2]'),
      );

      expect(jsonAction.action.type, NotificationActionType.page);
      expect(jsonAction.action.data, {'path': 'ProductDetail', 'id': 9});
      expect(malformedAction.action.type, NotificationActionType.unknown);
      expect(malformedAction.action.data, isNull);
    });

    test('未知通知类型降级，必填字段漂移仍抛出格式异常', () {
      final notification = UserNotification.fromJson(
        _notificationJson(type: 'future_type'),
      );
      expect(notification.type, NotificationType.unknown);

      expect(
        () => UserNotification.fromJson(
          _notificationJson()..['createdAt'] = 'not-a-time',
        ),
        throwsFormatException,
      );
    });
  });

  test('相对时间与 RN 阈值保持一致', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1784944800000);
    expect(
      formatNotificationTime(
        now.subtract(const Duration(seconds: 10)),
        now: now,
      ),
      '刚刚',
    );
    expect(
      formatNotificationTime(
        now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      '5分钟前',
    );
    expect(
      formatNotificationTime(now.subtract(const Duration(hours: 3)), now: now),
      '3小时前',
    );
    expect(
      formatNotificationTime(now.subtract(const Duration(days: 1)), now: now),
      '昨天',
    );
    expect(
      formatNotificationTime(now.subtract(const Duration(days: 4)), now: now),
      '4天前',
    );
    expect(formatNotificationTime(DateTime(2026, 7, 1), now: now), '7月1日');
  });
}

Map<String, Object?> _notificationJson({
  String type = 'system',
  String actionType = 'none',
  Object? actionData,
}) {
  return {
    'id': '12',
    'userId': 7,
    'type': type,
    'title': '订单状态更新',
    'content': '订单已经发货',
    'isRead': false,
    'actionType': actionType,
    'actionData': actionData,
    'priority': 1,
    'createdAt': '1784941200000',
    'updatedAt': 1784941201000,
    'readAt': null,
  };
}
