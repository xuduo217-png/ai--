import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/chat/data/consultation_messaging_repository.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';

void main() {
  test('解析免费与付费咨询会话分页数据', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/chat/conversations');
      expect(request.url.queryParameters, {'page': '1', 'limit': '100'});
      expect(request.headers['authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode({
          'code': 0,
          'data': {
            'data': [
              {
                'conversationId': 'conversation-1',
                'userId': 7,
                'doctorId': 10,
                'doctorName': '陈医生',
                'doctorAvatar': '/uploads/doctor.png',
                'status': 'PAID',
                'paymentRequired': false,
                'isTemporary': false,
                'orderId': 71,
                'lastMessage': {
                  'id': 101,
                  'conversationId': 'conversation-1',
                  'senderId': 10,
                  'receiverId': 7,
                  'content': '检查结果正常',
                  'type': 'TEXT',
                  'isAutoReply': false,
                  'createdAt': '2026-07-27T04:00:00.000Z',
                },
                'unreadCount': 2,
                'createdAt': '2026-07-27T01:00:00.000Z',
                'updatedAt': '2026-07-27T04:00:00.000Z',
              },
            ],
            'total': 1,
            'page': 1,
            'limit': 100,
            'totalPages': 1,
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repository = ConsultationMessagingRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        client: client,
        tokenProvider: () async => 'test-token',
      ),
    );

    final page = await repository.loadConversations();

    expect(page.total, 1);
    expect(page.pageSize, 100);
    expect(page.totalPages, 1);
    expect(page.items.single.doctorName, '陈医生');
    expect(page.items.single.status, ChatSessionStatus.paid);
    expect(page.items.single.unreadCount, 2);
    expect(page.items.single.lastMessage?.content, '检查结果正常');
  });
}
