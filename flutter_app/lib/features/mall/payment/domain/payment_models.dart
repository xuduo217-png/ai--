enum PaymentSdkStatus { success, cancelled, processing, networkError, failed }

class PaymentSdkResult {
  const PaymentSdkResult({
    required this.status,
    this.resultStatus = '',
    this.memo = '',
    this.raw = const {},
  });

  final PaymentSdkStatus status;
  final String resultStatus;
  final String memo;
  final Map<String, dynamic> raw;
}

abstract interface class PaymentGateway {
  Future<PaymentSdkResult> pay(String orderInfo);
}

enum PaymentFlowStatus {
  success,
  cancelled,
  processing,
  insufficientBalance,
  unavailable,
  networkError,
  failed,
}

class PaymentFlowResult {
  const PaymentFlowResult(this.status, this.message);

  final PaymentFlowStatus status;
  final String message;
  bool get paid => status == PaymentFlowStatus.success;
}
