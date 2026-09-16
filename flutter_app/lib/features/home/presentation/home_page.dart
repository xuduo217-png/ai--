import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../../../core/widgets/app_permission_dialog.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../activity/domain/activity_models.dart';
import '../../activity/presentation/pages/activity_detail_page.dart';
import '../../activity/presentation/pages/activity_list_page.dart';
import '../../agent/presentation/agent_home_view.dart';
import '../../agent/domain/agent_models.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/consultation_messaging_session.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/domain/consultation_conversation.dart';
import '../../chat/presentation/chat_controller.dart';
import '../../chat/presentation/chat_page.dart';
import '../../chat/presentation/consultation_conversation_list_view.dart';
import '../../charity/domain/charity_models.dart';
import '../../charity/presentation/charity_list_page.dart';
import '../../community/domain/community_models.dart';
import '../../community/presentation/pages/community_home_page.dart';
import '../../coupons/domain/coupon_models.dart';
import '../../coupons/presentation/pages/scanned_coupon_detail_page.dart';
import '../../doctors/domain/doctor_models.dart';
import '../../doctors/presentation/pages/doctor_detail_page.dart';
import '../../doctors/presentation/pages/doctor_list_page.dart';
import '../../emergency/domain/emergency_models.dart';
import '../../emergency/presentation/pages/emergency_center_page.dart';
import '../../friends/presentation/conversation_list_view.dart';
import '../../friends/friends_feature_session.dart';
import '../../friends/domain/friend_messaging_models.dart';
import '../../friends/presentation/friend_chat_page.dart';
import '../../health/domain/health_models.dart';
import '../../health/presentation/pages/ai_diagnosis_pages.dart';
import '../../health/presentation/pages/consultation_list_page.dart';
import '../../health/presentation/pages/health_page.dart';
import '../../lost_found/domain/lost_found_models.dart';
import '../../lost_found/presentation/pages/lost_found_list_page.dart';
import '../../mall/domain/mall_models.dart';
import '../../mall/catalog/domain/catalog_models.dart';
import '../../mall/navigation/mall_navigation_coordinator.dart';
import '../../mall/order/domain/order_models.dart';
import '../../mall/presentation/mall_controller.dart';
import '../../mall/presentation/mall_page.dart';
import '../../marketplace_chat/marketplace_chat_session.dart';
import '../../marketplace_chat/presentation/marketplace_conversation_list_view.dart';
import '../../marketplace_chat/presentation/messages_hub_view.dart';
import '../../nearby/data/nearby_location_service.dart';
import '../../nearby/domain/nearby_models.dart';
import '../../nearby/presentation/nearby_page.dart';
import '../../notifications/presentation/notification_badge_controller.dart';
import '../../profile/navigation/profile_navigation_coordinator.dart';
import '../../profile/presentation/pages/profile_page.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../scanner/presentation/qr_scanner_page.dart';
import '../domain/home_models.dart';
import 'home_controller.dart';

