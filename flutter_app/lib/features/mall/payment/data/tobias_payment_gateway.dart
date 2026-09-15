import 'package:tobias/tobias.dart';

import '../domain/payment_models.dart';

class TobiasPaymentGateway implements PaymentGateway {
  TobiasPaymentGateway({Tobias? client}) : _client = client ?? Tobias();

  static const appId = '2021006115617866';
  static const universalLink = 'https://gudeapi.zuoyongyoubao.com/alipay/';

  final Tobias _client;
  bool _registered = false;

  @override
  Future<PaymentSdkResult> pay(String orderInfo) async {
    try {
      if (!_registered) {
        await _client.registerApp(appId, universalLink: universalLink);
        _registered = true;
      }
      final result = await _client.pay(orderInfo, universalLink: universalLink);
      final normalized = result.map((key, value) => MapEntry('$key', value));
      final resultStatus = '${normalized['resultStatus'] ?? ''}';
      return PaymentSdkResult(
        status: switch (resultStatus) {
          '9000' => PaymentSdkStatus.success,
          '6001' => PaymentSdkStatus.cancelled,
          '8000' || '6004' => PaymentSdkStatus.processing,
          '6002' => PaymentSdkStatus.networkError,
          _ => PaymentSdkStatus.failed,
        },
        resultStatus: resultStatus,
        memo: '${normalized['memo'] ?? ''}',
        raw: normalized,
      );
    } catch (error) {
      return PaymentSdkResult(status: PaymentSdkStatus.failed, memo: '$error');
    }
  }
}
