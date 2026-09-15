import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/coupon_models.dart';

class ScannedCouponDetailPage extends StatefulWidget {
  const ScannedCouponDetailPage({
    super.key,
    required this.gateway,
    required this.claimCode,
    this.onOpenMyCoupons,
  });

  final CouponScanGateway gateway;
  final String claimCode;
  final Future<void> Function()? onOpenMyCoupons;

  @override
  State<ScannedCouponDetailPage> createState() =>
      _ScannedCouponDetailPageState();
}

class _ScannedCouponDetailPageState extends State<ScannedCouponDetailPage> {
  CouponScanDetail? _detail;
  bool _loading = true;
  bool _claiming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetail());
  }

  Future<void> _loadDetail() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final detail = await widget.gateway.loadScanDetail(widget.claimCode);
      if (!mounted) return;
      setState(() => _detail = detail);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _errorText(error, '优惠券加载失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim() async {
    final detail = _detail;
    if (detail == null || !detail.canClaim || _claiming) return;
    setState(() => _claiming = true);
    try {
      await widget.gateway.claimByScanCode(detail.claimCode);
      if (!mounted) return;
      _showMessage('领取成功');
      await _loadDetail();
    } on Object catch (error) {
      _showMessage(_errorText(error, '领取失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(Object error, String fallback) {
    final message = '$error'.trim().replaceFirst(
      RegExp(r'^(?:Exception|ApiException):\s*'),
      '',
    );
    return message.isEmpty || message == 'Exception' ? fallback : message;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('scanned-coupon-gradient-background'),
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
          title: const Text('优惠券详情'),
          foregroundColor: AppColors.ink,
          backgroundColor: const Color(0xFFDEE9FF),
          surfaceTintColor: const Color(0xFFDEE9FF),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomAction(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _detail == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_errorMessage != null && _detail == null) {
      return _CouponLoadError(message: _errorMessage!, onRetry: _loadDetail);
    }
    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();
    final status = _statusMeta(detail);
    final rule = detail.coupon;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadDetail,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Container(
            key: const ValueKey('scanned-coupon-hero'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF5B75E5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x265B75E5),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_offer_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 5),
                          Text(
                            '扫码专享',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: status.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          color: status.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  formatCouponFaceValue(rule),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatCouponCondition(rule),
                  style: const TextStyle(
                    color: Color(0xFFE8EDFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  rule.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (rule.description case final description?) ...[
                  const SizedBox(height: 7),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFFDDE5FF),
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(color: Color(0x55FFFFFF)),
                const SizedBox(height: 10),
                _HeroInfoRow(
                  label: '有效期',
                  value: formatCouponRuleValidity(rule),
                ),
                const SizedBox(height: 9),
                _HeroInfoRow(label: '领取码', value: detail.claimCode),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: '领取信息',
            children: [
              _InfoLine(
                icon: status.icon,
                title: status.headline,
                color: status.foreground,
              ),
              if (detail.unavailableReason case final reason?)
                _InfoLine(
                  icon: Icons.info_outline_rounded,
                  title: reason,
                  color: const Color(0xFF92400E),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: '使用规则',
            children: [
              _RuleLine(text: '${formatCouponCondition(rule)}，可在商城订单内使用'),
              _RuleLine(text: rule.canStack ? '支持与其他优惠叠加使用' : '不可与其他优惠叠加使用'),
              const _RuleLine(text: '领取成功后会自动同步到“我的优惠券”'),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomAction() {
    final detail = _detail;
    if (detail == null) return null;
    final isClaimed = detail.claimed;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE7ECF5))),
        ),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            key: const ValueKey('scanned-coupon-primary-action'),
            onPressed: _claiming
                ? null
                : isClaimed
                ? widget.onOpenMyCoupons
                : detail.canClaim
                ? _claim
                : null,
            icon: _claiming
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isClaimed
                        ? Icons.confirmation_number_outlined
                        : Icons.redeem_rounded,
                  ),
            label: Text(
              _claiming
                  ? '领取中...'
                  : isClaimed
                  ? '查看我的优惠券'
                  : detail.canClaim
                  ? '立即领取'
                  : '暂不可领取',
            ),
          ),
        ),
      ),
    );
  }
}

({
  String label,
  String headline,
  IconData icon,
  Color foreground,
  Color background,
})
_statusMeta(CouponScanDetail detail) {
  if (detail.claimed) {
    return (
      label: '已领取',
      headline: '优惠券已放入当前账号',
      icon: Icons.check_circle_rounded,
      foreground: const Color(0xFF047857),
      background: const Color(0xFFD1FAE5),
    );
  }
  if (detail.canClaim) {
    return (
      label: '待领取',
      headline: '点击下方按钮即可领取',
      icon: Icons.redeem_rounded,
      foreground: const Color(0xFF1D4ED8),
      background: const Color(0xFFDBEAFE),
    );
  }
  return (
    label: '暂不可领',
    headline: '当前状态不可领取',
    icon: Icons.info_rounded,
    foreground: const Color(0xFF92400E),
    background: const Color(0xFFFEF3C7),
  );
}

class _CouponLoadError extends StatelessWidget {
  const _CouponLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Color(0xFF9AA4B2),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('scanned-coupon-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroInfoRow extends StatelessWidget {
  const _HeroInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFCBD5FF), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: AppColors.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: SizedBox.square(
              dimension: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
