import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../core/platform/external_uri_launcher.dart';
import '../../domain/settings_models.dart';
import '../settings_controller.dart';

class SystemArticlePage extends StatefulWidget {
  const SystemArticlePage({
    super.key,
    required this.gateway,
    required this.type,
    required this.uriLauncher,
    required this.contentBaseUrl,
  });

  final SettingsGateway gateway;
  final SystemArticleType type;
  final ExternalUriLauncher uriLauncher;
  final String contentBaseUrl;

  @override
  State<SystemArticlePage> createState() => _SystemArticlePageState();
}

class _SystemArticlePageState extends State<SystemArticlePage> {
  late final SystemArticleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SystemArticleController(
      gateway: widget.gateway,
      type: widget.type,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(widget.type.title),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.error != null) {
            return _ArticleState(
              icon: Icons.wifi_off_rounded,
              title: '文章加载失败',
              description: '请检查网络后重试',
              onRetry: _controller.load,
            );
          }
          if (_controller.isEmpty) {
            return const _ArticleState(
              icon: Icons.article_outlined,
              title: '暂无内容',
              description: '内容正在准备中',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = math.max(0, constraints.maxWidth - 32);
              return SingleChildScrollView(
                key: const ValueKey('article-scroll-view'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: ColoredBox(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Html(
                          key: const ValueKey('article-html'),
                          data: _controller.article!.html,
                          onLinkTap: (url, _, _) => unawaited(_openLink(url)),
                          extensions: [
                            MatcherExtension(
                              matcher: (context) =>
                                  context.elementName == 'img',
                              builder: (context) => _buildImage(
                                context,
                                math.min(contentWidth - 32, 828),
                              ),
                            ),
                            TagWrapExtension(
                              tagsToWrap: const {'table'},
                              builder: (child) => SingleChildScrollView(
                                key: const ValueKey('article-wide-table'),
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: math.min(contentWidth - 32, 828),
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ],
                          style: {
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              color: const Color(0xFF25303B),
                              fontSize: FontSize(16),
                              lineHeight: LineHeight.number(1.45),
                            ),
                            'a': Style(
                              color: const Color(0xFF2563A6),
                              textDecoration: TextDecoration.underline,
                            ),
                            'table': Style(
                              margin: Margins.only(top: 12, bottom: 12),
                            ),
                            'th': Style(
                              backgroundColor: const Color(0xFFF0F3F6),
                              padding: HtmlPaddings.all(8),
                            ),
                            'td': Style(padding: HtmlPaddings.all(8)),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildImage(ExtensionContext context, double maxWidth) {
    final rawSource = context.attributes['src'] ?? '';
    final uri = resolveSafeWebUri(rawSource, baseUrl: widget.contentBaseUrl);
    final safeWidth = math.max(1.0, maxWidth);
    if (uri == null) {
      final alt = context.attributes['alt']?.trim();
      return SizedBox(
        width: safeWidth,
        height: 56,
        child: Center(child: Text(alt?.isNotEmpty == true ? alt! : '图片无法显示')),
      );
    }
    return SizedBox(
      key: ValueKey('article-image-$uri'),
      width: safeWidth,
      height: math.min(safeWidth * 0.62, 420),
      child: Image.network(
        uri.toString(),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Center(child: Text('图片加载失败')),
      ),
    );
  }

  Future<void> _openLink(String? rawUrl) async {
    final uri = resolveSafeWebUri(rawUrl ?? '', baseUrl: widget.contentBaseUrl);
    if (uri == null) {
      _showMessage('不支持打开此链接');
      return;
    }
    if (!await widget.uriLauncher.launch(uri)) {
      _showMessage('无法打开此链接');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ArticleState extends StatelessWidget {
  const _ArticleState({
    required this.icon,
    required this.title,
    required this.description,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String description;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFF8C96A2)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(color: Color(0xFF747E89))),
            if (onRetry case final retry?) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const ValueKey('article-retry'),
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