enum HomeTab { medical, mall, messages, friends, profile }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.gateway,
    required this.mallGateway,
    required this.authController,
    required this.session,
    required this.chatGateway,
    this.friendsSession,
    this.marketplaceSession,
    this.consultationSession,
    this.mallNavigation,
    this.profileNavigation,
    this.profileControllerFactory,
    this.notificationBadgeController,
    this.nearbyLocationGateway,
    this.initialTab = HomeTab.medical,
  }) : assert(
         profileNavigation == null || profileControllerFactory != null,
         'profileControllerFactory is required when profileNavigation is provided',
       ),
       guest = false;

  const HomePage.guest({
    super.key,
    required this.gateway,
    required this.mallGateway,
    this.mallNavigation,
    this.profileNavigation,
    this.initialTab = HomeTab.mall,
  }) : authController = null,
       session = null,
       chatGateway = null,
       friendsSession = null,
       marketplaceSession = null,
       consultationSession = null,
       profileControllerFactory = null,
       notificationBadgeController = null,
       nearbyLocationGateway = null,
       guest = true;

  final HomeGateway gateway;
  final MallGateway mallGateway;
  final AuthController? authController;
  final AuthSession? session;
  final ChatGateway? chatGateway;
  final FriendsFeatureSession? friendsSession;
  final MarketplaceChatSession? marketplaceSession;
  final ConsultationMessagingSession? consultationSession;
  final MallNavigationCoordinator? mallNavigation;
  final ProfileNavigator? profileNavigation;
  final ProfileControllerFactory? profileControllerFactory;
  final NotificationBadgeController? notificationBadgeController;
  final NearbyLocationGateway? nearbyLocationGateway;
  final HomeTab initialTab;
  final bool guest;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _accountTabs = {
    HomeTab.messages,
    HomeTab.friends,
    HomeTab.profile,
  };

  late final HomeController _controller;
  late final MallController _mallController;
  late final ProfileController? _profileController;
  late HomeTab _activeTab;
  AgentHomeContext? _agentHome;
  String? _agentSessionId;
  bool _routingAgentMessage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeTab = widget.guest && _accountTabs.contains(widget.initialTab)
        ? HomeTab.mall
        : widget.initialTab;
    _controller = HomeController(
      gateway: widget.gateway,
      authenticated: !widget.guest,
    );
    _mallController = MallController(
      gateway: widget.mallGateway,
      authenticated: !widget.guest,
    );
    _profileController =
        widget.guest ||
            widget.authController == null ||
            widget.profileControllerFactory == null
        ? null
        : widget.profileControllerFactory!(widget.authController!);
    _controller.load();
    _mallController.load();
    if (!widget.guest && widget.gateway is AgentGateway) {
      unawaited(_loadAgentHome());
    }
    unawaited(widget.friendsSession?.start());
    unawaited(widget.marketplaceSession?.start());
    unawaited(widget.consultationSession?.start());
    if (!widget.guest && widget.mallNavigation?.hasPendingDestination == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await widget.mallNavigation!.resumePending(
          context,
          requestLogin: _showLoginConfirm,
        );
        if (mounted) await _mallController.refresh();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final friendsSession = widget.friendsSession;
    if (friendsSession != null) unawaited(friendsSession.stop());
    final marketplaceSession = widget.marketplaceSession;
    if (marketplaceSession != null) unawaited(marketplaceSession.pause());
    final consultationSession = widget.consultationSession;
    if (consultationSession != null) unawaited(consultationSession.pause());
    _controller.dispose();
    _mallController.dispose();
    _profileController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.friendsSession?.resume());
      unawaited(widget.marketplaceSession?.resume());
      unawaited(widget.consultationSession?.resume());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // 后台大文件上传仍依赖消息 socket 完成最后的发送确认，不能在传输中
      // 主动 stop，否则 FriendsFeatureSession 会把本地 pending 消息标记为失败。
      if (widget.friendsSession?.hasActiveMediaTransfer != true) {
        unawaited(widget.friendsSession?.pause());
      }
      if (widget.marketplaceSession?.hasActiveMediaTransfer != true) {
        unawaited(widget.marketplaceSession?.pause());
      }
      unawaited(widget.consultationSession?.pause());
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsSession = widget.friendsSession;
    final friendsController = friendsSession?.messagingController;
    final marketplaceSession = widget.marketplaceSession;
    final marketplaceController = marketplaceSession?.controller;
    final consultationSession = widget.consultationSession;
    Widget buildScaffold() => Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Expanded(child: _buildTabContent()),
          HomeBottomBar(
            activeTab: _activeTab,
            onChanged: _changeTab,
            unreadMessageCount:
                (friendsController?.totalUnreadCount ?? 0) +
                (marketplaceController?.totalUnreadCount ?? 0) +
                (consultationSession?.totalUnreadCount ?? 0),
            pendingFriendRequestCount:
                friendsSession?.directoryController.pendingRequestCount ?? 0,
          ),
        ],
      ),
    );
    if (friendsController == null &&
        marketplaceController == null &&
        consultationSession == null) {
      return buildScaffold();
    }
    final listenables = <Listenable>[
      ?friendsController,
      ?friendsSession?.directoryController,
      ?marketplaceController,
      ?consultationSession,
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) => buildScaffold(),
    );
  }

  Widget _buildTabContent() {
    return switch (_activeTab) {
      HomeTab.medical => AgentHomeView(
        petName: _agentPetName,
        onPrompt: _handleAgentPrompt,
        onHealth: _openAiDiagnosisList,
        onShop: () => _changeTab(HomeTab.mall),
        onAppointment: _openHealth,
        onCommunity: _openCommunity,
      ),
      HomeTab.mall => MallHomeView(
        controller: _mallController,
        guest: widget.guest,
        onLoginRequired: _showLoginConfirm,
        onOpenFeature: _openFeature,
        onSearch: widget.mallNavigation == null ? null : _openMallSearch,
        onCart: widget.mallNavigation == null ? null : _openMallCart,
        onCategory: widget.mallNavigation == null ? null : _openMallCategory,
        onPopular: widget.mallNavigation == null ? null : _openMallPopular,
        onProduct: widget.mallNavigation == null ? null : _openMallProduct,
      ),
      HomeTab.messages =>
        widget.friendsSession != null &&
                widget.marketplaceSession != null &&
                widget.consultationSession != null
            ? MessagesHubView(
                friendsController: widget.friendsSession!.messagingController,
                marketplaceController: widget.marketplaceSession!.controller,
                consultationSession: widget.consultationSession!,
                onOpenConsultation: _openConsultationConversation,
                onOpenFriend: _openFriendConversation,
                onMarketplaceProductTap: widget.mallNavigation == null
                    ? null
                    : _openMarketplaceProduct,
              )
            : widget.marketplaceSession != null
            ? MarketplaceConversationListView(
                controller: widget.marketplaceSession!.controller,
                onProductTap: widget.mallNavigation == null
                    ? null
                    : _openMarketplaceProduct,
              )
            : widget.friendsSession == null
            ? widget.consultationSession == null
                  ? const _SecondaryTabView(
                      title: '消息',
                      icon: Icons.chat_bubble_outline_rounded,
                    )
                  : ConsultationConversationListView(
                      session: widget.consultationSession!,
                      onOpenConversation: _openConsultationConversation,
                    )
            : ConversationListView(
                controller: widget.friendsSession!.messagingController,
                onOpenConversation: _openFriendConversation,
              ),
      HomeTab.friends => _buildCommunityTab(),
      HomeTab.profile =>
        widget.profileNavigation != null && _profileController != null
            ? ProfilePage(
                controller: _profileController,
                navigator: widget.profileNavigation!,
                notificationUnreadCount: widget.notificationBadgeController,
              )
            : _SecondaryTabView(
                title: '我的',
                icon: Icons.person_outline_rounded,
                displayName: widget.session?.displayName,
                onLogout: widget.authController?.logout,
              ),
    };
  }

  void _changeTab(HomeTab tab) {
    if (widget.guest && _accountTabs.contains(tab)) {
      final featureName = switch (tab) {
        HomeTab.messages => '消息',
        HomeTab.friends => '好友',
        _ => '个人中心',
      };
      _showLoginConfirm('登录后即可使用$featureName功能');
      return;
    }
    setState(() => _activeTab = tab);
  }

  String get _agentPetName {
    final agentPetName = _agentHome?.primaryPet?.name.trim();
    if (agentPetName != null && agentPetName.isNotEmpty) return agentPetName;
    final profile = widget.session?.profile;
    final value = profile?['petName'] ?? profile?['defaultPetName'];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return '我的宠物';
  }

  Widget _buildCommunityTab() {
    final gateway = widget.gateway;
    if (gateway is! CommunityGateway) {
      return const _SecondaryTabView(
        title: '宠友',
        icon: Icons.people_alt_outlined,
      );
    }
    return CommunityHomePage(
      gateway: gateway as CommunityGateway,
      authenticated: !widget.guest,
      currentUserId: _currentUserId,
      currentUserAvatarUrl: _currentUserAvatarUrl,
      requestLogin: _showLoginConfirm,
      friendsSession: widget.friendsSession,
    );
  }

  Future<void> _loadAgentHome() async {
    final gateway = widget.gateway;
    if (gateway is! AgentGateway) return;
    final agentGateway = gateway as AgentGateway;
    try {
      final home = await agentGateway.loadAgentHome();
      if (mounted) {
        setState(() {
          _agentHome = home;
          _agentSessionId = home.activeSessionId;
        });
      }
    } on Object {
      // 首页其他正式模块仍可使用，Agent 请求时会显示明确错误。
    }
  }

  Future<void> _handleAgentPrompt(String prompt) async {
    if (_routingAgentMessage) return;
    final gateway = widget.gateway;
    if (widget.guest || gateway is! AgentGateway) {
      _showLoginConfirm('登录后即可使用小谷 Agent');
      return;
    }
    final agentGateway = gateway as AgentGateway;
    setState(() => _routingAgentMessage = true);
    try {
      final result = await agentGateway.routeAgentMessage(
        prompt,
        petId: _agentHome?.primaryPet?.id,
        sessionId: _agentSessionId,
      );
      if (!mounted) return;
      _agentSessionId = result.sessionId;
      switch (result.intent) {
        case AgentIntent.shop:
        case AgentIntent.order:
          _changeTab(HomeTab.mall);
        case AgentIntent.community:
          _openCommunity();
        case AgentIntent.appointment:
          _openHealth();
        case AgentIntent.health:
          _openAiDiagnosisList();
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('小谷暂时无法处理：$error')));
    } finally {
      if (mounted) setState(() => _routingAgentMessage = false);
    }
  }

  void _openFeature(String label, {bool loginRequired = false}) {
    if (label == '活动管理' || label == '查看全部活动') {
      _openActivities();
      return;
    }
    if (label == '走失领养') {
      _openLostFound();
      return;
    }
    if (label == '宠物社区') {
      _openCommunity();
      return;
    }
    if (label == '急救中心') {
      _openEmergencyCenter();
      return;
    }
    if (label == '金牌咨询') {
      _openDoctorList(goldOnly: true);
      return;
    }
    if (label == '查看全部医生') {
      _openDoctorList(goldOnly: false);
      return;
    }
    if (label == '二手商城' && widget.mallNavigation != null) {
      _openSecondHandMall();
      return;
    }
    if (widget.guest && loginRequired) {
      _showLoginConfirm('登录后即可使用该功能');
      return;
    }
    if (label == '附近') {
      _openNearby();
      return;
    }
    if (label == '公益中心') {
      _openCharity();
      return;
    }
    if (label == '营养师') {
      _openHealth();
      return;
    }
    if (label == 'AI 问诊记录') {
      _openAiDiagnosisList();
      return;
    }
    if (label == '查看全部历史咨询') {
      _openConsultationList();
      return;
    }
    if (label == '宠物档案' && widget.profileNavigation != null) {
      unawaited(widget.profileNavigation!.openPets(context));
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(label)));
  }

  // Kept for the legacy medical-home widget while the Agent migration lands.
  // ignore: unused_element
  void _openChat(HomeDoctor doctor) {
    _openChatTarget(
      doctorId: doctor.id,
      name: doctor.name,
      avatarUrl: doctor.avatarUrl,
    );
  }

  void _openDirectoryChat(DoctorProfile doctor) {
    _openChatTarget(
      doctorId: doctor.id,
      name: doctor.name,
      avatarUrl: doctor.avatarUrl,
    );
  }

  void _openChatTarget({
    required int doctorId,
    required String name,
    required String avatarUrl,
  }) {
    final session = widget.session;
    final gateway = widget.chatGateway;
    if (widget.guest || session == null || gateway == null) {
      _showLoginConfirm('登录后即可发起咨询');
      return;
    }
    final currentUserId = switch (session.profile['id']) {
      final int value => value,
      final num value => value.toInt(),
      final Object value => int.tryParse('$value') ?? 0,
      null => 0,
    };
    if (currentUserId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('账号信息不完整，请重新登录后重试')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          controller: ChatController(
            gateway: gateway,
            target: ChatTarget(
              doctorId: doctorId,
              name: name,
              avatarUrl: avatarUrl,
            ),
            currentUserId: currentUserId,
            currentUserAvatar: _currentUserAvatarUrl,
            accessToken: session.accessToken,
            consultationSession: widget.consultationSession,
          ),
        ),
      ),
    );
  }

  void _openConsultationConversation(ConsultationConversation conversation) {
    final session = widget.session;
    final gateway = widget.chatGateway;
    if (widget.guest || session == null || gateway == null) {
      _showLoginConfirm('登录后即可查看医生咨询');
      return;
    }
    final currentUserId = switch (session.profile['id']) {
      final int value => value,
      final num value => value.toInt(),
      final Object value => int.tryParse('$value') ?? 0,
      null => 0,
    };
    if (currentUserId <= 0 || conversation.doctorId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('咨询记录不完整，请稍后重试')));
      return;
    }

    unawaited(
      widget.consultationSession?.markConversationRead(
        conversation.conversationId,
      ),
    );
    final historyOrderId = conversation.status == ChatSessionStatus.expired
        ? conversation.orderId
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          controller: ChatController(
            gateway: gateway,
            target: ChatTarget(
              doctorId: conversation.doctorId,
              name: conversation.doctorName,
              avatarUrl: conversation.doctorAvatarUrl,
            ),
            currentUserId: currentUserId,
            currentUserAvatar: _currentUserAvatarUrl,
            accessToken: session.accessToken,
            historyOrderId: historyOrderId,
            viewOnly: historyOrderId != null,
            consultationSession: widget.consultationSession,
          ),
        ),
      ),
    );
  }

  void _openFriendConversation(FriendshipSummary friend) {
    final session = widget.friendsSession;
    if (session == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendChatPage(
          controller: session.createFriendChatController(friend),
        ),
      ),
    );
  }

  void _openDoctorList({required bool goldOnly}) {
    final gateway = widget.gateway;
    if (gateway is! DoctorDirectoryGateway) {
      _showFeatureUnavailable();
      return;
    }
    final doctorGateway = gateway as DoctorDirectoryGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorListPage(
          gateway: doctorGateway,
          goldOnly: goldOnly,
          onConsult: _openDirectoryChat,
          consultationGateway: widget.gateway is HealthGateway
              ? widget.gateway as HealthGateway
              : null,
          authenticated: !widget.guest,
          onOpenConsultation: _openHealthConsultation,
          onOpenAllConsultations: _openConsultationListForDoctor,
          onLoginRequired: _showLoginConfirm,
        ),
      ),
    );
  }

  void _openEmergencyCenter() {
    final gateway = widget.gateway;
    if (gateway is! EmergencyGateway) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('急救中心暂不可用，请稍后重试')));
      return;
    }
    final emergencyGateway = gateway as EmergencyGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyCenterPage(gateway: emergencyGateway),
      ),
    );
  }

  void _openHealth() {
    final gateway = widget.gateway;
    if (gateway is! HealthGateway) {
      _showHealthUnavailable();
      return;
    }
    final healthGateway = gateway as HealthGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthPage(
          gateway: healthGateway,
          onOpenPets: widget.profileNavigation == null
              ? null
              : () => widget.profileNavigation!.openPets(context),
        ),
      ),
    );
  }

  void _openNearby() {
    final gateway = widget.gateway;
    if (gateway is! NearbyGateway) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('附近服务暂不可用，请稍后重试')));
      return;
    }
    final nearbyGateway = gateway as NearbyGateway;
    final friendsSession = widget.friendsSession;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NearbyPage(
          gateway: nearbyGateway,
          locationGateway:
              widget.nearbyLocationGateway ??
              const MethodChannelNearbyLocationGateway(),
          sendFriendRequest: friendsSession == null
              ? null
              : ({required receiverId, required message}) =>
                    friendsSession.repository.sendFriendRequest(
                      receiverId: receiverId,
                      message: message,
                    ),
        ),
      ),
    );
  }

  void _openCharity() {
    final gateway = widget.gateway;
    if (gateway is! CharityGateway) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('公益中心暂不可用，请稍后重试')));
      return;
    }
    final charityGateway = gateway as CharityGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CharityListPage(
          gateway: charityGateway,
          authenticated: !widget.guest,
          requestLogin: _showLoginConfirm,
          paymentGateway: widget.mallNavigation?.dependencies.paymentGateway,
        ),
      ),
    );
  }

  void _openActivities() {
    final gateway = widget.gateway;
    if (gateway is! ActivityGateway) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('活动中心暂不可用，请稍后重试')));
      return;
    }
    final activityGateway = gateway as ActivityGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActivityListPage(
          gateway: activityGateway,
          authenticated: !widget.guest,
          currentUserId: _currentUserId,
          initialPhone: widget.session?.phone ?? '',
          requestLogin: _showLoginConfirm,
        ),
      ),
    );
  }

  // ignore: unused_element
  void _openHomeActivity(HomeActivity activity) {
    final gateway = widget.gateway;
    if (gateway is! ActivityGateway) {
      _openActivities();
      return;
    }
    final activityGateway = gateway as ActivityGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActivityDetailPage(
          gateway: activityGateway,
          activityId: activity.id,
          authenticated: !widget.guest,
          currentUserId: _currentUserId,
          initialPhone: widget.session?.phone ?? '',
          requestLogin: _showLoginConfirm,
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _openScanner() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => QrScannerPage(
          onCouponScanned: _openScannedCoupon,
          onActivityScanned: _openScannedActivity,
        ),
      ),
    );
  }

  Future<void> _openScannedCoupon(String claimCode) async {
    if (widget.guest) {
      await _showLoginConfirm('登录后即可查看并领取优惠券');
      return;
    }
    final scanGateway = switch (widget.gateway) {
      final CouponScanGateway gateway => gateway,
      _ => null,
    };
    if (scanGateway == null) {
      _showUnavailable('扫码优惠券暂不可用，请稍后重试');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScannedCouponDetailPage(
          gateway: scanGateway,
          claimCode: claimCode,
          onOpenMyCoupons: widget.profileNavigation == null
              ? null
              : () => widget.profileNavigation!.openCoupons(context),
        ),
      ),
    );
  }

  Future<void> _openScannedActivity(int activityId) async {
    final activityGateway = switch (widget.gateway) {
      final ActivityGateway gateway => gateway,
      _ => null,
    };
    if (activityGateway == null) {
      _showUnavailable('活动详情暂不可用，请稍后重试');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActivityDetailPage(
          gateway: activityGateway,
          activityId: activityId,
          authenticated: !widget.guest,
          currentUserId: _currentUserId,
          initialPhone: widget.session?.phone ?? '',
          requestLogin: _showLoginConfirm,
        ),
      ),
    );
  }

  int? get _currentUserId {
    final sessionId = widget.session?.profile['id'];
    return switch (sessionId) {
      final int value => value,
      final num value => value.toInt(),
      final Object value => int.tryParse('$value'),
      null => null,
    };
  }

  void _openLostFound() {
    final gateway = widget.gateway;
    if (gateway is! LostFoundGateway) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('走失领养暂不可用，请稍后重试')));
      return;
    }
    final sessionId = widget.session?.profile['id'];
    final currentUserId = switch (sessionId) {
      final int value => value,
      final num value => value.toInt(),
      final Object value => int.tryParse('$value'),
      null => null,
    };
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LostFoundListPage(
          gateway: gateway as LostFoundGateway,
          authenticated: !widget.guest,
          currentUserId: currentUserId,
          requestLogin: _showLoginConfirm,
        ),
      ),
    );
  }

  void _openCommunity() {
    final gateway = widget.gateway;
    if (gateway is! CommunityGateway) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('宠物社区暂不可用，请稍后重试')));
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityHomePage(
          gateway: gateway as CommunityGateway,
          authenticated: !widget.guest,
          currentUserId: _currentUserId,
          currentUserAvatarUrl: _currentUserAvatarUrl,
          requestLogin: _showLoginConfirm,
          friendsSession: widget.friendsSession,
        ),
      ),
    );
  }

  String get _currentUserAvatarUrl {
    final profile = widget.session?.profile;
    final value = profile?['avatar'] ?? profile?['avatarUrl'];
    return value is String ? value.trim() : '';
  }

  void _openAiDiagnosisList() {
    final gateway = widget.gateway;
    if (gateway is! HealthGateway) {
      _showHealthUnavailable();
      return;
    }
    final healthGateway = gateway as HealthGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AiDiagnosisListPage(
          gateway: healthGateway,
          onOpenPets: widget.profileNavigation == null
              ? null
              : () => widget.profileNavigation!.openPets(context),
        ),
      ),
    );
  }

  void _openConsultationList() {
    final gateway = widget.gateway;
    if (gateway is! HealthGateway) {
      _showHealthUnavailable();
      return;
    }
    final healthGateway = gateway as HealthGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConsultationListPage(
          gateway: healthGateway,
          onOpenConsultation: _openHealthConsultation,
        ),
      ),
    );
  }

  void _openConsultationListForDoctor(int doctorId) {
    final gateway = widget.gateway;
    if (gateway is! HealthGateway) {
      _showHealthUnavailable();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConsultationListPage(
          gateway: gateway as HealthGateway,
          doctorId: doctorId,
          onOpenConsultation: _openHealthConsultation,
        ),
      ),
    );
  }

  void _showHealthUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('营养师服务暂不可用，请稍后重试')));
  }

  // ignore: unused_element
  void _openDoctorDetail(HomeDoctor doctor) {
    final gateway = widget.gateway;
    if (gateway is! DoctorDirectoryGateway) {
      _showFeatureUnavailable();
      return;
    }
    final doctorGateway = gateway as DoctorDirectoryGateway;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorDetailPage(
          gateway: doctorGateway,
          doctorId: doctor.id,
          onConsult: _openDirectoryChat,
          consultationGateway: widget.gateway is HealthGateway
              ? widget.gateway as HealthGateway
              : null,
          authenticated: !widget.guest,
          onOpenConsultation: _openHealthConsultation,
          onOpenAllConsultations: () =>
              _openConsultationListForDoctor(doctor.id),
          onLoginRequired: _showLoginConfirm,
        ),
      ),
    );
  }

  void _showFeatureUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('医生服务暂不可用，请稍后重试')));
  }

  void _openHealthConsultation(HealthConsultation consultation) {
    final session = widget.session;
    final gateway = widget.chatGateway;
    if (widget.guest || session == null || gateway == null) {
      _showLoginConfirm('登录后即可查看历史咨询');
      return;
    }
    final currentUserId = switch (session.profile['id']) {
      final int value => value,
      final num value => value.toInt(),
      final Object value => int.tryParse('$value') ?? 0,
      null => 0,
    };
    if (currentUserId <= 0 ||
        consultation.doctorId <= 0 ||
        consultation.id <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('咨询记录不完整，请稍后重试')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          controller: ChatController(
            gateway: gateway,
            target: ChatTarget(
              doctorId: consultation.doctorId,
              name: consultation.doctorName,
              avatarUrl: consultation.doctorAvatarUrl,
            ),
            currentUserId: currentUserId,
            currentUserAvatar: _currentUserAvatarUrl,
            accessToken: session.accessToken,
            historyOrderId: consultation.id,
            viewOnly: !consultation.isActive,
            consultationSession: widget.consultationSession,
          ),
        ),
      ),
    );
  }

  Future<bool> _showLoginConfirm(String message) async {
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.person_outline_rounded),
        title: const Text('请先登录'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续浏览'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去登录'),
          ),
        ],
      ),
    );

    if (shouldLogin == true && mounted && widget.guest) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    return shouldLogin == true;
  }

  Future<void> _openMallSearch() async {
    final navigation = widget.mallNavigation;
    if (navigation == null) {
      _showUnavailable('商品搜索暂不可用，请稍后重试');
      return;
    }
    await navigation.openSearch(
      context,
      authenticated: !widget.guest,
      requestLogin: _showLoginConfirm,
    );
    await _refreshMallAfterRoute();
  }

  // ignore: unused_element
  Future<void> _openNotifications() async {
    if (widget.guest) {
      await _showLoginConfirm('登录后即可查看通知消息');
      return;
    }
    final navigation = widget.profileNavigation;
    if (navigation == null) {
      _showUnavailable('通知消息暂不可用，请稍后重试');
      return;
    }
    await navigation.openNotifications(context);
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openMallCart() async {
    await widget.mallNavigation?.openCart(
      context,
      authenticated: !widget.guest,
      requestLogin: _showLoginConfirm,
    );
    await _refreshMallAfterRoute();
  }

  Future<void> _openMallCategory(int categoryId) async {
    await widget.mallNavigation?.openCategories(
      context,
      CategoryBrowserRouteArgs(
        initialFirstCategoryId: categoryId > 0 ? categoryId : null,
      ),
      authenticated: !widget.guest,
      requestLogin: _showLoginConfirm,
    );
    await _refreshMallAfterRoute();
  }

  Future<void> _openMallPopular() async {
    await widget.mallNavigation?.openCatalog(
      context,
      const CatalogRouteArgs(title: '热门商品', popular: true),
      authenticated: !widget.guest,
      requestLogin: _showLoginConfirm,
    );
    await _refreshMallAfterRoute();
  }

  Future<void> _openMallProduct(int productId) async {
    await widget.mallNavigation?.openProduct(
      context,
      ProductRouteArgs(productId),
      authenticated: !widget.guest,
      requestLogin: _showLoginConfirm,
    );
    await _refreshMallAfterRoute();
  }

  Future<void> _openMarketplaceProduct(int productId) async {
    await widget.mallNavigation?.openProduct(
      context,
      ProductRouteArgs(productId, source: ProductSource.user),
      authenticated: !widget.guest,
      requestLogin: _showLoginConfirm,
    );
    await _refreshMallAfterRoute();
  }

  Future<void> _openSecondHandMall() async {
    await widget.mallNavigation?.openSecondHand(
      context,
      authenticated: !widget.guest,
      requestLogin: _showLoginConfirm,
    );
    await _refreshMallAfterRoute();
  }

  Future<void> _refreshMallAfterRoute() async {
    if (mounted && !widget.guest) await _mallController.refresh();
  }
}

