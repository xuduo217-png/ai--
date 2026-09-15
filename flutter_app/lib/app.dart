import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/messaging/in_app_message_banner_controller.dart';
import 'core/messaging/in_app_message_event.dart';
import 'core/navigation/app_route_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/in_app_message_banner.dart';
import 'features/auth/domain/auth_models.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/consultation_messaging_session.dart';
import 'features/chat/domain/chat_models.dart';
import 'features/chat/presentation/chat_controller.dart';
import 'features/chat/presentation/chat_page.dart';
import 'features/doctor_portal/domain/doctor_portal_models.dart';
import 'features/doctor_portal/navigation/doctor_portal_navigation_runtime.dart';
import 'features/doctor_portal/presentation/doctor_home_page.dart';
import 'features/friends/friends_feature_session.dart';
import 'features/friends/domain/friend_messaging_models.dart';
import 'features/friends/presentation/friend_chat_page.dart';
import 'features/friends/presentation/friends_messaging_controller.dart';
import 'features/home/domain/home_models.dart';
import 'features/home/presentation/home_page.dart';
import 'features/home/presentation/home_placeholder_page.dart';
import 'features/mall/domain/mall_models.dart';
import 'features/mall/catalog/domain/catalog_models.dart';
import 'features/mall/navigation/mall_navigation_coordinator.dart';
import 'features/mall/order/domain/order_models.dart';
import 'features/marketplace_chat/marketplace_chat_session.dart';
import 'features/marketplace_chat/presentation/marketplace_chat_page.dart';
import 'features/notifications/presentation/notification_badge_controller.dart';
import 'features/notifications/navigation/notification_navigation_runtime.dart';
import 'features/profile/navigation/profile_navigation_coordinator.dart';
import 'features/profile/presentation/profile_controller.dart';

typedef FriendsFeatureSessionFactory =
    FriendsFeatureSession Function({
      required int ownerUserId,
      required SessionRevokedCallback onSessionRevoked,
    });

typedef MarketplaceChatSessionFactory =
    MarketplaceChatSession Function({
      required int ownerUserId,
      required Future<void> Function() onSessionRevoked,
    });

typedef ConsultationMessagingSessionFactory =
    ConsultationMessagingSession Function({
      required int ownerUserId,
      required Future<void> Function() onSessionRevoked,
    });

class PetHospitalApp extends StatefulWidget {
  const PetHospitalApp({
    super.key,
    required this.authController,
    required this.homeGateway,
    required this.mallGateway,
    required this.chatGateway,
    this.friendsSessionFactory,
    this.marketplaceSessionFactory,
    this.consultationSessionFactory,
    this.mallNavigation,
    this.profileNavigation,
    this.profileControllerFactory,
    this.notificationBadgeController,
    this.notificationNavigationRuntime,
    this.doctorPortalGateway,
    this.doctorRealtimeGatewayFactory,
  });

  final AuthController authController;
  final HomeGateway homeGateway;
  final MallGateway mallGateway;
  final ChatGateway chatGateway;
  final FriendsFeatureSessionFactory? friendsSessionFactory;
  final MarketplaceChatSessionFactory? marketplaceSessionFactory;
  final ConsultationMessagingSessionFactory? consultationSessionFactory;
  final MallNavigationCoordinator? mallNavigation;
  final ProfileNavigator? profileNavigation;
  final ProfileControllerFactory? profileControllerFactory;
  final NotificationBadgeController? notificationBadgeController;
  final NotificationNavigationRuntime? notificationNavigationRuntime;
  final DoctorPortalGateway? doctorPortalGateway;
  final DoctorRealtimeGatewayFactory? doctorRealtimeGatewayFactory;

  @override
  State<PetHospitalApp> createState() => _PetHospitalAppState();
}

