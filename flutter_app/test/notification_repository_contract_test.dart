import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/notifications/data/notification_repository.dart';
import 'package:pet_hospital_flutter/features/notifications/domain/notification_models.dart';

void main() {
  test('通知列表使用 GET /notifications、分页筛选和鉴权', () async {
    late http.Request captured;
    final repository = _repository((request) {
      captured = request;
      return _ok(
        [_notificationJson(3)],
        pagination: {'total': 21, 'page': 2, 'pageSize': 20, 'totalPages': 2},
      );
    });

    final page = await repository.loadNotifications(
      const NotificationQuery(
        page: 2,
        pageSize: 20,
        type: NotificationType.announcement,
      ),
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/notifications');
    expect(captured.url.queryParameters, {
      'page': '2',
      'pageSize': '20',
      'type': 'announcement',
    });
    expect(captured.headers['authorization'], 'Bearer notification-token');
    expect(page.items.single.id, 3);
    expect(page.total, 21);
    expect(page.hasMore, isFalse);
  });

  test('未读数和详情使用既定 GET 契约', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) {
      requests.add(request);
      return switch (request.url.path) {
        '/notifications/unread-count' => _ok({'count': '9'}),
        '/notifications/8' => _ok(_notificationJson(8)),
        _ => throw StateError('unexpected ${request.url.path}'),
      };
    });

    expect(await repository.loadUnreadCount(), 9);
    expect((await repository.loadNotificationDetail(8)).id, 8);
    expect(requests.map((request) => request.method), everyElement('GET'));
    expect(
      requests.map((request) => request.headers['authorization']),
      everyElement('Bearer notification-token'),
    );
  });

  test('单条和全部已读使用既定 PUT 契约并解析 updatedCount', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) {
      requests.add(request);
      return request.url.path == '/notifications/read-all'
          ? _ok({'success': true, 'updatedCount': '4'})
          : _ok({'success': true});
    });

    await repository.markRead(8);
    final updatedCount = await repository.markAllRead();

    expect(updatedCount, 4);
    expect(requests.map((request) => request.method), ['PUT', 'PUT']);
    expect(requests.map((request) => request.url.path), [
      '/notifications/8/read',
      '/notifications/read-all',
    ]);
    expect(
      requests.map((request) => request.headers['authorization']),
      everyElement('Bearer notification-token'),
    );
  });

  test('通知列表兼容历史双层 data 分页响应', () async {
    final repository = _repository(
      (_) => _ok({
        'data': {
          'data': [_notificationJson(6)],
          'total': 1,
          'page': 1,
          'pageSize': 20,
          'totalPages': 1,
        },
      }),
    );

    final page = await repository.loadNotifications();

    expect(page.items.single.id, 6);
    expect(page.total, 1);
    expect(page.pageSize, 20);
  });

  test('列表分页或操作响应漂移时抛出格式异常', () async {
    final badList = _repository((_) => _ok({'id': 1}));
    final badRead = _repository((_) => _ok({'success': false}));

    await expectLater(badList.loadNotifications(), throwsFormatException);
    await expectLater(badRead.markRead(1), throwsFormatException);
  });
}

NotificationRepository _repository(
  http.Response Function(http.Request) handler,
) {
  return NotificationRepository(
    apiClient: ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async => handler(request)),
      tokenProvider: () async => 'notification-token',
    ),
  );
}

http.Response _ok(Object? data, {Map<String, Object?>? pagination}) {
  return http.Response(
    jsonEncode({
      'code': 0,
      'data': data,
      'pagination': ?pagination,
      'message': 'Success',
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, Object?> _notificationJson(int id) => {
  'id': id,
  'userId': 7,
  'type': 'system',
  'title': '系统消息',
  'content': '内容',
  'isRead': false,
  'actionType': 'none',
  'actionData': null,
  'priority': 0,
  'createdAt': 1784941200000,
  'updatedAt': 1784941200000,
  'readAt': null,
};
