import 'package:flutter/material.dart';

import '../../../shared/mall_widgets.dart';
import '../../domain/second_hand_models.dart';
import '../second_hand_controller.dart';

class PublishedProductPage extends StatefulWidget {
  const PublishedProductPage({
    super.key,
    required this.gateway,
    required this.onPublish,
    required this.onEdit,
  });

  final SecondHandGateway gateway;
  final Future<void> Function() onPublish;
  final Future<void> Function(int pendingId) onEdit;

  @override
  State<PublishedProductPage> createState() => _PublishedProductPageState();
}

class _PublishedProductPageState extends State<PublishedProductPage> {
  late final PublishedProductController _controller;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _controller = PublishedProductController(widget.gateway)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('published-product-gradient-background'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            '我发布商品',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          foregroundColor: const Color(0xFF1F2937),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            Tooltip(
              message: '发布商品',
              child: TextButton(
                onPressed: _openPublish,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7E97FA),
                  minimumSize: const Size(56, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('发布'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              children: [
                _PublishedProductTabs(controller: _controller),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_controller.loading && _controller.products.isEmpty) {
      return const _PublishedProductLoadingState();
    }
    if (_controller.errorMessage != null && _controller.products.isEmpty) {
      return MallStateView(
        icon: Icons.wifi_off_outlined,
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 220) _controller.loadMore();
        return false;
      },
      child: RefreshIndicator(
        color: const Color(0xFF7E97FA),
        onRefresh: _controller.load,
        child: _controller.products.isEmpty
            ? const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _PublishedProductEmptyState(),
                  ),
                ],
              )
            : ListView.builder(
                key: const ValueKey('published-product-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 9),
                itemCount:
                    _controller.products.length +
                    (_controller.loadingMore || !_controller.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _controller.products.length) {
                    return _PublishedProductListFooter(
                      loading: _controller.loadingMore,
                    );
                  }
                  return _productCard(_controller.products[index]);
                },
              ),
      ),
    );
  }

  Widget _productCard(PendingProduct product) {
    final busy = _busyIds.contains(product.id);
    final statusStyle = _statusStyle(product.status);
    final imageHeight = (MediaQuery.sizeOf(context).width * 360 / 750)
        .roundToDouble();

    return Container(
      key: ValueKey('published-product-card-${product.id}'),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: ValueKey('published-product-image-${product.id}'),
            height: imageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MallNetworkImage(url: product.images.firstOrNull ?? ''),
                if (product.categoryName.isNotEmpty)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _PublishedProductBadge(
                      backgroundColor: const Color(0x99000000),
                      label: product.categoryName,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: _PublishedProductBadge(
                    backgroundColor: statusStyle.backgroundColor,
                    label: statusStyle.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                if (product.status == PendingProductStatus.rejected &&
                    product.rejectReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    '拒绝原因: ${product.rejectReason}',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                const Text(
                  '¥',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  product.price.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (product.canChangeShelf)
                  SizedBox(
                    height: 33,
                    child: FilledButton.icon(
                      key: ValueKey('published-toggle-${product.id}'),
                      onPressed: busy ? null : () => _toggle(product),
                      style: FilledButton.styleFrom(
                        backgroundColor: product.isActive == true
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 33),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      icon: Icon(
                        product.isActive == true
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 21,
                      ),
                      label: Text(product.isActive == true ? '下架' : '上架'),
                    ),
                  ),
                if (product.canChangeShelf && product.canEdit)
                  const SizedBox(width: 6),
                if (product.canEdit)
                  SizedBox(
                    height: 33,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _openEdit(product.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7E97FA),
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 33),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Color(0xFF7E97FA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      icon: const Icon(Icons.edit, size: 21),
                      label: const Text('编辑'),
                    ),
                  )
                else
                  const Text(
                    '已售出不可操作',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(PendingProduct product) async {
    final action = product.isActive == true ? '下架' : '上架';
    if (!await showMallConfirm(
      context,
      title: '$action商品',
      message: '确定要$action“${product.title}”吗？',
      confirmText: action,
    )) {
      return;
    }
    try {
      setState(() => _busyIds.add(product.id));
      await _controller.toggleShelf(product);
      if (mounted) showMallMessage(context, '商品已$action');
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(product.id));
    }
  }

  Future<void> _openPublish() async {
    await widget.onPublish();
    if (mounted) await _controller.load();
  }

  Future<void> _openEdit(int id) async {
    await widget.onEdit(id);
    if (mounted) await _controller.load();
  }
}

class _PublishedProductTabs extends StatelessWidget {
  const _PublishedProductTabs({required this.controller});

  final PublishedProductController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('published-product-tabs'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          for (final filter in PublishedProductFilter.values)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('published-product-tab-${filter.name}'),
                  onTap: () => controller.load(nextFilter: filter),
                  child: SizedBox(
                    height: 31,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Text(
                            filter.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: controller.filter == filter
                                  ? const Color(0xFF7E97FA)
                                  : const Color(0xFF6B7280),
                              fontSize: 15,
                              fontWeight: controller.filter == filter
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (controller.filter == filter)
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 0,
                            height: 2,
                            child: DecoratedBox(
                              key: ValueKey(
                                'published-product-tab-indicator-${filter.name}',
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7E97FA),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(1),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PublishedProductBadge extends StatelessWidget {
  const _PublishedProductBadge({
    required this.backgroundColor,
    required this.label,
    required this.fontWeight,
  });

  final Color backgroundColor;
  final String label;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.3,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}

class _PublishedProductLoadingState extends StatelessWidget {
  const _PublishedProductLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 52),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF7E97FA)),
            SizedBox(height: 8),
            Text(
              '加载中...',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedProductEmptyState extends StatelessWidget {
  const _PublishedProductEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 52, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2,
              key: ValueKey('published-product-empty-icon'),
              size: 80,
              color: Color(0xFFD1D5DB),
            ),
            SizedBox(height: 12),
            Text(
              '暂无发布的商品',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '快去发布你的第一个商品吧',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedProductListFooter extends StatelessWidget {
  const _PublishedProductListFooter({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF7E97FA),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            loading ? '加载中...' : '没有更多了',
            style: TextStyle(
              fontSize: 14,
              color: loading
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

({String label, Color backgroundColor}) _statusStyle(
  PendingProductStatus status,
) {
  return switch (status) {
    PendingProductStatus.underReview => (
      label: '审核中',
      backgroundColor: const Color(0xE6F59E0B),
    ),
    PendingProductStatus.approved || PendingProductStatus.onShelf => (
      label: '已上架',
      backgroundColor: const Color(0xE610B981),
    ),
    PendingProductStatus.offShelf => (
      label: '已下架',
      backgroundColor: const Color(0xE66B7280),
    ),
    PendingProductStatus.rejected => (
      label: '已拒绝',
      backgroundColor: const Color(0xE6EF4444),
    ),
    PendingProductStatus.sold => (
      label: '已售出',
      backgroundColor: const Color(0xE69CA3AF),
    ),
    PendingProductStatus.unknown => (
      label: '审核中',
      backgroundColor: const Color(0xE6F59E0B),
    ),
  };
}
