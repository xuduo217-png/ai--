import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/notifications/domain/notification_models.dart';
import 'package:pet_hospital_flutter/features/notifications/presentation/notification_badge_controller.dart';
import 'package:pet_hospital_flutter/features/notifications/presentation/notification_list_controller.dart';

void main() {
  test('列表首拉、分页去重和刷新覆盖旧列表', () async {
    final gateway = _NotificationGateway()
      ..pages.add(_page([_notification(1), _notification(2)], totalPages: 2))
      ..pages.add(
        _page([_notification(2), _notification(3)], page: 2, totalPages: 2),
      )
      ..pages.add(_page([_notification(9)], totalPages: 1));
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(2);
    final controller = NotificationListController(
      gateway: gateway,
      badgeController: badge,
    );

    await controller.load();
    await controller.loadMore();
    expect(controller.notifications.map((item) => item.id), [1, 2, 3]);

    await controller.refresh();
    expect(controller.notifications.map((item) => item.id), [9]);
    expect(controller.hasMore, isFalse);
  });

  test('单条已读立即更新列表和角标，失败时完整回滚', () async {
    final mark = Completer<void>();
    final gateway = _NotificationGateway()
      ..pages.add(_page([_notification(1)], totalPages: 1))
      ..markReadFutures.add(mark.future);
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(1);
    final controller = NotificationListController(
      gateway: gateway,
      badgeController: badge,
    );
    await controller.load();

    final operation = controller.markNotificationRead(1);
    expect(controller.notifications.single.isRead, isTrue);
    expect(badge.value, 0);

    mark.completeError(StateError('offline'));
    expect(await operation, NotificationMutationResult.failed);
    expect(controller.notifications.single.isRead, isFalse);
    expect(badge.value, 1);
  });

  test('单条已读成功后保留乐观状态并请求服务端校准角标', () async {
    final gateway = _NotificationGateway()
      ..pages.add(_page([_notification(1)], totalPages: 1))
      ..markReadFutures.add(Future.value())
      ..unreadCounts.addAll([1, 0]);
    final badge = NotificationBadgeController(
      gateway: gateway,
      timerFactory: (_, _) => const _NoopPollHandle(),
    );
    await badge.start(7);
    final controller = NotificationListController(
      gateway: gateway,
      badgeController: badge,
    );
    await controller.load();

    expect(
      await controller.markNotificationRead(1),
      NotificationMutationResult.succeeded,
    );
    await _flush();

    expect(controller.notifications.single.isRead, isTrue);
    expect(badge.value, 0);
    expect(gateway.unreadCalls, 2);
    badge.deactivate();
  });

  test('写请求期间刷新列表后，写失败仍回滚角标且不覆盖刷新结果', () async {
    final mark = Completer<void>();
    final gateway = _NotificationGateway()
      ..pages.add(_page([_notification(1)], totalPages: 1))
      ..pages.add(_page([_notification(9)], totalPages: 1))
      ..markReadFutures.add(mark.future);
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(1);
    final controller = NotificationListController(
      gateway: gateway,
      badgeController: badge,
    );
    await controller.load();

    final operation = controller.markNotificationRead(1);
    await controller.refresh();
    mark.completeError(StateError('offline'));
    expect(await operation, NotificationMutationResult.failed);

    expect(controller.notifications.map((item) => item.id), [9]);
    expect(badge.value, 1);
  });

  test('全部已读失败恢复各项读取状态和原角标', () async {
    final markAll = Completer<int>();
    final gateway = _NotificationGateway()
      ..pages.add(
        _page([_notification(1), _notification(2, read: true)], totalPages: 1),
      )
      ..markAllFutures.add(markAll.future);
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(1);
    final controller = NotificationListController(
      gateway: gateway,
      badgeController: badge,
    );
    await controller.load();

    final operation = controller.markAllRead();
    expect(
      controller.notifications,
      everyElement(predicate<UserNotification>((item) => item.isRead)),
    );
    expect(badge.value, 0);

    markAll.completeError(StateError('offline'));
    expect(await operation, NotificationMutationResult.failed);
    expect(controller.notifications.map((item) => item.isRead), [false, true]);
    expect(badge.value, 1);
  });

  test('已读项不重复请求，重复提交会折叠', () async {
    final mark = Completer<void>();
    final gateway = _NotificationGateway()
      ..pages.add(
        _page([_notification(1), _notification(2, read: true)], totalPages: 1),
      )
      ..markReadFutures.add(mark.future);
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(1);
    final controller = NotificationListController(
      gateway: gateway,
      badgeController: badge,
    );
    await controller.load();

    expect(
      await controller.markNotificationRead(2),
      NotificationMutationResult.succeeded,
    );
    final first = controller.markNotificationRead(1);
    final duplicate = controller.markNotificationRead(1);
    expect(await duplicate, NotificationMutationResult.busy);
    expect(gateway.markReadIds, [1]);
    mark.complete();
    await first;
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

NotificationPage _page(
  List<UserNotification> items, {
  int page = 1,
  required int totalPages,
}) {
  return NotificationPage(
    items: items,
    total: items.length,
    page: page,
    pageSize: 20,
    totalPages: totalPages,
  );
}

UserNotification _notification(int id, {bool read = false}) => UserNotification(
  id: id,
  userId: 7,
  type: NotificationType.system,
  title: '通知 $id',
  content: '内容 $id',
  isRead: read,
  action: const NotificationAction(type: NotificationActionType.none),
  priority: 0,
  createdAt: DateTime(2026, 7, 25, 9),
  updatedAt: DateTime(2026, 7, 25, 9),
  readAt: read ? DateTime(2026, 7, 25, 10) : null,
);

class _NotificationGateway implements NotificationGateway {
  final List<NotificationPage> pages = [];
  final List<NotificationQuery> queries = [];
  final List<Future<void>> markReadFutures = [];
  final List<Future<int>> markAllFutures = [];
  final List<int> markReadIds = [];
  final List<int> unreadCounts = [];
  int unreadCalls = 0;

  @override
  Future<NotificationPage> loadNotifications([
    NotificationQuery query = const NotificationQuery(),
  ]) async {
    queries.add(query);
    return pages.removeAt(0);
  }

  @override
  Future<int> loadUnreadCount() async {
    unreadCalls += 1;
    return unreadCounts.removeAt(0);
  }

  @override
  Future<void> markRead(int id) {
    markReadIds.add(id);
    return markReadFutures.removeAt(0);
  }

  @override
  Future<int> markAllRead() => markAllFutures.removeAt(0);

  @override
  Future<UserNotification> loadNotificationDetail(int id) =>
      throw UnimplementedError();
}

class _NoopPollHandle implements NotificationPollHandle {
  const _NoopPollHandle();

  @override
  void cancel() {}
}
