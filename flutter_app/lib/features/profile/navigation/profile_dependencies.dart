import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../core/platform/external_uri_launcher.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../appointments/domain/appointment_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../community/data/community_repository.dart';
import '../../community/domain/community_models.dart';
import '../../community/presentation/pages/community_profile_page.dart';
import '../../coupons/data/coupon_repository.dart';
import '../../coupons/domain/coupon_models.dart';
import '../../coupons/presentation/pages/coupon_center_page.dart';
import '../../lost_found/data/lost_found_repository.dart';
import '../../lost_found/domain/lost_found_models.dart';
import '../../lost_found/presentation/pages/lost_found_list_page.dart';
import '../../health/data/health_repository.dart';
import '../../health/domain/health_models.dart';
import '../../mall/navigation/mall_navigation_coordinator.dart';
import '../../mall/order/domain/order_models.dart';
import '../../mall/payment/data/tobias_payment_gateway.dart';
import '../../mall/payment/domain/payment_models.dart';
import '../../medical_orders/data/medical_order_repository.dart';
import '../../medical_orders/domain/medical_order_models.dart';
import '../../medical_orders/presentation/pages/medical_order_page.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/domain/notification_models.dart';
import '../../notifications/presentation/notification_badge_controller.dart';
import '../../notifications/presentation/pages/notification_list_page.dart';
import '../../notifications/navigation/notification_navigation_runtime.dart';
import '../../pets/data/pet_repository.dart';
import '../../pets/domain/pet_models.dart';
import '../../pets/presentation/pages/pet_list_page.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/settings_models.dart';
import '../../settings/presentation/pages/settings_page.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_models.dart';
import '../../wallet/presentation/pages/wallet_page.dart';
import '../../wallet/presentation/pages/wallet_withdrawal_detail_page.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';
import 'profile_routes.dart';

typedef OpenProfileOrderDetail = Future<void> Function(OrderRouteArgs args);
typedef OpenProfileNotificationAction =
    Future<void> Function(ProfileNotificationAction action);

abstract interface class ProfilePageFactory {
  Widget? buildPage(
    ProfileOwnedDestination destination, {
    required OpenProfileOrderDetail onOrderDetail,
    required OpenProfileNotificationAction onNotificationAction,
  });
}

class ProfileDependencies {
  const ProfileDependencies({
    required this.profileGateway,
    required this.walletGateway,
    required this.mallNavigation,
    this.pageFactory,
    this.notificationGateway,
    this.notificationBadgeController,
    this.appointmentGateway,
    this.healthGateway,
    this.communityGateway,
    this.externalUriLauncher,
    this.contentBaseUrl,
    this.notificationNavigationRuntime,
    this.currentUserIdProvider,
  });

  factory ProfileDependencies.production({
    required ApiClient apiClient,
    required MallNavigationCoordinator mallNavigation,
    required AuthController authController,
    ProfilePageFactory? pageFactory,
    NotificationNavigationRuntime? notificationNavigationRuntime,
    PaymentGateway? paymentGateway,
    ExternalUriLauncher externalUriLauncher =
        const MethodChannelExternalUriLauncher(),
  }) {
    final walletGateway = WalletRepository(apiClient: apiClient);
    final profileGateway = ProfileRepository(apiClient: apiClient);
    final couponGateway = CouponRepository(apiClient: apiClient);
    final communityGateway = CommunityRepository(apiClient);
    final appointmentGateway = AppointmentRepository(apiClient);
    final healthGateway = HealthRepository(apiClient);
    final medicalOrderGateway = MedicalOrderRepository(apiClient: apiClient);
    final lostFoundGateway = LostFoundRepository(apiClient);
    final notificationGateway = NotificationRepository(apiClient: apiClient);
    final notificationBadgeController = NotificationBadgeController(
      gateway: notificationGateway,
    );
    final petGateway = PetRepository(apiClient: apiClient);
    final settingsGateway = SettingsRepository(apiClient: apiClient);
    final resolvedPaymentGateway = paymentGateway ?? TobiasPaymentGateway();
    return ProfileDependencies(
      profileGateway: profileGateway,
      walletGateway: walletGateway,
      mallNavigation: mallNavigation,
      notificationGateway: notificationGateway,
      notificationBadgeController: notificationBadgeController,
      appointmentGateway: appointmentGateway,
      healthGateway: healthGateway,
      communityGateway: communityGateway,
      externalUriLauncher: externalUriLauncher,
      contentBaseUrl: apiClient.baseUrl,
      notificationNavigationRuntime: notificationNavigationRuntime,
      currentUserIdProvider: () => _authUserId(authController),
      pageFactory:
          pageFactory ??
          _ProductionProfilePageFactory(
            walletGateway: walletGateway,
            paymentGateway: resolvedPaymentGateway,
            couponGateway: couponGateway,
            communityGateway: communityGateway,
            medicalOrderGateway: medicalOrderGateway,
            lostFoundGateway: lostFoundGateway,
            notificationGateway: notificationGateway,
            notificationBadgeController: notificationBadgeController,
            petGateway: petGateway,
            settingsGateway: settingsGateway,
            profileGateway: profileGateway,
            authController: authController,
            contentBaseUrl: apiClient.baseUrl,
          ),
    );
  }

