import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/home/data/home_repository.dart';

void main() {
  test('首页仓库并行解析菜单、Banner、医生和活动', () async {
    final requestedPaths = <String>[];
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final data = switch (request.url.path) {
          '/system-configs/home_menu_icons' => {
            'configValue': {
              'icons': {'pet-list': '/uploads/pet.jpg'},
            },
          },
          '/system-configs/home_ai_diagnosis_banner' => {
            'configValue': {'imageUrl': '/uploads/banner.jpg'},
          },
          '/system-configs/scrolling_announcement' => {
            'configValue': {
              'source': 'fixed',
              'announcementText': '欢迎来到宠物医院首页',
            },
          },
          '/doctors' => [
            {
              'id': 2,
              'name': '张晶',
              'avatar': '/uploads/doctor.jpg',
              'specialty': '中兽医，外科，内科',
              'experience': 8,
              'isGoldDoctor': true,
              'username': '张医生',
              'serviceItems': [
                {'price': '20.00'},
              ],
            },
          ],
          '/activities/app' => [
            {
              'id': 17,
              'title': '宠物选美大赛',
              'coverImage': '/uploads/activity.jpg',
              'status': 'ONGOING',
              'activityType': 'ONLINE',
            },
          ],
          _ => throw StateError('unexpected request: ${request.url}'),
        };

        return http.Response(
          jsonEncode({
            'code': 0,
            'data': data,
            'message': 'Success',
            if (data is List)
              'pagination': {
                'total': data.length,
                'page': 1,
                'pageSize': data.length,
                'totalPages': 1,
              },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      tokenProvider: () async => null,
    );

    final snapshot = await HomeRepository(
      apiClient,
    ).loadHome(authenticated: false);

    expect(requestedPaths, hasLength(5));
    expect(snapshot.scrollingAnnouncement, '欢迎来到宠物医院首页');
    expect(
      snapshot.menuIcons['pet-list'],
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/pet.jpg',
    );
    expect(
      snapshot.bannerImageUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/banner.jpg',
    );
    expect(snapshot.doctors.single.name, '张晶');
    expect(snapshot.doctors.single.price, '20.00');
    expect(
      snapshot.doctors.single.avatarUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/doctor.jpg',
    );
    expect(snapshot.activities.single.title, '宠物选美大赛');
    expect(snapshot.activities.single.status, 'ONGOING');
  });

  test('首页公告选择捐赠记录时拼接最新捐赠记录', () async {
    final requestedPaths = <String>[];
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final data = switch (request.url.path) {
          '/system-configs/home_menu_icons' => <String, dynamic>{},
          '/system-configs/home_ai_diagnosis_banner' => <String, dynamic>{},
          '/system-configs/scrolling_announcement' => {
            'configValue': {
              'source': 'donation',
              'announcementText': '不会展示这段固定内容',
            },
          },
          '/charity/latest-donations' => {
            'data': [
              {
                'userName': '小明',
                'donationAmount': '20.00',
                'donationSource': 'mall_order',
              },
              {'userName': '小红', 'donationAmount': 8.5},
            ],
            'total': 2,
            'page': 1,
            'pageSize': 20,
            'totalPages': 1,
          },
          '/doctors' => <Object?>[],
          '/activities/app' => <Object?>[],
          _ => throw StateError('unexpected request: ${request.url}'),
        };

        return http.Response(
          jsonEncode({'code': 0, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      tokenProvider: () async => null,
    );

    final snapshot = await HomeRepository(
      apiClient,
    ).loadHome(authenticated: false);

    expect(snapshot.scrollingAnnouncement, '小明在商城下单公益捐赠20元    小红公益捐赠8.5元');
    expect(requestedPaths, contains('/charity/latest-donations'));
  });

  test('首页公告关闭时隐藏且不查询捐赠记录', () async {
    final requestedPaths = <String>[];
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final data = switch (request.url.path) {
          '/system-configs/home_menu_icons' => <String, dynamic>{},
          '/system-configs/home_ai_diagnosis_banner' => <String, dynamic>{},
          '/system-configs/scrolling_announcement' => {
            'configValue': {'source': 'disabled', 'announcementText': '旧内容'},
          },
          '/doctors' => <Object?>[],
          '/activities/app' => <Object?>[],
          _ => throw StateError('unexpected request: ${request.url}'),
        };

        return http.Response(
          jsonEncode({'code': 0, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      tokenProvider: () async => null,
    );

    final snapshot = await HomeRepository(
      apiClient,
    ).loadHome(authenticated: false);

    expect(snapshot.scrollingAnnouncement, isEmpty);
    expect(requestedPaths, isNot(contains('/charity/latest-donations')));
  });

  test('单个首页接口失败时保留其他区块', () async {
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path == '/doctors') {
          return http.Response(
            jsonEncode({'code': 500, 'message': 'server error'}),
            500,
          );
        }
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': request.url.path == '/activities/app' ? [] : {},
          }),
          200,
        );
      }),
      tokenProvider: () async => null,
    );

    final snapshot = await HomeRepository(
      apiClient,
    ).loadHome(authenticated: false);

    expect(snapshot.doctors, isEmpty);
    expect(snapshot.activities, isEmpty);
  });

  for (final failedPath in [
    '/system-configs/scrolling_announcement',
    '/charity/latest-donations',
  ]) {
    test('公告接口 $failedPath 失败不影响首页原有内容', () async {
      final paths = <String>[];
      final apiClient = ApiClient(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'test-token',
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers.containsKey('authorization'), isFalse);
          if (request.url.path == failedPath) {
            return http.Response('{"message":"unavailable"}', 503);
          }
          final data = switch (request.url.path) {
            '/system-configs/scrolling_announcement' => {
              'configValue': {'source': 'donation'},
            },
            '/system-configs/home_ai_diagnosis_banner' => {
              'configValue': {'imageUrl': '/uploads/banner.jpg'},
            },
            '/doctors' => [
              {'id': 2, 'name': '张医生'},
            ],
            '/activities/app' => [
              {'id': 17, 'title': '公益活动'},
            ],
            _ => <String, dynamic>{},
          };
          return http.Response(
            jsonEncode({'code': 0, 'data': data}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final snapshot = await HomeRepository(
        apiClient,
      ).loadHome(authenticated: true);
      expect(snapshot.scrollingAnnouncement, isEmpty);
      expect(snapshot.doctors.single.name, '张医生');
      expect(snapshot.activities.single.id, 17);
      expect(
        snapshot.bannerImageUrl,
        'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/banner.jpg',
      );
      expect(paths, isNot(contains('/chat/history-consultations')));
    });
  }

  test('历史咨询单独按医生筛选并解析医生、订单状态和最后消息', () async {
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final data = switch (request.url.path) {
          '/system-configs/home_menu_icons' => <String, dynamic>{},
          '/system-configs/home_ai_diagnosis_banner' => <String, dynamic>{},
          '/doctors' => <Object?>[],
          '/activities/app' => <Object?>[],
          '/chat/history-consultations' => [
            {
              'id': 71,
              'doctorId': 2,
              'doctorName': '张晶',
              'doctorAvatar': '/uploads/doctor.jpg',
              'status': 'EXPIRED',
              'paidAt': '2026-07-20T09:00:00.000Z',
              'serviceStartAt': '2026-07-20T09:01:00.000Z',
              'serviceEndAt': '2026-07-21T09:01:00.000Z',
              'lastMessage': {
                'content': '/uploads/chat.jpg',
                'type': 'IMAGE',
                'createdAt': '2026-07-20T10:00:00.000Z',
              },
            },
          ],
          _ => throw StateError('unexpected request: ${request.url}'),
        };
        if (request.url.path == '/chat/history-consultations') {
          expect(request.headers['authorization'], 'Bearer test-token');
          expect(request.url.queryParameters, {
            'doctorId': '2',
            'limit': '3',
            'page': '1',
          });
        }
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': data,
            'message': 'Success',
            if (data is List)
              'pagination': {
                'total': data.length,
                'page': 1,
                'pageSize': data.length,
                'totalPages': 1,
              },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      tokenProvider: () async => 'test-token',
    );

    final consultation = (await HomeRepository(
      apiClient,
    ).loadHealthConsultations(doctorId: 2, pageSize: 3)).items.single;

    expect(consultation.id, 71);
    expect(consultation.doctorId, 2);
    expect(consultation.doctorName, '张晶');
    expect(
      consultation.doctorAvatarUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/doctor.jpg',
    );
    expect(consultation.isActive, isFalse);
    expect(consultation.lastMessage, '[图片]');
    expect(consultation.serviceStartAt, isNotNull);
    expect(consultation.serviceEndAt, isNotNull);
  });
}
