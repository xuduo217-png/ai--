import '../../../core/network/api_client.dart';
import '../address/data/address_repository.dart';
import '../address/domain/address_models.dart';
import '../cart/data/cart_repository.dart';
import '../cart/domain/cart_models.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../checkout/data/checkout_repository.dart';
import '../checkout/domain/checkout_models.dart';
import '../favorite/data/favorite_repository.dart';
import '../favorite/domain/favorite_models.dart';
import '../order/data/order_repository.dart';
import '../order/data/after_sale_repository.dart';
import '../order/domain/after_sale_models.dart';
import '../order/domain/order_models.dart';
import '../payment/data/tobias_payment_gateway.dart';
import '../payment/domain/payment_models.dart';
import '../second_hand/data/second_hand_repository.dart';
import '../second_hand/domain/second_hand_models.dart';

class MallDependencies {
  const MallDependencies({
    required this.catalogGateway,
    required this.cartGateway,
    required this.checkoutGateway,
    required this.addressGateway,
    required this.orderGateway,
    this.afterSaleGateway,
    required this.favoriteGateway,
    required this.secondHandGateway,
    required this.paymentGateway,
  });

  factory MallDependencies.production(
    ApiClient apiClient, {
    PaymentGateway? paymentGateway,
  }) {
    return MallDependencies(
      catalogGateway: CatalogRepository(apiClient),
      cartGateway: CartRepository(apiClient),
      checkoutGateway: CheckoutRepository(apiClient),
      addressGateway: AddressRepository(apiClient),
      orderGateway: OrderRepository(apiClient),
      afterSaleGateway: AfterSaleRepository(apiClient),
      favoriteGateway: FavoriteRepository(apiClient),
      secondHandGateway: SecondHandRepository(apiClient),
      paymentGateway: paymentGateway ?? TobiasPaymentGateway(),
    );
  }

  final CatalogGateway catalogGateway;
  final CartGateway cartGateway;
  final CheckoutGateway checkoutGateway;
  final AddressGateway addressGateway;
  final OrderGateway orderGateway;
  final AfterSaleGateway? afterSaleGateway;
  final FavoriteGateway favoriteGateway;
  final SecondHandGateway secondHandGateway;
  final PaymentGateway paymentGateway;
}
