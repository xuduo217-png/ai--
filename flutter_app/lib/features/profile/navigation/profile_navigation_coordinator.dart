import 'package:flutter/material.dart';

import '../../../core/platform/external_uri_launcher.dart';
import '../../appointments/presentation/pages/appointment_detail_page.dart';
import '../../community/presentation/pages/community_profile_page.dart';
import '../../community/presentation/pages/post_detail_page.dart';
import '../../health/presentation/pages/health_record_pages.dart';
import '../../mall/navigation/mall_navigation_coordinator.dart';
import '../../mall/order/domain/order_models.dart';
import 'profile_dependencies.dart';
import 'profile_routes.dart';

const profileDestinationUnavailableMessage = '当前页面暂不可用，请稍后再试';

abstract interface class ProfileNavigator {
  Future<void> openPets(BuildContext context);

  Future<void> openOrders(BuildContext context);

  Future<void> openSales(BuildContext context);

  Future<void> openMedicalOrders(BuildContext context);

  Future<void> openAddresses(BuildContext context);

  Future<void> openNotifications(BuildContext context);

  Future<void> openLostFoundPosts(BuildContext context);

  Future<void> openCommunityProfile(BuildContext context);

  Future<void> openCoupons(BuildContext context);

  Future<void> openFavorites(BuildContext context);

  Future<void> openPublishedProducts(BuildContext context);

  Future<void> openSettings(BuildContext context);

  Future<void> openWallet(BuildContext context);

  Future<void> openOrderDetail(BuildContext context, OrderRouteArgs args);

  Future<void> openNotificationAction(
    BuildContext context,
    ProfileNotificationAction action,
  );
}

class ProfileNavigationCoordinator implements ProfileNavigator {
  const ProfileNavigationCoordinator(this.dependencies);

  final ProfileDependencies dependencies;

  SecondHandOrderGateway? get orderActionGateway {
    final gateway = dependencies.mallNavigation.dependencies.orderGateway;
    return gateway is SecondHandOrderGateway
        ? gateway as SecondHandOrderGateway
        : null;
  }

  @override
  Future<void> openPets(BuildContext context) {
    return openDestination(context, const ProfilePetsDestination());
  }

  @override
  Future<void> openOrders(BuildContext context) {
    return openDestination(context, const ProfileOrdersDestination());
  }

  @override
  Future<void> openSales(BuildContext context) {
    return openDestination(context, const ProfileSalesDestination());
  }

  @override
  Future<void> openMedicalOrders(BuildContext context) {
    return openDestination(context, const ProfileMedicalOrdersDestination());
  }

  @override
  Future<void> openAddresses(BuildContext context) {
    return openDestination(context, const ProfileAddressesDestination());
  }

  @override
  Future<void> openNotifications(BuildContext context) {
    return openDestination(context, const ProfileNotificationsDestination());
  }

  @override
  Future<void> openLostFoundPosts(BuildContext context) {
    return openDestination(context, const ProfileLostFoundPostsDestination());
  }

  @override
  Future<void> openCommunityProfile(BuildContext context) {
    return openDestination(context, const ProfileCommunityDestination());
  }

  @override
  Future<void> openCoupons(BuildContext context) {
    return openDestination(context, const ProfileCouponsDestination());
  }

  @override
  Future<void> openFavorites(BuildContext context) {
    return openDestination(context, const ProfileFavoritesDestination());
  }

  @override
  Future<void> openPublishedProducts(BuildContext context) {
    return openDestination(
      context,
      const ProfilePublishedProductsDestination(),
    );
  }

  @override
  Future<void> openSettings(BuildContext context) {
    return openDestination(context, const ProfileSettingsDestination());
  }

  @override
  Future<void> openWallet(BuildContext context) {
    return openDestination(context, const ProfileWalletDestination());
  }

  @override
  Future<void> openOrderDetail(BuildContext context, OrderRouteArgs args) {
    return openDestination(context, ProfileOrderDetailDestination(args));
  }

  @override
  Future<void> openNotificationAction(
    BuildContext context,
    ProfileNotificationAction action,
  ) {
    return openDestination(
      context,
      parseProfileNotificationDestination(action),
    );
  }

