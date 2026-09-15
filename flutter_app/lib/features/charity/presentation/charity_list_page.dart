import 'package:flutter/material.dart';

import '../domain/charity_models.dart';
import '../../mall/payment/domain/payment_models.dart';
import 'charity_controller.dart';
import 'charity_detail_page.dart';
import 'charity_widgets.dart';

typedef CharityLoginRequester = Future<bool> Function(String message);

class CharityListPage extends StatefulWidget {
  const CharityListPage({
    super.key,
    required this.gateway,
    required this.authenticated,
    required this.requestLogin,
    this.paymentGateway,
  });

  final CharityGateway gateway;
  final bool authenticated;
  final CharityLoginRequester requestLogin;
  final PaymentGateway? paymentGateway;

  @override
  State<CharityListPage> createState() => _CharityListPageState();
}

class _CharityListPageState extends State<CharityListPage> {
  late final CharityListController _controller;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _controller = CharityListController(
      gateway: widget.gateway,
      authenticated: widget.authenticated,
    )..load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (_showSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  Future<void> _submitSearch() => _controller.search(_searchController.text);

  Future<void> _clearSearch() async {
    _searchController.clear();
    await _controller.search('');
    if (mounted) _searchFocusNode.requestFocus();
  }

  Future<void> _openDetail(CharityActivity activity) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CharityDetailPage(
          gateway: widget.gateway,
          charityId: activity.id,
          authenticated: widget.authenticated,
          requestLogin: widget.requestLogin,
          paymentGateway: widget.paymentGateway,
        ),
      ),
    );
    await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      body: CharityGradientBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                children: [
                  CharityAppBar(
                    title: '公益中心',
                    onBack: () => Navigator.of(context).pop(),
                    action: IconButton(
                      key: const ValueKey('charity-search-toggle'),
                      tooltip: _showSearch ? '收起搜索' : '搜索',
                      onPressed: _toggleSearch,
                      icon: Icon(
                        _showSearch
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: charityInk,
                        size: 25,
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: _showSearch
                        ? _SearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onSubmitted: _submitSearch,
                            onClear: _clearSearch,
                          )
                        : const SizedBox.shrink(),
                  ),
                  _FilterBar(controller: _controller),
                  Expanded(child: _buildBody()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.activities.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: charityPrimary),
      );
    }

    if (_controller.activities.isEmpty) {
      return RefreshIndicator(
        color: charityPrimary,
        onRefresh: _controller.refresh,
        child: ListView(
          key: const ValueKey('charity-empty-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.19),
            Icon(
              _controller.error == null
                  ? Icons.event_busy_rounded
                  : Icons.cloud_off_rounded,
              size: charityDesignPx(context, 144),
              color: charityHint,
            ),
            const SizedBox(height: 16),
            Text(
              _controller.error ?? '暂无相关公益',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: charityMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              key: const ValueKey('charity-retry'),
              onPressed: _controller.retry,
              child: const Text(
                '点击刷新',
                style: TextStyle(color: charityPrimary),
              ),
            ),
          ],
        ),
      );
    }

    final horizontalPadding = MediaQuery.sizeOf(context).width < 600
        ? 16.0
        : 24.0;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          _controller.loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        color: charityPrimary,
        onRefresh: _controller.refresh,
        child: ListView.separated(
          key: const ValueKey('charity-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            4,
            horizontalPadding,
            24,
          ),
          itemCount: _controller.activities.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == _controller.activities.length) {
              return _ListFooter(controller: _controller);
            }
            final activity = _controller.activities[index];
            return CharityCard(
              activity: activity,
              onPressed: () => _openDetail(activity),
            );
          },
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSubmitted;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('charity-search-bar'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: charityBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF9E9E9E)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('charity-search-input'),
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmitted(),
              decoration: const InputDecoration(
                hintText: '搜索公益名称',
                hintStyle: TextStyle(color: charityHint),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  key: const ValueKey('charity-search-clear'),
                  tooltip: '清空',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF9E9E9E),
                  ),
                );
              }
              return TextButton(
                key: const ValueKey('charity-search-submit'),
                onPressed: onSubmitted,
                child: const Text('搜索'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final CharityListController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Row(
        key: const ValueKey('charity-filter-bar'),
        children: CharityListFilter.values.map((filter) {
          final selected = controller.selectedFilter == filter;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: selected ? charityPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  key: ValueKey('charity-filter-${filter.name}'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => controller.selectFilter(filter),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      filter.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white : charityMuted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final CharityListController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: charityPrimary,
              ),
            ),
            SizedBox(width: 8),
            Text('加载中...', style: TextStyle(color: charityHint)),
          ],
        ),
      );
    }
    if (controller.error != null) {
      return TextButton(
        onPressed: controller.loadMore,
        child: const Text('加载失败，点击重试'),
      );
    }
    return const SizedBox(height: 4);
  }
}
