import 'package:flutter/material.dart';

import '../address/presentation/pages/address_list_page.dart';
import '../cart/presentation/cart_controller.dart';
import '../cart/presentation/pages/cart_page.dart';
import '../catalog/domain/catalog_models.dart';
import '../catalog/presentation/pages/category_browser_page.dart';
import '../catalog/presentation/pages/product_detail_page.dart';
import '../catalog/presentation/pages/product_list_page.dart';
import '../catalog/presentation/pages/product_search_page.dart';
import '../checkout/domain/checkout_models.dart';
import '../checkout/presentation/pages/checkout_page.dart';
import '../favorite/presentation/pages/favorite_page.dart';
import '../order/domain/order_models.dart';
import '../order/domain/after_sale_models.dart';
import '../order/presentation/pages/after_sale_pages.dart';
import '../order/presentation/pages/order_detail_page.dart';
import '../order/presentation/pages/order_list_page.dart';
import '../second_hand/presentation/pages/publish_product_page.dart';
import '../second_hand/presentation/pages/published_product_page.dart';
import '../second_hand/presentation/pages/second_hand_mall_page.dart';
import '../../marketplace_chat/marketplace_chat_session.dart';
import '../../marketplace_chat/presentation/marketplace_chat_page.dart';
import 'mall_dependencies.dart';

typedef RequestMallLogin = Future<bool> Function(String message);

class CatalogRouteArgs {
  const CatalogRouteArgs({
    this.categoryId,
    this.title = '全部商品',
    this.popular = false,
  });

  final int? categoryId;
  final String title;
  final bool popular;
}

class CategoryBrowserRouteArgs {
  const CategoryBrowserRouteArgs({
    this.initialFirstCategoryId,
    this.title = '商品分类',
    this.source = ProductSource.admin,
    this.showCartButton = true,
  });

  final int? initialFirstCategoryId;
  final String title;
  final ProductSource source;
  final bool showCartButton;
}

class PublishProductRouteArgs {
  const PublishProductRouteArgs({this.pendingId});
  final int? pendingId;
}

class MallNavigationCoordinator {
  MallNavigationCoordinator(this.dependencies);

  final MallDependencies dependencies;
  _MallDestination? _pendingDestination;
  MarketplaceChatSession? _marketplaceSession;

  bool get hasPendingDestination => _pendingDestination != null;

  void setMarketplaceChatSession(MarketplaceChatSession? session) {
    _marketplaceSession = session;
  }

