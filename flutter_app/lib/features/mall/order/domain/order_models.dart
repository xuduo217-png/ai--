import '../../catalog/domain/catalog_models.dart';

enum ShopOrderStatus {
  pending('pending', '待支付'),
  paid('paid', '待发货'),
  shipped('shipped', '待收货'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消'),
  unknown('unknown', '未知状态');

  const ShopOrderStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static ShopOrderStatus fromJson(Object? value) {
    final normalized = '$value'.toLowerCase();
    return ShopOrderStatus.values.firstWhere(
      (status) => status.wireValue == normalized,
      orElse: () => ShopOrderStatus.unknown,
    );
  }
}

enum OrderViewRole {
  buyer('buyer'),
  seller('seller');

  const OrderViewRole(this.wireValue);
  final String wireValue;

  static OrderViewRole fromJson(Object? value) =>
      '$value'.toLowerCase() == seller.wireValue ? seller : buyer;
}

class OrderAfterSaleSummary {
  const OrderAfterSaleSummary({
    required this.id,
    required this.afterSaleNo,
    required this.status,
    required this.refundAmount,
    this.updatedAt,
  });

  final int id;
  final String afterSaleNo;
  final String status;
  final double refundAmount;
  final DateTime? updatedAt;
}

class ShopOrderItem {
  const ShopOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.productImage = '',
    this.skuId,
    this.skuName,
    this.lineKey = '',
    this.discountAmount = 0,
    this.paidAmount = 0,
  });

  final int productId;
  final String productName;
  final String productImage;
  final int? skuId;
  final String? skuName;
  final String lineKey;
  final int quantity;
  final double price;
  final double discountAmount;
  final double paidAmount;

  double get subtotal => price * quantity;
  double get actualPaidAmount => paidAmount > 0 ? paidAmount : subtotal;
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.totalAmount,
    required this.originalAmount,
    required this.couponDiscount,
    required this.items,
    this.orderType = 'normal',
    this.shippingAddress,
    this.receiverName,
    this.receiverPhone,
    this.remark,
    this.paymentMethod,
    this.paymentNo,
    this.transactionId,
    this.createdAt,
    this.paidAt,
    this.shippedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.trackingNumber,
    this.viewRole = OrderViewRole.buyer,
    this.availableActions = const [],
    this.afterSaleSummary,
    this.autoConfirmAt,
    this.settlementStatus,
    this.charityDonationAmount,
  });

  final int id;
  final String orderNo;
  final String orderType;
  final ShopOrderStatus status;
  final double totalAmount;
  final double originalAmount;
  final double couponDiscount;
  final List<ShopOrderItem> items;
  final String? shippingAddress;
  final String? receiverName;
  final String? receiverPhone;
  final String? remark;
  final String? paymentMethod;
  final String? paymentNo;
  final String? transactionId;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? trackingNumber;
  final OrderViewRole viewRole;
  final List<String> availableActions;
  final OrderAfterSaleSummary? afterSaleSummary;
  final DateTime? autoConfirmAt;
  final String? settlementStatus;
  final double? charityDonationAmount;

  bool hasAction(String action) => availableActions.contains(action);
  bool get canPay => hasAction('pay');
  bool get canCancel => hasAction('cancel');
  bool get canConfirm => hasAction('confirm_receipt');
  bool get isSecondHand => orderType == 'second_hand';
  bool get paid => const {
    ShopOrderStatus.paid,
    ShopOrderStatus.shipped,
    ShopOrderStatus.completed,
  }.contains(status);
}

class OrderQuery {
  const OrderQuery({
    this.status,
    this.afterSaleStatus,
    this.viewRole = OrderViewRole.buyer,
    this.page = 1,
    this.pageSize = 20,
  });

  final ShopOrderStatus? status;
  final String? afterSaleStatus;
  final OrderViewRole viewRole;
  final int page;
  final int pageSize;

  Map<String, Object?> toQueryParameters() => {
    'status': status?.wireValue,
    'afterSaleStatus': afterSaleStatus,
    'page': page,
    'pageSize': pageSize,
  };
}

class OrderPage {
  const OrderPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.totalPages = 0,
  });

  final List<ShopOrder> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  bool get hasMore => totalPages > 0 && page < totalPages;
}

enum PaymentChannel {
  alipay('alipay'),
  balance('balance'),
  wechat('wechat');

  const PaymentChannel(this.wireValue);
  final String wireValue;
}

class OrderPayment {
  const OrderPayment({required this.order, this.paymentParams = const {}});

  final ShopOrder order;
  final Map<String, dynamic> paymentParams;

  String? get alipayOrderString {
    Object? current = paymentParams;
    for (var depth = 0; depth < 3 && current is Map; depth += 1) {
      final map = Map<String, dynamic>.from(current);
      final candidate = map['alipayOrderString'];
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
      current = map['paymentParams'];
    }
    return null;
  }
}

abstract interface class OrderGateway {
  Future<OrderPage> loadOrders(OrderQuery query);
  Future<ShopOrder> loadOrder(int orderId);
  Future<ShopOrder> cancelOrder(int orderId, {String? reason});
  Future<ShopOrder> confirmOrder(int orderId);
  Future<OrderPayment> payOrder(int orderId, PaymentChannel channel);
}

class OrderActionSummary {
  const OrderActionSummary({
    this.pendingReceipt = 0,
    this.afterSaleResult = 0,
    this.pendingShipment = 0,
    this.pendingAfterSale = 0,
  });

  final int pendingReceipt;
  final int afterSaleResult;
  final int pendingShipment;
  final int pendingAfterSale;

  int get purchaseCount => pendingReceipt;
  int get salesCount => pendingShipment + pendingAfterSale;
}

abstract interface class SecondHandOrderGateway {
  Future<ShopOrder> shipOrder(int orderId, {String? trackingNumber});
  Future<ShopOrder> updateTracking(int orderId, {String? trackingNumber});
  Future<OrderActionSummary> loadActionSummary();
}

class OrderRouteArgs {
  const OrderRouteArgs(
    this.orderId, {
    this.viewRole = OrderViewRole.buyer,
    this.afterSaleId,
  });
  final int orderId;
  final OrderViewRole viewRole;
  final int? afterSaleId;
}

class ProductRouteArgs {
  const ProductRouteArgs(this.productId, {this.source = ProductSource.admin});
  final int productId;
  final ProductSource source;
}