class MedicalHomeView extends StatelessWidget {
  const MedicalHomeView({
    super.key,
    required this.controller,
    required this.guest,
    required this.onLoginRequired,
    required this.onOpenFeature,
    required this.onConsultDoctor,
    required this.onOpenDoctor,
    required this.onScan,
    required this.onSearch,
    required this.onNotification,
    this.notificationUnreadCount,
    this.onOpenActivity,
    this.homeImageUrl = '',
    this.onRefresh,
  });

  final HomeController controller;
  final String homeImageUrl;
  final Future<void> Function()? onRefresh;
  final bool guest;
  final ValueChanged<String> onLoginRequired;
  final void Function(String label, {bool loginRequired}) onOpenFeature;
  final ValueChanged<HomeDoctor> onConsultDoctor;
  final ValueChanged<HomeDoctor> onOpenDoctor;
  final VoidCallback onScan;
  final VoidCallback onSearch;
  final VoidCallback onNotification;
  final ValueListenable<int>? notificationUnreadCount;
  final ValueChanged<HomeActivity>? onOpenActivity;

  static const _features = <_HomeFeature>[
    _HomeFeature(
      keyName: 'pet-list',
      text: '宠物档案',
      icon: Icons.pets,
      color: Color(0xFF57C2AD),
      loginRequired: true,
    ),
    _HomeFeature(
      keyName: 'gold-doctor',
      text: '金牌咨询',
      icon: Icons.emoji_events,
      color: Color(0xFFE0B45A),
    ),
    _HomeFeature(
      keyName: 'emergency',
      text: '急救中心',
      icon: Icons.medical_services,
      color: Color(0xFFE78E86),
    ),
    _HomeFeature(
      keyName: 'health',
      text: '营养师',
      icon: Icons.monitor_heart,
      color: Color(0xFF9BA9FF),
      loginRequired: true,
    ),
    _HomeFeature(
      keyName: 'nearby',
      text: '附近',
      icon: Icons.place,
      color: Color(0xFF6BB7F3),
      loginRequired: true,
    ),
    _HomeFeature(
      keyName: 'charity',
      text: '公益中心',
      icon: Icons.volunteer_activism,
      color: Color(0xFFE0B45A),
    ),
    _HomeFeature(
      keyName: 'lost-found',
      text: '走失领养',
      icon: Icons.search,
      color: Color(0xFFE78E86),
    ),
    _HomeFeature(
      keyName: 'activity',
      text: '活动管理',
      icon: Icons.event,
      color: Color(0xFF57C2AD),
    ),
    _HomeFeature(
      keyName: 'community',
      text: '宠物社区',
      icon: Icons.forum,
      color: Color(0xFF6BB7F3),
    ),
    _HomeFeature(
      keyName: 'second-hand-mall',
      text: '二手商城',
      icon: Icons.storefront,
      color: Color(0xFF7E97FA),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: controller.loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7E97FA)),
                  )
                : Column(
                    children: [
                      _MedicalTopBar(
                        onSearch: onSearch,
                        onScan: onScan,
                        onNotification: onNotification,
                        notificationUnreadCount: notificationUnreadCount,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          color: const Color(0xFF7E97FA),
                          onRefresh: onRefresh ?? controller.refresh,
                          child: ListView(
                            key: const ValueKey('medical-home-scroll-view'),
                            padding: EdgeInsets.zero,
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              _AiBanner(
                                imageUrl: controller.snapshot.bannerImageUrl,
                                onTap: () {
                                  if (guest) {
                                    onLoginRequired('登录后即可查看 AI 问诊记录');
                                  } else {
                                    onOpenFeature('AI 问诊记录');
                                  }
                                },
                              ),
                              if (controller.snapshot.scrollingAnnouncement
                                  .trim()
                                  .isNotEmpty)
                                _ScrollingAnnouncementBanner(
                                  text:
                                      controller.snapshot.scrollingAnnouncement,
                                ),
                              _FeatureGrid(
                                features: _features,
                                iconUrls: controller.snapshot.menuIcons,
                                onTap: (feature) => onOpenFeature(
                                  feature.text,
                                  loginRequired: feature.loginRequired,
                                ),
                              ),
                              if (controller.snapshot.activities.isNotEmpty)
                                _ActivitySection(
                                  activities: controller.snapshot.activities,
                                  onOpenFeature: onOpenFeature,
                                  onOpenActivity: onOpenActivity,
                                ),
                              _DoctorSection(
                                doctors: controller.snapshot.doctors,
                                guest: guest,
                                onLoginRequired: onLoginRequired,
                                onOpenAll: () => onOpenFeature('查看全部医生'),
                                onOpenDoctor: onOpenDoctor,
                                onConsultDoctor: onConsultDoctor,
                              ),
                              if (homeImageUrl.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    20,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _HomePromotionImage(
                                      imageUrl: homeImageUrl.trim(),
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
        );
      },
    );
  }
}

class _HomePromotionImage extends StatefulWidget {
  const _HomePromotionImage({required this.imageUrl});

  final String imageUrl;

  @override
  State<_HomePromotionImage> createState() => _HomePromotionImageState();
}

class _HomePromotionImageState extends State<_HomePromotionImage> {
  static const _saveChannel = MethodChannel(
    'com.good.pet.hospital/activity_share_poster',
  );
  bool _saving = false;

  Future<void> _saveImage() async {
    if (_saving) return;
    _saving = true;
    // 固定本次长按的图片，避免确认期间首页刷新导致保存了另一张图。
    final provider = NetworkImage(widget.imageUrl);
    try {
      final confirmed = await showAppPermissionDialog(
        context: context,
        icon: Icons.photo_library_rounded,
        title: '保存首页图片',
        description: '需要相册写入权限，用于保存当前首页图片。',
        assurances: const ['只保存您当前长按的图片', '不会读取或上传您的相册内容'],
        confirmText: '允许保存',
        cancelText: '暂不需要',
        cancelButtonKey: const ValueKey('home-image-save-cancel'),
        confirmButtonKey: const ValueKey('home-image-save-confirm'),
      );
      if (!confirmed || !mounted) return;
      final stream = provider.resolve(createLocalImageConfiguration(context));
      final completer = Completer<ImageInfo>();
      final listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.clone());
        },
        onError: (Object error, StackTrace? stack) {
          if (!completer.isCompleted) completer.completeError(error, stack);
        },
      );
      stream.addListener(listener);
      ImageInfo? info;
      try {
        info = await completer.future.timeout(const Duration(seconds: 15));
        // 原生通道按 PNG 保存，不能直接传入 JPEG 等原始编码。
        final data = await info.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) throw StateError('图片转换失败');
        if (!mounted) return;
        final saved = await _saveChannel.invokeMethod<bool>('savePng', {
          'bytes': data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        });
        if (saved != true) throw StateError('保存失败');
        _showMessage('图片已保存到相册');
      } finally {
        stream.removeListener(listener);
        info?.dispose();
      }
    } on PlatformException catch (error) {
      _showMessage(error.message ?? '保存失败，请检查相册权限后重试');
    } catch (_) {
      _showMessage('保存失败，请检查相册权限后重试');
    } finally {
      _saving = false;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _saveImage,
      child: Image.network(
        widget.imageUrl,
        key: const ValueKey('medical-home-promotion-image'),
        width: double.infinity,
        fit: BoxFit.contain,
        semanticLabel: '首页展示图，长按保存到相册',
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _MedicalTopBar extends StatelessWidget {
  const _MedicalTopBar({
    required this.onSearch,
    required this.onScan,
    required this.onNotification,
    this.notificationUnreadCount,
  });

  final VoidCallback onSearch;
  final VoidCallback onScan;
  final VoidCallback onNotification;
  final ValueListenable<int>? notificationUnreadCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('medical-home-top-bar'),
      padding: EdgeInsets.fromLTRB(
        _s(context, 16),
        _s(context, 12),
        _s(context, 16),
        _s(context, 18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_s(context, 32)),
                side: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: _s(context, 1),
                ),
              ),
              child: InkWell(
                key: const ValueKey('medical-home-search-entry'),
                onTap: onSearch,
                borderRadius: BorderRadius.circular(_s(context, 32)),
                child: SizedBox(
                  height: _s(context, 85),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: _s(context, 16)),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: _s(context, 40),
                          color: const Color(0xFF9CA3AF),
                        ),
                        SizedBox(width: _s(context, 8)),
                        Text(
                          '热门搜索...',
                          style: TextStyle(
                            fontSize: _s(context, 30),
                            color: const Color(0xFF9CA3AF),
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: _s(context, 12)),
          _TopIconButton(
            key: const ValueKey('medical-home-scan-entry'),
            icon: Icons.qr_code_scanner,
            size: _s(context, 44),
            onTap: onScan,
            tooltip: '扫一扫',
          ),
          SizedBox(width: _s(context, 12)),
          if (notificationUnreadCount case final unreadCount?)
            ValueListenableBuilder<int>(
              valueListenable: unreadCount,
              builder: (context, count, _) => _NotificationTopButton(
                onTap: onNotification,
                hasUnread: count > 0,
              ),
            )
          else
            _NotificationTopButton(onTap: onNotification),
        ],
      ),
    );
  }
}

