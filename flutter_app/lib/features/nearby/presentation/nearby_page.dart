import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../core/network/asset_url_resolver.dart';
import '../domain/nearby_models.dart';
import 'nearby_controller.dart';

const _nearbyPrimary = Color(0xFF7E97FA);
const _nearbyInk = Color(0xFF1F2937);
const _nearbyMuted = Color(0xFF6B7280);
const _nearbyHint = Color(0xFF9CA3AF);
const _nearbyBorder = Color(0xFFE5E7EB);

double _nearbyPx(BuildContext context, num designPixels) {
  final size = MediaQuery.sizeOf(context);
  final referenceWidth = size.width < size.height ? size.width : size.height;
  return (designPixels * referenceWidth / 750).roundToDouble();
}

class NearbyPage extends StatefulWidget {
  const NearbyPage({
    super.key,
    required this.gateway,
    required this.locationGateway,
    this.sendFriendRequest,
  });

  final NearbyGateway gateway;
  final NearbyLocationGateway locationGateway;
  final NearbyFriendRequestSender? sendFriendRequest;

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> with WidgetsBindingObserver {
  late final NearbyController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _rationaleShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = NearbyController(
      gateway: widget.gateway,
      locationGateway: widget.locationGateway,
      sendFriendRequest: widget.sendFriendRequest,
    );
    _scrollController.addListener(_handleScroll);
    _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted ||
        defaultTargetPlatform != TargetPlatform.android ||
        _controller.viewState != NearbyViewState.permissionRequired ||
        _rationaleShown) {
      return;
    }
    _rationaleShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showLocationRationale();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_controller.viewState == NearbyViewState.permissionRequired ||
        _controller.viewState == NearbyViewState.permissionDeniedForever ||
        _controller.viewState == NearbyViewState.locationServiceDisabled) {
      _controller.resumeAfterSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    _controller.loadMore();
  }

  Future<void> _handleLocationAction() async {
    switch (_controller.viewState) {
      case NearbyViewState.permissionDeniedForever:
        await _showOpenSettingsDialog();
      case NearbyViewState.locationServiceDisabled:
        await _showLocationSettingsDialog();
      case NearbyViewState.permissionRequired:
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _showLocationRationale();
        } else {
          await _controller.requestLocationPermission();
        }
      case NearbyViewState.loading:
      case NearbyViewState.ready:
      case NearbyViewState.error:
        await _controller.requestLocationPermission();
    }
  }

  Future<void> _showLocationRationale() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _LocationPermissionPrompt(
        onDeny: () => Navigator.of(dialogContext).pop(false),
        onGrant: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed == true && mounted) {
      await _controller.requestLocationPermission();
    }
  }

  Future<void> _showOpenSettingsDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.location_off_rounded),
        title: const Text('定位权限未开启'),
        content: const Text('请在系统设置中允许谷德E宠使用位置信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.openAppSettings();
  }

  Future<void> _showLocationSettingsDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.gps_off_rounded),
        title: const Text('定位服务已关闭'),
        content: const Text('请先开启设备定位服务，再刷新当前位置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.openLocationSettings();
  }

  Future<void> _toggleDiscovery(bool enabled) async {
    final result = await _controller.toggleDiscovery(enabled);
    if (!mounted || result == null) {
      if (mounted && _controller.errorMessage != null) {
        _showMessage(_controller.errorMessage!);
      }
      return;
    }
    _showMessage(result ? '已开启发现' : '已关闭发现');
  }

  Future<void> _confirmAddFriend(NearbyUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.person_add_alt_1_rounded),
        title: const Text('发送好友申请'),
        content: Text('确定向“${user.username}”发送好友申请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: ValueKey('nearby-friend-confirm-${user.userId}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _controller.addFriend(user);
    if (!mounted) return;
    _showMessage(result?.message ?? _controller.errorMessage ?? '好友申请发送失败');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('nearby-gradient-background'),
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
          toolbarHeight: 52,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            key: const ValueKey('nearby-back'),
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 25,
              color: _nearbyInk,
            ),
          ),
          title: const Text('附近的人'),
          titleTextStyle: const TextStyle(
            color: _nearbyInk,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          actions: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => IconButton(
                key: const ValueKey('nearby-discovery-action'),
                tooltip: _controller.discoveryEnabled ? '关闭发现' : '开启发现',
                onPressed: _controller.updatingDiscovery
                    ? null
                    : () => _toggleDiscovery(!_controller.discoveryEnabled),
                icon: _controller.updatingDiscovery
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _controller.discoveryEnabled
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 25,
                        color: _controller.discoveryEnabled
                            ? _nearbyPrimary
                            : _nearbyHint,
                      ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            children: [
              if (_controller.currentLocation != null)
                _NearbyLocationHeader(controller: _controller),
              Expanded(
                child: switch (_controller.viewState) {
                  NearbyViewState.loading => const _LoadingState(),
                  NearbyViewState.permissionRequired => _AccessState(
                    icon: Icons.location_on_outlined,
                    title: '需要定位权限',
                    description: '请开启定位权限以查看附近的人',
                    buttonText: defaultTargetPlatform == TargetPlatform.iOS
                        ? '继续'
                        : '去开启',
                    loading: _controller.locating,
                    onPressed: _handleLocationAction,
                  ),
                  NearbyViewState.permissionDeniedForever => _AccessState(
                    icon: Icons.location_disabled_outlined,
                    title: '定位权限未开启',
                    description: '请在系统设置中允许谷德E宠使用位置信息',
                    buttonText: '去设置',
                    loading: _controller.locating,
                    onPressed: _handleLocationAction,
                  ),
                  NearbyViewState.locationServiceDisabled => _AccessState(
                    icon: Icons.gps_off_outlined,
                    title: '定位服务已关闭',
                    description: '开启设备定位服务后即可获取当前位置',
                    buttonText: '去设置',
                    loading: _controller.locating,
                    onPressed: _handleLocationAction,
                  ),
                  NearbyViewState.error => _AccessState(
                    icon: Icons.cloud_off_outlined,
                    title: '暂时无法加载',
                    description: _controller.errorMessage ?? '请稍后重试',
                    buttonText: '重新加载',
                    loading: false,
                    onPressed: _controller.initialize,
                  ),
                  NearbyViewState.ready => _NearbyContent(
                    controller: _controller,
                    scrollController: _scrollController,
                    onAddFriend: _confirmAddFriend,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPermissionPrompt extends StatelessWidget {
  const _LocationPermissionPrompt({
    required this.onDeny,
    required this.onGrant,
  });

  final VoidCallback onDeny;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('nearby-location-rationale'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF44336).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 30,
                    color: Color(0xFFF44336),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '需要位置权限',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _nearbyInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '为了为你推荐附近的养宠用户并提供准确的距离信息，我们需要获取你的当前位置。',
                style: TextStyle(
                  color: _nearbyMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '我们将：',
                style: TextStyle(
                  color: _nearbyInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const _PermissionFeature(text: '查找附近的养宠用户'),
              const _PermissionFeature(text: '提供准确的距离信息'),
              const _PermissionFeature(text: '按同城、5km 和 10km 筛选'),
              const SizedBox(height: 6),
              const Text(
                '位置信息仅用于附近功能，不会用于其他用途。',
                style: TextStyle(
                  color: _nearbyHint,
                  fontSize: 12,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDeny,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _nearbyMuted,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('暂不需要'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('nearby-location-rationale-confirm'),
                      onPressed: onGrant,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF44336),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('授权'),
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

class _PermissionFeature extends StatelessWidget {
  const _PermissionFeature({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: Color(0xFF4CAF50),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _nearbyMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _nearbyPrimary),
          SizedBox(height: 12),
          Text('获取位置中...', style: TextStyle(color: _nearbyMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

class _AccessState extends StatelessWidget {
  const _AccessState({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.loading,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: _nearbyHint, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 112),
              child: FilledButton(
                key: const ValueKey('nearby-location-action'),
                onPressed: loading ? null : onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(112, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  backgroundColor: _nearbyPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyContent extends StatelessWidget {
  const _NearbyContent({
    required this.controller,
    required this.scrollController,
    required this.onAddFriend,
  });

  final NearbyController controller;
  final ScrollController scrollController;
  final ValueChanged<NearbyUser> onAddFriend;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const ValueKey('nearby-user-list'),
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (controller.errorMessage != null)
            SliverToBoxAdapter(
              child: Container(
                key: const ValueKey('nearby-inline-error'),
                color: const Color(0xFFFFF1F2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  controller.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFBE123C),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          if (controller.users.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: Icons.people_outline,
                title: '附近暂无用户',
                description: '试试扩大搜索范围或稍后再来看看',
              ),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _nearbyPx(context, 16),
                _nearbyPx(context, 12),
                _nearbyPx(context, 16),
                _nearbyPx(context, 24),
              ),
              sliver: SliverList.separated(
                itemCount: controller.users.length,
                itemBuilder: (context, index) {
                  final user = controller.users[index];
                  return _NearbyUserCard(
                    user: user,
                    requestPending: controller.isFriendRequestPending(
                      user.userId,
                    ),
                    sending: controller.isSendingFriendRequest(user.userId),
                    canAddFriend: controller.sendFriendRequest != null,
                    onAddFriend: () => onAddFriend(user),
                  );
                },
                separatorBuilder: (_, _) =>
                    SizedBox(height: _nearbyPx(context, 16)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: Center(
                  child: controller.loadingMore
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          controller.hasMore ? '' : '没有更多了',
                          style: const TextStyle(
                            color: _nearbyHint,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NearbyLocationHeader extends StatelessWidget {
  const _NearbyLocationHeader({required this.controller});

  final NearbyController controller;

  @override
  Widget build(BuildContext context) {
    final locationText = switch (controller.currentLocation?.city) {
      final String city when city.trim().isNotEmpty => city,
      _ => '当前位置',
    };
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _nearbyPx(context, 16),
        vertical: _nearbyPx(context, 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: _nearbyPx(context, 36),
                color: _nearbyPrimary,
              ),
              SizedBox(width: _nearbyPx(context, 6)),
              Expanded(
                child: Text(
                  locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _nearbyInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _nearbyPx(context, 12)),
          Row(
            key: const ValueKey('nearby-distance-selector'),
            children: [
              for (
                var index = 0;
                index < NearbyDistanceRange.values.length;
                index++
              ) ...[
                if (index > 0) SizedBox(width: _nearbyPx(context, 12)),
                _NearbyDistanceButton(
                  distance: NearbyDistanceRange.values[index],
                  selected:
                      controller.selectedDistance ==
                      NearbyDistanceRange.values[index],
                  onPressed: controller.viewState == NearbyViewState.loading
                      ? null
                      : () => controller.selectDistance(
                          NearbyDistanceRange.values[index],
                        ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbyDistanceButton extends StatelessWidget {
  const _NearbyDistanceButton({
    required this.distance,
    required this.selected,
    required this.onPressed,
  });

  final NearbyDistanceRange distance;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _nearbyPrimary : const Color(0xFFF3F4F6),
      shape: StadiumBorder(
        side: BorderSide(color: selected ? _nearbyPrimary : Colors.transparent),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('nearby-distance-${distance.name}'),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _nearbyPx(context, 16),
            vertical: _nearbyPx(context, 8),
          ),
          child: Text(
            distance.label,
            style: TextStyle(
              color: selected ? Colors.white : _nearbyMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyUserCard extends StatelessWidget {
  const _NearbyUserCard({
    required this.user,
    required this.requestPending,
    required this.sending,
    required this.canAddFriend,
    required this.onAddFriend,
  });

  final NearbyUser user;
  final bool requestPending;
  final bool sending;
  final bool canAddFriend;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('nearby-user-${user.userId}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_nearbyPx(context, 12)),
        side: const BorderSide(color: _nearbyBorder, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(_nearbyPx(context, 16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NearbyAvatar(user: user),
            SizedBox(width: _nearbyPx(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _nearbyInk,
                          ),
                        ),
                      ),
                      SizedBox(width: _nearbyPx(context, 6)),
                      _NearbyDistanceBadge(distanceMeters: user.distanceMeters),
                    ],
                  ),
                  SizedBox(height: _nearbyPx(context, 6)),
                  Text(
                    formatNearbyLastActive(user.lastActiveAt),
                    style: const TextStyle(color: _nearbyHint, fontSize: 12),
                  ),
                  if (user.signature != null) ...[
                    SizedBox(height: _nearbyPx(context, 6)),
                    Text(
                      user.signature!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _nearbyMuted, fontSize: 12),
                    ),
                  ],
                  if (user.petTypes.isNotEmpty) ...[
                    SizedBox(height: _nearbyPx(context, 8)),
                    Wrap(
                      spacing: _nearbyPx(context, 8),
                      runSpacing: _nearbyPx(context, 8),
                      children: [
                        for (final petType in user.petTypes.take(3))
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: _nearbyPx(context, 8),
                              vertical: _nearbyPx(context, 4),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(
                                _nearbyPx(context, 8),
                              ),
                            ),
                            child: Text(
                              petType,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _nearbyMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: _nearbyPx(context, 12)),
            _FriendAction(
              user: user,
              requestPending: requestPending,
              sending: sending,
              canAddFriend: canAddFriend,
              onPressed: onAddFriend,
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyAvatar extends StatelessWidget {
  const _NearbyAvatar({required this.user});

  final NearbyUser user;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveAssetUrl(user.avatarUrl);
    final size = _nearbyPx(context, 96);
    final fallback = Image.asset(
      'assets/images/health/pet_avatar.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? fallback
          : Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _NearbyDistanceBadge extends StatelessWidget {
  const _NearbyDistanceBadge({required this.distanceMeters});

  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _nearbyPx(context, 8),
        vertical: _nearbyPx(context, 4),
      ),
      decoration: BoxDecoration(
        color: _nearbyPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_nearbyPx(context, 12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: _nearbyPx(context, 28),
            color: _nearbyPrimary,
          ),
          SizedBox(width: _nearbyPx(context, 4)),
          Text(
            formatNearbyDistance(distanceMeters),
            style: const TextStyle(
              color: _nearbyPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendAction extends StatelessWidget {
  const _FriendAction({
    required this.user,
    required this.requestPending,
    required this.sending,
    required this.canAddFriend,
    required this.onPressed,
  });

  final NearbyUser user;
  final bool requestPending;
  final bool sending;
  final bool canAddFriend;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (user.isFriend || requestPending) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: _nearbyPx(context, 12),
          vertical: _nearbyPx(context, 8),
        ),
        decoration: BoxDecoration(
          color: requestPending
              ? const Color(0xFFEEF2FF)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(_nearbyPx(context, 8)),
        ),
        child: Text(
          user.isFriend ? '已是好友' : '申请已发送',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: user.isFriend ? _nearbyHint : const Color(0xFF4F46E5),
            fontWeight: requestPending ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 76, minHeight: 34),
      child: OutlinedButton.icon(
        key: ValueKey('nearby-add-friend-${user.userId}'),
        onPressed: canAddFriend && !sending ? onPressed : null,
        icon: sending
            ? const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_outlined, size: 17),
        label: const Text('加好友'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _nearbyPrimary,
          side: const BorderSide(color: _nearbyPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _nearbyHint, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

String formatNearbyDistance(double distanceMeters) {
  if (distanceMeters < 1000) return '${distanceMeters.round()}m';
  return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
}

String formatNearbyLastActive(DateTime? lastActiveAt, {DateTime? now}) {
  if (lastActiveAt == null) return '活跃时间未知';
  final reference = now ?? DateTime.now();
  final localTime = lastActiveAt.toLocal();
  final difference = reference.difference(localTime);
  if (difference.isNegative || difference.inMinutes < 1) return '刚刚活跃';
  if (difference.inMinutes < 60) return '${difference.inMinutes}分钟前活跃';
  if (difference.inHours < 24) return '${difference.inHours}小时前活跃';
  if (difference.inDays < 7) return '${difference.inDays}天前活跃';
  return '${localTime.year}-${_twoDigits(localTime.month)}-${_twoDigits(localTime.day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
