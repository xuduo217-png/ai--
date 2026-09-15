import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/doctors/data/doctor_repository.dart';

void main() {
  test('金牌医生列表使用 RN 同款公开筛选并解析分页与价格', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;
    final repository = DoctorRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requestedUri = request.url;
          requestedHeaders = request.headers;
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': [
                {
                  'id': 9,
                  'name': '林医生',
                  'avatar': '/uploads/lin.png',
                  'username': 'doctor-lin',
                  'specialty': '犬猫内科',
                  'description': '擅长犬猫常见病诊疗',
                  'experience': 12,
                  'rating': '4.90',
                  'consultationCount': 86,
                  'isGoldDoctor': true,
                  'onlineStatus': 'ONLINE',
                  'serviceItems': [
                    {'price': '38.50'},
                  ],
                  'hospital': {'name': '谷德宠物医院'},
                  'department': {'name': '内科'},
                },
              ],
              'pagination': {
                'total': 21,
                'page': 2,
                'pageSize': 10,
                'totalPages': 3,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        tokenProvider: () async => 'should-not-be-used',
      ),
    );

    final page = await repository.loadDoctors(page: 2, goldOnly: true);
    final doctor = page.items.single;

    expect(requestedUri.path, '/doctors');
    expect(requestedUri.queryParameters, {
      'page': '2',
      'pageSize': '10',
      'isActive': '1',
      'sortBy': 'rating',
      'sortOrder': 'DESC',
      'isGoldDoctor': '1',
    });
    expect(requestedHeaders, isNot(contains('authorization')));
    expect(page.page, 2);
    expect(page.totalPages, 3);
    expect(page.hasMore, isTrue);
    expect(
      doctor.avatarUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/lin.png',
    );
    expect(doctor.price, '38.50');
    expect(doctor.rating, 4.9);
    expect(doctor.isGold, isTrue);
    expect(doctor.online, isTrue);
    expect(doctor.hospitalName, '谷德宠物医院');
    expect(doctor.departmentName, '内科');
  });

  test('全部医生列表不携带金牌筛选，详情缺少简介时回退到专长', () async {
    final requests = <Uri>[];
    final repository = DoctorRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request.url);
          final data = request.url.path == '/doctors'
              ? <Object?>[]
              : {
                  'id': 3,
                  'name': '周医生',
                  'avatar': '',
                  'username': 'doctor-zhou',
                  'specialty': '宠物外科',
                  'description': '',
                  'experience': 6,
                  'rating': 4,
                  'consultationCount': 10,
                  'consultationPrice': 20,
                  'isGoldDoctor': false,
                  'onlineStatus': 'OFFLINE',
                };
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': data,
              if (data is List)
                'pagination': {
                  'total': 0,
                  'page': 1,
                  'pageSize': 10,
                  'totalPages': 0,
                },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        tokenProvider: () async => null,
      ),
    );

    await repository.loadDoctors(page: 1, goldOnly: false);
    final doctor = await repository.loadDoctor(3);

    expect(requests.first.queryParameters, isNot(contains('isGoldDoctor')));
    expect(requests.last.path, '/doctors/3');
    expect(doctor.description, '宠物外科');
    expect(doctor.price, '20.00');
  });
}