class _NotificationTopButton extends StatelessWidget {
  const _NotificationTopButton({required this.onTap, this.hasUnread = false});

  final VoidCallback onTap;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _TopIconButton(
          key: const ValueKey('medical-home-notification-entry'),
          icon: Icons.notifications_none,
          size: 28,
          color: const Color(0xFF1F2937),
          onTap: onTap,
          tooltip: '通知',
        ),
        if (hasUnread)
          Positioned(
            top: _s(context, 4),
            right: _s(context, 4),
            child: Container(
              key: const ValueKey('medical-home-notification-badge-dot'),
              width: _s(context, 20),
              height: _s(context, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF44336),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: _s(context, 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    super.key,
    required this.icon,
    required this.size,
    required this.onTap,
    required this.tooltip,
    this.color = const Color(0xFF4B5563),
  });

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: _s(context, 48),
          height: _s(context, 48),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.imageUrl, required this.onTap});

  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'AI 智能诊断',
      child: GestureDetector(
        key: const ValueKey('medical-home-ai-diagnosis-banner'),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: _s(context, 12)),
          color: const Color(0xFFF3F4F6),
          child: AspectRatio(
            aspectRatio: 1029 / 420,
            child: imageUrl.isEmpty
                ? Image.asset(
                    'assets/images/main/main_banner.jpg',
                    key: const ValueKey(
                      'medical-home-ai-diagnosis-banner-image',
                    ),
                    fit: BoxFit.contain,
                  )
                : Image.network(
                    imageUrl,
                    key: const ValueKey(
                      'medical-home-ai-diagnosis-banner-image',
                    ),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/images/main/main_banner.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScrollingAnnouncementBanner extends StatelessWidget {
  const _ScrollingAnnouncementBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('medical-home-scrolling-announcement'),
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        _s(context, 20),
        _s(context, 20),
        _s(context, 20),
        _s(context, 12),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _s(context, 24),
        vertical: _s(context, 18),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(_s(context, 16)),
        border: Border.all(color: const Color(0xFFDCE7FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(right: _s(context, 16)),
            child: Icon(
              Icons.volume_up_rounded,
              size: _s(context, 40),
              color: const Color(0xFF5B82F7),
            ),
          ),
          Expanded(child: _ScrollingAnnouncementText(text: text)),
        ],
      ),
    );
  }
}

