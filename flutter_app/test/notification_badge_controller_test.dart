import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/notifications/domain/notification_models.dart';
import 'package:pet_hospital_flutter/features/notifications/presentation/notification_badge_controller.dart';

void main() {
  test('登录首拉、60 秒轮询、暂停和恢复即时刷新', () async {
    final gateway = _NotificationGateway()..unreadCounts.addAll([3, 4, 5]);
    final timers = _FakePollFactory();
    final controller = NotificationBadgeController(
      gateway: gateway,
      timerFactory: timers.call,
    );

    await controller.start(7);
    expect(controller.value, 3);
    expect(gateway.unreadCalls, 1);
    expect(timers.intervals, [const Duration(seconds: 60)]);

    timers.active.single.fire();
    await _flush();
    expect(controller.value, 4);

    controller.pause();
    expect(timers.created.first.cancelled, isTrue);
    timers.created.first.fire();
    await _flush();
    expect(gateway.unreadCalls, 2);

    await controller.resume();
    expect(controller.value, 5);
    expect(gateway.unreadCalls, 3);
    expect(timers.active, hasLength(1));
  });

  test('退出重置角标并忽略旧账号迟到响应', () async {
    final stale = Completer<int>();
    final gateway = _NotificationGateway()..unreadFutures.add(stale.future);
    final controller = NotificationBadgeController(gateway: gateway);

    final starting = controller.start(7);
    controller.deactivate();
    expect(controller.value, 0);
    stale.complete(88);
    await starting;

    expect(controller.value, 0);
    expect(controller.ownerUserId, isNull);
  });

  test('切换账号不会复用旧账号请求或轮询，失败保留最后有效值', () async {
    final stale = Completer<int>();
    final gateway = _NotificationGateway()
      ..unreadFutures.add(stale.future)
      ..unreadCounts.add(6);
    final timers = _FakePollFactory();
    final controller = NotificationBadgeController(
      gateway: gateway,
      timerFactory: timers.call,
    );

    final first = controller.start(7);
    await controller.start(9);
    expect(controller.ownerUserId, 9);
    expect(controller.value, 6);
    expect(timers.created.first.cancelled, isTrue);

    stale.complete(99);
    await first;
    gateway.error = StateError('offline');
    await controller.refresh();

    expect(controller.value, 6);
    expect(controller.errorMessage, isNotNull);
  });

  test('dispose 取消轮询且定时回调不再发请求', () async {
    final gateway = _NotificationGateway()..unreadCounts.add(2);
    final timers = _FakePollFactory();
    final controller = NotificationBadgeController(
      gateway: gateway,
      timerFactory: timers.call,
    );
    await controller.start(7);

    controller.dispose();
    expect(timers.active, isEmpty);
    timers.created.single.fire();
    await _flush();

    expect(gateway.unreadCalls, 1);
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _FakePollFactory {
  final List<_FakePollHandle> created = [];
  final List<Duration> intervals = [];

  NotificationPollHandle call(Duration interval, void Function() callback) {
    intervals.add(interval);
    final timer = _FakePollHandle(callback);
    created.add(timer);
    return timer;
  }

  List<_FakePollHandle> get active =>
      created.where((timer) => !timer.cancelled).toList();
}

class _FakePollHandle implements NotificationPollHandle {
  _FakePollHandle(this.callback);

  final void Function() callback;
  bool cancelled = false;

  void fire() {
    if (!cancelled) callback();
  }

  @override
  void cancel() => cancelled = true;
}

class _NotificationGateway implements NotificationGateway {
  final List<int> unreadCounts = [];
  final List<Future<int>> unreadFutures = [];
  Object? error;
  int unreadCalls = 0;

  @override
  Future<int> loadUnreadCount() {
    unreadCalls += 1;
    if (error case final value?) return Future.error(value);
    if (unreadFutures.isNotEmpty) return unreadFutures.removeAt(0);
    return Future.value(unreadCounts.removeAt(0));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
