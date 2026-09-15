import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../core/network/asset_url_resolver.dart';
import '../../domain/health_models.dart';
import '../health_controller.dart';
import 'health_page.dart';

class HealthKnowledgeListPage extends StatefulWidget {
  const HealthKnowledgeListPage({super.key, required this.gateway});

  final HealthGateway gateway;

  @override
  State<HealthKnowledgeListPage> createState() =>
      _HealthKnowledgeListPageState();
}

class _HealthKnowledgeListPageState extends State<HealthKnowledgeListPage> {
  late final HealthArticleListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HealthArticleListController(gateway: widget.gateway);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: healthBackground,
      appBar: AppBar(title: const Text('健康知识')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _controller.selectedCategoryId == null,
                    showCheckmark: false,
                    onSelected: (_) => _controller.selectCategory(null),
                  ),
                  const SizedBox(width: 8),
                  for (final category in _controller.categories) ...[
                    ChoiceChip(
                      label: Text(category.name),
                      selected: _controller.selectedCategoryId == category.id,
                      showCheckmark: false,
                      onSelected: (_) =>
                          _controller.selectCategory(category.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null) {
      return _KnowledgeState(
        icon: Icons.cloud_off_outlined,
        title: _controller.error!,
        onRetry: _controller.initialize,
      );
    }
    if (_controller.articles.isEmpty) {
      return const _KnowledgeState(
        icon: Icons.article_outlined,
        title: '暂无相关文章',
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.initialize,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        itemCount: _controller.articles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final article = _controller.articles[index];
          return _ArticleTile(
            article: article,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => HealthKnowledgeDetailPage(
                  gateway: widget.gateway,
                  articleId: article.id,
                  initialArticle: article,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HealthKnowledgeDetailPage extends StatefulWidget {
  const HealthKnowledgeDetailPage({
    super.key,
    required this.gateway,
    required this.articleId,
    this.initialArticle,
  });

  final HealthGateway gateway;
  final int articleId;
  final HealthArticle? initialArticle;

  @override
  State<HealthKnowledgeDetailPage> createState() =>
      _HealthKnowledgeDetailPageState();
}

class _HealthKnowledgeDetailPageState extends State<HealthKnowledgeDetailPage> {
  late Future<HealthArticle> _article;

  @override
  void initState() {
    super.initState();
    _article = widget.gateway.loadHealthArticle(widget.articleId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: healthBackground,
      appBar: AppBar(title: const Text('健康知识详情')),
      body: FutureBuilder<HealthArticle>(
        future: _article,
        initialData: widget.initialArticle?.content.isNotEmpty == true
            ? widget.initialArticle
            : null,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return _KnowledgeState(
              icon: Icons.cloud_off_outlined,
              title: '文章加载失败',
              onRetry: () => setState(() {
                _article = widget.gateway.loadHealthArticle(widget.articleId);
              }),
            );
          }
          final article = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          article.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${article.categoryName.isEmpty ? '健康知识' : article.categoryName} · ${_dateLabel(article.createdAt)} · ${article.viewCount} 阅读',
                          style: const TextStyle(color: Color(0xFF75807B)),
                        ),
                        const Divider(height: 28),
                        if (article.content.isEmpty)
                          Text(article.summary)
                        else
                          Html(
                            data: article.content,
                            style: {
                              'body': Style(
                                margin: Margins.zero,
                                padding: HtmlPaddings.zero,
                                fontSize: FontSize(16),
                                lineHeight: LineHeight.number(1.5),
                                color: const Color(0xFF25302C),
                              ),
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onTap});

  final HealthArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverUrl = resolveAssetUrl(article.coverImageUrl);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: coverUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFE7F6EF),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: healthGreen,
                          ),
                        )
                      : Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE7F6EF),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: healthGreen,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF75807B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${article.categoryName.isEmpty ? '健康知识' : article.categoryName} · ${article.viewCount} 阅读',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B9691),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnowledgeState extends StatelessWidget {
  const _KnowledgeState({
    required this.icon,
    required this.title,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: const Color(0xFF96A29D)),
          const SizedBox(height: 12),
          Text(title),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
