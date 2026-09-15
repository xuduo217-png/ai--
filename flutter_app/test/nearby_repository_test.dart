import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/nearby/data/nearby_repository.dart';
import 'package:pet_hospital_flutter/features/nearby/domain/nearby_models.dart';

void main() {
  test('附近仓库按后端 contract 发送定位、筛选和发现设置请求', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requests.add(request);
        final payload = switch ((request.method, request.url.path)) {
          ('GET', '/nearby/settings') => {
            'code': 0,
            'data': {
              'discoveryEnabled': true,
              'currentLocation': {
                'latitude': '31.2304',
                'longitude': 121.4737,
                'city': '上海市',
                'updatedAt': '2026-07-25T08:00:00.000Z',
              },
            },
          },
          ('POST', '/nearby/location') => {
            'code': 0,
            'data': {'success': true},
          },
          ('GET', '/nearby/users') => {
            'code': 0,
            'data': {
              'data': [
                {
                  'userId': 8,
                  'username': '小顾',
                  'avatar': '/uploads/avatar.png',
                  'distance': '1250',
                  'lastActiveAt': '2026-07-25T08:10:00.000Z',
                  'petTypes': ['猫', '狗'],
                  'isFriend': false,
                },
              ],
              'total': 1,
              'page': 1,
              'limit': 20,
              'totalPages': 1,
            },
          },
          ('PUT', '/nearby/settings/discovery') => {
            'code': 0,
            'data': {'success': true, 'discoveryEnabled': false},
          },
          _ => throw StateError(
            'Unexpected request: ${request.method} ${request.url}',
          ),
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      tokenProvider: () async => 'test-token',
    );
    final repository = NearbyRepository(client);

    final settings = await repository.loadNearbySettings();
    await repository.updateNearbyLocation(
      const NearbyCoordinate(
        latitude: 31.2304,
        longitude: 121.4737,
        city: '上海市',
      ),
    );
    final page = await repository.loadNearbyUsers(
      location: settings.currentLocation!,
      distance: NearbyDistanceRange.fiveKilometers,
      page: 1,
    );
    final discoveryEnabled = await repository.updateNearbyDiscovery(false);

    expect(settings.currentLocation?.city, '上海市');
    expect(page.items.single.username, '小顾');
    expect(page.items.single.distanceMeters, 1250);
    expect(page.pageSize, 20);
    expect(discoveryEnabled, isFalse);
    expect(requests, hasLength(4));
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer test-token',
      ),
      isTrue,
    );
    expect(jsonDecode(requests[1].body), {
      'latitude': 31.2304,
      'longitude': 121.4737,
      'city': '上海市',
    });
    expect(requests[2].url.queryParameters, {
      'latitude': '31.2304',
      'longitude': '121.4737',
      'radius': '5000',
      'page': '1',
      'pageSize': '20',
    });
    expect(jsonDecode(requests[3].body), {'enabled': false});
  });
}
