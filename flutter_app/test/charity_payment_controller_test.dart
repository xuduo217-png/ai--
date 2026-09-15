import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/charity/domain/charity_models.dart';
import 'package:pet_hospital_flutter/features/charity/presentation/charity_controller.dart';
import 'package:pet_hospital_flutter/features/charity/presentation/charity_payment_controller.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';

void main() {
  test('余额捐款通过统一支付会话提交并刷新公益详情', () async {
    final gateway = _PaymentCharityGateway();
    final controller = _controller(gateway);
    final session = CharityPaymentController(
      detailController: controller,
      paymentGateway: _PaymentGateway(),
      amount: 12.5,
      delay: (_) async {},
      idempotencyKeyFactory: () => _idempotencyKey,
    );

    await session.loadWalletBalance();
    final result = await session.submit(PaymentChannel.balance);

    expect(result.status, PaymentFlowStatus.success);
    expect(gateway.donatedAmounts, [12.5]);
    expect(gateway.detailLoads, 1);
  });

  test('支付宝 SDK 返回成功后主动查单并确认公益到账', () async {
    final gateway = _PaymentCharityGateway(
      paymentStatuses: [
        CharityDonationPaymentStatus.pending,
        CharityDonationPaymentStatus.success,
      ],
    );
    final paymentGateway = _PaymentGateway();
    final session = CharityPaymentController(
      detailController: _controller(gateway),
      paymentGateway: paymentGateway,
      amount: 20,
      delay: (_) async {},
      idempotencyKeyFactory: () => _idempotencyKey,
    );

    final result = await session.submit(PaymentChannel.alipay);

    expect(result.status, PaymentFlowStatus.success);
    expect(paymentGateway.orderInfos, ['alipay-order-string']);
    expect(gateway.createdAmount, 20);
    expect(gateway.idempotencyKey, _idempotencyKey);
    expect(gateway.paymentStatusLoads, 2);
    expect(gateway.detailLoads, 1);
  });

  test('支付宝用户取消时不继续查单', () async {
    final gateway = _PaymentCharityGateway();
    final session = CharityPaymentController(
      detailController: _controller(gateway),
      paymentGateway: _PaymentGateway(PaymentSdkStatus.cancelled),
      amount: 20,
      delay: (_) async {},
      idempotencyKeyFactory: () => _idempotencyKey,
    );

    final result = await session.submit(PaymentChannel.alipay);

    expect(result.status, PaymentFlowStatus.cancelled);
    expect(gateway.paymentStatusLoads, 0);
  });
}

CharityDetailController _controller(CharityGateway gateway) {
  return CharityDetailController(
    gateway: gateway,
    charityId: 7,
    authenticated: true,
  );
}

const _idempotencyKey = '123e4567-e89b-42d3-a456-426614174000';

class _PaymentCharityGateway implements CharityGateway {
  _PaymentCharityGateway({
    this.paymentStatuses = const [CharityDonationPaymentStatus.success],
  });

  final List<CharityDonationPaymentStatus> paymentStatuses;
  final donatedAmounts = <double>[];
  int detailLoads = 0;
  int paymentStatusLoads = 0;
  double? createdAmount;
  String? idempotencyKey;

  @override
  Future<double> loadCharityWalletBalance() async => 88.6;

  @override
  Future<CharityDonationResult> donateCharity(
    int charityId, {
    required double amount,
  }) async {
    donatedAmounts.add(amount);
    return CharityDonationResult(
      message: '感谢您的爱心',
      donationAmount: amount,
      donatedAmount: amount,
      balanceBefore: 88.6,
      balanceAfter: 88.6 - amount,
    );
  }

  @override
  Future<CharityDonationPayment> createCharityDonationPayment(
    int charityId, {
    required double amount,
    required String idempotencyKey,
  }) async {
    createdAmount = amount;
    this.idempotencyKey = idempotencyKey;
    return CharityDonationPayment(
      paymentNo: 'PAY_CHARITY_1',
      amount: amount,
      alipayOrderString: 'alipay-order-string',
    );
  }

  @override
  Future<CharityDonationPaymentStatus> loadCharityDonationPaymentStatus(
    String paymentNo,
  ) async {
    final index = paymentStatusLoads.clamp(0, paymentStatuses.length - 1);
    paymentStatusLoads += 1;
    return paymentStatuses[index];
  }

  @override
  Future<CharityActivity> loadCharityDetail(
    int charityId, {
    required bool authenticated,
  }) async {
    detailLoads += 1;
    return _activity;
  }

  @override
  Future<CharityRecordPage> loadCharityDonations(
    int charityId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) async => CharityRecordPage(
    items: const [],
    total: 0,
    page: page,
    pageSize: pageSize,
    totalPages: 0,
  );

  @override
  Future<CharityRecordPage> loadCharityRecords(
    int charityId, {
    int page = 1,
    int pageSize = 10,
  }) => loadCharityDonations(
    charityId,
    authenticated: true,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<CharityPage> loadCharities({
    required bool authenticated,
    CharityStatus? status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) => throw UnimplementedError();

  @override
  Future<CharityCheckInResult> checkInCharity(int charityId) =>
      throw UnimplementedError();
}

class _PaymentGateway implements PaymentGateway {
  _PaymentGateway([this.status = PaymentSdkStatus.success]);

  final PaymentSdkStatus status;
  final orderInfos = <String>[];

  @override
  Future<PaymentSdkResult> pay(String orderInfo) async {
    orderInfos.add(orderInfo);
    return PaymentSdkResult(status: status);
  }
}

const _activity = CharityActivity(
  id: 7,
  title: '流浪动物救助',
  description: '为流浪动物提供医疗和食物支持',
  details: '',
  coverImageUrl: '',
  targetCheckIns: 0,
  completedCheckIns: 0,
  donatedAmount: 100,
  participantType: CharityParticipantType.donation,
  status: CharityStatus.active,
  hasCheckedToday: false,
);
