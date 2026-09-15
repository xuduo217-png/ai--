import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/media/route_aware_video_surface.dart';
import '../../../core/network/api_client.dart';
import '../../mall/payment/domain/payment_models.dart';
import '../../mall/payment/presentation/payment_sheet_session.dart';
import '../../mall/payment/presentation/widgets/payment_sheet.dart';
import '../domain/charity_models.dart';
import 'charity_controller.dart';
import 'charity_payment_controller.dart';
import 'charity_list_page.dart';
import 'charity_widgets.dart';

class CharityDetailPage extends StatefulWidget {
  const CharityDetailPage({
    super.key,
    required this.gateway,
    required this.charityId,
    required this.authenticated,
    required this.requestLogin,
    this.paymentGateway,
  });

  final CharityGateway gateway;
  final int charityId;
  final bool authenticated;
  final CharityLoginRequester requestLogin;
  final PaymentGateway? paymentGateway;

  @override
  State<CharityDetailPage> createState() => _CharityDetailPageState();
}

class _CharityDetailPageState extends State<CharityDetailPage> {
  late final CharityDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CharityDetailController(
      gateway: widget.gateway,
      charityId: widget.charityId,
      authenticated: widget.authenticated,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleCheckIn() async {
    final activity = _controller.activity;
    if (activity == null || activity.isDonation) return;
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可参与打卡');
      return;
    }
    try {
      final result = await _controller.checkIn();
      if (result.success) {
        _showMessage(
          result.isCompleted ? '完成目标：${result.message}' : result.message,
        );
      } else if (result.alreadyChecked) {
        _showMessage(result.message.isEmpty ? '您今天已经打过卡了' : result.message);
      } else {
        _showMessage(result.message.isEmpty ? '打卡未成功，请稍后重试' : result.message);
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } on Object {
      _showMessage('签到失败，请稍后重试');
    }
  }

  Future<void> _handleDonation() async {
    final activity = _controller.activity;
    if (activity == null || !activity.isDonation || activity.isMallAutoDonation)
      return;
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可参与捐款');
      return;
    }
    if (activity.status != CharityStatus.active) {
      _showMessage('当前公益暂不可捐款');
      return;
    }

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DonationSheet(charityTitle: activity.title),
    );
    if (!mounted || amount == null) return;
    final paymentGateway = widget.paymentGateway;
    if (paymentGateway == null) {
      _showMessage('支付服务暂不可用，请稍后重试');
      return;
    }

    final paymentController = CharityPaymentController(
      detailController: _controller,
      paymentGateway: paymentGateway,
      amount: amount,
    );
    try {
      final result = await showUnifiedPaymentSheet(
        context,
        session: paymentController,
        summary: PaymentSheetSummary(
          amount: amount,
          referenceLabel: '公益项目',
          referenceValue: activity.title,
          timeoutMessage: '支付已超时，请稍后在公益详情确认捐款状态',
        ),
      );
      if (result != null) _showMessage(result.message);
    } finally {
      paymentController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final activity = _controller.activity;
          return Scaffold(
            backgroundColor: const Color(0xFFFAFBFF),
            body: CharityGradientBackground(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    CharityAppBar(
                      title: '公益详情',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: activity == null || activity.isMallAutoDonation
                ? null
                : _DetailActionBar(
                    activity: activity,
                    loading: _controller.actionLoading,
                    onPressed: activity.isDonation
                        ? _handleDonation
                        : _handleCheckIn,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.activity == null) {
      return const Center(
        child: CircularProgressIndicator(color: charityPrimary),
      );
    }
    if (_controller.activity == null) {
      return _DetailError(
        message: _controller.error ?? '无法加载公益详情，请稍后重试',
        onRetry: _controller.load,
      );
    }

    final activity = _controller.activity!;
    final horizontalPadding = MediaQuery.sizeOf(context).width < 600
        ? 16.0
        : 24.0;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 160) {
          _controller.loadMoreRecords();
        }
        return false;
      },
      child: RefreshIndicator(
        color: charityPrimary,
        onRefresh: _controller.refresh,
        child: ListView(
          key: const ValueKey('charity-detail-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            16,
          ),
          children: [
            _BasicInfoSection(activity: activity),
            if (activity.details.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailsSection(activity: activity),
            ],
            const SizedBox(height: 12),
            _RecordsSection(controller: _controller, activity: activity),
          ],
        ),
      ),
    );
  }
}

class _BasicInfoSection extends StatelessWidget {
  const _BasicInfoSection({required this.activity});

  final CharityActivity activity;

