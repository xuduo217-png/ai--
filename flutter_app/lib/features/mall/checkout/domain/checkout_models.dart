import '../../address/domain/address_models.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../order/domain/order_models.dart';

class CheckoutItem {
  const CheckoutItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.source,
    this.skuId,
    this.skuName,
    this.imageUrl = '',
    this.cartItemId,
  });

  final int productId;
  final int? skuId;
  final String productName;
  final String? skuName;
  final String imageUrl;
  final double price;
  final int quantity;
  final ProductSource source;
  final int? cartItemId;

  bool get isSecondHand => source == ProductSource.user;
  double get subtotal => price * quantity;

  Map<String, Object?> toOrderJson() => {
    'productId': productId,
    if (skuId != null) 'skuId': skuId,
    'quantity': quantity,
  };
}

class CheckoutCoupon {
  const CheckoutCoupon({
    required this.id,
    required this.name,
    required this.type,
    required this.discount,
    required this.minAmount,
    required this.isApplicable,
    required this.discountAmount,
    this.unavailableReason,
    this.validUntil,
  });

  final int id;
  final String name;
  final String type;
  final double discount;
  final double minAmount;
  final bool isApplicable;
  final double discountAmount;
  final String? unavailableReason;
  final DateTime? validUntil;
}

class OrderPreview {
  const OrderPreview({
    required this.originalAmount,
    required this.couponDiscount,
    required this.totalAmount,
    required this.containsUserPublishedProducts,
    required this.couponEligibleAmount,
    required this.couponExcludedAmount,
    this.coupons = const [],
    this.selectedCoupon,
    this.charityDonationRate,
    this.charityDonationAmount,
  });

  final double originalAmount;
  final double couponDiscount;
  final double totalAmount;
  final List<CheckoutCoupon> coupons;
  final CheckoutCoupon? selectedCoupon;
  final bool containsUserPublishedProducts;
  final double couponEligibleAmount;
  final double couponExcludedAmount;
  final double? charityDonationRate;
  final double? charityDonationAmount;
}

class CreateOrderInput {
  const CreateOrderInput({
    required this.items,
    required this.address,
    required this.paymentChannel,
    this.remark = '',
    this.userCouponId,
  });

  final List<CheckoutItem> items;
  final ShippingAddress address;
  final PaymentChannel paymentChannel;
  final String remark;
  final int? userCouponId;

  Map<String, Object?> toJson() => {
    'items': items.map((item) => item.toOrderJson()).toList(growable: false),
    'shippingAddress': address.fullAddress,
    'receiverName': address.receiverName,
    'receiverPhone': address.receiverPhone,
    if (remark.trim().isNotEmpty) 'remark': remark.trim(),
    if (userCouponId != null) 'userCouponId': userCouponId,
    'paymentChannel': paymentChannel.wireValue,
  };
}

class CheckoutResult {
  const CheckoutResult.success(this.payment)
    : stockError = null,
      stockDetails = const [];

  const CheckoutResult.stockFailure({
    required this.stockError,
    this.stockDetails = const [],
  }) : payment = null;

  final OrderPayment? payment;
  final String? stockError;
  final List<String> stockDetails;
  bool get isSuccess => payment != null;
}

abstract interface class CheckoutGateway {
  Future<OrderPreview> preview(List<CheckoutItem> items, {int? userCouponId});
  Future<CheckoutResult> createOrder(CreateOrderInput input);
  Future<double> loadWalletBalance();
}

class CheckoutRouteArgs {
  const CheckoutRouteArgs(this.items);
  final List<CheckoutItem> items;
  List<int> get cartItemIds => items
      .map((item) => item.cartItemId)
      .whereType<int>()
      .toList(growable: false);
}
