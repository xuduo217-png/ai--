import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/asset_url_resolver.dart';
import '../../domain/medical_order_models.dart';
import '../medical_order_controller.dart';

class MedicalOrderListPage extends StatefulWidget {
  const MedicalOrderListPage({
    super.key,
    required this.gateway,
    this.assetBaseUrl = ApiConfig.assetBaseUrl,
  });

  final MedicalOrderGateway gateway;
  final String assetBaseUrl;

  @override
  State<MedicalOrderListPage> createState() => _MedicalOrderListPageState();
}

class _MedicalOrderListPageState extends State<MedicalOrderListPage> {
  late final MedicalOrderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MedicalOrderController(widget.gateway);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      key: const ValueKey('medical-order-gradient-background'),
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
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 52,
          centerTitle: true,
          title: Text(
            '医疗服务订单',
            style: TextStyle(
              color: primary,
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isInitialLoading && _controller.orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF5B75E5)),
            SizedBox(height: 10),
            Text(
              '加载中...',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (_controller.errorMessage != null && _controller.orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.retry,
        child: _MedicalOrderStateView(
          icon: Icons.wifi_off_rounded,
          title: '医疗订单加载失败',
          description: '请检查网络后重试',
          action: OutlinedButton.icon(
            key: const ValueKey('medical-order-retry'),
            onPressed: _controller.retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
      );
    }
    if (_controller.orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.refresh,
        child: const _MedicalOrderStateView(
          icon: Icons.medical_services_outlined,
          title: '暂无医疗服务订单',
        ),
      );
    }

    return Column(
      children: [
        if (_controller.errorMessage != null)
          Material(
            color: const Color(0xFFFFF4E5),
            child: ListTile(
              dense: true,
              leading: const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFB66A18),
              ),
              title: const Text('刷新失败，正在显示上次内容'),
              trailing: TextButton(
                onPressed: _controller.refresh,
                child: const Text('重试'),
              ),
            ),
          ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 220) {
                unawaited(_controller.loadMore());
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: _controller.refresh,
              child: ListView.builder(
                key: const ValueKey('medical-order-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
                itemCount: _controller.orders.length + 1,
                itemBuilder: (context, index) {
                  if (index < _controller.orders.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MedicalOrderCard(
                        order: _controller.orders[index],
                        assetBaseUrl: widget.assetBaseUrl,
                      ),
                    );
                  }
                  return _buildFooter();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_controller.loadMoreError != null) {
      return Center(
        child: TextButton.icon(
          key: const ValueKey('medical-order-load-more-retry'),
          onPressed: _controller.loadMore,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('加载更多失败，重试'),
        ),
      );
    }
    return const SizedBox(height: 10);
  }
}

class _MedicalOrderCard extends StatelessWidget {
  const _MedicalOrderCard({required this.order, required this.assetBaseUrl});

  final MedicalServiceOrder order;
  final String assetBaseUrl;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      key: ValueKey('medical-order-card-${order.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '订单号: ${order.orderNo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: ValueKey('medical-order-status-${order.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status.label,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18, color: Color(0xFFEFEFEF)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DoctorAvatar(order: order, assetBaseUrl: assetBaseUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.doctor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.serviceItem.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order.durationMinutes} 分钟',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 15,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    formatMedicalOrderTime(order.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '¥${order.amount.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({required this.order, required this.assetBaseUrl});

  final MedicalServiceOrder order;
  final String assetBaseUrl;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = resolveAssetUrl(
      order.doctor.avatarUrl,
      assetBaseUrl: assetBaseUrl,
    );
    if (avatarUrl.isEmpty) return _fallback();
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      key: ValueKey('medical-order-avatar-fallback-${order.id}'),
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F5FC),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.medical_services_outlined,
        color: Color(0xFF5B75E5),
        size: 24,
      ),
    );
  }
}

class _MedicalOrderStateView extends StatelessWidget {
  const _MedicalOrderStateView({
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const ValueKey('medical-order-state-icon-surface'),
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F5FC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE3E8F2)),
                    ),
                    child: Icon(icon, size: 38, color: const Color(0xFFAAB4C6)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description case final description?) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF7B8491)),
                    ),
                  ],
                  if (action case final action?) ...[
                    const SizedBox(height: 14),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Color _statusColor(MedicalOrderStatus status) => switch (status) {
  MedicalOrderStatus.pending => const Color(0xFFD97706),
  MedicalOrderStatus.paid => const Color(0xFF059669),
  MedicalOrderStatus.refunded => const Color(0xFF2563B8),
  MedicalOrderStatus.expired => const Color(0xFF6B7280),
  MedicalOrderStatus.cancelled => const Color(0xFFC9362B),
  MedicalOrderStatus.unknown => const Color(0xFF6B7280),
};
