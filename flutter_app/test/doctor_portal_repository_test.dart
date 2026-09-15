import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/data/doctor_portal_repository.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/domain/doctor_portal_models.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';

void main() {
  test('医生工作台沿用 RN 的咨询、收入和资料接口契约', () async {
    final requests = <http.Request>[];
    final repository = DoctorPortalRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return switch (request.url.path) {
            '/chat/doctor/sessions' => _ok({
              'sessions': [_consultationJson()],
              'unreadCount': 2,
              'pagination': {
                'total': 1,
                'page': 1,
                'pageSize': 20,
                'totalPages': 1,
              },
            }),
            '/chat/doctor/income-stats' => _ok({
              'today': '29.90',
              'thisWeek': 80,
              'thisMonth': 160,
              'total': 520.5,
              'consultationCount': 18,
            }),
            '/chat/doctor/income-list' => _ok({
              'data': [
                {
                  'id': '31',
                  'consultationId': 'CO20260727001',
                  'amount': '29.90',
                  'status': 'paid',
                  'createdAt': '2026-07-27T08:30:00.000Z',
                  'userName': '林女士',
                  'serviceName': '在线复诊',
                },
              ],
              'total': 11,
              'page': 1,
              'pageSize': 10,
              'totalPages': 2,
            }),
            '/doctors/profile' => _ok(_profileJson()),
            '/doctors/online-status' => _ok({
              ..._profileJson(),
              'onlineStatus': 'OFFLINE',
            }),
            _ => throw StateError('unexpected ${request.url.path}'),
          };
        }),
        tokenProvider: () async => 'doctor-token',
      ),
    );

    final consultations = await repository.loadConsultations(
      doctorId: 7,
      status: DoctorConsultationStatus.paid,
    );
    final income = await repository.loadIncome();
    final profile = await repository.loadProfile();
    final offline = await repository.updateOnlineStatus(false);

    expect(requests.first.url.queryParameters, {
      'status': 'PAID',
      'page': '1',
      'limit': '20',
    });
    expect(
      requests.map((request) => request.headers['authorization']),
      everyElement('Bearer doctor-token'),
    );
    expect(consultations.items.single.userName, '林女士');
    expect(
      consultations.items.single.userAvatarUrl,
      '/uploads/user-avatar.jpg',
    );
    expect(consultations.items.single.status, DoctorConsultationStatus.paid);
    expect(consultations.items.single.lastMessage, '宠物刚刚吐了');
    expect(consultations.items.single.unreadCount, 2);
    expect(consultations.totalUnreadCount, 2);
    expect(income.stats.total, 520.5);
    expect(income.records.items.single.serviceName, '在线复诊');
    expect(income.records.hasMore, isTrue);
    expect(profile.hospitalName, '谷德动物医院');
    expect(profile.departmentName, '内科');
    expect(profile.isGoldDoctor, isTrue);
    expect(offline.isOnline, isFalse);

    final patchRequest = requests.singleWhere(
      (request) => request.url.path == '/doctors/online-status',
    );
    expect(patchRequest.method, 'PATCH');
    expect(jsonDecode(patchRequest.body), {'onlineStatus': 'OFFLINE'});
  });

  test('医生打开会话后按 conversationId 标记已读', () async {
    late http.Request capturedRequest;
    final repository = DoctorPortalRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          return _ok(null);
        }),
        tokenProvider: () async => 'doctor-token',
      ),
    );

    await repository.markConversationRead('session/1');

    expect(capturedRequest.method, 'PUT');
    expect(capturedRequest.url.path, '/chat/conversations/session%2F1/read');
    expect(capturedRequest.headers['authorization'], 'Bearer doctor-token');
  });

  test('医生聊天按 conversationId 加载并按咨询状态控制发送', () async {
    final requests = <http.Request>[];
    final repository = DoctorPortalRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return _ok({
            'data': [
              {
                'id': 8,
                'conversationId': '12_7',
                'senderId': 12,
                'receiverId': 7,
                'content': '医生您好',
                'type': 'TEXT',
                'isAutoReply': false,
                'isRead': false,
                'createdAt': '2026-07-27T09:00:00.000Z',
              },
            ],
            'total': 1,
            'page': 1,
            'limit': 50,
          });
        }),
        tokenProvider: () async => 'doctor-token',
      ),
    );

    final active = DoctorConsultation.fromJson(_consultationJson());
    final bootstrap = await repository.loadDoctorChat(
      consultation: active,
      doctorId: 7,
    );

    expect(requests.single.url.path, '/chat/messages');
    expect(requests.single.url.queryParameters['conversationId'], '12_7');
    expect(bootstrap.session?.doctorId, 7);
    expect(bootstrap.session?.userId, 12);
    expect(bootstrap.canSend, isTrue);
    expect(bootstrap.messages.single.content, '医生您好');

    final expired = DoctorConsultation.fromJson({
      ..._consultationJson(),
      'status': 'EXPIRED',
    });
    final expiredBootstrap = await repository.loadDoctorChat(
      consultation: expired,
      doctorId: 7,
    );
    expect(expiredBootstrap.canSend, isFalse);
  });

  test('医生按会话读取用户档案、历史咨询、AI 报告、护理建议和健康档案', () async {
    final requests = <http.Request>[];
    final repository = DoctorPortalRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return switch (request.url.path) {
            '/chat/doctor/sessions/session-1/patient' => _ok({
              'user': {'id': 12, 'name': '林女士', 'avatar': ''},
              'petCount': 1,
              'pets': [_patientPetJson()],
            }),
            '/chat/doctor/sessions/session-1/history' => _page([
              _historySessionJson(),
            ]),
            '/chat/doctor/sessions/session-1/history/history-1/messages' =>
              _page([_historyMessageJson()]),
            '/chat/doctor/sessions/session-1/pets/31/ai-reports' => _page([
              _aiReportJson(),
            ]),
            '/chat/doctor/sessions/session-1/ai-reports/9' => _ok(
              _aiReportJson(),
            ),
            '/chat/doctor/sessions/session-1/pets/31/care-plan' => _ok(
              _carePlanJson(),
            ),
            '/chat/doctor/sessions/session-1/pets/31/appointments' => _page([
              _appointmentJson(),
            ]),
            '/chat/doctor/sessions/session-1/appointments/6' => _ok(
              _appointmentJson(),
            ),
            _ => throw StateError('unexpected ${request.url.path}'),
          };
        }),
        tokenProvider: () async => 'doctor-token',
      ),
    );

    final patient = await repository.loadPatientRecord('session-1');
    final history = await repository.loadPatientHistory(
      conversationId: 'session-1',
    );
    final historyMessages = await repository.loadPatientHistoryMessages(
      conversationId: 'session-1',
      historyConversationId: 'history-1',
    );
    final reports = await repository.loadPatientAiReports(
      conversationId: 'session-1',
      petId: 31,
    );
    final report = await repository.loadPatientAiReport(
      conversationId: 'session-1',
      reportId: 9,
    );
    final carePlan = await repository.loadPatientCarePlan(
      conversationId: 'session-1',
      petId: 31,
    );
    final appointments = await repository.loadPatientAppointments(
      conversationId: 'session-1',
      petId: 31,
    );
    final appointment = await repository.loadPatientAppointment(
      conversationId: 'session-1',
      appointmentId: 6,
    );

    expect(patient.petCount, 1);
    expect(patient.pets.single.pet.name, '团团');
    expect(patient.pets.single.vaccination.count, 3);
    expect(patient.pets.single.healthStats.vaccine.count, 3);
    expect(patient.pets.single.healthStats.deworming.count, 2);
    expect(patient.pets.single.healthStats.checkup.count, 1);
    expect(history.items.single.serviceItemName, '首次咨询');
    expect(history.items.single.messageCount, 6);
    expect(history.items.single.lastMessage, '[图片]');
    expect(historyMessages.items.single.senderType, 'user');
    expect(historyMessages.items.single.content, '宠物昨晚开始呕吐');
    expect(reports.items.single.symptoms, '食欲下降');
    expect(report.status, AiDiagnosisStatus.completed);
    expect(carePlan.plan?.care.grooming, ['每周梳毛 2 次']);
    expect(appointments.items.single.hospital?.name, '谷德动物医院');
    expect(appointment.type, HealthAppointmentType.vaccine);
    expect(appointment.operationContent, '狂犬疫苗加强针接种');
    expect(appointment.detailContent, '<p>体温正常，已完成接种</p>');
    expect(
      requests.map((request) => request.headers['authorization']),
      everyElement('Bearer doctor-token'),
    );
    final historyRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/session-1/history'),
    );
    expect(historyRequest.url.queryParameters, {'page': '1', 'pageSize': '20'});
    final messageRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/history-1/messages'),
    );
    expect(messageRequest.url.queryParameters['pageSize'], '50');
  });

  test('旧版用户档案响应仍可从 vaccination 回退疫苗汇总', () {
    final legacyPet = _patientPetJson()..remove('healthStats');

    final patient = DoctorPatientRecord.fromJson({
      'user': {'id': 12, 'name': '林女士', 'avatar': ''},
      'petCount': 1,
      'pets': [legacyPet],
    });

    expect(patient.pets.single.healthStats.vaccine.count, 3);
    expect(patient.pets.single.healthStats.deworming.count, 0);
    expect(patient.pets.single.healthStats.checkup.count, 0);
  });
}

