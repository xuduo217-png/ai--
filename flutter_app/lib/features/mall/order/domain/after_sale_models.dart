import 'order_models.dart';

enum AfterSaleStatus {
  pendingHandler('pending_handler', '等待处理'),
  handlerRejected('handler_rejected', '申请已拒绝'),
  handlerTimeout('handler_timeout', '处理已超时'),
  waitingBuyerReturn('waiting_buyer_return', '等待买家退货'),
  waitingHandlerReceipt('waiting_handler_receipt', '等待确认收货'),
  arbitrationPending('arbitration_pending', '平台仲裁中'),
  refunding('refunding', '退款处理中'),
  refunded('refunded', '已退款'),
  closed('closed', '售后已关闭'),
  unknown('unknown', '未知状态');

  const AfterSaleStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static AfterSaleStatus fromJson(Object? value) {
    final wireValue = '$value'.toLowerCase();
    return switch (wireValue) {
      'pending_seller' => pendingHandler,
      'seller_rejected' => handlerRejected,
      'seller_timeout' => handlerTimeout,
      'waiting_seller_receipt' => waitingHandlerReceipt,
      _ => values.firstWhere(
        (status) => status.wireValue == wireValue,
        orElse: () => unknown,
      ),
    };
  }
}

enum AfterSaleHandlerType {
  seller('seller', '卖家处理'),
  platform('platform', '平台处理');

  const AfterSaleHandlerType(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static AfterSaleHandlerType fromJson(Object? value) =>
      '$value'.toLowerCase() == platform.wireValue ? platform : seller;
}

enum AfterSaleType {
  refundOnly('refund_only', '仅退款'),
  returnRefund('return_refund', '退货退款');

  const AfterSaleType(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static AfterSaleType fromJson(Object? value) =>
      '$value'.toLowerCase() == returnRefund.wireValue
      ? returnRefund
      : refundOnly;
}

class AfterSaleRequestItem {
  const AfterSaleRequestItem({required this.lineKey, required this.quantity});

  final String lineKey;
  final int quantity;

  Map<String, Object> toJson() => {'lineKey': lineKey, 'quantity': quantity};
}

class AfterSaleItem {
  const AfterSaleItem({
    required this.lineKey,
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.unitPrice,
    required this.paidAmount,
    this.skuId,
    this.skuName,
    this.productImage = '',
    this.approvedQuantity = 0,
    this.refundedQuantity = 0,
    this.discountAmount = 0,
    this.approvedAmount = 0,
    this.refundedAmount = 0,
    this.restockQuantity = 0,
    this.inventoryRestoredQuantity = 0,
  });

  final String lineKey;
  final int productId;
  final int? skuId;
  final String productName;
  final String? skuName;
  final String productImage;
  final int requestedQuantity;
  final int approvedQuantity;
  final int refundedQuantity;
  final double unitPrice;
  final double discountAmount;
  final double paidAmount;
  final double approvedAmount;
  final double refundedAmount;
  final int restockQuantity;
  final int inventoryRestoredQuantity;
}

class AfterSaleLog {
  const AfterSaleLog({
    required this.id,
    required this.action,
    required this.operatorType,
    this.description,
    this.createdAt,
  });

  final int id;
  final String action;
  final String operatorType;
  final String? description;
  final DateTime? createdAt;
}

class OrderAfterSale {
  const OrderAfterSale({
    required this.id,
    required this.afterSaleNo,
    required this.orderId,
    required this.status,
    required this.reasonCode,
    required this.refundAmount,
    this.orderType = 'second_hand',
    this.handlerType = AfterSaleHandlerType.seller,
    this.afterSaleType = AfterSaleType.refundOnly,
    this.requestedAmount = 0,
    this.approvedAmount,
    this.items = const [],
    this.description,
    this.evidenceUrls = const [],
    this.handlerDecision,
    this.handlerReason,
    this.returnRequired,
    this.returnAddress,
    this.returnTrackingNumber,
    this.returnEvidenceUrls = const [],
    this.arbitrationReason,
    this.arbitrationEvidenceUrls = const [],
    this.arbitrationDecision,
    this.arbitrationRemark,
    this.currentDeadlineAt,
    this.refundFailureReason,
    this.availableActions = const [],
    this.logs = const [],
    this.order,
    this.viewRole = OrderViewRole.buyer,
  });

  final int id;
  final String afterSaleNo;
  final int orderId;
  final String orderType;
  final AfterSaleHandlerType handlerType;
  final AfterSaleType afterSaleType;
  final AfterSaleStatus status;
  final String reasonCode;
  final String? description;
  final List<String> evidenceUrls;
  final String? handlerDecision;
  final String? handlerReason;
  final bool? returnRequired;
  final String? returnAddress;
  final String? returnTrackingNumber;
  final List<String> returnEvidenceUrls;
  final String? arbitrationReason;
  final List<String> arbitrationEvidenceUrls;
  final String? arbitrationDecision;
  final String? arbitrationRemark;
  final DateTime? currentDeadlineAt;
  final double requestedAmount;
  final double? approvedAmount;
  final double refundAmount;
  final String? refundFailureReason;
  final List<AfterSaleItem> items;
  final List<String> availableActions;
  final List<AfterSaleLog> logs;
  final ShopOrder? order;
  final OrderViewRole viewRole;

  String? get sellerDecision => handlerDecision;
  String? get sellerReason => handlerReason;
  bool hasAction(String action) => availableActions.contains(action);
}

abstract interface class AfterSaleGateway {
  Future<OrderAfterSale> createAfterSale(
    int orderId, {
    required AfterSaleType afterSaleType,
    required List<AfterSaleRequestItem> items,
    required String reasonCode,
    String? description,
    List<String> evidenceUrls = const [],
  });

  Future<OrderAfterSale> loadAfterSale(int afterSaleId);
  Future<OrderAfterSale> cancelAfterSale(int afterSaleId);

  Future<OrderAfterSale> approveAfterSale(
    int afterSaleId, {
    required bool returnRequired,
    String? returnAddress,
    String? reason,
  });

  Future<OrderAfterSale> rejectAfterSale(
    int afterSaleId, {
    required String reason,
  });

  Future<OrderAfterSale> submitReturn(
    int afterSaleId, {
    String? trackingNumber,
    List<String> evidenceUrls = const [],
  });

  Future<OrderAfterSale> confirmReturn(int afterSaleId);

  Future<OrderAfterSale> applyArbitration(
    int afterSaleId, {
    required String reason,
    List<String> evidenceUrls = const [],
  });

  Future<String> uploadEvidence(String filePath);
}

class AfterSaleRouteArgs {
  const AfterSaleRouteArgs(this.afterSaleId, {required this.viewRole});
  final int afterSaleId;
  final OrderViewRole viewRole;
}
