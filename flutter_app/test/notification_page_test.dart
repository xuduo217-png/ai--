import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/notifications/domain/notification_models.dart';
import 'package:pet_hospital_flutter/features/notifications/presentation/notification_badge_controller.dart';
import 'package:pet_hospital_flutter/features/notifications/presentation/pages/notification_list_page.dart';

import 'support/wp11_viewports.dart';

void main() {
  for (final viewport in wp11Viewports) {
    testWidgets('通知页在 ${viewport.label} 展示 RN 核心信息且无溢出', (tester) async {
      configureWp11Viewport(tester, viewport);
      final gateway = _NotificationGateway()
        ..pages.add(
          _page([
            _notification(
              1,
              title: '一条标题很长但不会覆盖时间和未读标记的订单通知',
              action: const NotificationAction(
                type: NotificationActionType.order,
                data: {'orderId': 47},
              ),
            ),
            _notification(2, read: true, title: '系统维护通知'),
          ]),
        );
      final badge = NotificationBadgeController(gateway: gateway)
        ..setLocalCount(1);

      await tester.pumpWidget(
        MaterialApp(
          builder: wp11TextScaleBuilder(viewport.textScale),
          home: NotificationListPage(
            gateway: gateway,
            badgeController: badge,
            onAction: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFDEE9FF));
      expect(appBar.surfaceTintColor, const Color(0xFFDEE9FF));
      expect(appBar.foregroundColor, AppColors.ink);
      final markAllButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('notification-mark-all-button')),
      );
      expect(
        markAllButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColors.ink,
      );
      expect(find.text('通知消息'), findsOneWidget);
      expect(find.textContaining('一条标题很长'), findsOneWidget);
      expect(find.text('内容 1'), findsOneWidget);
      expect(find.text('系统维护通知'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notification-unread-dot-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification-unread-dot-2')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('未读状态通过语义文本表达而非仅依赖颜色和圆点', (tester) async {
    final semantics = tester.ensureSemantics();
    final gateway = _NotificationGateway()
      ..pages.add(_page([_notification(1), _notification(2, read: true)]));
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(1);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationListPage(
          gateway: gateway,
          badgeController: badge,
          onAction: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('未读，通知 1，内容 1'), findsOneWidget);
    expect(find.bySemanticsLabel('已读，通知 2，内容 2'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('点击未读项先乐观标记，服务端成功后再执行 action', (tester) async {
    final mark = Completer<void>();
    final actions = <NotificationAction>[];
    final gateway = _NotificationGateway()
      ..pages.add(
        _page([
          _notification(
            1,
            action: const NotificationAction(
              type: NotificationActionType.order,
              data: {'orderId': 47},
            ),
          ),
        ]),
      )
      ..markReadFutures.add(mark.future);
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(1);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationListPage(
          gateway: gateway,
          badgeController: badge,
          onAction: (action) async => actions.add(action),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notification-card-1')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('notification-unread-dot-1')),
      findsNothing,
    );
    expect(badge.value, 0);
    expect(actions, isEmpty);

    mark.complete();
    await tester.pumpAndSettle();
    expect(actions.single.type, NotificationActionType.order);
  });

  testWidgets('单条已读失败恢复未读视觉与角标并显示反馈', (tester) async {
    final mark = Completer<void>();
    final gateway = _NotificationGateway()
      ..pages.add(_page([_notification(1)]))
      ..markReadFutures.add(mark.future);
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(1);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationListPage(
          gateway: gateway,
          badgeController: badge,
          onAction: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-card-1')));
    await tester.pump();
    mark.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-unread-dot-1')),
      findsOneWidget,
    );
    expect(find.text('标记已读失败，请稍后重试'), findsOneWidget);
    expect(badge.value, 1);
  });

  testWidgets('全部已读需要确认，失败时恢复原状态', (tester) async {
    final markAll = Completer<int>();
    final gateway = _NotificationGateway()
      ..pages.add(_page([_notification(1), _notification(2)]))
      ..markAllFutures.add(markAll.future);
    final badge = NotificationBadgeController(gateway: gateway)
      ..setLocalCount(2);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationListPage(
          gateway: gateway,
          badgeController: badge,
          onAction: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('notification-mark-all-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('全部标为已读？'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('notification-mark-all-confirm')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('notification-unread-dot-1')),
      findsNothing,
    );
    expect(badge.value, 0);

    markAll.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('notification-unread-dot-1')),
      findsOneWidget,
    );
    expect(find.text('全部标记已读失败，请稍后重试'), findsOneWidget);
    expect(badge.value, 2);
  });

  testWidgets('首屏失败可重试并进入明确空态', (tester) async {
    final gateway = _NotificationGateway()
      ..loadError = StateError('offline')
      ..pages.add(_page(const []));
    final badge = NotificationBadgeController(gateway: gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationListPage(
          gateway: gateway,
          badgeController: badge,
          onAction: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('通知加载失败'), findsOneWidget);

    gateway.loadError = null;
    await tester.tap(find.byKey(const ValueKey('notification-retry')));
    await tester.pumpAndSettle();
    expect(find.text('暂无通知消息'), findsOneWidget);
  });

  testWidgets('首屏加载不阻止返回且迟到请求不触达已销毁页面', (tester) async {
    final pending = Completer<NotificationPage>();
    final gateway = _NotificationGateway()..pendingPage = pending.future;
    final badge = NotificationBadgeController(gateway: gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => NotificationListPage(
                    gateway: gateway,
                    badgeController: badge,
                    onAction: (_) async {},
                  ),
                ),
              ),
              child: const Text('打开通知'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开通知'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('打开通知'), findsOneWidget);

    pending.complete(_page(const []));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

NotificationPage _page(List<UserNotification> items) => NotificationPage(
  items: items,
  total: items.length,
  page: 1,
  pageSize: 20,
  totalPages: items.isEmpty ? 0 : 1,
);

UserNotification _notification(
  int id, {
  bool read = false,
  String? title,
  NotificationAction action = const NotificationAction(
    type: NotificationActionType.none,
  ),
}) => UserNotification(
  id: id,
  userId: 7,
  type: id.isEven ? NotificationType.announcement : NotificationType.system,
  title: title ?? '通知 $id',
  content: '内容 $id',
  isRead: read,
  action: action,
  priority: 0,
  createdAt: DateTime.now().subtract(Duration(minutes: id)),
  updatedAt: DateTime.now(),
  readAt: read ? DateTime.now() : null,
);

class _NotificationGateway implements NotificationGateway {
  final List<NotificationPage> pages = [];
  final List<Future<void>> markReadFutures = [];
  final List<Future<int>> markAllFutures = [];
  Object? loadError;
  Future<NotificationPage>? pendingPage;

  @override
  Future<NotificationPage> loadNotifications([
    NotificationQuery query = const NotificationQuery(),
  ]) async {
    if (pendingPage case final pending?) return pending;
    if (loadError case final error?) throw error;
    return pages.removeAt(0);
  }

  @override
  Future<void> markRead(int id) => markReadFutures.removeAt(0);

  @override
  Future<int> markAllRead() => markAllFutures.removeAt(0);

  @override
  Future<int> loadUnreadCount() async => 0;

  @override
  Future<UserNotification> loadNotificationDetail(int id) =>
      throw UnimplementedError();
}
