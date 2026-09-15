import 'package:flutter/foundation.dart';

import '../../order/domain/order_models.dart';
import '../domain/payment_models.dart';

abstract interface class PaymentSheetSession implements Listenable {
  bool get loading;
  bool get walletLoading;
  double get walletBalance;
  String? get walletErrorMessage;

  Future<void> loadWalletBalance();
  Future<PaymentFlowResult> submit(PaymentChannel channel);
}

class PaymentSheetSummary {
  const PaymentSheetSummary({
    required this.amount,
    required this.referenceLabel,
    required this.referenceValue,
    required this.timeoutMessage,
  });

  final double amount;
  final String referenceLabel;
  final String referenceValue;
  final String timeoutMessage;
}
