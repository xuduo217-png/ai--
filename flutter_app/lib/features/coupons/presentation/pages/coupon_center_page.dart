import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/coupon_models.dart';
import '../coupon_center_controller.dart';

class CouponCenterPage extends StatefulWidget {
  const CouponCenterPage({super.key, required this.gateway});

  final CouponGateway gateway;

  @override
  State<CouponCenterPage> createState() => _CouponCenterPageState();
}

class _CouponCenterPageState extends State<CouponCenterPage> {
  late final CouponCenterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CouponCenterController(widget.gateway);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('coupon-gradient-background'),
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
          title: const Text(
            '我的优惠券',
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
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            children: [
              _CouponTabs(controller: _controller),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && _controller.coupons.isEmpty) {
      return const _CouponLoadingView();
    }
    if (_controller.errorMessage != null && _controller.coupons.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF2196F3),
        onRefresh: _controller.retry,
        child: _CouponStateView(
          icon: Icons.wifi_off_rounded,
          title: '优惠券加载失败',
          description: '请检查网络后重试',
          action: OutlinedButton.icon(
            key: const ValueKey('coupon-retry'),
            onPressed: _controller.retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
      );
    }
    if (_controller.coupons.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF2196F3),
        onRefresh: _controller.refresh,
        child: _CouponStateView(
          icon: _emptyIcon(_controller.selectedStatus),
          title: _emptyTitle(_controller.selectedStatus),
          description: _emptyDescription(_controller.selectedStatus),
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
                color: Color(0xFF9A6500),
              ),
              title: const Text('刷新失败，正在显示上次内容'),
              trailing: TextButton(
                onPressed: _controller.refresh,
                child: const Text('重试'),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF2196F3),
            onRefresh: _controller.refresh,
            child: ListView.separated(
              key: const ValueKey('coupon-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 15),
              itemCount: _controller.coupons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _CouponCard(coupon: _controller.coupons[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CouponTabs extends StatelessWidget {
  const _CouponTabs({required this.controller});

  final CouponCenterController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white)),
      ),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            for (final status in const [
              UserCouponStatus.available,
              UserCouponStatus.used,
              UserCouponStatus.expired,
            ])
              Expanded(
                child: InkWell(
                  key: ValueKey('coupon-tab-${status.wireValue}'),
                  onTap: () => unawaited(controller.selectStatus(status)),
                  child: DecoratedBox(
                    key: controller.selectedStatus == status
                        ? ValueKey('coupon-tab-active-${status.wireValue}')
                        : null,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: controller.selectedStatus == status
                              ? const Color(0xFF2196F3)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: controller.selectedStatus == status
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: controller.selectedStatus == status
                              ? const Color(0xFF2196F3)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatefulWidget {
  const _CouponCard({required this.coupon});

  final UserCoupon coupon;

  @override
  State<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends State<_CouponCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final isAvailable = coupon.status == UserCouponStatus.available;
    final primaryText = isAvailable
        ? const Color(0xFF1F2937)
        : const Color(0xFF9CA3AF);
    final secondaryText = isAvailable
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return Semantics(
      label: '${coupon.rule.name}，${coupon.status.label}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          key: ValueKey('coupon-card-${coupon.id}'),
          decoration: BoxDecoration(
            color: isAvailable ? const Color(0xFFFFF7ED) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isAvailable
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: 73,
                child: ColoredBox(
                  key: ValueKey('coupon-card-amount-${coupon.id}'),
                  color: isAvailable
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFD1D5DB),
                ),
              ),
              const Positioned(
                top: 0,
                bottom: 0,
                left: 73,
                width: 1,
                child: ColoredBox(color: Color(0xFFE5E7EB)),
              ),
              Positioned(
                top: 4,
                bottom: 4,
                left: 73,
                width: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var index = 0; index < 6; index += 1)
                      SizedBox(
                        height: 4,
                        child: OverflowBox(
                          minWidth: 4,
                          maxWidth: 4,
                          minHeight: 4,
                          maxHeight: 4,
                          child: Container(
                            key: ValueKey(
                              'coupon-card-connector-dot-${coupon.id}-$index',
                            ),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: -5,
                left: 68,
                child: _CouponNotch(
                  key: ValueKey('coupon-card-notch-top-${coupon.id}'),
                ),
              ),
              Positioned(
                bottom: -5,
                left: 68,
                child: _CouponNotch(
                  key: ValueKey('coupon-card-notch-bottom-${coupon.id}'),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 74,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatCouponFaceValue(coupon.rule),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  coupon.rule.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: primaryText,
                                  ),
                                ),
                              ),
                              if (isAvailable) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  key: ValueKey('coupon-expand-${coupon.id}'),
                                  tooltip: _expanded ? '收起优惠券详情' : '展开优惠券详情',
                                  onPressed: () =>
                                      setState(() => _expanded = !_expanded),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 28,
                                    height: 28,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    _expanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 18,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCouponCondition(coupon.rule),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCouponValidity(coupon),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: isAvailable
                                  ? const Color(0xFF9CA3AF)
                                  : secondaryText,
                            ),
                          ),
                          if (_expanded) _ExpandedCouponDetails(coupon: coupon),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponNotch extends StatelessWidget {
  const _CouponNotch({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 10,
      height: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ExpandedCouponDetails extends StatelessWidget {
  const _ExpandedCouponDetails({required this.coupon});

  final UserCoupon coupon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 7),
          _CouponDetailRow(
            icon: Icons.description_outlined,
            label: '描述',
            value: coupon.rule.description ?? '暂无描述',
          ),
          const SizedBox(height: 5),
          _CouponDetailRow(
            icon: Icons.category_outlined,
            label: '使用范围',
            value: coupon.rule.scope.label,
          ),
          const SizedBox(height: 5),
          _CouponDetailRow(
            icon: Icons.layers_outlined,
            label: '叠加规则',
            value: coupon.rule.canStack ? '支持叠加' : '不可叠加',
            valueColor: coupon.rule.canStack ? const Color(0xFF059669) : null,
          ),
        ],
      ),
    );
  }
}

class _CouponDetailRow extends StatelessWidget {
  const _CouponDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF6B7280)),
        const SizedBox(width: 3),
        SizedBox(
          width: 51,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF4B5563),
              fontSize: 11,
              height: 1.35,
              fontWeight: valueColor == null
                  ? FontWeight.w400
                  : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CouponLoadingView extends StatelessWidget {
  const _CouponLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF2196F3),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '加载中...',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _CouponStateView extends StatelessWidget {
  const _CouponStateView({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
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
                  Icon(
                    icon,
                    key: const ValueKey('coupon-empty-icon'),
                    size: 64,
                    color: const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

IconData _emptyIcon(UserCouponStatus status) => switch (status) {
  UserCouponStatus.available => Icons.local_offer_outlined,
  UserCouponStatus.used => Icons.confirmation_number_outlined,
  UserCouponStatus.expired => Icons.event_busy_outlined,
  UserCouponStatus.unknown => Icons.local_offer_outlined,
};

String _emptyTitle(UserCouponStatus status) => switch (status) {
  UserCouponStatus.available => '暂无可用优惠券',
  UserCouponStatus.used => '暂无已使用优惠券',
  UserCouponStatus.expired => '暂无过期优惠券',
  UserCouponStatus.unknown => '暂无优惠券',
};

String _emptyDescription(UserCouponStatus status) => switch (status) {
  UserCouponStatus.available => '快去领取优惠券吧',
  UserCouponStatus.used => '使用的优惠券会显示在这里',
  UserCouponStatus.expired => '过期的优惠券会显示在这里',
  UserCouponStatus.unknown => '优惠券会显示在这里',
};
