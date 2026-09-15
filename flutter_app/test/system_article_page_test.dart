import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/platform/external_uri_launcher.dart';
import 'package:pet_hospital_flutter/features/settings/domain/settings_models.dart';
import 'package:pet_hospital_flutter/features/settings/presentation/pages/system_article_page.dart';

import 'support/wp11_viewports.dart';

void main() {
  testWidgets('文章页区分空态、错误与重试成功', (tester) async {
    final gateway = _ArticleGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.text('暂无内容'), findsOneWidget);

    gateway.error = StateError('offline');
    await tester.pumpWidget(_app(gateway, key: const ValueKey('error-page')));
    await tester.pumpAndSettle();
    expect(find.text('文章加载失败'), findsOneWidget);

    gateway
      ..error = null
      ..article = const SystemArticle(
        id: 1,
        type: SystemArticleType.privacy,
        html: '<p>隐私协议正文</p>',
      );
    await tester.tap(find.byKey(const ValueKey('article-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('article-html')), findsOneWidget);
    expect(find.textContaining('隐私协议正文'), findsOneWidget);
  });

  for (final viewport in wp11Viewports) {
    testWidgets('相对图片、宽图和宽表格在 ${viewport.label} 稳定渲染', (tester) async {
      configureWp11Viewport(tester, viewport);
      final gateway = _ArticleGateway(
        article: const SystemArticle(
          id: 1,
          type: SystemArticleType.privacy,
          html: '''
          <h1>隐私协议</h1>
          <img src="/uploads/wide.png" width="4000" height="1200" />
          <table><tr><th>超长字段</th><th>第二列</th></tr><tr><td>内容</td><td>内容</td></tr></table>
        ''',
        ),
      );

      await tester.pumpWidget(_app(gateway, textScale: viewport.textScale));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'article-image-https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/wide.png',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('article-wide-table')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('文章链接仅允许 http/https 且直接尝试启动', (tester) async {
    final launcher = _UriLauncher();
    final gateway = _ArticleGateway(
      article: const SystemArticle(
        id: 1,
        type: SystemArticleType.privacy,
        html: '<p>链接策略</p>',
      ),
    );
    await tester.pumpWidget(_app(gateway, launcher: launcher));
    await tester.pumpAndSettle();
    final html = tester.widget<Html>(find.byType(Html));

    html.onLinkTap?.call('javascript:alert(1)', const {}, null);
    await tester.pump();
    expect(find.text('不支持打开此链接'), findsOneWidget);
    expect(launcher.canLaunchUris, isEmpty);

    html.onLinkTap?.call('/docs/privacy', const {}, null);
    await tester.pumpAndSettle();
    expect(launcher.canLaunchUris, isEmpty);
    expect(
      launcher.launchUris.single.toString(),
      'https://api.example.com/docs/privacy',
    );
  });
}

Widget _app(
  _ArticleGateway gateway, {
  Key? key,
  ExternalUriLauncher? launcher,
  double textScale = 1,
}) {
  return MaterialApp(
    key: key,
    builder: wp11TextScaleBuilder(textScale),
    home: SystemArticlePage(
      gateway: gateway,
      type: SystemArticleType.privacy,
      uriLauncher: launcher ?? _UriLauncher(),
      contentBaseUrl: 'https://api.example.com/server-api',
    ),
  );
}

class _ArticleGateway implements SettingsGateway {
  _ArticleGateway({this.article});

  SystemArticle? article;
  Object? error;

  @override
  Future<SystemArticle?> loadArticle(SystemArticleType type) async {
    if (error case final value?) throw value;
    return article;
  }

  @override
  Future<ContactInfo> loadContactInfo() async => ContactInfo.empty;
}

class _UriLauncher implements ExternalUriLauncher {
  final List<Uri> canLaunchUris = [];
  final List<Uri> launchUris = [];

  @override
  Future<bool> canLaunch(Uri uri) async {
    canLaunchUris.add(uri);
    return false;
  }

  @override
  Future<bool> launch(Uri uri) async {
    launchUris.add(uri);
    return true;
  }
}
