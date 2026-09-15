import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/mall/domain/mall_models.dart';
import 'package:pet_hospital_flutter/features/mall/presentation/mall_controller.dart';
import 'package:pet_hospital_flutter/features/mall/presentation/mall_page.dart';

void main() {
  testWidgets('商城首页保持 RN 轮播、四分类和双列商品结构', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _FakeMallGateway();
    final controller = MallController(gateway: gateway, authenticated: true);
    await controller.load();
    addTearDown(controller.dispose);
    String? openedFeature;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MallHomeView(
            controller: controller,
            guest: false,
            onLoginRequired: (_) {},
            onOpenFeature: (feature) => openedFeature = feature,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('mall-home-top-bar')), findsOneWidget);
    expect(find.text('热门搜索'), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-cart-badge')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-home-banner')), findsOneWidget);
    expect(find.text('商品分类'), findsOneWidget);
    expect(find.text('全部分类 >'), findsOneWidget);
    expect(find.text('宠物食品'), findsOneWidget);
    expect(find.text('宠物用品'), findsOneWidget);
    expect(find.text('热门商品'), findsOneWidget);
    expect(find.text('更多商品 >'), findsOneWidget);
    expect(find.text('全价猫粮'), findsOneWidget);
    expect(find.text('¥89.90'), findsOneWidget);
    expect(find.text('加购'), findsNWidgets(2));

    final bannerSize = tester.getSize(
      find.descendant(
        of: find.byKey(const ValueKey('mall-home-banner')),
        matching: find.byType(PageView),
      ),
    );
    expect(bannerSize.width, closeTo(373, 1));
    expect(bannerSize.height, closeTo(177, 1));

    await tester.tap(find.byKey(const ValueKey('mall-cart-button')));
    expect(openedFeature, '购物车');
    expect(tester.takeException(), isNull);
  });

  testWidgets('商城游客点击购物车和加购时触发登录提示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = MallController(
      gateway: _FakeMallGateway(),
      authenticated: false,
    );
    await controller.load();
    addTearDown(controller.dispose);
    String? loginMessage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MallHomeView(
            controller: controller,
            guest: true,
            onLoginRequired: (message) => loginMessage = message,
            onOpenFeature: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('mall-cart-button')));
    expect(loginMessage, '登录后即可查看购物车');

    final addButton = find.byKey(const ValueKey('mall-add-product-47'));
    await tester.scrollUntilVisible(
      addButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addButton);
    expect(loginMessage, '登录后即可加入购物车');
    expect(tester.takeException(), isNull);
  });

  testWidgets('配置首页图片后进入商城和刷新都不再弹窗', (tester) async {
    final controller = MallController(
      gateway: _FakeMallGateway(
        popupImageUrl: 'https://example.test/popup.jpg',
      ),
      authenticated: true,
    );
    await controller.load();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MallHomeView(
            controller: controller,
            guest: false,
            onLoginRequired: (_) {},
            onOpenFeature: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('mall-home-popup-dialog')), findsNothing);
    await controller.refresh();
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('商城加载完成时不在已打开的商品页面上弹出广告', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final controller = MallController(
      gateway: _FakeMallGateway(
        popupImageUrl: 'https://example.test/popup.jpg',
      ),
      authenticated: true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: MallHomeView(
            controller: controller,
            guest: false,
            onLoginRequired: (_) {},
            onOpenFeature: (_) {},
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('商品详情')),
      ),
    );
    await tester.pumpAndSettle();
    await controller.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('商品详情'), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-home-popup-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('商城 Banner 跳转规则与 RN 保持一致', () {
    expect(
      const MallBanner(
        id: '1',
        imageUrl: '',
        actionType: 'product',
        productId: 47,
      ).target?.type,
      MallBannerTargetType.product,
    );
    expect(
      const MallBanner(id: '2', imageUrl: '', link: '/category/8').target?.id,
      8,
    );
    expect(
      const MallBanner(id: '3', imageUrl: '', actionType: 'none').target,
      isNull,
    );
  });
}

class _FakeMallGateway implements MallGateway {
  _FakeMallGateway({this.popupImageUrl = ''});

  final String popupImageUrl;

  @override
  Future<MallSnapshot> loadMall({required bool authenticated}) async {
    return MallSnapshot(
      banners: const [
        MallBanner(id: 'banner-1', imageUrl: '', productId: 47),
        MallBanner(id: 'banner-2', imageUrl: '', link: '/category/8'),
      ],
      categories: const [
        MallCategory(id: 1, name: '宠物食品', imageUrl: '', sortOrder: 1),
        MallCategory(id: 2, name: '宠物用品', imageUrl: '', sortOrder: 2),
        MallCategory(id: 3, name: '清洁护理', imageUrl: '', sortOrder: 3),
        MallCategory(id: 4, name: '宠物玩具', imageUrl: '', sortOrder: 4),
      ],
      products: const [
        MallProduct(
          id: 47,
          name: '全价猫粮',
          price: 89.9,
          imageUrl: '',
          stock: 20,
          hasSku: true,
          isTop: true,
          publishSource: 'ADMIN',
          skus: [
            MallSku(
              id: 91,
              specs: {'重量': '2kg'},
              price: 89.9,
              stock: 20,
              status: 'ACTIVE',
            ),
          ],
        ),
        MallProduct(
          id: 48,
          name: '宠物清洁湿巾',
          price: 19.9,
          imageUrl: '',
          stock: 8,
          hasSku: false,
          isTop: false,
          publishSource: 'ADMIN',
        ),
      ],
      homePopupImageUrl: popupImageUrl,
      hasCartItems: authenticated,
    );
  }

  @override
  Future<MallProduct> loadProduct(int productId) async =>
      (await loadMall(authenticated: true)).products.first;

  @override
  Future<void> addToCart({
    required int productId,
    required int? skuId,
    required int quantity,
  }) async {}

  @override
  Future<bool> loadCartBadge() async => true;
}
