import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/wallet/data/wallet_repository.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';

void main() {
  test('GET /shop/wallet/stats 解析三项真实金额并携带 token', () async {
    late http.Request capturedRequest;
    final repository = WalletRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': {
                'success': true,
                'data': {
                  'available': 12.3,
                  'pending': '4.00',
                  'total': 98,
                  'frozen': '2.50',
                },
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
        tokenProvider: () async => 'test-token',
      ),
    );

    final stats = await repository.loadStats();

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/shop/wallet/stats');
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(stats.availableBalance, 12.3);
    expect(stats.pendingSettlement, 4);
    expect(stats.totalSecondHandIncome, 98);
    expect(stats.withdrawalFrozenBalance, 2.5);
  });

  test('钱包字段缺失或非法时抛出格式错误而不是伪造 0', () async {
    final repository = WalletRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 0,
              'data': {
                'success': true,
                'data': {
                  'available': 1,
                  'pending': null,
                  'total': 3,
                  'frozen': 0,
                },
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        ),
        tokenProvider: () async => 'test-token',
      ),
    );

    await expectLater(repository.loadStats(), throwsA(isA<FormatException>()));
  });

  test('GET /shop/wallet/transactions 透传筛选分页并解析服务端 envelope', () async {
    late http.Request capturedRequest;
    final repository = WalletRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 18,
                  'userId': 7,
                  'type': 'income',
                  'amount': '123.45',
                  'balanceBefore': '10.00',
                  'balanceAfter': '133.45',
                  'relatedType': 'order',
                  'relatedId': 47,
                  'status': 'approved',
                  'remark': '订单结算',
                  'createdAt': '2026-07-24T08:30:00.000Z',
                  'withdrawalStatus': null,
                  'withdrawalNo': null,
                },
              ],
              'total': 21,
              'page': 2,
              'limit': 10,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
        tokenProvider: () async => 'test-token',
      ),
    );

    final page = await repository.loadTransactions(
      const WalletTransactionQuery(
        status: WalletTransactionStatus.approved,
        type: WalletTransactionType.income,
        relatedType: WalletRelatedType.order,
        page: 2,
      ),
    );

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/shop/wallet/transactions');
    expect(capturedRequest.url.queryParameters, {
      'status': 'approved',
      'type': 'income',
      'relatedType': 'order',
      'page': '2',
      'limit': '10',
    });
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(page.total, 21);
    expect(page.page, 2);
    expect(page.pageSize, 10);
    expect(page.totalPages, 3);
    expect(page.hasMore, isTrue);
    expect(page.items.single.id, 18);
    expect(page.items.single.amount, 123.45);
    expect(page.items.single.type, WalletTransactionType.income);
    expect(page.items.single.status, WalletTransactionStatus.approved);
    expect(page.items.single.relatedType, WalletRelatedType.order);
    expect(page.items.single.relatedId, 47);
    expect(page.items.single.createdAt, DateTime.utc(2026, 7, 24, 8, 30));
  });

  test('交易列表兼容 pagination 包装并保留未知枚举', () async {
    final repository = WalletRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 1,
                  'userId': 7,
                  'type': 'future_type',
                  'amount': 8,
                  'balanceBefore': 0,
                  'balanceAfter': 8,
                  'relatedType': 'future_relation',
                  'relatedId': 0,
                  'status': 'future_status',
                  'createdAt': '2026-07-24T08:30:00Z',
                },
              ],
              'pagination': {
                'total': 1,
                'page': 1,
                'pageSize': 20,
                'totalPages': 1,
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        ),
        tokenProvider: () async => 'test-token',
      ),
    );

    final page = await repository.loadTransactions(
      const WalletTransactionQuery(pageSize: 20),
    );

    expect(page.pageSize, 20);
    expect(page.hasMore, isFalse);
    expect(page.items.single.type, WalletTransactionType.unknown);
    expect(page.items.single.status, WalletTransactionStatus.unknown);
    expect(page.items.single.relatedType, WalletRelatedType.unknown);
  });

  test('交易关键字段非法时抛出格式错误', () async {
    final repository = WalletRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 1,
                  'userId': 7,
                  'type': 'income',
                  'amount': 'not-money',
                  'balanceBefore': 0,
                  'balanceAfter': 0,
                  'relatedType': 'order',
                  'relatedId': 47,
                  'status': 'approved',
                  'createdAt': 'bad-time',
                },
              ],
              'total': 1,
              'page': 1,
              'limit': 10,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        ),
        tokenProvider: () async => 'test-token',
      ),
    );

    await expectLater(
      repository.loadTransactions(const WalletTransactionQuery()),
      throwsA(isA<FormatException>()),
    );
  });

  test('POST 提现携带稳定幂等头且只解析脱敏响应', () async {
    late http.Request capturedRequest;
    final repository = WalletRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': {
                'id': 9,
                'withdrawalNo': 'W20260730001',
                'amount': '10.00',
                'status': 'pending_review',
                'payeeAccountMasked': 'us***om',
                'payeeNameMasked': '测***',
                'createdAt': '2026-07-30T08:00:00Z',
                'updatedAt': '2026-07-30T08:00:00Z',
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
        tokenProvider: () async => 'test-token',
      ),
    );

    final withdrawal = await repository.createWithdrawal(
      const CreateWalletWithdrawal(
        amount: '10.00',
        alipayAccount: 'user@example.com',
        payeeRealName: '测试用户',
        idempotencyKey: '123e4567-e89b-42d3-a456-426614174000',
      ),
    );

    expect(capturedRequest.method, 'POST');
    expect(
      capturedRequest.headers['idempotency-key'],
      '123e4567-e89b-42d3-a456-426614174000',
    );
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(withdrawal.status, WalletWithdrawalStatus.pendingReview);
    expect(withdrawal.payeeAccountMasked, 'us***om');
  });

  test('POST 充值携带幂等头、金额并解析支付宝支付参数', () async {
    late http.Request capturedRequest;
    final repository = WalletRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': {
                'id': 21,
                'rechargeNo': 'RC20260731001',
                'amount': 50,
                'status': 'pending',
                'paymentNo': 'PAY20260731001',
                'alipayOrderString': 'signed-order-info',
                'expiredAt': '2026-07-31T09:15:00Z',
                'paidAt': null,
                'failureMessage': null,
                'createdAt': '2026-07-31T09:00:00Z',
                'updatedAt': '2026-07-31T09:00:00Z',
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
        tokenProvider: () async => 'test-token',
      ),
    );

    final recharge = await repository.createRecharge(
      const CreateWalletRecharge(
        amount: '50.00',
        idempotencyKey: '123e4567-e89b-42d3-a456-426614174000',
      ),
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/shop/wallet/recharges');
    expect(
      capturedRequest.headers['idempotency-key'],
      '123e4567-e89b-42d3-a456-426614174000',
    );
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(capturedRequest.body), {'amount': '50.00'});
    expect(recharge.status, WalletRechargeStatus.pending);
    expect(recharge.alipayOrderString, 'signed-order-info');
  });

  test('GET 充值记录透传状态分页并保留服务端到账状态', () async {
    late http.Request capturedRequest;
    final repository = WalletRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 21,
                  'rechargeNo': 'RC20260731001',
                  'amount': '50.00',
                  'status': 'succeeded',
                  'paymentNo': 'PAY20260731001',
                  'alipayOrderString': null,
                  'paidAt': '2026-07-31T09:01:00Z',
                  'createdAt': '2026-07-31T09:00:00Z',
                  'updatedAt': '2026-07-31T09:01:00Z',
                },
              ],
              'total': 11,
              'page': 2,
              'limit': 10,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
        tokenProvider: () async => 'test-token',
      ),
    );

    final page = await repository.loadRecharges(
      page: 2,
      status: WalletRechargeStatus.succeeded,
    );

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/shop/wallet/recharges');
    expect(capturedRequest.url.queryParameters, {
      'page': '2',
      'limit': '10',
      'status': 'succeeded',
    });
    expect(page.total, 11);
    expect(page.hasMore, isFalse);
    expect(page.items.single.status, WalletRechargeStatus.succeeded);
    expect(page.items.single.paidAt, DateTime.utc(2026, 7, 31, 9, 1));
  });
}
