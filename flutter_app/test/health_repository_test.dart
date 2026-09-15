import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/health/data/health_repository.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';

void main() {
  test('营养师仓库按宠物加载健康统计和预约记录', () async {
    final requests = <http.Request>[];
    final repository = HealthRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          final data = switch (request.url.path) {
            '/pets/my' => [_petJson(id: 8, name: '团子')],
            '/pets/8/health-stats' => {
              'vaccine': {
                'count': 3,
                'lastAt': '2026-06-01T08:00:00.000Z',
                'nextAt': '2026-08-01T08:00:00.000Z',
                'daysUntilNext': 7,
              },
              'deworming': {'count': 5, 'daysUntilNext': 2},
              'checkup': {'count': 1, 'daysUntilNext': 30},
            },
            '/health-appointments/pet/8' => [
              _appointmentJson(id: 21, status: 'completed'),
            ],
            _ => throw StateError('unexpected request: ${request.url}'),
          };
          return _success(data, pagination: data is List);
        }),
        tokenProvider: () async => 'token-1',
      ),
    );

    final pets = await repository.loadHealthPets();
    final stats = await repository.loadPetHealthStats(8);
    final records = await repository.loadAppointments(
      petId: 8,
      status: HealthAppointmentStatus.completed,
    );

    expect(pets.single.name, '团子');
    expect(stats.vaccine.count, 3);
    expect(stats.vaccine.daysUntilNext, 7);
    expect(records.items.single.type, HealthAppointmentType.vaccine);
    expect(records.items.single.status, HealthAppointmentStatus.completed);
    expect(
      requests.last.url.queryParameters,
      containsPair('status', 'completed'),
    );
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer token-1',
      ),
      isTrue,
    );
  });

  test('创建预约使用 RN 同款 wire value、日期和时间段', () async {
    late Map<String, Object?> requestBody;
    final repository = HealthRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requestBody = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return _success(_appointmentJson(id: 30, status: 'pending'));
        }),
        tokenProvider: () async => 'token-1',
      ),
    );

    final appointment = await repository.createAppointment(
      petId: 8,
      hospitalId: 3,
      type: HealthAppointmentType.vaccine,
      appointmentDate: '2026-07-30',
      timeSlot: '09:00-10:00',
      notes: '首次预约',
    );

    expect(appointment.id, 30);
    expect(requestBody, {
      'petId': 8,
      'hospitalId': 3,
      'type': 'vaccine',
      'appointmentDate': '2026-07-30',
      'timeSlot': '09:00-10:00',
      'notes': '首次预约',
    });
  });

  test('AI 报告兼容 petInfo 和 TCM data 包装并解析中西医结果', () async {
    final repository = HealthRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/ai-diagnosis-reports/91');
          return _success({
            'id': 91,
            'petId': 8,
            'status': 'COMPLETED',
            'symptoms': '精神不振，食欲下降',
            'diagnosisImages': ['/uploads/a.jpg'],
            'selfCheckSnapshot': [
              {
                'listName': '消化系统自查',
                'questions': [
                  {
                    'questionText': '是否呕吐？',
                    'options': [
                      {
                        'optionText': '是',
                        'image': '/images/symptom1.jpg',
                        'selected': true,
                      },
                    ],
                  },
                ],
              },
            ],
            'basicInfo': {
              'bodyTemperature': '正常',
              'heartRate': '偏快',
              'breathe': '正常',
            },
            'westernDiagnosis': {
              'diagnosis': [
                {'symptom': '胃肠不适', 'reason': '饮食变化', 'probability': '65%'},
              ],
              'medications': [
                {
                  'symptom': '食欲下降',
                  'drug_name': '益生菌',
                  'dosage': '按说明',
                  'frequency': '每日一次',
                },
              ],
            },
            'tcmDiagnosis': {
              'data': [
                {
                  'zhengming': '脾胃不和',
                  'description': '运化失常',
                  'p': '60%',
                  'therapy': '健脾和胃',
                  'base': '基础方',
                  'base_prescription': '处方内容',
                  'base_prescription_usage': '遵医嘱',
                },
              ],
            },
            'petInfo': {'name': '团子'},
            'createdAt': '2026-07-25T09:30:00.000Z',
          });
        }),
        tokenProvider: () async => 'token-1',
      ),
    );

    final report = await repository.loadAiDiagnosisReport(91);

    expect(report.status, AiDiagnosisStatus.completed);
    expect(report.petSnapshot['name'], '团子');
    expect(report.selfCheckSnapshot.single.name, '消化系统自查');
    expect(report.selfCheckSnapshot.single.questions.single.text, '是否呕吐？');
    expect(
      report.selfCheckSnapshot.single.questions.single.options.single.imageUrl,
      '/images/symptom1.jpg',
    );
    expect(report.westernDiagnosis.single.symptom, '胃肠不适');
    expect(report.medications.single.drugName, '益生菌');
    expect(report.tcmDiagnosis.single.name, '脾胃不和');
  });

  test('护理方案解析营养比例和五类护理建议', () async {
    final repository = HealthRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (request) async => _success({
            ..._petJson(id: 8, name: '团子'),
            'carePlanStatus': 'COMPLETED',
            'carePlanGeneratedAt': '2026-07-25T08:00:00.000Z',
            'carePlan': {
              'nutrition_plan': {
                'daily_calories': 420,
                'macro_ratio': {'protein': '35%', 'fat': '25%', 'carbs': '40%'},
                'recommended_foods': ['鸡胸肉'],
                'avoid_foods': ['巧克力'],
                'supplements': ['鱼油'],
                'feeding_schedule': ['早晚各一次'],
              },
              'care_plan': {
                'grooming': ['每周梳毛'],
                'medical': ['观察食欲'],
                'exercise': ['每日散步'],
                'vaccination': ['按期接种'],
                'environment': ['保持通风'],
              },
            },
          }),
        ),
        tokenProvider: () async => 'token-1',
      ),
    );

    final state = await repository.loadCarePlan(8);

    expect(state.status, CarePlanStatus.completed);
    expect(state.plan!.nutrition.dailyCalories, '420');
    expect(state.plan!.nutrition.recommendedFoods, ['鸡胸肉']);
    expect(state.plan!.care.environment, ['保持通风']);
  });

  test('健康知识接口携带登录 token', () async {
    final requests = <http.Request>[];
    final repository = HealthRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          final data = switch (request.url.path) {
            '/health-articles/categories' => [
              {'id': 2, 'name': '营养护理', 'articleCount': 1},
            ],
            '/health-articles' => [_articleJson()],
            '/health-articles/17' => _articleJson(),
            _ => throw StateError('unexpected request: ${request.url}'),
          };
          return _success(
            data,
            pagination: request.url.path == '/health-articles',
          );
        }),
        tokenProvider: () async => 'token-1',
      ),
    );

    await repository.loadHealthArticleCategories();
    await repository.loadHealthArticles(categoryId: 2);
    await repository.loadHealthArticle(17);

    expect(requests, hasLength(3));
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer token-1',
      ),
      isTrue,
    );
  });
}