http.Response _ok(Object? data) => http.Response(
  jsonEncode({'code': 0, 'data': data, 'message': 'Success'}),
  200,
  headers: const {'content-type': 'application/json'},
);

http.Response _page(List<Object?> data) => http.Response(
  jsonEncode({
    'code': 0,
    'data': data,
    'pagination': {
      'total': data.length,
      'page': 1,
      'pageSize': 20,
      'totalPages': data.isEmpty ? 0 : 1,
    },
    'message': 'Success',
  }),
  200,
  headers: const {'content-type': 'application/json'},
);

Map<String, Object?> _patientPetJson() => {
  'id': 31,
  'name': '团团',
  'avatar': '',
  'ownerId': 12,
  'gender': 2,
  'birthDate': '2024-02-01',
  'weight': '4.20',
  'isNeutered': true,
  'vaccineCount': 3,
  'createdAt': '2024-02-01T00:00:00.000Z',
  'updatedAt': '2026-01-10T00:00:00.000Z',
  'vaccination': {'count': 3, 'lastAt': '2026-01-10', 'nextAt': '2027-01-10'},
  'healthStats': {
    'vaccine': {'count': 3, 'lastAt': '2026-01-10', 'nextAt': '2027-01-10'},
    'deworming': {'count': 2, 'lastAt': '2026-06-01', 'nextAt': '2026-09-01'},
    'checkup': {'count': 1, 'lastAt': '2026-03-15', 'nextAt': '2027-03-15'},
  },
};