  Future<void> openSearch(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      const _SearchDestination(),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openCatalog(
    BuildContext context,
    CatalogRouteArgs args, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      _CatalogDestination(args),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openCategories(
    BuildContext context,
    CategoryBrowserRouteArgs args, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      _CategoryBrowserDestination(args),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openProduct(
    BuildContext context,
    ProductRouteArgs args, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      _ProductDestination(args),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openSecondHand(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      const _SecondHandDestination(),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openCart(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      const _CartDestination(),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openOrders(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
    OrderViewRole viewRole = OrderViewRole.buyer,
  }) {
    return _open(
      context,
      _OrdersDestination(viewRole),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openAfterSale(
    BuildContext context,
    AfterSaleRouteArgs args, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      _AfterSaleDestination(args),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openOrderDetail(
    BuildContext context,
    OrderRouteArgs args, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      _OrderDetailDestination(args),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openAddresses(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      const _AddressesDestination(),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openFavorites(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      const _FavoritesDestination(),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> openPublishedProducts(
    BuildContext context, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    return _open(
      context,
      const _PublishedProductsDestination(),
      authenticated: authenticated,
      requestLogin: requestLogin,
    );
  }

  Future<void> resumePending(
    BuildContext context, {
    required RequestMallLogin requestLogin,
  }) async {
    final destination = _pendingDestination;
    if (destination == null) return;
    _pendingDestination = null;
    await _open(
      context,
      destination,
      authenticated: true,
      requestLogin: requestLogin,
    );
  }

  Future<void> _open(
    BuildContext context,
    _MallDestination destination, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
    bool replaceCurrent = false,
  }) async {
    if (destination.protected && !authenticated) {
      _pendingDestination = destination;
      await requestLogin(destination.loginMessage);
      return;
    }
    final route = MaterialPageRoute<void>(
      builder: (routeContext) => _buildPage(
        routeContext,
        destination,
        authenticated: authenticated,
        requestLogin: requestLogin,
      ),
    );
    if (replaceCurrent) {
      await Navigator.of(context).pushReplacement<void, void>(route);
    } else {
      await Navigator.of(context).push<void>(route);
    }
  }

  Widget _buildPage(
    BuildContext context,
    _MallDestination destination, {
    required bool authenticated,
    required RequestMallLogin requestLogin,
  }) {
    switch (destination) {
      case _SearchDestination():
        return ProductSearchPage(
          gateway: dependencies.catalogGateway,
          onProduct: (product) => openProduct(
            context,
            ProductRouteArgs(product.id, source: product.source),
            authenticated: authenticated,
            requestLogin: requestLogin,
          ),
        );
      case _CatalogDestination(:final args):
        return ProductListPage(
          gateway: dependencies.catalogGateway,
          title: args.title,
          categoryId: args.categoryId,
          popular: args.popular,
          onProduct: (product) => openProduct(
            context,
            ProductRouteArgs(product.id, source: product.source),
            authenticated: authenticated,
            requestLogin: requestLogin,
          ),
        );
      case _CategoryBrowserDestination(:final args):
        return CategoryBrowserPage(
          gateway: dependencies.catalogGateway,
          cartGateway: dependencies.cartGateway,
          initialFirstCategoryId: args.initialFirstCategoryId,
          title: args.title,
          source: args.source,
          showCartButton: args.showCartButton,
          authenticated: authenticated,
          onLoginRequired: () {
            _pendingDestination = destination;
            requestLogin('登录后即可加入购物车');
          },
          onSearch: () => openSearch(
            context,
            authenticated: authenticated,
            requestLogin: requestLogin,
          ),
          onCart: () => openCart(
            context,
            authenticated: authenticated,
            requestLogin: requestLogin,
          ),
          onProduct: (product) => openProduct(
            context,
            ProductRouteArgs(product.id, source: product.source),
            authenticated: authenticated,
            requestLogin: requestLogin,
          ),
        );
      case _ProductDestination(:final args):
        return ProductDetailPage(
          productId: args.productId,
          catalogGateway: dependencies.catalogGateway,
          cartGateway: dependencies.cartGateway,
          favoriteGateway: dependencies.favoriteGateway,
          secondHandGateway: dependencies.secondHandGateway,
          authenticated: authenticated,
          onLoginRequired: () {
            _pendingDestination = destination;
            requestLogin('登录后即可购买、收藏或管理商品');
          },
          onCheckout: (checkoutArgs) => _open(
            context,
            _CheckoutDestination(checkoutArgs),
            authenticated: authenticated,
            requestLogin: requestLogin,
          ),
          currentUserId: _marketplaceSession?.ownerUserId,
          onContactSeller: () async {
            final session = _marketplaceSession;
            if (session == null) {
              await requestLogin('登录后即可联系卖家');
              return;
            }
            try {
              final conversation = await session.controller
                  .openProductConversation(args.productId);
              if (!context.mounted) return;
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => MarketplaceChatPage(
                    controller: session.controller,
                    conversation: conversation,
                    onProductTap: (_) async {
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              );
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$error')));
              }
            }
          },
        );
      case _SecondHandDestination():
        return SecondHandMallPage(
          gateway: dependencies.secondHandGateway,
          onProduct: (product) => openProduct(
            context,
            ProductRouteArgs(product.id, source: ProductSource.user),
            authenticated: authenticated,
            requestLogin: requestLogin,
          ),
        );
      case _CartDestination():
        return CartPage(
          gateway: dependencies.cartGateway,
          onProduct: (id) => openProduct(
            context,
            ProductRouteArgs(id),
            authenticated: true,
            requestLogin: requestLogin,
          ),
          onCheckout: (args, controller) => _open(
            context,
            _CheckoutDestination(args, cartController: controller),
            authenticated: true,
            requestLogin: requestLogin,
          ),
        );
      case _CheckoutDestination(:final args, :final cartController):
        return CheckoutPage(
          args: args,
          checkoutGateway: dependencies.checkoutGateway,
          addressGateway: dependencies.addressGateway,
          orderGateway: dependencies.orderGateway,
          paymentGateway: dependencies.paymentGateway,
          cartController: cartController,
          onOrderDetail: (id) => _open(
            context,
            _OrderDetailDestination(OrderRouteArgs(id)),
            authenticated: true,
            requestLogin: requestLogin,
            replaceCurrent: true,
          ),
        );
      case _OrdersDestination(:final viewRole):
        return OrderListPage(
          gateway: dependencies.orderGateway,
          viewRole: viewRole,
          onOrder: (id) => _open(
            context,
            _OrderDetailDestination(OrderRouteArgs(id, viewRole: viewRole)),
            authenticated: true,
            requestLogin: requestLogin,
          ),
        );
      case _OrderDetailDestination(:final args):
        if (args.afterSaleId case final afterSaleId?) {
          final gateway = dependencies.afterSaleGateway;
          if (gateway != null) {
            return AfterSaleDetailPage(
              afterSaleId: afterSaleId,
              gateway: gateway,
            );
          }
        }
        return OrderDetailPage(
          orderId: args.orderId,
          gateway: dependencies.orderGateway,
          checkoutGateway: dependencies.checkoutGateway,
          paymentGateway: dependencies.paymentGateway,
          afterSaleGateway: dependencies.afterSaleGateway,
        );
      case _AfterSaleDestination(:final args):
        final gateway = dependencies.afterSaleGateway;
        if (gateway == null) {
          return const Scaffold(body: Center(child: Text('售后功能暂不可用')));
        }
        return AfterSaleDetailPage(
          afterSaleId: args.afterSaleId,
          gateway: gateway,
        );
      case _AddressesDestination():
        return AddressListPage(gateway: dependencies.addressGateway);
      case _FavoritesDestination():
        return FavoritePageView(
          gateway: dependencies.favoriteGateway,
          cartGateway: dependencies.cartGateway,
          onProduct: (product) => openProduct(
            context,
            ProductRouteArgs(product.id, source: product.source),
            authenticated: true,
            requestLogin: requestLogin,
          ),
          onBrowse: () => openCatalog(
            context,
            const CatalogRouteArgs(),
            authenticated: true,
            requestLogin: requestLogin,
          ),
        );
      case _PublishedProductsDestination():
        return PublishedProductPage(
          gateway: dependencies.secondHandGateway,
          onPublish: () => _open(
            context,
            const _PublishProductDestination(PublishProductRouteArgs()),
            authenticated: true,
            requestLogin: requestLogin,
          ),
          onEdit: (id) => _open(
            context,
            _PublishProductDestination(PublishProductRouteArgs(pendingId: id)),
            authenticated: true,
            requestLogin: requestLogin,
          ),
        );
      case _PublishProductDestination(:final args):
        return PublishProductPage(
          gateway: dependencies.secondHandGateway,
          pendingId: args.pendingId,
        );
    }
  }
}

sealed class _MallDestination {
  const _MallDestination({required this.protected, this.loginMessage = ''});

  final bool protected;
  final String loginMessage;
}

class _SearchDestination extends _MallDestination {
  const _SearchDestination() : super(protected: false);
}

class _CatalogDestination extends _MallDestination {
  const _CatalogDestination(this.args) : super(protected: false);
  final CatalogRouteArgs args;
}

class _CategoryBrowserDestination extends _MallDestination {
  const _CategoryBrowserDestination(this.args) : super(protected: false);
  final CategoryBrowserRouteArgs args;
}

class _ProductDestination extends _MallDestination {
  const _ProductDestination(this.args) : super(protected: false);
  final ProductRouteArgs args;
}

class _SecondHandDestination extends _MallDestination {
  const _SecondHandDestination() : super(protected: false);
}

class _CartDestination extends _MallDestination {
  const _CartDestination() : super(protected: true, loginMessage: '登录后即可查看购物车');
}

class _CheckoutDestination extends _MallDestination {
  const _CheckoutDestination(this.args, {this.cartController})
    : super(protected: true, loginMessage: '登录后即可提交订单');
  final CheckoutRouteArgs args;
  final CartController? cartController;
}

class _OrdersDestination extends _MallDestination {
  const _OrdersDestination(this.viewRole)
    : super(protected: true, loginMessage: '登录后即可查看订单');
  final OrderViewRole viewRole;
}

class _OrderDetailDestination extends _MallDestination {
  const _OrderDetailDestination(this.args)
    : super(protected: true, loginMessage: '登录后即可查看订单详情');
  final OrderRouteArgs args;
}

class _AfterSaleDestination extends _MallDestination {
  const _AfterSaleDestination(this.args)
    : super(protected: true, loginMessage: '登录后即可查看售后详情');
  final AfterSaleRouteArgs args;
}

class _AddressesDestination extends _MallDestination {
  const _AddressesDestination()
    : super(protected: true, loginMessage: '登录后即可管理收货地址');
}

class _FavoritesDestination extends _MallDestination {
  const _FavoritesDestination()
    : super(protected: true, loginMessage: '登录后即可查看我的收藏');
}

class _PublishedProductsDestination extends _MallDestination {
  const _PublishedProductsDestination()
    : super(protected: true, loginMessage: '登录后即可查看我发布的商品');
}

class _PublishProductDestination extends _MallDestination {
  const _PublishProductDestination(this.args)
    : super(protected: true, loginMessage: '登录后即可发布商品');
  final PublishProductRouteArgs args;
}