  Future<void> openDestination(
    BuildContext context,
    ProfileDestination destination,
  ) async {
    switch (destination) {
      case final ProfileOwnedDestination ownedDestination:
        await _openOwned(context, ownedDestination);
      case ProfileOrdersDestination():
        await dependencies.mallNavigation.openOrders(
          context,
          authenticated: true,
          requestLogin: _authenticatedProfileLoginRequest(context),
        );
      case ProfileSalesDestination():
        await dependencies.mallNavigation.openOrders(
          context,
          authenticated: true,
          requestLogin: _authenticatedProfileLoginRequest(context),
          viewRole: OrderViewRole.seller,
        );
      case ProfileAddressesDestination():
        await dependencies.mallNavigation.openAddresses(
          context,
          authenticated: true,
          requestLogin: _authenticatedProfileLoginRequest(context),
        );
      case ProfileFavoritesDestination():
        await dependencies.mallNavigation.openFavorites(
          context,
          authenticated: true,
          requestLogin: _authenticatedProfileLoginRequest(context),
        );
      case ProfilePublishedProductsDestination():
        await dependencies.mallNavigation.openPublishedProducts(
          context,
          authenticated: true,
          requestLogin: _authenticatedProfileLoginRequest(context),
        );
      case ProfileOrderDetailDestination(:final args):
        await dependencies.mallNavigation.openOrderDetail(
          context,
          args,
          authenticated: true,
          requestLogin: _authenticatedProfileLoginRequest(context),
        );
      case ProfileAfterSaleDestination(:final args):
        await dependencies.mallNavigation.openAfterSale(
          context,
          args,
          authenticated: true,
          requestLogin: _authenticatedProfileLoginRequest(context),
        );
      case ProfileProductDestination(:final args):
        await dependencies.mallNavigation.openProduct(
          context,
          args,
          authenticated: true,
          requestLogin: _authenticatedProfileLoginRequest(context),
        );
      case ProfileAppointmentDestination(:final appointmentId):
        final gateway = dependencies.appointmentGateway;
        if (gateway == null) {
          _showFeedback(context, profileDestinationUnavailableMessage);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AppointmentDetailPage(
              gateway: gateway,
              appointmentId: appointmentId,
            ),
          ),
        );
      case ProfileHealthAppointmentDestination(:final appointmentId):
        final gateway = dependencies.healthGateway;
        if (gateway == null) {
          _showFeedback(context, profileDestinationUnavailableMessage);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => HealthRecordDetailPage(
              gateway: gateway,
              appointmentId: appointmentId,
            ),
          ),
        );
      case ProfileCommunityPostDestination(:final postId):
        final gateway = dependencies.communityGateway;
        if (gateway == null) {
          _showFeedback(context, profileDestinationUnavailableMessage);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => CommunityPostDetailPage(
              gateway: gateway,
              postId: postId,
              authenticated: true,
              currentUserId: dependencies.currentUserIdProvider?.call(),
              requestLogin: (_) async => false,
            ),
          ),
        );
      case ProfileCommunityUserDestination(:final userId):
        final gateway = dependencies.communityGateway;
        if (gateway == null) {
          _showFeedback(context, profileDestinationUnavailableMessage);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => CommunityProfilePage(
              gateway: gateway,
              userId: userId,
              authenticated: true,
              currentUserId: dependencies.currentUserIdProvider?.call(),
              requestLogin: (_) async => false,
            ),
          ),
        );
      case ProfileChatDestination(:final conversationId):
        final opened = await dependencies.notificationNavigationRuntime
            ?.openConsultation(conversationId);
        if (opened != true && context.mounted) {
          _showFeedback(context, profileDestinationUnavailableMessage);
        }
      case ProfileUrlDestination(:final url):
        final launcher = dependencies.externalUriLauncher;
        final baseUrl = dependencies.contentBaseUrl;
        final uri = baseUrl == null
            ? null
            : resolveSafeWebUri(url, baseUrl: baseUrl);
        if (launcher == null || uri == null || !await launcher.launch(uri)) {
          if (context.mounted) {
            _showFeedback(context, profileUnsupportedDestinationMessage);
          }
        }
      case ProfileHomeDestination():
        Navigator.of(context).popUntil((route) => route.isFirst);
      case ProfileNoActionDestination():
        return;
      case ProfileUnsupportedDestination():
        _showFeedback(context, profileUnsupportedDestinationMessage);
    }
  }

  Future<void> _openOwned(
    BuildContext context,
    ProfileOwnedDestination destination,
  ) async {
    final pageFactory = dependencies.pageFactory;
    if (pageFactory == null) {
      _showFeedback(context, profileDestinationUnavailableMessage);
      return;
    }

    final page = pageFactory.buildPage(
      destination,
      onOrderDetail: (args) => openOrderDetail(context, args),
      onNotificationAction: (action) => openNotificationAction(context, action),
    );
    if (page == null) {
      _showFeedback(context, profileDestinationUnavailableMessage);
      return;
    }

    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  RequestMallLogin _authenticatedProfileLoginRequest(BuildContext context) {
    return (message) async {
      _showFeedback(context, message);
      return false;
    };
  }

  void _showFeedback(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