Map<String, Object?> _carePlanJson() => {
  ..._patientPetJson(),
  'carePlanStatus': 'COMPLETED',
  'carePlanGeneratedAt': '2026-07-20T08:00:00.000Z',
  'carePlan': {
    'nutrition_plan': <String, Object?>{},
    'care_plan': {
      'grooming': ['每周梳毛 2 次'],
      'medical': ['每月检查耳道'],
      'exercise': ['每天散步 30 分钟'],
      'vaccination': ['按年度计划接种'],
      'environment': ['保持居住环境干燥'],
    },
  },
};

Map<String, Object?> _aiReportJson() => {
  'id': 9,
  'petId': 31,
  'status': 'COMPLETED',
  'symptoms': '食欲下降',
  'diagnosisImages': <String>[],
  'basicInfo': <String, Object?>{},
  'westernDiagnosis': <String, Object?>{},
  'tcmDiagnosis': <Object?>[],
  'createdAt': '2026-07-20T08:00:00.000Z',
};

Map<String, Object?> _appointmentJson() => {
  'id': 6,
  'type': 'vaccine',
  'status': 'confirmed',
  'appointmentDate': '2026-08-01',
  'timeSlot': '09:00-10:00',
  'petId': 31,
  'hospitalId': 2,
  'hospital': {'id': 2, 'name': '谷德动物医院', 'address': '深圳市南山区宠物路 1 号'},
  'doctor': {'name': '张晶'},
  'operationContent': '狂犬疫苗加强针接种',
  'detailContent': '<p>体温正常，已完成接种</p>',
  'notes': '接种后观察 30 分钟',
};

Map<String, Object?> _historySessionJson() => {
  'id': 2,
  'conversationId': 'history-1',
  'status': 'EXPIRED',
  'orderId': 20,
  'serviceItemName': '首次咨询',
  'messageCount': 6,
  'serviceStartAt': '2026-07-10T08:00:00.000Z',
  'lastMessage': {
    'id': 6,
    'content': '{"url":"/uploads/chat/image.jpg"}',
    'type': 'IMAGE',
    'createdAt': '2026-07-10T09:00:00.000Z',
  },
};

Map<String, Object?> _historyMessageJson() => {
  'id': 1,
  'conversationId': 'history-1',
  'senderId': 12,
  'senderType': 'user',
  'receiverId': 7,
  'receiverType': 'doctor',
  'content': '宠物昨晚开始呕吐',
  'type': 'TEXT',
  'isAutoReply': false,
  'isRead': true,
  'createdAt': '2026-07-10T08:30:00.000Z',
};

Map<String, Object?> _consultationJson() => {
  'id': 4,
  'conversationId': '12_7',
  'userId': 12,
  'userName': '林女士',
  'userAvatar': '/uploads/user-avatar.jpg',
  'doctorId': 7,
  'status': 'PAID',
  'orderId': 31,
  'serviceItemName': '在线复诊',
  'lastMessage': {
    'id': 8,
    'content': '宠物刚刚吐了',
    'type': 'TEXT',
    'createdAt': '2026-07-27T09:00:00.000Z',
  },
  'unreadCount': 2,
  'serviceStartAt': '2026-07-27T08:00:00.000Z',
  'serviceEndAt': '2026-07-28T08:00:00.000Z',
  'lastMessageAt': '2026-07-27T09:00:00.000Z',
  'createdAt': '2026-07-27T08:00:00.000Z',
  'updatedAt': '2026-07-27T09:00:00.000Z',
};

Map<String, Object?> _profileJson() => {
  'id': 7,
  'name': '张晶',
  'phone': '13800138000',
  'avatar': '/uploads/doctor.jpg',
  'specialty': '犬猫内科、皮肤病',
  'experience': 8,
  'consultationCount': 126,
  'isActive': true,
  'isGoldDoctor': true,
  'onlineStatus': 'ONLINE',
  'hospital': {'id': 2, 'name': '谷德动物医院'},
  'department': {'id': 5, 'name': '内科'},
};