  final ProfileGateway profileGateway;
  final WalletSummaryGateway walletGateway;
  final MallNavigationCoordinator mallNavigation;
  final ProfilePageFactory? pageFactory;
  final NotificationGateway? notificationGateway;
  final NotificationBadgeController? notificationBadgeController;
  final AppointmentGateway? appointmentGateway;
  final HealthGateway? healthGateway;
  final CommunityGateway? communityGateway;
  final ExternalUriLauncher? externalUriLauncher;
  final String? contentBaseUrl;
  final NotificationNavigationRuntime? notificationNavigationRuntime;
  final int? Function()? currentUserIdProvider;
}

class _ProductionProfilePageFactory implements ProfilePageFactory {
  const _ProductionProfilePageFactory({
    required WalletGateway walletGateway,
    required PaymentGateway paymentGateway,
    required CouponGateway couponGateway,
    required CommunityGateway communityGateway,
    required MedicalOrderGateway medicalOrderGateway,
    required LostFoundGateway lostFoundGateway,
    required NotificationGateway notificationGateway,
    required NotificationBadgeController notificationBadgeController,
    required PetGateway petGateway,
    required SettingsGateway settingsGateway,
    required ProfileGateway profileGateway,
    required AuthController authController,
    required String contentBaseUrl,
  }) : _walletGateway = walletGateway,
       _paymentGateway = paymentGateway,
       _couponGateway = couponGateway,
       _communityGateway = communityGateway,
       _medicalOrderGateway = medicalOrderGateway,
       _lostFoundGateway = lostFoundGateway,
       _notificationGateway = notificationGateway,
       _notificationBadgeController = notificationBadgeController,
       _petGateway = petGateway,
       _settingsGateway = settingsGateway,
       _profileGateway = profileGateway,
       _authController = authController,
       _contentBaseUrl = contentBaseUrl;

  final WalletGateway _walletGateway;
  final PaymentGateway _paymentGateway;
  final CouponGateway _couponGateway;
  final CommunityGateway _communityGateway;
  final MedicalOrderGateway _medicalOrderGateway;
  final LostFoundGateway _lostFoundGateway;
  final NotificationGateway _notificationGateway;
  final NotificationBadgeController _notificationBadgeController;
  final PetGateway _petGateway;
  final SettingsGateway _settingsGateway;
  final ProfileGateway _profileGateway;
  final AuthController _authController;
  final String _contentBaseUrl;

  @override
  Widget? buildPage(
    ProfileOwnedDestination destination, {
    required OpenProfileOrderDetail onOrderDetail,
    required OpenProfileNotificationAction onNotificationAction,
  }) {
    return switch (destination) {
      ProfilePetsDestination() => PetListPage(gateway: _petGateway),
      ProfileMedicalOrdersDestination() => MedicalOrderListPage(
        gateway: _medicalOrderGateway,
        assetBaseUrl: _contentBaseUrl,
      ),
      ProfileNotificationsDestination() => NotificationListPage(
        gateway: _notificationGateway,
        badgeController: _notificationBadgeController,
        onAction: (action) => onNotificationAction(
          ProfileNotificationAction(
            actionType: action.type.wireValue,
            actionData: action.data,
          ),
        ),
      ),
      ProfileLostFoundPostsDestination() => _buildLostFoundPostsPage(),
      ProfileCommunityDestination() => _buildCommunityProfilePage(),
      ProfileCouponsDestination() => CouponCenterPage(gateway: _couponGateway),
      ProfileWalletDestination() => WalletPage(
        gateway: _walletGateway,
        paymentGateway: _paymentGateway,
        onOrderDetail: (orderId) => onOrderDetail(OrderRouteArgs(orderId)),
      ),
      ProfileWalletWithdrawalDetailDestination(:final withdrawalId) =>
        WalletWithdrawalDetailPage(
          gateway: _walletGateway,
          withdrawalId: withdrawalId,
        ),
      ProfileSettingsDestination() => SettingsPage(
        settingsGateway: _settingsGateway,
        accountGateway: _profileGateway,
        authController: _authController,
        uriLauncher: const MethodChannelExternalUriLauncher(),
        contentBaseUrl: _contentBaseUrl,
      ),
    };
  }

  Widget? _buildLostFoundPostsPage() {
    final userId = _currentUserId;
    if (userId == null) return null;
    return LostFoundListPage(
      gateway: _lostFoundGateway,
      authenticated: true,
      currentUserId: userId,
      publisherId: userId,
      title: '我的发布',
    );
  }

  Widget? _buildCommunityProfilePage() {
    final userId = _currentUserId;
    if (userId == null) return null;
    return CommunityProfilePage(
      gateway: _communityGateway,
      userId: userId,
      authenticated: true,
      currentUserId: userId,
      requestLogin: (_) async => false,
    );
  }

  int? get _currentUserId {
    final value = _authController.session?.profile['id'];
    return switch (value) {
      final int id => id,
      final num id => id.toInt(),
      final Object id => int.tryParse('$id'),
      null => null,
    };
  }
}

int? _authUserId(AuthController authController) {
  final value = authController.session?.profile['id'];
  final parsed = switch (value) {
    final int id when id > 0 => id,
    final num id when id > 0 => id.toInt(),
    final Object id => int.tryParse('$id'),
    null => null,
  };
  return parsed != null && parsed > 0 ? parsed : null;
}
