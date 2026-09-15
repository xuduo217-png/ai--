import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/messaging/in_app_message_banner_controller.dart';
import 'package:pet_hospital_flutter/core/messaging/in_app_message_event.dart';
import 'package:pet_hospital_flutter/core/widgets/in_app_message_banner.dart';

void main() {
  test('浮层队列去重、合并同会话并忽略离线补拉消息', () {
    final controller = InAppMessageBannerController(
      displayDuration: const Duration(days: 1),
      maxPendingBanners: 2,
    );
    addTearDown(controller.dispose);

    controller.show(_event(key: 'friend-1', conversationId: 'friend-a'));
    controller.show(_event(key: 'friend-1', conversationId: 'friend-a'));
    controller.show(_event(key: 'friend-2', conversationId: 'friend-a'));
    controller.show(_event(key: 'doctor-1', conversationId: 'doctor-a'));
    controller.show(
      _event(key: 'offline-1', conversationId: 'offline-a', isOffline: true),
    );

    expect(controller.current?.event.eventKey, 'friend-2');
    expect(controller.current?.messageCount, 2);
    expect(controller.pendingCount, 1);

    controller.dismiss();
    expect(controller.current?.event.eventKey, 'doctor-1');
  });

  testWidgets('浮层自动关闭并避让顶部安全区', (tester) async {
    final controller = InAppMessageBannerController(
      displayDuration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);
    controller.show(_event(key: 'auto', conversationId: 'friend-a'));

    await tester.pumpWidget(_harness(controller));
    final banner = find.byKey(const ValueKey('in-app-message-banner'));
    expect(banner, findsOneWidget);
    expect(tester.getTopLeft(banner).dy, greaterThanOrEqualTo(55));

    await tester.pump(const Duration(milliseconds: 101));
    expect(controller.current, isNull);
  });

  testWidgets('浮层支持左右和向上滑动关闭，向下滑动会回弹', (tester) async {
    final controller = InAppMessageBannerController(
      displayDuration: const Duration(days: 1),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_harness(controller));

    Future<void> showAndDismiss(String key, Offset offset) async {
      controller.show(_event(key: key, conversationId: key));
      await tester.pump();
      final banner = find.byKey(const ValueKey('in-app-message-banner'));
      expect(banner, findsOneWidget);
      await tester.drag(banner, offset);
      await tester.pumpAndSettle();
      expect(controller.current, isNull);
    }

    await showAndDismiss('left', const Offset(-110, 0));
    await showAndDismiss('right', const Offset(110, 0));
    await showAndDismiss('up', const Offset(0, -75));

    controller.show(_event(key: 'down', conversationId: 'down'));
    await tester.pump();
    final banner = find.byKey(const ValueKey('in-app-message-banner'));
    await tester.drag(banner, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(controller.current?.event.eventKey, 'down');
    expect(tester.getTopLeft(banner).dy, greaterThanOrEqualTo(55));
    controller.clear();
  });

  testWidgets('点击浮层返回对应消息事件并关闭当前提示', (tester) async {
    final controller = InAppMessageBannerController(
      displayDuration: const Duration(days: 1),
    );
    addTearDown(controller.dispose);
    InAppMessageEvent? tapped;
    final event = _event(key: 'tap', conversationId: 'friend-a');
    controller.show(event);

    await tester.pumpWidget(
      _harness(controller, onTap: (event) async => tapped = event),
    );
    await tester.tap(find.byKey(const ValueKey('in-app-message-banner')));
    await tester.pump();

    expect(tapped, same(event));
    expect(controller.current, isNull);
  });
}

Widget _harness(
  InAppMessageBannerController controller, {
  Future<void> Function(InAppMessageEvent event)? onTap,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 844),
        padding: EdgeInsets.only(top: 47),
      ),
      child: InAppMessageOverlayHost(
        controller: controller,
        onMessageTap: onTap ?? (_) async {},
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ),
  );
}

InAppMessageEvent _event({
  required String key,
  required String conversationId,
  bool isOffline = false,
}) {
  return InAppMessageEvent(
    eventKey: key,
    channel: InAppMessageChannel.friend,
    conversationId: conversationId,
    senderId: 2,
    title: '测试用户',
    preview: '收到一条测试消息',
    createdAt: DateTime(2026, 7, 27, 12),
    isOffline: isOffline,
  );
}