  @override
  Widget build(BuildContext context) {
    double px(num value) => charityDesignPx(context, value);
    return ClipRRect(
      borderRadius: BorderRadius.circular(px(12)),
      child: ColoredBox(
        key: const ValueKey('charity-basic-info'),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (activity.coverImageUrl.isNotEmpty)
              CharityCoverImage(
                url: activity.coverImageUrl,
                semanticLabel: '${activity.title}公益封面',
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(px(16), px(16), px(16), px(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      activity.title,
                      style: TextStyle(
                        color: charityInk,
                        fontSize: px(32),
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: px(12)),
                  CharityStatusBadge(status: activity.status),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(px(16), 0, px(16), px(4)),
              child: Row(
                children: [
                  Text(
                    '公益类型',
                    style: TextStyle(color: charityMuted, fontSize: px(24)),
                  ),
                  const Spacer(),
                  Text(
                    activity.participantType.label,
                    style: TextStyle(
                      color: charityInk,
                      fontSize: px(24),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (activity.description.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(px(16), px(16), px(16), 0),
                child: Text(
                  activity.description,
                  style: TextStyle(
                    color: charityMuted,
                    fontSize: px(26),
                    height: 1.31,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(px(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: px(40),
                    color: const Color(0xFF9E9E9E),
                  ),
                  SizedBox(width: px(8)),
                  Expanded(
                    child: Text(
                      _activityPeriod(activity),
                      style: TextStyle(
                        color: charityMuted,
                        fontSize: px(24),
                        height: 1.33,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (activity.isDonation)
              Container(
                key: const ValueKey('charity-donation-summary'),
                margin: EdgeInsets.fromLTRB(px(16), 0, px(16), px(16)),
                padding: EdgeInsets.all(px(16)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(px(12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.isMallAutoDonation ? '平台累计公益' : '已捐金额',
                      style: TextStyle(
                        color: const Color(0xFF9A3412),
                        fontSize: px(22),
                      ),
                    ),
                    SizedBox(height: px(8)),
                    Text(
                      '¥${activity.donatedAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: const Color(0xFFC2410C),
                        fontSize: px(36),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (activity.isMallAutoDonation) ...[
                      SizedBox(height: px(6)),
                      Text(
                        '普通商品实付金额的 ${activity.donationRate.toStringAsFixed(2)}% 自动计入',
                        style: TextStyle(
                          color: const Color(0xFF9A3412),
                          fontSize: px(20),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else if (activity.showProgress)
              Padding(
                padding: EdgeInsets.fromLTRB(px(16), 0, px(16), px(16)),
                child: CharityProgress(activity: activity),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.activity});

  final CharityActivity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('charity-details-section'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(charityDesignPx(context, 12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '公益详情',
            style: TextStyle(
              color: charityInk,
              fontSize: charityDesignPx(context, 28),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          CharityRichContent(content: activity.details),
        ],
      ),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.controller, required this.activity});

  final CharityDetailController controller;
  final CharityActivity activity;

  @override
  Widget build(BuildContext context) {
    final donation = activity.isDonation;
    return Container(
      key: const ValueKey('charity-records-section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(charityDesignPx(context, 12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            donation
                ? (activity.isMallAutoDonation ? '商城公益流水' : '捐款明细')
                : '打卡记录',
            style: TextStyle(
              color: charityInk,
              fontSize: charityDesignPx(context, 32),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          if (controller.recordsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: charityPrimary),
              ),
            )
          else if (controller.records.isEmpty)
            _EmptyRecords(
              donation: donation,
              autoDonation: activity.isMallAutoDonation,
              error: controller.recordsError,
            )
          else ...[
            for (final record in controller.records)
              _RecordRow(record: record, donation: donation),
            if (controller.hasMoreRecords)
              TextButton(
                key: const ValueKey('charity-records-load-more'),
                onPressed: controller.loadingMore
                    ? null
                    : controller.loadMoreRecords,
                child: controller.loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('加载更多'),
              ),
          ],
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords({
    required this.donation,
    required this.autoDonation,
    required this.error,
  });

  final bool donation;
  final bool autoDonation;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            donation
                ? Icons.volunteer_activism_rounded
                : Icons.event_note_rounded,
            size: charityDesignPx(context, 128),
            color: const Color(0xFFBDBDBD),
          ),
          const SizedBox(height: 16),
          Text(
            error ?? (donation ? '暂无捐款记录' : '暂无打卡记录'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            donation
                ? (autoDonation ? '购买普通商品后，公益金额会自动累计' : '成为第一个爱心捐赠者吧！')
                : '完成首次打卡，开始您的挑战吧！',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.donation});

  final CharityRecord record;
  final bool donation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: donation ? _buildDonation(context) : _buildCheckIn(),
    );
  }

  Widget _buildDonation(BuildContext context) {
    final isReversal = record.donationEntryType == 'reversal';
    final sourceLabel = record.donationSource == 'mall_order'
        ? (isReversal ? '退款冲销' : '消费公益')
        : '爱心捐款';
    final orderSuffix = record.orderNo?.isNotEmpty == true
        ? ' · ${record.orderNo}'
        : '';
    return Row(
      children: [
        _RecordAvatar(url: record.userAvatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.userName.isEmpty ? '爱心人士' : record.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: charityInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$sourceLabel$orderSuffix',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: charityHint, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(record.checkInTime),
                style: const TextStyle(color: charityHint, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${isReversal ? '-' : '+'}¥${record.donationAmount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: isReversal
                ? const Color(0xFFDC2626)
                : const Color(0xFFD97706),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckIn() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.checkInDate ?? _formatDate(record.checkInTime),
                style: const TextStyle(
                  color: charityInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(record.checkInTime),
                style: const TextStyle(color: charityHint, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
          size: 26,
        ),
      ],
    );
  }
}

class _RecordAvatar extends StatelessWidget {
  const _RecordAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const size = 42.0;
    if (url.isEmpty) {
      return const CircleAvatar(
        radius: size / 2,
        backgroundColor: Color(0xFFD97706),
        child: Icon(Icons.person_rounded, color: Colors.white, size: 22),
      );
    }
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Color(0xFFD97706),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.person_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({
    required this.activity,
    required this.loading,
    required this.onPressed,
  });

  final CharityActivity activity;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final unavailable = activity.status != CharityStatus.active;
    final checked = !activity.isDonation && activity.hasCheckedToday;
    final label = activity.isDonation
        ? switch (activity.status) {
            CharityStatus.active => '立即捐款',
            CharityStatus.expired => '公益已结束',
            CharityStatus.draft => '公益未开始',
          }
        : unavailable
        ? activity.status == CharityStatus.expired
              ? '公益已结束'
              : '公益未开始'
        : checked
        ? '今日已打卡'
        : '立即打卡';
    final accent = activity.isDonation ? charityDonation : charityPrimary;
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            key: const ValueKey('charity-primary-action'),
            onPressed: unavailable || checked || loading ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              disabledBackgroundColor: const Color(0xFFD1D5DB),
              shape: const StadiumBorder(),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: charityHint),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: charityMuted),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}

class _DonationSheet extends StatefulWidget {
  const _DonationSheet({required this.charityTitle});

  final String charityTitle;

  @override
  State<_DonationSheet> createState() => _DonationSheetState();
}

class _DonationSheetState extends State<_DonationSheet> {
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_handleAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _handleAmountChanged() {
    if (mounted) setState(() {});
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirm() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      _message('请输入有效的捐款金额');
      return;
    }
    final normalizedAmount = (amount * 100).round() / 100;
    Navigator.of(context).pop(normalizedAmount);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      key: const ValueKey('charity-donation-keyboard-inset'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.48,
        child: Material(
          key: const ValueKey('charity-donation-sheet'),
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: charityBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '爱心捐款',
                                  style: TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.charityTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: charityMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('charity-donation-close'),
                            tooltip: '关闭',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '捐款金额',
                        style: TextStyle(
                          color: charityInk,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: charityBorder),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              '¥',
                              style: TextStyle(
                                color: charityDonation,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: const ValueKey('charity-donation-amount'),
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.done,
                                inputFormatters: [_DonationAmountFormatter()],
                                decoration: const InputDecoration(
                                  hintText: '请输入捐款金额',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '请输入大于 0 的金额，支持两位小数',
                        style: TextStyle(color: charityHint, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          key: const ValueKey('charity-donation-confirm'),
                          onPressed: _confirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: charityDonation,
                            disabledBackgroundColor: charityDonation.withValues(
                              alpha: 0.7,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            '下一步',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonationAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var value = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (value.isEmpty) return TextEditingValue.empty;
    final dot = value.indexOf('.');
    if (dot >= 0) {
      var decimal = value.substring(dot + 1).replaceAll('.', '');
      if (decimal.length > 2) decimal = decimal.substring(0, 2);
      value = '${value.substring(0, dot)}.$decimal';
    }
    final pieces = value.split('.');
    var integer = pieces.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (integer.isEmpty) integer = '0';
    value = pieces.length > 1 ? '$integer.${pieces[1]}' : integer;
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

String _activityPeriod(CharityActivity activity) {
  if (activity.startTime != null && activity.endTime != null) {
    return '${_formatDate(activity.startTime!)} - ${_formatDate(activity.endTime!)}';
  }
  if (activity.endTime != null) return '截止：${_formatDate(activity.endTime!)}';
  return '永久公益';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}月${local.day}日';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
