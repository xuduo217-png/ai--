import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/charity/data/charity_repository.dart';
import 'package:pet_hospital_flutter/features/charity/domain/charity_models.dart';

void main() {
  test('公益仓库遵循列表、详情、记录、签到和余额捐款 contract', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test/server-api',
      client: MockClient((request) async {
        requests.add(request);
        final payload = switch ((request.method, request.url.path)) {
          ('GET', '/server-api/charity') => {
            'code': 0,
            'data': [_activityJson],
            'pagination': {
              'total': 1,
              'page': 1,
              'pageSize': 10,
              'totalPages': 1,
            },
          },
          ('GET', '/server-api/charity/7') => {
            'code': 0,
            'data': _activityJson,
          },
          ('GET', '/server-api/charity/7/donations') => {
            'code': 0,
            'data': [
              {
                'id': 9,
                'charityId': 7,
                'userId': 8,
                'userName': '小顾',
                'userAvatar': '/uploads/avatar.png',
                'donationAmount': '12.50',
                'checkInTime': '2026-07-25T08:10:00.000Z',
              },
            ],
            'pagination': {
              'total': 1,
              'page': 1,
              'pageSize': 10,
              'totalPages': 1,
            },
          },
          ('POST', '/server-api/charity/7/checkin') => {
            'code': 0,
            'data': {
              'success': false,
              'alreadyChecked': true,
              'totalCheckIns': 8,
              'message': '今天已经打过卡了',
              'isCompleted': false,
            },
          },
          ('GET', '/server-api/shop/wallet/balance') => {
            'code': 0,
            'data': {
              'success': true,
              'data': {'balance': '88.60'},
            },
          },
          ('POST', '/server-api/charity/7/donate') => {
            'code': 0,
            'data': {
              'message': '感谢您的爱心',
              'donationAmount': 12.5,
              'donatedAmount': 112.5,
              'balanceBefore': 88.6,
              'balanceAfter': 76.1,
            },
          },
          ('POST', '/server-api/charity/7/donations/payment') => {
            'code': 0,
            'data': {
              'paymentNo': 'PAY_CHARITY_1',
              'amount': 12.5,
              'paymentParams': {'alipayOrderString': 'alipay-order-string'},
            },
          },
          ('GET', '/server-api/payment/query/PAY_CHARITY_1') => {
            'code': 0,
            'data': {'status': 'success'},
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
      tokenProvider: () async => 'charity-token',
    );
    final repository = CharityRepository(client);

    final page = await repository.loadCharities(
      authenticated: false,
      status: CharityStatus.active,
      keyword: '流浪',
    );
    final detail = await repository.loadCharityDetail(7, authenticated: true);
    final records = await repository.loadCharityDonations(
      7,
      authenticated: false,
    );
    final checkIn = await repository.checkInCharity(7);
    final balance = await repository.loadCharityWalletBalance();
    final donation = await repository.donateCharity(7, amount: 12.5);
    final payment = await repository.createCharityDonationPayment(
      7,
      amount: 12.5,
      idempotencyKey: '123e4567-e89b-42d3-a456-426614174000',
    );
    final paymentStatus = await repository.loadCharityDonationPaymentStatus(
      payment.paymentNo,
    );

    expect(page.items.single.title, '流浪动物救助');
    expect(
      page.items.single.coverImageUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/cover.png',
    );
    expect(detail.participantType, CharityParticipantType.donation);
    expect(
      records.items.single.userAvatarUrl,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/avatar.png',
    );
    expect(checkIn.alreadyChecked, isTrue);
    expect(balance, 88.6);
    expect(donation.balanceAfter, 76.1);
    expect(payment.alipayOrderString, 'alipay-order-string');
    expect(paymentStatus, CharityDonationPaymentStatus.success);

    final listRequest = requests[0];
    expect(listRequest.headers['authorization'], isNull);
    expect(listRequest.url.queryParameters, {
      'status': 'ACTIVE',
      'keyword': '流浪',
      'page': '1',
      'pageSize': '10',
    });
    expect(requests[1].headers['authorization'], 'Bearer charity-token');
    expect(requests[2].headers['authorization'], isNull);
    expect(requests[3].headers['authorization'], 'Bearer charity-token');
    expect(requests[4].headers['authorization'], 'Bearer charity-token');
    expect(jsonDecode(requests[5].body), {
      'amount': 12.5,
      'paymentMethod': 'balance',
    });
    expect(
      requests[6].headers['idempotency-key'],
      '123e4567-e89b-42d3-a456-426614174000',
    );
    expect(jsonDecode(requests[6].body), {'amount': 12.5});
    expect(requests[7].headers['authorization'], 'Bearer charity-token');
  });
}

const _activityJson = {
  'id': 7,
  'title': '流浪动物救助',
  'description': '为流浪动物提供医疗和食物',
  'details': '<p>每一份帮助都很重要</p>',
  'coverImage': '/uploads/cover.png',
  'startTime': '2026-07-01T00:00:00.000Z',
  'endTime': '2026-08-01T00:00:00.000Z',
  'targetCheckIns': 0,
  'completedCheckIns': 0,
  'donatedAmount': '100.00',
  'participantType': 'donation',
  'status': 'ACTIVE',
  'hasCheckedToday': false,
};
