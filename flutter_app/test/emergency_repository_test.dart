import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/emergency/data/emergency_repository.dart';

void main() {
  test('急救中心公开接口按 RN contract 请求并解析服务端包装', () async {
    final requests = <http.Request>[];
    final repository = EmergencyRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          final data = switch (request.url.path) {
            '/system-configs/emergency_center' => {
              'configKey': 'emergency_center',
              'configValue': jsonEncode({
                'emergencyTime': '全天候在线',
                'emergencyHotline': '400-123-4567',
              }),
            },
            '/aid-guides' => [
              {
                'id': 1,
                'title': '宠物心肺复苏',
                'icon': '/uploads/cpr.png',
                'content': '<p>检查呼吸</p>',
                'categoryId': 7,
                'category': {
                  'id': 7,
                  'name': '心肺复苏',
                  'sortOrder': 1,
                  'isActive': true,
                  'guideCount': 1,
                },
                'status': 'PUBLISHED',
                'sortOrder': 1,
                'publishedAt': '2026-07-20T10:00:00.000Z',
                'createdAt': '2026-07-19T10:00:00.000Z',
              },
            ],
            '/aid-guides/categories' => [
              {
                'id': 7,
                'name': '心肺复苏',
                'icon': '/uploads/category.png',
                'sortOrder': 1,
                'isActive': 1,
                'guideCount': 1,
              },
            ],
            '/aid-guides/1' => {
              'id': 1,
              'title': '宠物心肺复苏',
              'content': '<p>检查呼吸</p>',
              'categoryId': 7,
              'status': 'PUBLISHED',
              'sortOrder': 1,
              'createdAt': '2026-07-19T10:00:00.000Z',
            },
            '/hospitals/nearby' => [
              {
                'id': 3,
                'name': '谷德宠物医院',
                'logo': '/uploads/hospital.png',
                'address': '北京市朝阳区测试路 1 号',
                'phone': '010-12345678',
                'latitude': '39.905',
                'longitude': 116.408,
                'businessStatusText': '营业中',
                'distance': '1.2',
              },
            ],
            _ => <Object?>[],
          };
          final wrapped =
              request.url.path.contains('categories') ||
                  request.url.path == '/aid-guides'
              ? {
                  'code': 0,
                  'data': data,
                  'pagination': {'page': 1, 'totalPages': 1},
                }
              : {'code': 0, 'data': data};
          return http.Response(
            jsonEncode(wrapped),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        tokenProvider: () async => 'must-not-be-used',
      ),
    );

    final config = await repository.loadEmergencyConfig();
    final guides = await repository.loadAidGuides();
    final categories = await repository.loadAidGuideCategories();
    final detail = await repository.loadAidGuide(1);
    final hospitals = await repository.loadNearbyHospitals(
      latitude: 39.9,
      longitude: 116.4,
    );

    expect(config.emergencyTime, '全天候在线');
    expect(config.emergencyHotline, '400-123-4567');
    expect(guides.single.title, '宠物心肺复苏');
    expect(
      guides.single.iconUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/cpr.png',
    );
    expect(guides.single.category?.name, '心肺复苏');
    expect(
      categories.single.iconUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/category.png',
    );
    expect(detail.content, '<p>检查呼吸</p>');
    expect(hospitals.single.distance, 1.2);
    expect(hospitals.single.latitude, 39.905);
    expect(
      hospitals.single.logoUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/hospital.png',
    );
    expect(requests, everyElement(isNot(hasAuthorizationHeader)));
    expect(requests[1].url.queryParameters, {
      'status': 'PUBLISHED',
      'sortBy': 'sortOrder:ASC',
    });
    expect(requests[2].url.queryParameters, {
      'page': '1',
      'pageSize': '50',
      'isActive': 'true',
    });
    expect(requests.last.url.queryParameters, {
      'latitude': '39.9',
      'longitude': '116.4',
      'limit': '10',
    });
  });

  test('分类筛选使用专用 endpoint，空热线回退默认值', () async {
    final paths = <String>[];
    final repository = EmergencyRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          final data = request.url.path == '/system-configs/emergency_center'
              ? {
                  'configValue': {
                    'emergencyTime': '',
                    'emergencyHotline': '   ',
                  },
                }
              : <Object?>[];
          return http.Response(jsonEncode({'code': 0, 'data': data}), 200);
        }),
        tokenProvider: () async => null,
      ),
    );

    final config = await repository.loadEmergencyConfig();
    await repository.loadAidGuides(categoryId: 8);

    expect(config.emergencyHotline, '400-000-0000');
    expect(config.emergencyTime, isEmpty);
    expect(paths.last, '/aid-guides/category/8');
  });
}

Matcher get hasAuthorizationHeader => predicate<http.Request>(
  (request) =>
      request.headers.keys.any((key) => key.toLowerCase() == 'authorization'),
  'has authorization header',
);
