import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/mall/address/domain/address_models.dart';
import 'package:pet_hospital_flutter/features/mall/address/presentation/address_controller.dart';
import 'package:pet_hospital_flutter/features/mall/address/presentation/pages/address_edit_page.dart';
import 'package:pet_hospital_flutter/features/mall/address/presentation/pages/address_list_page.dart';
import 'package:pet_hospital_flutter/features/mall/cart/domain/cart_models.dart';
import 'package:pet_hospital_flutter/features/mall/cart/presentation/pages/cart_page.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/domain/catalog_models.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/presentation/pages/product_detail_page.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/presentation/pages/product_list_page.dart';
import 'package:pet_hospital_flutter/features/mall/catalog/presentation/pages/product_search_page.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/domain/checkout_models.dart';
import 'package:pet_hospital_flutter/features/mall/checkout/presentation/pages/checkout_page.dart';
import 'package:pet_hospital_flutter/features/mall/favorite/domain/favorite_models.dart';
import 'package:pet_hospital_flutter/features/mall/favorite/presentation/pages/favorite_page.dart';
import 'package:pet_hospital_flutter/features/mall/navigation/mall_dependencies.dart';
import 'package:pet_hospital_flutter/features/mall/navigation/mall_navigation_coordinator.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/order/presentation/pages/order_detail_page.dart';
import 'package:pet_hospital_flutter/features/mall/order/presentation/pages/order_list_page.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';
import 'package:pet_hospital_flutter/features/mall/second_hand/domain/second_hand_models.dart';
import 'package:pet_hospital_flutter/features/mall/second_hand/presentation/pages/publish_product_page.dart';
import 'package:pet_hospital_flutter/features/mall/second_hand/presentation/pages/published_product_page.dart';
import 'package:pet_hospital_flutter/features/mall/second_hand/presentation/pages/second_hand_mall_page.dart';
import 'package:pet_hospital_flutter/features/mall/shared/mall_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/wp11_viewports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final viewport in wp11Viewports) {
    testWidgets('商城完整页面集在 ${viewport.label} 下无布局溢出', (tester) async {
      SharedPreferences.setMockInitialValues({});
      configureWp11Viewport(tester, viewport);

      final gateway = _MallGateway();
      final addressController = AddressController(gateway);
      addTearDown(addressController.dispose);
      final pages = <String, Widget>{
        '商品搜索': ProductSearchPage(gateway: gateway, onProduct: (_) {}),
        '商品列表': ProductListPage(gateway: gateway, onProduct: (_) {}),
        '商品详情': ProductDetailPage(
          productId: 1,
          catalogGateway: gateway,
          cartGateway: gateway,
          favoriteGateway: gateway,
          secondHandGateway: gateway,
          authenticated: true,
          onLoginRequired: () {},
          onCheckout: (_) {},
        ),
        '购物车': CartPage(
          gateway: gateway,
          onProduct: (_) {},
          onCheckout: (_, _) {},
        ),
        '确认订单': CheckoutPage(
          args: const CheckoutRouteArgs([_checkoutItem]),
          checkoutGateway: gateway,
          addressGateway: gateway,
          orderGateway: gateway,
          paymentGateway: gateway,
          onOrderDetail: (_) {},
        ),
        '地址列表': AddressListPage(gateway: gateway),
        '地址编辑': AddressEditPage(
          controller: addressController,
          existing: _address,
        ),
        '订单列表': OrderListPage(gateway: gateway, onOrder: (_) async {}),
        '订单详情': OrderDetailPage(
          orderId: 7,
          gateway: gateway,
          checkoutGateway: gateway,
          paymentGateway: gateway,
        ),
        '收藏列表': FavoritePageView(
          gateway: gateway,
          cartGateway: gateway,
          onProduct: (_) {},
          onBrowse: () {},
        ),
        '二手商城': SecondHandMallPage(gateway: gateway, onProduct: (_) {}),
        '我的发布': PublishedProductPage(
          gateway: gateway,
          onPublish: () async {},
          onEdit: (_) async {},
        ),
        '发布商品': PublishProductPage(gateway: gateway),
      };

      for (final entry in pages.entries) {
        await tester.pumpWidget(
          MaterialApp(
            builder: wp11TextScaleBuilder(viewport.textScale),
            home: entry.value,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} @ ${viewport.label}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }

  testWidgets('商城列表页覆盖空态、失败态和重试入口', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CartPage(
          gateway: _MallGateway(empty: true),
          onProduct: (_) {},
          onCheckout: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('购物车还是空的'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductListPage(
          gateway: _MallGateway(failure: StateError('网络异常')),
          onProduct: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('网络异常'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('二手商城对齐商品分类页并使用立即购买入口', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _MallGateway();
    CatalogProduct? openedProduct;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SecondHandMallPage(
          gateway: gateway,
          onProduct: (product) => openedProduct = product,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFDEE9FF));
    expect(appBar.surfaceTintColor, const Color(0xFFDEE9FF));
    expect(appBar.foregroundColor, AppColors.ink);
    expect(appBar.centerTitle, isTrue);
    expect(find.text('二手商品仅支持立即购买'), findsNothing);
    expect(find.text('请核验商品信息后下单'), findsNothing);
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('second-hand-search-area')),
          )
          .color,
      const Color(0xFFDEE9FF),
    );
    expect(
      find.byKey(const ValueKey('second-hand-first-category-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('second-hand-selected-first-category-20')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('second-hand-second-category-20-22')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('second-hand-product-2')), findsOneWidget);
    expect(find.text(_secondHandProduct.name), findsOneWidget);
    expect(find.text('加入购物车'), findsNothing);
    expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('立即购买'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('buy-second-hand-product-2')));
    expect(openedProduct?.id, _secondHandProduct.id);

    await tester.enterText(
      find.byKey(const ValueKey('second-hand-search-input')),
      '航空箱',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(gateway.productQueries.last.categoryId, 22);
    expect(gateway.productQueries.last.keyword, '航空箱');
    expect(tester.takeException(), isNull);
  });

  testWidgets('购物车在语义树开启时可稳定更新布局', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: CartPage(
          gateway: _MallGateway(),
          onProduct: (_) {},
          onCheckout: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('增加数量'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('购物车路由动画期间返回数据时语义树保持稳定', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final cartResult = Completer<List<CartItem>>();
    final gateway = _MallGateway(cartResult: cartResult);
    final coordinator = MallNavigationCoordinator(
      MallDependencies(
        catalogGateway: gateway,
        cartGateway: gateway,
        checkoutGateway: gateway,
        addressGateway: gateway,
        orderGateway: gateway,
        favoriteGateway: gateway,
        secondHandGateway: gateway,
        paymentGateway: gateway,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                coordinator.openCart(
                  context,
                  authenticated: true,
                  requestLogin: (_) async => false,
                ),
              ),
              child: const Text('打开购物车'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开购物车'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    cartResult.complete(const [_cartItem]);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('购物车'), findsOneWidget);
    expect(find.text(_adminProduct.name), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('富文本详情点击立即购买可稳定切换到确认订单页', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final gateway = _MallGateway(product: _richAdminProduct);
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            pageContext = context;
            return ProductDetailPage(
              productId: _richAdminProduct.id,
              catalogGateway: gateway,
              cartGateway: gateway,
              favoriteGateway: gateway,
              secondHandGateway: gateway,
              authenticated: true,
              onLoginRequired: () {},
              onCheckout: (args) {
                Navigator.of(pageContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CheckoutPage(
                      args: args,
                      checkoutGateway: gateway,
                      addressGateway: gateway,
                      orderGateway: gateway,
                      paymentGateway: gateway,
                      onOrderDetail: (_) {},
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即购买'));
    await tester.pumpAndSettle();

    expect(find.text('确认订单'), findsOneWidget);
    expect(find.textContaining('张三丰'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('checkout-charity-notice')),
      findsOneWidget,
    );
    final charityCopy = tester.widget<RichText>(
      find.byKey(const ValueKey('checkout-charity-copy')),
    );
    expect(charityCopy.text.toPlainText(), contains('1.5%'));
    expect(find.text('您本单预计捐赠 ¥2.70'), findsOneWidget);
    final submitButton = find.widgetWithText(FilledButton, '提交订单');
    expect(submitButton, findsOneWidget);
    expect(tester.getSize(submitButton), const Size(120, 52));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('确认订单预计捐赠为零时隐藏公益区块', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _MallGateway(charityDonationAmount: 0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CheckoutPage(
          args: const CheckoutRouteArgs([_checkoutItem]),
          checkoutGateway: gateway,
          addressGateway: gateway,
          orderGateway: gateway,
          paymentGateway: gateway,
          onOrderDetail: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('checkout-charity-notice')), findsNothing);
    expect(find.textContaining('您本单预计捐赠'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('商品详情底部双操作按钮尺寸和视觉结构一致', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _MallGateway(product: _richAdminProduct);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProductDetailPage(
          productId: _richAdminProduct.id,
          catalogGateway: gateway,
          cartGateway: gateway,
          favoriteGateway: gateway,
          secondHandGateway: gateway,
          authenticated: true,
          onLoginRequired: () {},
          onCheckout: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addButton = find.ancestor(
      of: find.text('加入购物车'),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    final buyButton = find.ancestor(
      of: find.text('立即购买'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(addButton, findsOneWidget);
    expect(buyButton, findsOneWidget);
    final addSize = tester.getSize(addButton);
    final buySize = tester.getSize(buyButton);

    expect(addSize.height, 52);
    expect(buySize.height, 52);
    expect(addSize.width, buySize.width);
    expect(tester.getTopLeft(addButton).dy, tester.getTopLeft(buyButton).dy);
    expect(
      find.descendant(
        of: addButton,
        matching: find.byIcon(Icons.add_shopping_cart_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: buyButton, matching: find.byIcon(Icons.bolt_rounded)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('订单备注顶部对齐且键盘弹出后保持可见', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final gateway = _MallGateway();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CheckoutPage(
          args: const CheckoutRouteArgs([_checkoutItem]),
          checkoutGateway: gateway,
          addressGateway: gateway,
          orderGateway: gateway,
          paymentGateway: gateway,
          onOrderDetail: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final remarkField = find.byType(TextField);
    final field = tester.widget<TextField>(remarkField);
    expect(field.decoration?.alignLabelWithHint, isTrue);
    expect(field.textAlignVertical, TextAlignVertical.top);

    await tester.tap(remarkField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.getBottomLeft(remarkField).dy, lessThanOrEqualTo(544));
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增地址表单层级清晰且键盘弹出后详细地址保持可见', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final controller = AddressController(_MallGateway());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AddressEditPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收货人'), findsOneWidget);
    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('所在地区'), findsOneWidget);
    expect(find.text('详细地址'), findsOneWidget);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(3));
    expect(
      fields.every((field) => field.decoration?.labelText == null),
      isTrue,
    );
    expect(
      fields.every((field) => field.decoration?.counterText == ''),
      isTrue,
    );
    expect(fields.last.textAlignVertical, TextAlignVertical.top);

    final detailField = find.byKey(const ValueKey('address-detail-field'));
    await tester.tap(detailField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.getBottomLeft(detailField).dy, lessThanOrEqualTo(544));
    expect(tester.takeException(), isNull);
  });

  testWidgets('订单详情返回后列表重新加载', (tester) async {
    final gateway = _MallGateway();
    final detailResult = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: OrderListPage(
          gateway: gateway,
          onOrder: (_) => detailResult.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(gateway.loadOrderListCalls, 1);

    await tester.tap(find.textContaining('ORDER-20260724'));
    await tester.pump();
    detailResult.complete();
    await tester.pumpAndSettle();

    expect(gateway.loadOrderListCalls, 2);
  });

  testWidgets('待支付订单详情显示支付倒计时', (tester) async {
    final pendingOrder = ShopOrder(
      id: _order.id,
      orderNo: _order.orderNo,
      status: ShopOrderStatus.pending,
      totalAmount: _order.totalAmount,
      originalAmount: _order.originalAmount,
      couponDiscount: _order.couponDiscount,
      items: _order.items,
      shippingAddress: _order.shippingAddress,
      receiverName: _order.receiverName,
      receiverPhone: _order.receiverPhone,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      availableActions: const ['pay', 'cancel'],
    );
    final gateway = _MallGateway(order: pendingOrder);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailPage(
          orderId: pendingOrder.id,
          gateway: gateway,
          checkoutGateway: gateway,
          paymentGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请在订单有效期内完成支付'), findsOneWidget);
    expect(find.textContaining('支付倒计时'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('订单详情在金额明细上方展示独立公益区块', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _MallGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailPage(
          orderId: _order.id,
          gateway: gateway,
          checkoutGateway: gateway,
          paymentGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本单公益'), findsOneWidget);
    expect(find.text('爱心金额'), findsOneWidget);
    expect(find.text('¥1.35'), findsOneWidget);
    expect(find.text('感谢你的每一次选择，让爱心抵达更多需要帮助的毛孩子。'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('order-charity-donation-card')))
          .dy,
      lessThan(tester.getTopLeft(find.text('金额明细')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('订单详情不展示零元公益', (tester) async {
    final zeroDonationOrder = ShopOrder(
      id: _order.id,
      orderNo: _order.orderNo,
      status: _order.status,
      totalAmount: _order.totalAmount,
      originalAmount: _order.originalAmount,
      couponDiscount: _order.couponDiscount,
      charityDonationAmount: 0,
      items: _order.items,
    );
    final gateway = _MallGateway(order: zeroDonationOrder);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailPage(
          orderId: zeroDonationOrder.id,
          gateway: gateway,
          checkoutGateway: gateway,
          paymentGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本单公益'), findsNothing);
    expect(
      find.byKey(const ValueKey('order-charity-donation-card')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('收藏无 SKU 商品直接加购一件，SKU 商品委托统一详情流程', (tester) async {
    final directGateway = _MallGateway(product: _richAdminProduct);

    await tester.pumpWidget(
      MaterialApp(
        home: FavoritePageView(
          key: const ValueKey('direct-favorite-page'),
          gateway: directGateway,
          cartGateway: directGateway,
          onProduct: (_) {},
          onBrowse: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('加入购物车'));
    await tester.pumpAndSettle();

    expect(directGateway.addedItems, [
      (productId: _richAdminProduct.id, skuId: null, quantity: 1),
    ]);
    expect(find.text('已加入购物车'), findsOneWidget);

    final skuGateway = _MallGateway();
    CatalogProduct? openedProduct;
    await tester.pumpWidget(
      MaterialApp(
        home: FavoritePageView(
          key: const ValueKey('sku-favorite-page'),
          gateway: skuGateway,
          cartGateway: skuGateway,
          onProduct: (product) => openedProduct = product,
          onBrowse: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('加入购物车'));
    await tester.pumpAndSettle();

    expect(skuGateway.addedItems, isEmpty);
    expect(openedProduct?.id, _adminProduct.id);
    expect(find.text('请先选择商品规格'), findsOneWidget);
  });

  testWidgets('取消收藏经确认且仅在服务端成功后移出列表', (tester) async {
    final gateway = _MallGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: FavoritePageView(
          gateway: gateway,
          cartGateway: gateway,
          onProduct: (_) {},
          onBrowse: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消收藏'));
    await tester.pumpAndSettle();

    expect(find.text('确定取消收藏该商品吗？'), findsOneWidget);
    expect(gateway.removedFavoriteIds, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(gateway.removedFavoriteIds, [9]);
    expect(find.textContaining('暂无收藏'), findsOneWidget);
  });

  testWidgets('收藏列表严格对齐 RN 卡片结构', (tester) async {
    final gateway = _MallGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: FavoritePageView(
          gateway: gateway,
          cartGateway: gateway,
          onProduct: (_) {},
          onBrowse: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Material>(
      find.byKey(const ValueKey('favorite-card-9')),
    );
    final shape = card.shape! as RoundedRectangleBorder;
    expect(card.color, Colors.white);
    expect(shape.side.color, const Color(0xFFE5E7EB));
    expect(shape.side.width, 1);
    expect(shape.borderRadius, BorderRadius.circular(6));
    expect(
      tester.getSize(find.byType(MallNetworkImage).first),
      const Size.square(74),
    );
    expect(find.text('加购'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);

    final addButton = find.widgetWithText(FilledButton, '加购');
    final removeButton = find.widgetWithText(OutlinedButton, '取消收藏');
    expect(tester.getSize(addButton).height, 32);
    expect(tester.getSize(removeButton).height, 32);
    expect(
      tester.getTopLeft(addButton).dx,
      lessThan(tester.getTopLeft(removeButton).dx),
    );
  });

  testWidgets('收藏空态沿用 RN 渐变背景和去选商品操作，失败态保留重试', (tester) async {
    var browsed = false;
    final emptyGateway = _MallGateway(empty: true);

    await tester.pumpWidget(
      MaterialApp(
        home: FavoritePageView(
          gateway: emptyGateway,
          cartGateway: emptyGateway,
          onProduct: (_) {},
          onBrowse: () => browsed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.surfaceTintColor, Colors.transparent);
    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('favorite-gradient-background')),
    );
    final decoration = background.decoration as BoxDecoration;
    expect((decoration.gradient! as LinearGradient).colors, const [
      Color(0xFFDEE9FF),
      Color(0xFFFAFBFF),
    ]);
    expect(find.text('去选商品'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    await tester.tap(find.text('去选商品'));
    expect(browsed, isTrue);

    final failedGateway = _MallGateway(failure: StateError('加载失败'));
    await tester.pumpWidget(
      MaterialApp(
        home: FavoritePageView(
          key: const ValueKey('favorite-failed'),
          gateway: failedGateway,
          cartGateway: failedGateway,
          onProduct: (_) {},
          onBrowse: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('重试'), findsOneWidget);
    expect(find.text('去选商品'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout 地址选择模式返回所选地址且不暴露管理操作', (tester) async {
    final gateway = _MallGateway();
    ShippingAddress? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<ShippingAddress>(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddressListPage(gateway: gateway, selectionMode: true),
                  ),
                );
              },
              child: const Text('选择地址'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择地址'));
    await tester.pumpAndSettle();

    expect(find.text('选择收货地址'), findsOneWidget);
    expect(find.text('编辑'), findsNothing);
    expect(find.text('删除'), findsNothing);
    await tester.tap(find.text(_address.receiverName));
    await tester.pumpAndSettle();

    expect(selected?.id, _address.id);
  });

  testWidgets('收货地址列表顶部与个人中心主题一致', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AddressListPage(gateway: _MallGateway()),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(find.text('收货地址'));
    expect(appBar.backgroundColor, const Color(0xFFDEE9FF));
    expect(appBar.surfaceTintColor, const Color(0xFFDEE9FF));
    expect(title.style?.color, AppColors.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('发布商品顶部使用首页淡蓝背景和深色前景', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PublishProductPage(gateway: _MallGateway())),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFDEE9FF));
    expect(appBar.surfaceTintColor, const Color(0xFFDEE9FF));
    expect(appBar.foregroundColor, AppColors.ink);
    expect(find.text('发布商品'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('发布商品表单按 RN 顺序展示必填信息并固定提交栏', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PublishProductPage(gateway: _MallGateway()),
      ),
    );
    await tester.pumpAndSettle();

    final form = find.byKey(const ValueKey('publish-product-form'));
    final listView = tester.widget<ListView>(form);
    final delegate = listView.childrenDelegate as SliverChildListDelegate;
    final sectionKeys = delegate.children
        .map((child) => child.key)
        .whereType<ValueKey<String>>()
        .map((key) => key.value)
        .toList(growable: false);
    expect(sectionKeys, const [
      'publish-title-section',
      'publish-description-section',
      'publish-price-section',
      'publish-stock-section',
      'publish-images-section',
      'publish-category-section',
      'publish-condition-section',
    ]);

    const requiredLabels = [
      '商品标题 *',
      '商品描述 *',
      '价格（元）*',
      '库存（件）*',
      '商品图片 *（最多9张）',
      '商品分类 *',
      '新旧程度 *',
    ];
    final scrollable = find
        .descendant(of: form, matching: find.byType(Scrollable))
        .first;
    for (final label in requiredLabels) {
      await tester.scrollUntilVisible(
        find.text(label),
        180,
        scrollable: scrollable,
      );
      expect(find.text(label), findsOneWidget);
      if (label == '库存（件）*') {
        expect(find.text('默认 1 件，最少 1 件'), findsOneWidget);
      }
    }

    final conditionChips = tester.widgetList<ChoiceChip>(
      find.byType(ChoiceChip),
    );
    expect(conditionChips, isNotEmpty);
    expect(conditionChips.every((chip) => chip.showCheckmark == false), isTrue);

    final submit = find.widgetWithText(FilledButton, '提交审核');
    expect(submit, findsOneWidget);
    expect(find.descendant(of: form, matching: submit), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('商城分类和商品规格选中后不显示对号', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _MallGateway(product: _adminProduct);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProductListPage(gateway: gateway, onProduct: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    var chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips, isNotEmpty);
    expect(chips.every((chip) => chip.showCheckmark == false), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProductDetailPage(
          productId: _adminProduct.id,
          catalogGateway: gateway,
          cartGateway: gateway,
          favoriteGateway: gateway,
          secondHandGateway: gateway,
          authenticated: true,
          onLoginRequired: () {},
          onCheckout: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips, isNotEmpty);
    expect(chips.every((chip) => chip.showCheckmark == false), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('我的订单使用一体化渐变背景和无下划线圆角筛选', (tester) async {
    final gateway = _MallGateway(empty: true, pendingReceiptCount: 3);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrderListPage(gateway: gateway, onOrder: (_) async {}),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('order-gradient-background')),
    );
    final decoration = background.decoration as BoxDecoration;
    expect((decoration.gradient! as LinearGradient).colors, const [
      Color(0xFFDEE9FF),
      Color(0xFFFAFBFF),
    ]);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(find.text('我买到的'));
    expect(appBar.backgroundColor, Colors.transparent);
    expect(title.style?.color, AppColors.primary);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const ValueKey('order-filter-tabs')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('order-pending-receipt-badge')),
      findsOneWidget,
    );
    expect(find.text('3'), findsOneWidget);

    final selectedTab = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('order-filter-tab-surface-0')),
    );
    final selectedDecoration = selectedTab.decoration as BoxDecoration;
    expect(selectedDecoration.color, const Color(0xFFE7EEFF));
    expect(selectedDecoration.borderRadius, BorderRadius.circular(7));
    expect(find.text('暂无订单'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('order-empty-icon-surface')),
      findsOneWidget,
    );

    await tester.tap(find.text('待付款'));
    await tester.pumpAndSettle();

    final pendingTab = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('order-filter-tab-surface-1')),
    );
    expect(
      (pendingTab.decoration as BoxDecoration).color,
      const Color(0xFFE7EEFF),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('我的订单卡片使用紧凑图片、主题价格和状态操作区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrderListPage(gateway: _MallGateway(), onOrder: (_) async {}),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Material>(
      find.byKey(const ValueKey('order-card-7')),
    );
    final shape = card.shape! as RoundedRectangleBorder;
    expect(card.color, Colors.white);
    expect(shape.side.color, const Color(0xFFE5E7EB));
    expect(shape.borderRadius, BorderRadius.circular(8));
    expect(
      tester.getSize(find.byType(MallNetworkImage).first),
      const Size.square(64),
    );

    final price = tester.widget<Text>(find.text('¥179.80'));
    expect(price.style?.color, AppColors.primary);
    final confirm = find.widgetWithText(FilledButton, '确认收货');
    expect(confirm, findsOneWidget);
    expect(tester.getSize(confirm).height, 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('我发布商品严格使用 RN 渐变标题栏、文字发布入口和四页签空态', (tester) async {
    configureWp11Viewport(tester, wp11Viewports[1]);
    var publishCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PublishedProductPage(
          gateway: _MallGateway(empty: true),
          onPublish: () async => publishCalls += 1,
          onEdit: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('published-product-gradient-background')),
    );
    final decoration = background.decoration as BoxDecoration;
    expect((decoration.gradient! as LinearGradient).colors, const [
      Color(0xFFDEE9FF),
      Color(0xFFFAFBFF),
    ]);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(find.text('我发布商品'), findsOneWidget);
    expect(find.text('我发布的商品'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('发布商品'), findsOneWidget);
    expect(find.text('发布'), findsOneWidget);

    for (final label in const ['全部', '在售', '已售出', '审核']) {
      expect(find.text(label), findsOneWidget);
    }
    final activeIndicator = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('published-product-tab-indicator-all')),
    );
    expect(
      (activeIndicator.decoration as BoxDecoration).color,
      const Color(0xFF7E97FA),
    );

    final emptyIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('published-product-empty-icon')),
    );
    expect(emptyIcon.icon, Icons.inventory_2);
    expect(emptyIcon.size, 80);
    expect(emptyIcon.color, const Color(0xFFD1D5DB));
    expect(tester.getCenter(find.byWidget(emptyIcon)).dy, closeTo(191, 2));
    expect(find.text('暂无发布的商品'), findsOneWidget);
    expect(find.text('快去发布你的第一个商品吧'), findsOneWidget);

    await tester.tap(find.text('审核'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('published-product-tab-indicator-audit')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('发布商品'));
    await tester.pumpAndSettle();
    expect(publishCalls, 1);
  });

  testWidgets('我发布商品卡片严格使用 RN 图片、状态标签和操作区', (tester) async {
    configureWp11Viewport(tester, wp11Viewports[1]);

    await tester.pumpWidget(
      MaterialApp(
        home: PublishedProductPage(
          gateway: _MallGateway(),
          onPublish: () async {},
          onEdit: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('published-product-card-3')),
    );
    final cardDecoration = card.decoration as BoxDecoration;
    expect(cardDecoration.color, Colors.white);
    expect(cardDecoration.borderRadius, BorderRadius.circular(6));
    expect(cardDecoration.boxShadow, isNotEmpty);

    expect(
      tester
          .getSize(find.byKey(const ValueKey('published-product-image-3')))
          .height,
      187,
    );
    expect(find.text('出行用品'), findsOneWidget);
    expect(find.text('已拒绝'), findsOneWidget);
    expect(find.text('¥'), findsOneWidget);
    expect(find.text('88.00'), findsOneWidget);
    expect(find.textContaining('拒绝原因:'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('上架'), findsNothing);
    expect(find.text('下架'), findsNothing);
  });

  testWidgets('发布商品上下架防重复，拒绝原因不截断', (tester) async {
    final statusResult = Completer<void>();
    final gateway = _MallGateway(
      pendingProduct: _onShelfPendingProduct,
      updateStatusResult: statusResult,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PublishedProductPage(
          key: const ValueKey('on-shelf-published-page'),
          gateway: gateway,
          onPublish: () async {},
          onEdit: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('下架'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下架'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '下架'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(gateway.updateStatusCalls, 1);
    final action = tester.widget<FilledButton>(
      find.byKey(const ValueKey('published-toggle-4')),
    );
    expect(action.onPressed, isNull);

    statusResult.complete();
    await tester.pumpAndSettle();
    expect(gateway.updateStatusCalls, 1);

    final rejectedGateway = _MallGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: PublishedProductPage(
          key: const ValueKey('rejected-published-page'),
          gateway: rejectedGateway,
          onPublish: () async {},
          onEdit: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reason = tester.widget<Text>(find.textContaining('拒绝原因:'));
    expect(reason.maxLines, isNull);
    expect(reason.overflow, isNull);
  });

  testWidgets('发布和编辑返回后重新加载我发布的商品', (tester) async {
    final gateway = _MallGateway();
    var publishCalls = 0;
    var editCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PublishedProductPage(
          gateway: gateway,
          onPublish: () async => publishCalls += 1,
          onEdit: (_) async => editCalls += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(gateway.loadPublishedProductCalls, 1);

    await tester.tap(find.byTooltip('发布商品'));
    await tester.pumpAndSettle();
    expect(publishCalls, 1);
    expect(gateway.loadPublishedProductCalls, 2);

    await tester.ensureVisible(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(editCalls, 1);
    expect(gateway.loadPublishedProductCalls, 3);
  });

  testWidgets('二手商品向买家展示联系卖家入口，并对本人商品隐藏', (tester) async {
    final gateway = _MallGateway(product: _secondHandProduct);
    var contactCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailPage(
          productId: _secondHandProduct.id,
          catalogGateway: gateway,
          cartGateway: gateway,
          favoriteGateway: gateway,
          secondHandGateway: gateway,
          authenticated: true,
          currentUserId: 1,
          onLoginRequired: () {},
          onContactSeller: () async => contactCalls += 1,
          onCheckout: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('联系卖家'), findsOneWidget);
    await tester.tap(find.text('联系卖家'));
    await tester.pump();
    expect(contactCalls, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailPage(
          productId: _secondHandProduct.id,
          catalogGateway: gateway,
          cartGateway: gateway,
          favoriteGateway: gateway,
          secondHandGateway: gateway,
          authenticated: true,
          currentUserId: 12,
          onLoginRequired: () {},
          onContactSeller: () async => contactCalls += 1,
          onCheckout: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('联系卖家'), findsNothing);
  });
}

const _adminProduct = CatalogProduct(
  id: 1,
  name: '全价冻干猫粮超长商品标题用于验证窄屏布局',
  description: '高蛋白配方，适合成年猫日常食用。',
  price: 89.9,
  originalPrice: 109,
  stock: 8,
  source: ProductSource.admin,
  hasSku: true,
  skus: [
    ProductSku(
      id: 11,
      name: '2kg 大包装',
      specs: {'重量': '2kg', '口味': '鸡肉'},
      price: 89.9,
      stock: 8,
      status: 'ACTIVE',
    ),
  ],
);

const _secondHandProduct = CatalogProduct(
  id: 2,
  name: '九成新宠物航空箱',
  description: '仅使用一次，无明显划痕。',
  price: 88,
  stock: 1,
  source: ProductSource.user,
  condition: '90%',
  publisher: ProductPublisher(id: 12, nickname: '爱宠用户'),
);

const _richAdminProduct = CatalogProduct(
  id: 47,
  name: '犬猫病毒感染用品',
  description:
      '<p><img src="https://example.test/uploads/detail.png" alt="商品详情图" /></p>',
  price: 20,
  stock: 100,
  source: ProductSource.admin,
);

const _cartItem = CartItem(
  id: 5,
  productId: 1,
  skuId: 11,
  quantity: 2,
  product: _adminProduct,
  sku: ProductSku(
    id: 11,
    name: '2kg 大包装',
    specs: {'重量': '2kg', '口味': '鸡肉'},
    price: 89.9,
    stock: 8,
    status: 'ACTIVE',
  ),
);

const _checkoutItem = CheckoutItem(
  productId: 1,
  skuId: 11,
  productName: '全价冻干猫粮超长商品标题用于验证窄屏布局',
  skuName: '2kg 大包装',
  price: 89.9,
  quantity: 2,
  source: ProductSource.admin,
  cartItemId: 5,
);

const _address = ShippingAddress(
  id: 4,
  receiverName: '张三丰',
  receiverPhone: '13800138000',
  provinceCode: '110000',
  provinceName: '北京市',
  cityCode: '110100',
  cityName: '北京市',
  districtCode: '110101',
  districtName: '东城区',
  detailAddress: '东长安街一号测试大厦二单元三层 301 室',
  isDefault: true,
);

const _order = ShopOrder(
  id: 7,
  orderNo: 'ORDER-20260724-VERY-LONG-NUMBER',
  status: ShopOrderStatus.shipped,
  totalAmount: 179.8,
  originalAmount: 179.8,
  couponDiscount: 0,
  charityDonationAmount: 1.35,
  shippingAddress: '北京市北京市东城区东长安街一号测试大厦二单元三层 301 室',
  receiverName: '张三丰',
  receiverPhone: '13800138000',
  trackingNumber: 'SF12345678901234567890',
  availableActions: ['confirm_receipt'],
  items: [
    ShopOrderItem(
      productId: 1,
      productName: '全价冻干猫粮超长商品标题用于验证窄屏布局',
      skuId: 11,
      skuName: '2kg 大包装',
      quantity: 2,
      price: 89.9,
    ),
  ],
);

const _pendingProduct = PendingProduct(
  id: 3,
  userId: 12,
  productId: 2,
  title: '九成新宠物航空箱超长标题',
  description: '仅使用一次，无明显划痕。',
  price: 88,
  stock: 1,
  images: [],
  categoryId: 22,
  categoryName: '出行用品',
  condition: ProductCondition.ninety,
  status: PendingProductStatus.rejected,
  rejectReason: '商品主图不够清晰，请重新上传能够完整展示商品细节的照片。',
  isActive: false,
);

const _onShelfPendingProduct = PendingProduct(
  id: 4,
  userId: 12,
  productId: 2,
  title: '在售宠物航空箱',
  description: '仅使用一次。',
  price: 88,
  stock: 1,
  images: [],
  categoryId: 22,
  categoryName: '出行用品',
  condition: ProductCondition.ninety,
  status: PendingProductStatus.onShelf,
  isActive: true,
);

class _MallGateway
    implements
        CatalogGateway,
        CartGateway,
        AddressGateway,
        CheckoutGateway,
        OrderGateway,
        PaymentGateway,
        FavoriteGateway,
        SecondHandGateway,
        SecondHandOrderGateway {
  _MallGateway({
    this.empty = false,
    this.failure,
    this.product,
    this.cartResult,
    this.pendingProduct,
    this.updateStatusResult,
    this.order,
    this.pendingReceiptCount = 0,
    this.charityDonationAmount = 2.7,
  });

  final bool empty;
  final Object? failure;
  final CatalogProduct? product;
  final Completer<List<CartItem>>? cartResult;
  final PendingProduct? pendingProduct;
  final Completer<void>? updateStatusResult;
  final ShopOrder? order;
  final int pendingReceiptCount;
  final double? charityDonationAmount;
  int loadOrderListCalls = 0;
  int loadPublishedProductCalls = 0;
  int updateStatusCalls = 0;
  final List<ProductQuery> productQueries = [];
  final List<({int productId, int? skuId, int quantity})> addedItems = [];
  final List<int> removedFavoriteIds = [];

  @override
  Future<OrderActionSummary> loadActionSummary() async =>
      OrderActionSummary(pendingReceipt: pendingReceiptCount);

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<CatalogPage<CatalogProduct>> loadProducts(ProductQuery query) async {
    _throwIfNeeded();
    productQueries.add(query);
    final product = query.source == ProductSource.user
        ? _secondHandProduct
        : _adminProduct;
    return CatalogPage(
      items: empty ? const [] : [product],
      total: empty ? 0 : 1,
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<CatalogPage<CatalogProduct>> loadPopularProducts(ProductQuery query) =>
      loadProducts(query);

  @override
  Future<List<CatalogCategory>> loadCategoryTree({
    ProductSource source = ProductSource.admin,
  }) async {
    _throwIfNeeded();
    if (empty) return const [];
    return const [
      CatalogCategory(
        id: 10,
        name: '宠物食品',
        children: [CatalogCategory(id: 11, name: '主粮')],
      ),
    ];
  }

  @override
  Future<CatalogProduct> loadProduct(
    int productId, {
    required bool authenticated,
  }) async {
    _throwIfNeeded();
    if (product != null) return product!;
    return productId == 2 ? _secondHandProduct : _adminProduct;
  }

  @override
  Future<List<CatalogBanner>> loadBanners() async => const [];

  @override
  Future<List<CartItem>> loadCart() async {
    _throwIfNeeded();
    if (cartResult case final result?) return result.future;
    return empty ? const [] : const [_cartItem];
  }

  @override
  Future<CartItem> addItem({
    required int productId,
    int? skuId,
    required int quantity,
  }) async {
    addedItems.add((productId: productId, skuId: skuId, quantity: quantity));
    return _cartItem;
  }

  @override
  Future<CartItem> updateQuantity(int cartItemId, int quantity) async =>
      _cartItem.copyWith(quantity: quantity);

  @override
  Future<void> removeItem(int cartItemId) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<int> loadCount() async => empty ? 0 : 1;

  @override
  Future<List<ShippingAddress>> loadAddresses() async {
    _throwIfNeeded();
    return empty ? const [] : const [_address];
  }

  @override
  Future<ShippingAddress> createAddress(AddressInput input) async => _address;

  @override
  Future<ShippingAddress> updateAddress(int id, AddressInput input) async =>
      _address;

  @override
  Future<void> deleteAddress(int id) async {}

  @override
  Future<void> setDefaultAddress(int id) async {}

  @override
  Future<OrderPreview> preview(
    List<CheckoutItem> items, {
    int? userCouponId,
  }) async {
    _throwIfNeeded();
    return OrderPreview(
      originalAmount: 179.8,
      couponDiscount: 0,
      totalAmount: 179.8,
      containsUserPublishedProducts: false,
      couponEligibleAmount: 179.8,
      couponExcludedAmount: 0,
      charityDonationRate: 1.5,
      charityDonationAmount: charityDonationAmount,
      coupons: [
        CheckoutCoupon(
          id: 6,
          name: '满 100 减 10',
          type: 'FULL_REDUCTION',
          discount: 10,
          minAmount: 100,
          isApplicable: true,
          discountAmount: 10,
        ),
      ],
    );
  }

  @override
  Future<CheckoutResult> createOrder(CreateOrderInput input) async =>
      const CheckoutResult.success(OrderPayment(order: _order));

  @override
  Future<double> loadWalletBalance() async => 1000;

  @override
  Future<OrderPage> loadOrders(OrderQuery query) async {
    _throwIfNeeded();
    loadOrderListCalls += 1;
    return OrderPage(
      items: empty ? const [] : const [_order],
      total: empty ? 0 : 1,
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<ShopOrder> loadOrder(int orderId) async {
    _throwIfNeeded();
    return order ?? _order;
  }

  @override
  Future<ShopOrder> cancelOrder(int orderId, {String? reason}) async => _order;

  @override
  Future<ShopOrder> confirmOrder(int orderId) async => _order;

  @override
  Future<ShopOrder> shipOrder(int orderId, {String? trackingNumber}) async =>
      _order;

  @override
  Future<ShopOrder> updateTracking(
    int orderId, {
    String? trackingNumber,
  }) async => _order;

  @override
  Future<OrderPayment> payOrder(int orderId, PaymentChannel channel) async =>
      const OrderPayment(
        order: _order,
        paymentParams: {'alipayOrderString': 'signed'},
      );

  @override
  Future<PaymentSdkResult> pay(String orderInfo) async =>
      const PaymentSdkResult(status: PaymentSdkStatus.success);

  @override
  Future<FavoritePage> loadFavorites({int page = 1, int pageSize = 20}) async {
    _throwIfNeeded();
    return FavoritePage(
      items: empty
          ? const []
          : [
              FavoriteEntry(
                id: 9,
                productId: (product ?? _adminProduct).id,
                product: product ?? _adminProduct,
              ),
            ],
      total: empty ? 0 : 1,
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<bool> toggleFavorite(int productId) async => true;

  @override
  Future<bool> isFavorite(int productId) async => true;

  @override
  Future<void> removeFavorite(int favoriteId) async {
    removedFavoriteIds.add(favoriteId);
  }

  @override
  Future<int> loadFavoriteCount() async => 1;

  @override
  Future<List<SecondHandCategory>> loadCategories() async {
    _throwIfNeeded();
    if (empty) return const [];
    return const [
      SecondHandCategory(
        id: 20,
        name: '宠物用品',
        children: [SecondHandCategory(id: 22, name: '出行用品')],
      ),
    ];
  }

  @override
  Future<PendingProductPage> loadMyProducts({
    int page = 1,
    int pageSize = 10,
    List<PendingProductStatus> statuses = const [],
  }) async {
    _throwIfNeeded();
    loadPublishedProductCalls += 1;
    return PendingProductPage(
      items: empty ? const [] : [pendingProduct ?? _pendingProduct],
      total: empty ? 0 : 1,
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<PendingProduct> loadPendingProduct(int pendingId) async =>
      _pendingProduct;

  @override
  Future<int> publishProduct(PublishProductInput input) async => 3;

  @override
  Future<void> updateProduct(int pendingId, PublishProductInput input) async {}

  @override
  Future<void> updateProductStatus(int productId, bool active) async {
    updateStatusCalls += 1;
    final result = updateStatusResult;
    if (result != null) await result.future;
  }

  @override
  Future<String> uploadImage(String filePath) async => '/uploads/product.jpg';

  @override
  Future<void> reportProduct(
    int productId, {
    required String reason,
    String? description,
  }) async {}

  @override
  Future<void> blockUser(int userId, {String? reason}) async {}
}
