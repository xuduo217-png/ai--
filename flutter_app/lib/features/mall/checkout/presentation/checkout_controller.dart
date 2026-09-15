import 'package:flutter/foundation.dart';

import '../../address/domain/address_models.dart';
import '../../address/presentation/address_controller.dart';
import '../../cart/domain/cart_models.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../order/domain/order_models.dart';
import '../domain/checkout_models.dart';

class CheckoutController extends ChangeNotifier {
  CheckoutController({
    required CheckoutGateway checkoutGateway,
    required AddressController addressController,
    CartController? cartController,
    required this.items,
  }) : _checkoutGateway = checkoutGateway,
       _addressController = addressController,
       _cartController = cartController;

  final CheckoutGateway _checkoutGateway;
  final AddressController _addressController;
  final CartController? _cartController;
  final List<CheckoutItem> items;

  ShippingAddress? address;
  OrderPreview? preview;
  CheckoutCoupon? selectedCoupon;
  bool loading = false;
  bool submitting = false;
  String? errorMessage;

  double get fallbackTotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get payableAmount => preview?.totalAmount ?? fallbackTotal;
  bool get containsSecondHand => items.any((item) => item.isSecondHand);

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _addressController.load();
      address = _addressController.defaultAddress;
      preview = await _checkoutGateway.preview(items);
      selectedCoupon = preview?.selectedCoupon;
    } catch (error) {
      errorMessage = '$error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectAddress(ShippingAddress value) {
    address = value;
    notifyListeners();
  }

  Future<void> selectCoupon(CheckoutCoupon? coupon) async {
    try {
      preview = await _checkoutGateway.preview(items, userCouponId: coupon?.id);
      selectedCoupon = preview?.selectedCoupon;
    } catch (_) {
      preview = await _checkoutGateway.preview(items);
      selectedCoupon = null;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<CheckoutResult> submit(String remark) async {
    if (address == null) throw StateError('请选择收货地址');
    submitting = true;
    notifyListeners();
    try {
      final result = await _checkoutGateway.createOrder(
        CreateOrderInput(
          items: items,
          address: address!,
          paymentChannel: PaymentChannel.alipay,
          remark: remark,
          userCouponId: selectedCoupon?.id,
        ),
      );
      if (result.isSuccess) await _removeCreatedCartItems();
      return result;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> _removeCreatedCartItems() async {
    final cartController = _cartController;
    if (cartController == null) return;
    final ids = items.map((item) => item.cartItemId).whereType<int>().toSet();
    if (ids.isEmpty) return;
    try {
      await cartController.removeByIds(ids);
    } catch (_) {
      // 订单已经创建成功，购物车清理失败不应改变提交结果。
    }
  }
}

CheckoutItem checkoutItemFromCart(CartItem item) {
  return CheckoutItem(
    productId: item.productId,
    skuId: item.skuId,
    productName: item.product.name,
    skuName: item.sku?.name,
    imageUrl: item.sku?.imageUrl.isNotEmpty == true
        ? item.sku!.imageUrl
        : item.product.imageUrl,
    price: item.unitPrice,
    quantity: item.quantity,
    source: item.product.source,
    cartItemId: item.id,
  );
}
