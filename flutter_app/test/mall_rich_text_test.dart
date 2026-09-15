import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/mall/shared/mall_rich_text.dart';

void main() {
  testWidgets('商城富文本解析 HTML 标签而不是显示原始源码', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: MallRichText(
              content: '<h2>商品说明</h2><p>适合<strong>成年猫</strong></p>',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('商品说明', findRichText: true), findsOneWidget);
    expect(find.textContaining('成年猫', findRichText: true), findsOneWidget);
    expect(find.textContaining('<h2>', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('商城富文本补全相对图片地址并限制为内容宽度', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: MallRichText(
              content: '<p><img src="/uploads/detail.png" alt="商品图" /></p>',
              baseUrl: 'https://example.test',
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;
    expect(
      provider.url,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/detail.png',
    );
    expect(image.width, 280);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连续详情图在加载前也占据全宽布局', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: MallRichText(
              content:
                  '<p>'
                  '<img src="/uploads/detail-1.png" alt="详情图一" />'
                  '<img src="/uploads/detail-2.png" alt="详情图二" />'
                  '</p>',
              baseUrl: 'https://example.test',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNWidgets(2));
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      expect(image.width, 280);
      expect(image.fit, BoxFit.fitWidth);
      expect(image.excludeFromSemantics, isTrue);
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final firstImage = find.byType(Image).first;
    final secondImage = find.byType(Image).last;
    expect(tester.getSize(firstImage).width, 280);
    expect(tester.getSize(firstImage).height, greaterThan(0));
    expect(
      tester.getTopLeft(secondImage).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(firstImage).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('商城富文本为空时展示缺省文案', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MallRichText(content: '  ')),
      ),
    );

    expect(find.text('暂无商品描述'), findsOneWidget);
  });

  testWidgets('商品详情可识别 wangEditor 富文本视频节点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: MallRichText(
              baseUrl: 'https://api.example.com',
              content:
                  '<div data-w-e-type="video" data-w-e-is-void>'
                  '<video poster="/uploads/product-cover.jpg" controls="true">'
                  '<source src="/uploads/product.mov" type="video/mp4"/>'
                  '</video></div>',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final video = find.byKey(const ValueKey('mall-rich-video-0'));
    expect(video, findsOneWidget);
    expect(
      tester.widget<Semantics>(video).properties.value,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/product.mov',
    );
    expect(find.text('视频地址无效'), findsNothing);
  });

  testWidgets('商品详情对不安全的视频地址显示明确占位', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MallRichText(
            content:
                '<video src="javascript:alert(1)" controls="true"></video>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mall-rich-video-unavailable-0')),
      findsOneWidget,
    );
    expect(find.text('视频地址无效'), findsOneWidget);
  });
}