class _PetHospitalAppState extends State<PetHospitalApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final InAppMessageBannerController _messageBannerController =
      InAppMessageBannerController();
  final DoctorPortalNavigationRuntime _doctorPortalNavigationRuntime =
      DoctorPortalNavigationRuntime();
  FriendsFeatureSession? _friendsSession;
  MarketplaceChatSession? _marketplaceSession;
  ConsultationMessagingSession? _consultationSession;
  FriendsFeatureSession? _boundFriendsSession;
  MarketplaceChatSession? _boundMarketplaceSession;
  ConsultationMessagingSession? _boundConsultationSession;
  StreamSubscription<InAppMessageEvent>? _friendsMessageSubscription;
  StreamSubscription<InAppMessageEvent>? _marketplaceMessageSubscription;
  StreamSubscription<InAppMessageEvent>? _consultationMessageSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authController.setLocalSessionInvalidator(_invalidateLocalSession);
    widget.authController.addListener(_handleAuthStateChanged);
    widget.notificationNavigationRuntime?.bindConsultationHandler(
      _openConsultationFromNotification,
    );
    _syncNotificationSession();
  }

  @override
  void didUpdateWidget(covariant PetHospitalApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authController != widget.authController) {
      oldWidget.authController.setLocalSessionInvalidator(null);
      oldWidget.authController.removeListener(_handleAuthStateChanged);
      widget.authController.setLocalSessionInvalidator(_invalidateLocalSession);
      widget.authController.addListener(_handleAuthStateChanged);
    }
    if (oldWidget.notificationBadgeController !=
        widget.notificationBadgeController) {
      oldWidget.notificationBadgeController?.deactivate();
    }
    if (oldWidget.notificationNavigationRuntime !=
        widget.notificationNavigationRuntime) {
      oldWidget.notificationNavigationRuntime?.unbindConsultationHandler();
      widget.notificationNavigationRuntime?.bindConsultationHandler(
        _openConsultationFromNotification,
      );
    }
    _syncNotificationSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.setLocalSessionInvalidator(null);
    widget.authController.removeListener(_handleAuthStateChanged);
    widget.notificationBadgeController?.deactivate();
    widget.notificationNavigationRuntime?.unbindConsultationHandler();
    _messageBannerController.dispose();
    unawaited(_friendsMessageSubscription?.cancel());
    unawaited(_marketplaceMessageSubscription?.cancel());
    unawaited(_consultationMessageSubscription?.cancel());
    final session = _friendsSession;
    _friendsSession = null;
    if (session != null) unawaited(session.close());
    final marketplaceSession = _marketplaceSession;
    _marketplaceSession = null;
    widget.mallNavigation?.setMarketplaceChatSession(null);
    if (marketplaceSession != null) unawaited(marketplaceSession.close());
    final consultationSession = _consultationSession;
    _consultationSession = null;
    if (consultationSession != null) unawaited(consultationSession.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [appRouteObserver],
      title: '谷德E宠',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      builder: (context, child) => InAppMessageOverlayHost(
        controller: _messageBannerController,
        onMessageTap: _openMessageFromBanner,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AnimatedBuilder(
        animation: widget.authController,
        builder: (context, _) {
          return switch (widget.authController.status) {
            AuthStatus.initializing => const SplashPage(),
            AuthStatus.unauthenticated => AuthPage(
              authController: widget.authController,
              homeGateway: widget.homeGateway,
              mallGateway: widget.mallGateway,
              mallNavigation: widget.mallNavigation,
              profileNavigation: widget.profileNavigation,
            ),
            AuthStatus.authenticated =>
              widget.authController.session!.accountType == AccountType.doctor
                  ? widget.doctorPortalGateway == null
                        ? HomePlaceholderPage(
                            authController: widget.authController,
                            session: widget.authController.session!,
                          )
                        : DoctorHomePage(
                            authController: widget.authController,
                            session: widget.authController.session!,
                            gateway: widget.doctorPortalGateway!,
                            chatGateway: widget.chatGateway,
                            realtimeGatewayFactory:
                                widget.doctorRealtimeGatewayFactory,
                            onIncomingMessage: _showDoctorMessageBanner,
                            messageNavigationRuntime:
                                _doctorPortalNavigationRuntime,
                          )
                  : HomePage(
                      gateway: widget.homeGateway,
                      mallGateway: widget.mallGateway,
                      authController: widget.authController,
                      session: widget.authController.session!,
                      chatGateway: widget.chatGateway,
                      friendsSession: _sessionFor(
                        widget.authController.session!,
                      ),
                      marketplaceSession: _marketplaceSessionFor(
                        widget.authController.session!,
                      ),
                      consultationSession: _consultationSessionFor(
                        widget.authController.session!,
                      ),
                      mallNavigation: widget.mallNavigation,
                      profileNavigation: widget.profileNavigation,
                      profileControllerFactory: widget.profileControllerFactory,
                      notificationBadgeController:
                          widget.notificationBadgeController,
                    ),
          };
        },
      ),
    );
  }

  FriendsFeatureSession? _sessionFor(AuthSession session) {
    final factory = widget.friendsSessionFactory;
    final ownerUserId = _sessionUserId(session);
    if (factory == null || ownerUserId <= 0) {
      _bindFriendsMessageEvents(null);
      return null;
    }
    final existing = _friendsSession;
    final currentUserAvatar = _sessionAvatar(session);
    if (existing?.ownerUserId == ownerUserId) {
      existing!.updateCurrentUserAvatar(currentUserAvatar);
      _bindFriendsMessageEvents(existing);
      return existing;
    }
    if (existing != null) unawaited(existing.close());
    final created = factory(
      ownerUserId: ownerUserId,
      onSessionRevoked: widget.authController.invalidateLocalSession,
    );
    created.updateCurrentUserAvatar(currentUserAvatar);
    _friendsSession = created;
    _bindFriendsMessageEvents(created);
    return created;
  }

  MarketplaceChatSession? _marketplaceSessionFor(AuthSession session) {
    final factory = widget.marketplaceSessionFactory;
    final ownerUserId = _sessionUserId(session);
    if (factory == null || ownerUserId <= 0) {
      _bindMarketplaceMessageEvents(null);
      return null;
    }
    final existing = _marketplaceSession;
    final currentUserAvatar = _sessionAvatar(session);
    if (existing?.ownerUserId == ownerUserId) {
      existing!.updateCurrentUserAvatar(currentUserAvatar);
      widget.mallNavigation?.setMarketplaceChatSession(existing);
      _bindMarketplaceMessageEvents(existing);
      return existing;
    }
    if (existing != null) unawaited(existing.close());
    final created = factory(
      ownerUserId: ownerUserId,
      onSessionRevoked: widget.authController.invalidateLocalSession,
    );
    created.updateCurrentUserAvatar(currentUserAvatar);
    _marketplaceSession = created;
    widget.mallNavigation?.setMarketplaceChatSession(created);
    _bindMarketplaceMessageEvents(created);
    return created;
  }

  ConsultationMessagingSession? _consultationSessionFor(AuthSession session) {
    final factory = widget.consultationSessionFactory;
    final ownerUserId = _sessionUserId(session);
    if (factory == null || ownerUserId <= 0) {
      _bindConsultationMessageEvents(null);
      return null;
    }
    final existing = _consultationSession;
    if (existing?.ownerUserId == ownerUserId) {
      _bindConsultationMessageEvents(existing);
      return existing;
    }
    if (existing != null) unawaited(existing.close());
    final created = factory(
      ownerUserId: ownerUserId,
      onSessionRevoked: widget.authController.invalidateLocalSession,
    );
    _consultationSession = created;
    _bindConsultationMessageEvents(created);
    return created;
  }

  Future<void> _invalidateLocalSession(AuthSession session) async {
    widget.notificationBadgeController?.deactivate();
    _messageBannerController.clear();
    final ownerUserId = _sessionUserId(session);
    final closeOperations = <Future<void>>[];
    final friendsSession = _friendsSession;
    if (friendsSession != null && friendsSession.ownerUserId == ownerUserId) {
      _friendsSession = null;
      _bindFriendsMessageEvents(null);
      closeOperations.add(friendsSession.close(clearLocalData: true));
    }
    final marketplaceSession = _marketplaceSession;
    if (marketplaceSession != null &&
        marketplaceSession.ownerUserId == ownerUserId) {
      _marketplaceSession = null;
      _bindMarketplaceMessageEvents(null);
      widget.mallNavigation?.setMarketplaceChatSession(null);
      closeOperations.add(marketplaceSession.close(clearLocalData: true));
    }
    final consultationSession = _consultationSession;
    if (consultationSession != null &&
        consultationSession.ownerUserId == ownerUserId) {
      _consultationSession = null;
      _bindConsultationMessageEvents(null);
      closeOperations.add(consultationSession.close());
    }
    await Future.wait(closeOperations);
  }

  void _handleAuthStateChanged() {
    _syncNotificationSession();
    if (widget.authController.status != AuthStatus.unauthenticated) return;
    _messageBannerController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.authController.status != AuthStatus.unauthenticated) {
        return;
      }
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _messageBannerController.clear();
    }
    final badgeController = widget.notificationBadgeController;
    if (badgeController == null) return;
    if (state == AppLifecycleState.resumed) {
      _syncNotificationSession();
      unawaited(badgeController.resume());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      badgeController.pause();
    }
  }

  void _syncNotificationSession() {
    final badgeController = widget.notificationBadgeController;
    if (badgeController == null) return;
    final session = widget.authController.session;
    if (widget.authController.status != AuthStatus.authenticated ||
        session == null ||
        session.accountType != AccountType.user) {
      badgeController.deactivate();
      return;
    }
    final ownerUserId = _sessionUserId(session);
    if (ownerUserId <= 0) {
      badgeController.deactivate();
      return;
    }
    unawaited(badgeController.start(ownerUserId));
  }

  void _bindFriendsMessageEvents(FriendsFeatureSession? session) {
    if (identical(_boundFriendsSession, session)) return;
    _boundFriendsSession = session;
    unawaited(_friendsMessageSubscription?.cancel());
    _friendsMessageSubscription = session
        ?.messagingController
        .incomingMessageEvents
        .listen((event) {
          if (!identical(_boundFriendsSession, session)) return;
          _showMessageBanner(event, session.ownerUserId);
        });
  }

  void _bindMarketplaceMessageEvents(MarketplaceChatSession? session) {
    if (identical(_boundMarketplaceSession, session)) return;
    _boundMarketplaceSession = session;
    unawaited(_marketplaceMessageSubscription?.cancel());
    _marketplaceMessageSubscription = session?.controller.incomingMessageEvents
        .listen((event) {
          if (!identical(_boundMarketplaceSession, session)) return;
          _showMessageBanner(event, session.ownerUserId);
        });
  }

  void _bindConsultationMessageEvents(ConsultationMessagingSession? session) {
    if (identical(_boundConsultationSession, session)) return;
    _boundConsultationSession = session;
    unawaited(_consultationMessageSubscription?.cancel());
    _consultationMessageSubscription = session?.incomingMessageEvents.listen((
      event,
    ) {
      if (!identical(_boundConsultationSession, session)) return;
      _showMessageBanner(event, session.ownerUserId);
    });
  }

  void _showMessageBanner(InAppMessageEvent event, int ownerUserId) {
    final authSession = widget.authController.session;
    if (widget.authController.status != AuthStatus.authenticated ||
        authSession == null ||
        authSession.accountType != AccountType.user ||
        _sessionUserId(authSession) != ownerUserId) {
      return;
    }

    final activeConversationId = switch (event.channel) {
      InAppMessageChannel.friend =>
        _friendsSession?.messagingController.activeConversationId,
      InAppMessageChannel.consultation =>
        _consultationSession?.activeConversationId,
      InAppMessageChannel.marketplace =>
        _marketplaceSession?.controller.activeConversationId,
    };
    if (activeConversationId == event.conversationId) return;
    _messageBannerController.show(event);
  }

  void _showDoctorMessageBanner(InAppMessageEvent event, int ownerDoctorId) {
    final authSession = widget.authController.session;
    if (widget.authController.status != AuthStatus.authenticated ||
        authSession == null ||
        authSession.accountType != AccountType.doctor ||
        _sessionUserId(authSession) != ownerDoctorId) {
      return;
    }
    _messageBannerController.show(event);
  }

  Future<void> _openMessageFromBanner(InAppMessageEvent event) async {
    final authSession = widget.authController.session;
    if (widget.authController.status != AuthStatus.authenticated ||
        authSession == null) {
      return;
    }
    try {
      if (authSession.accountType == AccountType.doctor) {
        if (event.channel != InAppMessageChannel.consultation) return;
        final opened = await _doctorPortalNavigationRuntime.openConsultation(
          event.conversationId,
        );
        if (!opened) _showMessageNavigationError();
        return;
      }
      switch (event.channel) {
        case InAppMessageChannel.friend:
          await _openFriendMessage(event);
          return;
        case InAppMessageChannel.consultation:
          await _openConsultationMessage(event, authSession);
          return;
        case InAppMessageChannel.marketplace:
          await _openMarketplaceMessage(event);
          return;
      }
    } on Object {
      _showMessageNavigationError();
    }
  }

  Future<void> _openFriendMessage(InAppMessageEvent event) async {
    final friendsSession = _friendsSession;
    final controller = friendsSession?.messagingController;
    final navigator = _navigatorKey.currentState;
    if (friendsSession == null || controller == null || navigator == null) {
      return;
    }
    if (controller.activeConversationId == event.conversationId) return;

    FriendshipSummary? friend;
    for (final conversation in controller.conversations) {
      if (conversation.conversationId == event.conversationId) {
        friend = controller.friendForConversation(conversation);
        break;
      }
    }
    final senderId = event.senderId ?? 0;
    friend ??= senderId > 0
        ? FriendshipSummary(
            friendId: senderId,
            friendName: event.title,
            friendAvatar: event.avatarUrl,
            serverConversationId: event.conversationId,
            lastChatAt: event.createdAt,
          )
        : null;
    if (friend == null) {
      _showMessageNavigationError();
      return;
    }
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => FriendChatPage(
          controller: friendsSession.createFriendChatController(friend!),
        ),
      ),
    );
  }

  Future<void> _openConsultationMessage(
    InAppMessageEvent event,
    AuthSession authSession,
  ) async {
    final opened = await _openConsultationConversation(
      event.conversationId,
      authSession,
    );
    if (!opened) _showMessageNavigationError();
  }

  Future<bool> _openConsultationFromNotification(String conversationId) async {
    final authSession = widget.authController.session;
    if (widget.authController.status != AuthStatus.authenticated ||
        authSession == null ||
        authSession.accountType != AccountType.user) {
      return false;
    }
    try {
      return await _openConsultationConversation(conversationId, authSession);
    } on Object {
      return false;
    }
  }

  Future<bool> _openConsultationConversation(
    String conversationId,
    AuthSession authSession,
  ) async {
    final consultationSession = _consultationSession;
    final navigator = _navigatorKey.currentState;
    if (consultationSession == null || navigator == null) return false;
    if (consultationSession.activeConversationId == conversationId) {
      return true;
    }
    final conversation = await consultationSession.resolveConversation(
      conversationId,
    );
    if (conversation == null || conversation.doctorId <= 0) {
      return false;
    }
    final currentUserId = _sessionUserId(authSession);
    if (currentUserId <= 0) {
      return false;
    }
    final historyOrderId = conversation.status == ChatSessionStatus.expired
        ? conversation.orderId
        : null;
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          controller: ChatController(
            gateway: widget.chatGateway,
            target: ChatTarget(
              doctorId: conversation.doctorId,
              name: conversation.doctorName,
              avatarUrl: conversation.doctorAvatarUrl,
            ),
            currentUserId: currentUserId,
            currentUserAvatar: _sessionAvatar(authSession) ?? '',
            accessToken: authSession.accessToken,
            historyOrderId: historyOrderId,
            viewOnly: historyOrderId != null,
            consultationSession: consultationSession,
          ),
        ),
      ),
    );
    return true;
  }

  Future<void> _openMarketplaceMessage(InAppMessageEvent event) async {
    final controller = _marketplaceSession?.controller;
    final navigator = _navigatorKey.currentState;
    if (controller == null || navigator == null) return;
    if (controller.activeConversationId == event.conversationId) return;
    final conversation = await controller.resolveConversation(
      event.conversationId,
    );
    if (conversation == null) {
      _showMessageNavigationError();
      return;
    }
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => MarketplaceChatPage(
          controller: controller,
          conversation: conversation,
          onProductTap: widget.mallNavigation == null
              ? null
              : (productId) => _openMarketplaceProduct(productId),
        ),
      ),
    );
  }

  void _showMessageNavigationError() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('会话信息加载失败，请从消息列表重试')));
  }

  Future<void> _openMarketplaceProduct(int productId) async {
    final context = _navigatorKey.currentContext;
    final navigation = widget.mallNavigation;
    if (context == null || navigation == null) return;
    await navigation.openProduct(
      context,
      ProductRouteArgs(productId, source: ProductSource.user),
      authenticated: true,
      requestLogin: (_) async => false,
    );
  }
}

int _sessionUserId(AuthSession session) {
  return switch (session.profile['id']) {
    final int value => value,
    final num value => value.toInt(),
    final Object value => int.tryParse('$value') ?? 0,
    null => 0,
  };
}

String? _sessionAvatar(AuthSession session) {
  final raw = session.profile['avatar'] ?? session.profile['avatarUrl'];
  final value = raw is String ? raw.trim() : '';
  return value.isEmpty ? null : value;
}
