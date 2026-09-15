import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/profile_models.dart';
import '../../navigation/profile_navigation_coordinator.dart';
import '../../../mall/order/domain/order_models.dart';
import '../profile_controller.dart';
import 'profile_edit_page.dart';

const _defaultProfileAvatarAsset = 'assets/images/health/pet_avatar.png';
const _profileBackgroundColor = Color(0xFFDEE9FF);
const _profileSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: _profileBackgroundColor,
  statusBarBrightness: Brightness.light,
  statusBarIconBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
);

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.navigator,
    this.notificationUnreadCount,
  });

  final ProfileController controller;
  final ProfileNavigator navigator;
  final ValueListenable<int>? notificationUnreadCount;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  OrderActionSummary? _orderActionSummary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.load());
    unawaited(_loadOrderActionSummary());
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      unawaited(widget.controller.load());
      unawaited(_loadOrderActionSummary());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refresh());
      unawaited(_loadOrderActionSummary());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        ?widget.notificationUnreadCount,
      ]),
      builder: (context, _) {
        final profile = widget.controller.profile;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _profileSystemUiOverlayStyle,
          child: DecoratedBox(
            key: const ValueKey('profile-background'),
            decoration: const BoxDecoration(color: _profileBackgroundColor),
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: const Color(0xFF3988E8),
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  key: const ValueKey('profile-scroll-view'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: _profileSpace(context, 24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBand(profile),
                      if (profile == null && widget.controller.isInitialLoading)
                        const SizedBox(
                          height: 360,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (profile == null)
                        _ProfileUnavailable(onRetry: widget.controller.refresh)
                      else ...[
                        if (widget.controller.profileError != null)
                          _InlineError(
                            message: widget.controller.profileError!,
                            onRetry: widget.controller.refresh,
                          ),
                        _buildWalletBand(),
                        _buildServicesBand(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBand(UserProfile? profile) {
    return DecoratedBox(
      key: const ValueKey('profile-header-band'),
      decoration: const BoxDecoration(color: _profileBackgroundColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (profile != null) _buildProfileBand(profile),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _profileSpace(context, 24),
        vertical: _profileSpace(context, 18),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            '个人中心',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF223047),
              letterSpacing: 0,
            ),
          ),
          if (widget.controller.isRefreshing)
            const Align(
              alignment: Alignment.centerRight,
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileBand(UserProfile profile) {
    final genderSemantic = genderIconSemantic(profile.gender);
    final genderIcon = switch (genderSemantic) {
      ProfileGenderIcon.person => Icons.person_outline_rounded,
      ProfileGenderIcon.male => Icons.male_rounded,
      ProfileGenderIcon.female => Icons.female_rounded,
    };
    return Padding(
      key: const ValueKey('profile-user-card'),
      padding: EdgeInsets.fromLTRB(
        _profileSpace(context, 24),
        _profileSpace(context, 8),
        _profileSpace(context, 24),
        _profileSpace(context, 28),
      ),
      child: Row(
        children: [
          _ProfileAvatar(profile: profile),
          SizedBox(width: _profileSpace(context, 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF223047),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    SizedBox(width: _profileSpace(context, 8)),
                    Semantics(
                      label: switch (profile.gender) {
                        UserGender.male => '性别，男',
                        UserGender.female => '性别，女',
                        UserGender.unknown => '性别，未设置',
                      },
                      excludeSemantics: true,
                      child: Icon(
                        genderIcon,
                        key: ValueKey('profile-gender-${profile.gender.name}'),
                        size: _profileSpace(context, 34),
                        color: switch (genderSemantic) {
                          ProfileGenderIcon.male => const Color(0xFF3988E8),
                          ProfileGenderIcon.female => const Color(0xFFF26F88),
                          ProfileGenderIcon.person => const Color(0xFF7D8998),
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _profileSpace(context, 12)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(
                      _profileSpace(context, 12),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _profileSpace(context, 12),
                      vertical: _profileSpace(context, 6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: _profileSpace(context, 30),
                          color: const Color(0xFFE69A16),
                        ),
                        SizedBox(width: _profileSpace(context, 6)),
                        Text(
                          profile.membershipLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC17B0E),
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: _profileSpace(context, 8)),
          Semantics(
            button: true,
            label: '编辑个人资料',
            excludeSemantics: true,
            child: SizedBox(
              key: const ValueKey('profile-edit-button'),
              height: 48,
              child: TextButton.icon(
                onPressed: _openEditor,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4B6688),
                  padding: EdgeInsets.symmetric(
                    horizontal: _profileSpace(context, 8),
                  ),
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑资料'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletBand() {
    final stats = widget.controller.walletStats;
    final radius = BorderRadius.circular(_profileSpace(context, 16));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _profileSpace(context, 24),
        _profileSpace(context, 18),
        _profileSpace(context, 24),
        _profileSpace(context, 18),
      ),
      child: Container(
        key: const ValueKey('profile-wallet-card'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: const Color(0xFFE6EEF8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x143B6FA8),
              offset: Offset(0, 6),
              blurRadius: 20,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                _openDestination(() => widget.navigator.openWallet(context)),
            child: Padding(
              padding: EdgeInsets.all(_profileSpace(context, 24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: _profileSpace(context, 64),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F2FF),
                            borderRadius: BorderRadius.circular(
                              _profileSpace(context, 12),
                            ),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: _profileSpace(context, 38),
                            color: const Color(0xFF3988E8),
                          ),
                        ),
                      ),
                      SizedBox(width: _profileSpace(context, 12)),
                      const Expanded(
                        child: Text(
                          '我的钱包',
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF223047),
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const Text(
                        '进入钱包',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4B6688),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: _profileSpace(context, 36),
                        color: const Color(0xFF9DAABC),
                      ),
                    ],
                  ),
                  SizedBox(height: _profileSpace(context, 20)),
                  if (stats != null) ...[
                    _WalletPrimaryAmount(amount: stats.availableBalance),
                    SizedBox(height: _profileSpace(context, 20)),
                    const Divider(height: 1, color: Color(0xFFE7EDF5)),
                    SizedBox(height: _profileSpace(context, 18)),
                    Row(
                      children: [
                        _WalletAmount(
                          label: '待到账',
                          amount: stats.pendingSettlement,
                        ),
                        _WalletDivider(height: _profileSpace(context, 54)),
                        _WalletAmount(
                          label: '累计二手收益',
                          amount: stats.totalSecondHandIncome,
                        ),
                      ],
                    ),
                  ] else if (widget.controller.walletError != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.controller.walletError!,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('profile-wallet-retry'),
                          onPressed: widget.controller.refresh,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF3988E8),
                          ),
                          child: const Text('重试'),
                        ),
                      ],
                    )
                  else
                    const Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3988E8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesBand() {
    final quickServices = _serviceItems.take(4).toList(growable: false);
    final toolServices = _serviceItems
        .skip(4)
        .take(_serviceItems.length - 5)
        .toList(growable: false);
    final settings = _serviceItems.last;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _profileSpace(context, 24),
        0,
        _profileSpace(context, 24),
        _profileSpace(context, 30),
      ),
      child: KeyedSubtree(
        key: const ValueKey('profile-services-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildQuickServices(quickServices),
            SizedBox(height: _profileSpace(context, 18)),
            _buildToolsBand(toolServices),
            SizedBox(height: _profileSpace(context, 18)),
            _buildSettingsItem(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickServices(List<_ProfileServiceItem> services) {
    return Container(
      key: const ValueKey('profile-quick-services-card'),
      decoration: _profileCardDecoration(context),
      padding: EdgeInsets.fromLTRB(
        _profileSpace(context, 24),
        _profileSpace(context, 20),
        _profileSpace(context, 24),
        _profileSpace(context, 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProfileSectionTitle('常用服务'),
          SizedBox(height: _profileSpace(context, 18)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final service in services)
                Expanded(child: _buildQuickServiceItem(service)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickServiceItem(_ProfileServiceItem item) {
    return Semantics(
      button: true,
      label: '${item.title}，${item.description}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('profile-service-${item.id}'),
          borderRadius: BorderRadius.circular(_profileSpace(context, 12)),
          onTap: () =>
              _openDestination(() => item.open(widget.navigator, context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _profileSpace(context, 4),
                vertical: _profileSpace(context, 8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildServiceIcon(item, dimension: 78, iconSize: 42),
                      if (_badgeFor(item) > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: _ServiceBadge(count: _badgeFor(item)),
                        ),
                    ],
                  ),
                  SizedBox(height: _profileSpace(context, 12)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF223047),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolsBand(List<_ProfileServiceItem> services) {
    return Container(
      key: const ValueKey('profile-tools-card'),
      decoration: _profileCardDecoration(context),
      padding: EdgeInsets.fromLTRB(
        _profileSpace(context, 24),
        _profileSpace(context, 20),
        _profileSpace(context, 24),
        _profileSpace(context, 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProfileSectionTitle('我的工具'),
          SizedBox(height: _profileSpace(context, 10)),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final useSingleColumn =
                  constraints.maxWidth < 330 || textScale > 1.2;
              if (useSingleColumn) {
                return Column(
                  children: [
                    for (var index = 0; index < services.length; index++) ...[
                      if (index > 0) const _ToolDivider(),
                      _buildToolServiceItem(services[index]),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < services.length; index += 2) ...[
                    if (index > 0) const _ToolDivider(),
                    _buildToolRow(
                      services[index],
                      index + 1 < services.length ? services[index + 1] : null,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolRow(_ProfileServiceItem left, _ProfileServiceItem? right) {
    if (right == null) return _buildToolServiceItem(left);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildToolServiceItem(left)),
          const VerticalDivider(
            width: 1,
            thickness: 0.5,
            color: Color(0xFFF1F4F8),
          ),
          Expanded(child: _buildToolServiceItem(right)),
        ],
      ),
    );
  }

  Widget _buildToolServiceItem(_ProfileServiceItem item) {
    final badge = _badgeFor(item);
    final semanticLabel = badge > 0
        ? '${item.title}，$badge 条未读'
        : '${item.title}，${item.description}';
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('profile-service-${item.id}'),
          borderRadius: BorderRadius.circular(_profileSpace(context, 10)),
          onTap: () =>
              _openDestination(() => item.open(widget.navigator, context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _profileSpace(context, 12),
                vertical: _profileSpace(context, 16),
              ),
              child: Row(
                children: [
                  _buildServiceIcon(item, dimension: 68, iconSize: 38),
                  SizedBox(width: _profileSpace(context, 12)),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF223047),
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badge > 0) _ServiceBadge(count: badge),
                  SizedBox(width: _profileSpace(context, 4)),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: _profileSpace(context, 30),
                    color: const Color(0xFFA7B2C0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(_ProfileServiceItem item) {
    return Container(
      key: const ValueKey('profile-settings-card'),
      decoration: _profileCardDecoration(context),
      child: Semantics(
        button: true,
        label: '${item.title}，${item.description}',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_profileSpace(context, 16)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('profile-service-${item.id}'),
            onTap: () =>
                _openDestination(() => item.open(widget.navigator, context)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _profileSpace(context, 20),
                  vertical: _profileSpace(context, 16),
                ),
                child: Row(
                  children: [
                    _buildServiceIcon(item, dimension: 68, iconSize: 38),
                    SizedBox(width: _profileSpace(context, 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF223047),
                            ),
                          ),
                          SizedBox(height: _profileSpace(context, 4)),
                          Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7D8998),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFFA7B2C0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceIcon(
    _ProfileServiceItem item, {
    required num dimension,
    required num iconSize,
  }) {
    return SizedBox.square(
      dimension: _profileSpace(context, dimension),
      child: DecoratedBox(
        key: ValueKey('profile-service-icon-${item.id}'),
        decoration: BoxDecoration(
          color: item.tint,
          borderRadius: BorderRadius.circular(_profileSpace(context, 16)),
        ),
        child: Icon(
          item.icon,
          size: _profileSpace(context, iconSize),
          color: item.color,
        ),
      ),
    );
  }

  int _badgeFor(_ProfileServiceItem item) {
    return switch (item.id) {
      'orders' => _orderActionSummary?.purchaseCount ?? 0,
      'sales' => _orderActionSummary?.salesCount ?? 0,
      'notifications' =>
        widget.notificationUnreadCount?.value ??
            widget.controller.notificationUnreadCount,
      _ => 0,
    };
  }

  Future<void> _loadOrderActionSummary() async {
    final navigator = widget.navigator;
    if (navigator is! ProfileNavigationCoordinator) return;
    final gateway = navigator.orderActionGateway;
    if (gateway == null) return;
    try {
      final summary = await gateway.loadActionSummary();
      if (mounted) setState(() => _orderActionSummary = summary);
    } catch (_) {
      // 待办提示失败不阻塞个人中心主要内容。
    }
  }

  Future<void> _refresh() async {
    await Future.wait([widget.controller.refresh(), _loadOrderActionSummary()]);
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<ProfileEditCompletion>(
      MaterialPageRoute(
        builder: (_) => ProfileEditPage(controller: widget.controller),
      ),
    );
    if (!mounted || result == null) return;
    final message = result == ProfileEditCompletion.saved
        ? '个人资料已更新'
        : '资料没有变化';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDestination(Future<void> Function() action) async {
    await action();
    if (mounted) await _refresh();
  }
}

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile-unread-dot'),
      height: 18,
      constraints: const BoxConstraints(minWidth: 18),
      width: count < 10 ? 18 : null,
      padding: count < 10
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4D4D),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final url = profile.resolvedAvatarUrl();
    return Semantics(
      image: true,
      label: '头像，${profile.displayName}',
      excludeSemantics: true,
      child: Container(
        width: _profileSpace(context, 120),
        height: _profileSpace(context, 120),
        padding: EdgeInsets.all(_profileSpace(context, 5)),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x183B6FA8),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: ClipOval(
          child: url.isEmpty
              ? _defaultProfileAvatar()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _defaultProfileAvatar(),
                ),
        ),
      ),
    );
  }
}

Widget _defaultProfileAvatar() {
  return Image.asset(
    _defaultProfileAvatarAsset,
    key: const ValueKey('profile-default-avatar'),
    fit: BoxFit.cover,
  );
}

class _WalletPrimaryAmount extends StatelessWidget {
  const _WalletPrimaryAmount({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '可提现余额，${amount.toStringAsFixed(2)} 元',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '可提现余额',
            style: TextStyle(
              fontSize: 13,
              height: 1.25,
              color: Color(0xFF7D8998),
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '¥${amount.toStringAsFixed(2)}',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3988E8),
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: Color(0xFF223047),
        letterSpacing: 0,
      ),
    );
  }
}

BoxDecoration _profileCardDecoration(BuildContext context) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(_profileSpace(context, 16)),
    border: Border.all(color: const Color(0xFFE8EEF6)),
  );
}

class _WalletAmount extends StatelessWidget {
  const _WalletAmount({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        container: true,
        label: '$label，${amount.toStringAsFixed(2)} 元',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                color: Color(0xFF7D8998),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '¥${amount.toStringAsFixed(2)}',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF223047),
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletDivider extends StatelessWidget {
  const _WalletDivider({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: _profileSpace(context, 12)),
      color: const Color(0xFFE5E7EB),
    );
  }
}

class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF1F4F8));
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF4ED),
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB54708), fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 46,
            color: Color(0xFF98A0AA),
          ),
          const SizedBox(height: 12),
          const Text('个人资料加载失败'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}

typedef _OpenProfileService =
    Future<void> Function(ProfileNavigator navigator, BuildContext context);

class _ProfileServiceItem {
  const _ProfileServiceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.tint,
    required this.open,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color tint;
  final _OpenProfileService open;
}

final List<_ProfileServiceItem> _serviceItems = [
  _ProfileServiceItem(
    id: 'pets',
    title: '我的宠物',
    description: '添加和管理您的宠物信息',
    icon: Icons.pets,
    color: const Color(0xFFF0645A),
    tint: const Color(0xFFFFF0ED),
    open: (navigator, context) => navigator.openPets(context),
  ),
  _ProfileServiceItem(
    id: 'orders',
    title: '我买到的',
    description: '查看购买订单和售后进度',
    icon: Icons.shopping_bag_outlined,
    color: const Color(0xFFD99518),
    tint: const Color(0xFFFFF6DE),
    open: (navigator, context) => navigator.openOrders(context),
  ),
  _ProfileServiceItem(
    id: 'medical-orders',
    title: '医疗服务',
    description: '查看医疗服务订单',
    icon: Icons.medical_services_outlined,
    color: const Color(0xFF397EDB),
    tint: const Color(0xFFEAF3FF),
    open: (navigator, context) => navigator.openMedicalOrders(context),
  ),
  _ProfileServiceItem(
    id: 'addresses',
    title: '收货地址',
    description: '管理您的收货地址',
    icon: Icons.location_on_outlined,
    color: const Color(0xFF159DB0),
    tint: const Color(0xFFE7F8FA),
    open: (navigator, context) => navigator.openAddresses(context),
  ),
  _ProfileServiceItem(
    id: 'community',
    title: '社区主页',
    description: '查看和管理我的社区帖子',
    icon: Icons.dynamic_feed_outlined,
    color: const Color(0xFF7656D6),
    tint: const Color(0xFFF1EDFF),
    open: (navigator, context) => navigator.openCommunityProfile(context),
  ),
  _ProfileServiceItem(
    id: 'lost-found-posts',
    title: '走失领养发布',
    description: '管理我发布的走失和领养信息',
    icon: Icons.campaign_outlined,
    color: const Color(0xFF5B75E5),
    tint: const Color(0xFFEFF2FF),
    open: (navigator, context) => navigator.openLostFoundPosts(context),
  ),
  _ProfileServiceItem(
    id: 'notifications',
    title: '通知消息',
    description: '查看系统通知和消息',
    icon: Icons.notifications_none_rounded,
    color: const Color(0xFF3988E8),
    tint: const Color(0xFFEDF4FF),
    open: (navigator, context) => navigator.openNotifications(context),
  ),
  _ProfileServiceItem(
    id: 'coupons',
    title: '我的优惠券',
    description: '查看我的优惠券',
    icon: Icons.confirmation_number_outlined,
    color: const Color(0xFFE69622),
    tint: const Color(0xFFFFF4E5),
    open: (navigator, context) => navigator.openCoupons(context),
  ),
  _ProfileServiceItem(
    id: 'favorites',
    title: '我的收藏',
    description: '查看收藏的商品',
    icon: Icons.star_border_rounded,
    color: const Color(0xFF3988E8),
    tint: const Color(0xFFEDF4FF),
    open: (navigator, context) => navigator.openFavorites(context),
  ),
  _ProfileServiceItem(
    id: 'sales',
    title: '我卖出的',
    description: '处理发货和买家售后',
    icon: Icons.sell_outlined,
    color: const Color(0xFFB45309),
    tint: const Color(0xFFFFF3E6),
    open: (navigator, context) => navigator.openSales(context),
  ),
  _ProfileServiceItem(
    id: 'published-products',
    title: '我发布商品',
    description: '查看我发布的商品',
    icon: Icons.storefront_outlined,
    color: const Color(0xFF18A6B2),
    tint: const Color(0xFFE8F8F8),
    open: (navigator, context) => navigator.openPublishedProducts(context),
  ),
  _ProfileServiceItem(
    id: 'settings',
    title: '设置',
    description: '账号、安全与通用设置',
    icon: Icons.settings_outlined,
    color: const Color(0xFF7C8793),
    tint: const Color(0xFFF1F3F5),
    open: (navigator, context) => navigator.openSettings(context),
  ),
];

double _profileSpace(BuildContext context, num designPixels) {
  final size = MediaQuery.sizeOf(context);
  final referenceWidth = size.width < size.height ? size.width : size.height;
  return (designPixels * referenceWidth / 750).roundToDouble();
}