Map<String, Object?> _articleJson() => {
  'id': 17,
  'title': '科学喂养',
  'summary': '营养知识摘要',
  'content': '<p>营养知识正文</p>',
  'categoryId': 2,
  'category': {'id': 2, 'name': '营养护理'},
  'viewCount': 10,
  'publishedAt': '2026-07-25T08:00:00.000Z',
};

Map<String, Object?> _petJson({required int id, required String name}) => {
  'id': id,
  'name': name,
  'avatar': '',
  'categoryId': 1,
  'subCategoryId': 2,
  'gender': 1,
  'birthDate': '2024-01-01',
  'weight': 6.2,
  'isNeutered': true,
  'vaccineCount': 3,
  'category': {'id': 1, 'name': '猫', 'parentId': null, 'sortOrder': 1},
  'subCategory': {'id': 2, 'name': '英短', 'parentId': 1, 'sortOrder': 1},
  'ownerId': 5,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-07-01T00:00:00.000Z',
};

Map<String, Object?> _appointmentJson({
  required int id,
  required String status,
}) => {
  'id': id,
  'type': 'vaccine',
  'status': status,
  'appointmentDate': '2026-07-30',
  'timeSlot': '09:00-10:00',
  'petId': 8,
  'hospitalId': 3,
  'hospital': {'id': 3, 'name': '谷德宠物医院', 'address': '测试路 1 号'},
  'createdAt': '2026-07-25T08:00:00.000Z',
};

http.Response _success(Object? data, {bool pagination = false}) {
  return http.Response(
    jsonEncode({
      'code': 0,
      'message': 'Success',
      'data': data,
      if (pagination)
        'pagination': {
          'total': data is List ? data.length : 0,
          'page': 1,
          'pageSize': 20,
          'totalPages': 1,
        },
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