class _ScrollingAnnouncementText extends StatefulWidget {
  const _ScrollingAnnouncementText({required this.text});

  final String text;

  @override
  State<_ScrollingAnnouncementText> createState() =>
      _ScrollingAnnouncementTextState();
}

class _ScrollingAnnouncementTextState
    extends State<_ScrollingAnnouncementText> {
  static const double _scrollSpeedPxPerSecond = 24;

  final ScrollController _scrollController = ScrollController();

  bool _shouldScroll = false;
  double _scrollTarget = 0;
  bool _scrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: _s(context, 28),
      color: const Color(0xFF36508F),
      height: 1.2,
      letterSpacing: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final textWidth = _measureTextWidth(context, style);
        final shouldScroll = textWidth > availableWidth;
        final gapWidth = _s(context, 56);
        final lineHeight = _s(context, 36);
        final scrollTarget = textWidth + gapWidth;

        if (shouldScroll != _shouldScroll || scrollTarget != _scrollTarget) {
          _shouldScroll = shouldScroll;
          _scrollTarget = scrollTarget;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            if (!_scrolling) {
              _scrollController.jumpTo(0);
              if (_shouldScroll) {
                unawaited(_runScrollAnimation());
              }
            } else if (!_shouldScroll) {
              _scrollController.jumpTo(0);
            }
          });
        } else if (!_scrolling && _shouldScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients || _scrolling) return;
            _scrollController.jumpTo(0);
            if (_shouldScroll) {
              unawaited(_runScrollAnimation());
            }
          });
        }

        if (!shouldScroll) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: style,
          );
        }

        return SizedBox(
          height: lineHeight,
          child: ClipRect(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: lineHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.text,
                      maxLines: 1,
                      softWrap: false,
                      style: style,
                    ),
                    SizedBox(width: gapWidth),
                    Text(
                      widget.text,
                      maxLines: 1,
                      softWrap: false,
                      style: style,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _runScrollAnimation() async {
    if (_scrolling || !_scrollController.hasClients || !_shouldScroll) {
      return;
    }
    _scrolling = true;
    try {
      while (mounted && _scrollController.hasClients && _shouldScroll) {
        final durationMs = (_scrollTarget / _scrollSpeedPxPerSecond * 1000)
            .round();
        await _scrollController.animateTo(
          _scrollTarget,
          duration: Duration(milliseconds: durationMs < 1 ? 1 : durationMs),
          curve: Curves.linear,
        );
        if (!mounted || !_scrollController.hasClients || !_shouldScroll) {
          break;
        }
        _scrollController.jumpTo(0);
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } catch (_) {
      // ignore animation cancellation
    } finally {
      _scrolling = false;
    }
  }

  double _measureTextWidth(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.features,
    required this.iconUrls,
    required this.onTap,
  });

  final List<_HomeFeature> features;
  final Map<String, String> iconUrls;
  final ValueChanged<_HomeFeature> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _s(context, 10),
        _s(context, 40),
        _s(context, 10),
        _s(context, 12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 5;
          return Wrap(
            children: [
              for (final feature in features)
                SizedBox(
                  width: itemWidth,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: _s(context, 20)),
                    child: InkWell(
                      key: ValueKey('medical-home-feature-${feature.keyName}'),
                      onTap: () => onTap(feature),
                      borderRadius: BorderRadius.circular(_s(context, 24)),
                      child: Column(
                        children: [
                          Container(
                            width: _s(context, 88),
                            height: _s(context, 88),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: feature.color,
                              borderRadius: BorderRadius.circular(
                                _s(context, 24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7E97FA,
                                  ).withValues(alpha: 0.08),
                                  offset: Offset(0, _s(context, 6)),
                                  blurRadius: _s(context, 12),
                                ),
                              ],
                            ),
                            child: _FeatureIcon(
                              imageUrl: iconUrls[feature.keyName] ?? '',
                              icon: feature.icon,
                            ),
                          ),
                          SizedBox(height: _s(context, 18)),
                          SizedBox(
                            width: itemWidth * 0.92,
                            child: Text(
                              feature.text,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _s(context, 26),
                                height: 32 / 26,
                                color: const Color(0xFF1F2937),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.imageUrl, required this.icon});

  final String imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(icon, size: _s(context, 48), color: Colors.white);
    if (imageUrl.isEmpty) {
      return fallback;
    }
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.activities,
    required this.onOpenFeature,
    this.onOpenActivity,
  });

  final List<HomeActivity> activities;
  final void Function(String label, {bool loginRequired}) onOpenFeature;
  final ValueChanged<HomeActivity>? onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final single = activities.length == 1;
    final cardWidth = single ? screenWidth - _s(context, 32) : _s(context, 560);

    return _HomeSection(
      title: '热门活动',
      onMore: () => onOpenFeature('查看全部活动'),
      horizontalContent: true,
      child: SizedBox(
        height: cardWidth / 2 + _s(context, 78),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: single ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.only(right: _s(context, 16)),
          itemCount: activities.length,
          separatorBuilder: (_, _) => SizedBox(width: _s(context, 12)),
          itemBuilder: (context, index) => SizedBox(
            width: cardWidth,
            child: _ActivityCard(
              activity: activities[index],
              onTap: () => onOpenActivity != null
                  ? onOpenActivity!(activities[index])
                  : onOpenFeature(activities[index].title),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onTap});

  final HomeActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = activity.activityType == 'ONLINE';
    final statusLabel = switch (activity.status) {
      'ONGOING' => '进行中',
      'EXPIRED' => '已结束',
      _ => '未开始',
    };
    final statusColor = switch (activity.status) {
      'ONGOING' => const Color(0xFF10B981),
      'EXPIRED' => const Color(0xFF9CA3AF),
      _ => const Color(0xFF7E97FA),
    };

    return Material(
      key: ValueKey('medical-home-hot-activity-card-${activity.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_s(context, 12)),
        side: BorderSide(color: const Color(0xFFEEF2FF), width: _s(context, 1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (activity.coverImageUrl.isNotEmpty)
                    Image.network(
                      activity.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _ActivityImageFallback(online: online),
                    )
                  else
                    _ActivityImageFallback(online: online),
                  Positioned(
                    top: _s(context, 10),
                    left: _s(context, 10),
                    child: _ActivityBadge(
                      text: online ? '线上活动' : '线下活动',
                      color: const Color(0xB8111827),
                    ),
                  ),
                  Positioned(
                    top: _s(context, 10),
                    right: _s(context, 10),
                    child: _ActivityBadge(
                      text: statusLabel,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _s(context, 14),
                vertical: _s(context, 16),
              ),
              child: Row(
                children: [
                  Container(
                    width: _s(context, 34),
                    height: _s(context, 34),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(_s(context, 8)),
                    ),
                    child: Icon(
                      online ? Icons.how_to_vote : Icons.event,
                      size: _s(context, 26),
                      color: const Color(0xFF7E97FA),
                    ),
                  ),
                  SizedBox(width: _s(context, 8)),
                  Expanded(
                    child: Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _s(context, 28),
                        height: 44 / 28,
                        color: const Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityImageFallback extends StatelessWidget {
  const _ActivityImageFallback({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF7E97FA),
      child: Icon(
        online ? Icons.how_to_vote : Icons.event,
        size: _s(context, 64),
        color: Colors.white,
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _s(context, 10),
        vertical: _s(context, 5),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: _s(context, 20),
          height: 26 / 20,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DoctorSection extends StatelessWidget {
  const _DoctorSection({
    required this.doctors,
    required this.guest,
    required this.onLoginRequired,
    required this.onOpenAll,
    required this.onOpenDoctor,
    required this.onConsultDoctor,
  });

  final List<HomeDoctor> doctors;
  final bool guest;
  final ValueChanged<String> onLoginRequired;
  final VoidCallback onOpenAll;
  final ValueChanged<HomeDoctor> onOpenDoctor;
  final ValueChanged<HomeDoctor> onConsultDoctor;

  @override
  Widget build(BuildContext context) {
    return _HomeSection(
      key: const ValueKey('medical-home-hot-doctor-section'),
      title: '热门医生',
      onMore: onOpenAll,
      child: Column(
        children: [
          for (final doctor in doctors)
            _DoctorCard(
              doctor: doctor,
              onTap: () => onOpenDoctor(doctor),
              onConsult: () {
                if (guest) {
                  onLoginRequired('登录后即可发起咨询');
                } else {
                  onConsultDoctor(doctor);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.onTap,
    required this.onConsult,
  });

  final HomeDoctor doctor;
  final VoidCallback onTap;
  final VoidCallback onConsult;

  @override
  Widget build(BuildContext context) {
    final experienceColor = doctor.experience >= 10
        ? const Color(0xFFF3E8FF)
        : doctor.experience >= 5
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFDBEAFE);
    final experienceTextColor = doctor.experience >= 10
        ? const Color(0xFF7C3AED)
        : doctor.experience >= 5
        ? const Color(0xFFD97706)
        : const Color(0xFF2563EB);

    return Padding(
      padding: EdgeInsets.only(bottom: _s(context, 16)),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(context, 12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(_s(context, 20)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(_s(context, 28)),
                  child: Container(
                    width: _s(context, 80),
                    height: _s(context, 80),
                    color: const Color(0xFFF3F4F6),
                    child: doctor.avatarUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            color: const Color(0xFF9CA3AF),
                            size: _s(context, 48),
                          )
                        : Image.network(
                            doctor.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.person,
                              color: const Color(0xFF9CA3AF),
                              size: _s(context, 48),
                            ),
                          ),
                  ),
                ),
                SizedBox(width: _s(context, 12)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: _s(context, 16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                doctor.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: _s(context, 28),
                                  color: const Color(0xFF1F2937),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: _s(context, 8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: _s(context, 8),
                                vertical: _s(context, 2),
                              ),
                              decoration: BoxDecoration(
                                color: experienceColor,
                                borderRadius: BorderRadius.circular(
                                  _s(context, 4),
                                ),
                              ),
                              child: Text(
                                '${doctor.experience}年经验',
                                style: TextStyle(
                                  fontSize: _s(context, 20),
                                  color: experienceTextColor,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            if (doctor.isGold)
                              Image.asset(
                                'assets/images/main/main_glod.png',
                                width: _s(context, 24),
                                height: _s(context, 24),
                                fit: BoxFit.contain,
                              ),
                          ],
                        ),
                        SizedBox(height: _s(context, 6)),
                        Text(
                          doctor.specialty,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _s(context, 24),
                            height: 32 / 24,
                            color: const Color(0xFF6B7280),
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          doctor.price,
                          style: TextStyle(
                            fontSize: _s(context, 28),
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(width: _s(context, 2)),
                        Text(
                          '/次',
                          style: TextStyle(
                            fontSize: _s(context, 22),
                            color: const Color(0xFF6B7280),
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: _s(context, 8)),
                    GestureDetector(
                      onTap: onConsult,
                      child: Container(
                        width: _s(context, 120),
                        height: _s(context, 44),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_s(context, 12)),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF7E97FA),
                              Color(0xFF6480F9),
                              Color(0xFF6481F9),
                            ],
                          ),
                        ),
                        child: Text(
                          '去咨询',
                          style: TextStyle(
                            fontSize: _s(context, 24),
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    super.key,
    required this.title,
    required this.onMore,
    required this.child,
    this.horizontalContent = false,
  });

  final String title;
  final VoidCallback onMore;
  final Widget child;
  final bool horizontalContent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _s(context, 16),
        _s(context, 16),
        horizontalContent ? 0 : _s(context, 16),
        _s(context, 12),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              right: horizontalContent ? _s(context, 16) : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _s(context, 32),
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                InkWell(
                  onTap: onMore,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: _s(context, 4)),
                    child: Row(
                      children: [
                        Text(
                          '查看全部',
                          style: TextStyle(
                            fontSize: _s(context, 24),
                            color: const Color(0xFF9CA3AF),
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(width: _s(context, 4)),
                        Icon(
                          Icons.chevron_right,
                          size: _s(context, 16),
                          color: const Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _s(context, 16)),
          child,
        ],
      ),
    );
  }
}

class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({
    super.key,
    required this.activeTab,
    required this.onChanged,
    this.unreadMessageCount = 0,
    this.pendingFriendRequestCount = 0,
  });

  final HomeTab activeTab;
  final ValueChanged<HomeTab> onChanged;
  final int unreadMessageCount;
  final int pendingFriendRequestCount;

  static const _items = <_BottomTabItem>[
    _BottomTabItem(HomeTab.medical, '小谷', Icons.auto_awesome_rounded),
    _BottomTabItem(HomeTab.messages, '消息', Icons.chat_bubble_outline),
    _BottomTabItem(HomeTab.friends, '宠友', Icons.people_alt_outlined),
    _BottomTabItem(HomeTab.profile, '我的', Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF7),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_s(context, 18)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F26332C),
            offset: Offset(0, -3),
            blurRadius: 18,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: _s(context, 8)),
          child: Row(
            children: [
              for (final item in _items)
                Expanded(
                  child: _BottomTabButton(
                    item: item,
                    selected: activeTab == item.tab,
                    badgeCount: item.tab == HomeTab.messages
                        ? unreadMessageCount
                        : item.tab == HomeTab.friends
                        ? pendingFriendRequestCount
                        : 0,
                    onTap: () => onChanged(item.tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTabButton extends StatelessWidget {
  const _BottomTabButton({
    required this.item,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final _BottomTabItem item;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF202F29) : const Color(0xFF929892);
    return InkWell(
      key: ValueKey('home-tab-${item.tab.name}'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _s(context, 4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              key: ValueKey('home-tab-${item.tab.name}-icon-slot'),
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox.square(
                  dimension: _s(context, 56),
                  child: Center(
                    child: Icon(item.icon, size: _s(context, 56), color: color),
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: _s(context, -8),
                    right: _s(context, -16),
                    child: Container(
                      width: badgeCount < 10 ? _s(context, 24) : null,
                      constraints: BoxConstraints(
                        minWidth: _s(context, badgeCount > 99 ? 32 : 24),
                      ),
                      height: _s(context, 24),
                      padding: badgeCount < 10
                          ? EdgeInsets.zero
                          : EdgeInsets.symmetric(horizontal: _s(context, 6)),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(_s(context, 12)),
                        border: Border.all(
                          color: Colors.white,
                          width: _s(context, 1),
                        ),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: _s(context, 12),
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: _s(context, 2)),
            Text(
              item.label,
              key: ValueKey('home-tab-${item.tab.name}-label'),
              style: TextStyle(
                fontSize: _s(context, 22),
                height: 1.15,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryTabView extends StatelessWidget {
  const _SecondaryTabView({
    required this.title,
    required this.icon,
    this.displayName,
    this.onLogout,
  });

  final String title;
  final IconData icon;
  final String? displayName;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF7E97FA)),
            const SizedBox(height: 12),
            Text(
              displayName?.isNotEmpty == true ? displayName! : title,
              style: const TextStyle(
                fontSize: 22,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            if (onLogout != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('退出登录'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeFeature {
  const _HomeFeature({
    required this.keyName,
    required this.text,
    required this.icon,
    required this.color,
    this.loginRequired = false,
  });

  final String keyName;
  final String text;
  final IconData icon;
  final Color color;
  final bool loginRequired;
}

class _BottomTabItem {
  const _BottomTabItem(this.tab, this.label, this.icon);

  final HomeTab tab;
  final String label;
  final IconData icon;
}

double _s(BuildContext context, num designPixels) {
  final size = MediaQuery.sizeOf(context);
  final referenceWidth = size.width < size.height ? size.width : size.height;
  return (designPixels * referenceWidth / 750).roundToDouble();
}
