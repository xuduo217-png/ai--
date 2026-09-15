import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/conversation_visibility_store.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/auth_storage.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/data/consultation_messaging_repository.dart';
import 'features/chat/data/consultation_realtime_socket_client.dart';
import 'features/chat/consultation_messaging_session.dart';
import 'features/doctor_portal/data/doctor_portal_repository.dart';
import 'features/friends/data/friends_database.dart';
import 'features/friends/data/friend_relations_repository.dart';
import 'features/friends/data/friends_local_store.dart';
import 'features/friends/data/friends_media_uploader.dart';
import 'features/friends/data/friends_repository.dart';
import 'features/friends/data/friends_socket_client.dart';
import 'features/friends/friends_feature_session.dart';
import 'features/friends/presentation/friends_directory_controller.dart';
import 'features/friends/presentation/friends_messaging_controller.dart';
import 'features/home/data/home_repository.dart';
import 'features/mall/data/mall_repository.dart';
import 'features/mall/navigation/mall_dependencies.dart';
import 'features/mall/navigation/mall_navigation_coordinator.dart';
import 'features/mall/payment/data/tobias_payment_gateway.dart';
import 'features/marketplace_chat/data/marketplace_chat_database.dart';
import 'features/marketplace_chat/data/marketplace_chat_local_store.dart';
import 'features/marketplace_chat/data/marketplace_chat_repository.dart';
import 'features/marketplace_chat/data/marketplace_chat_socket_client.dart';
import 'features/marketplace_chat/marketplace_chat_session.dart';
import 'features/marketplace_chat/presentation/marketplace_chat_controller.dart';
import 'features/profile/navigation/profile_dependencies.dart';
import 'features/profile/navigation/profile_navigation_coordinator.dart';
import 'features/profile/presentation/profile_controller.dart';
import 'features/notifications/navigation/notification_navigation_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authStorage = await AuthStorage.create();
  final apiClient = ApiClient(
    baseUrl: ApiConfig.baseUrl,
    client: http.Client(),
    tokenProvider: authStorage.readToken,
  );
  final authController = AuthController(
    gateway: AuthRepository(apiClient),
    sessionStore: authStorage,
  );
  final homeRepository = HomeRepository(apiClient);
  final mallRepository = MallRepository(apiClient);
  final paymentGateway = TobiasPaymentGateway();
  final mallNavigation = MallNavigationCoordinator(
    MallDependencies.production(apiClient, paymentGateway: paymentGateway),
  );
  final notificationNavigationRuntime = NotificationNavigationRuntime();
  final profileDependencies = ProfileDependencies.production(
    apiClient: apiClient,
    mallNavigation: mallNavigation,
    authController: authController,
    notificationNavigationRuntime: notificationNavigationRuntime,
    paymentGateway: paymentGateway,
  );
  final profileNavigation = ProfileNavigationCoordinator(profileDependencies);
  final chatRepository = ChatRepository(
    apiClient: apiClient,
    tokenProvider: authStorage.readToken,
    baseUrl: ApiConfig.baseUrl,
    paymentGateway: paymentGateway,
  );
  final friendsLocalStore = FriendsLocalStore(FriendsDatabase.production());
  final marketplaceLocalStore = MarketplaceChatLocalStore(
    MarketplaceChatDatabase.production(),
  );
  final conversationVisibilityStore = ConversationVisibilityStore();

  unawaited(authController.initialize());
  runApp(
    PetHospitalApp(
      authController: authController,
      homeGateway: homeRepository,
      mallGateway: mallRepository,
      chatGateway: chatRepository,
      doctorPortalGateway: DoctorPortalRepository(apiClient),
      doctorRealtimeGatewayFactory: () => ConsultationRealtimeSocketClient(
        baseUrl: ApiConfig.baseUrl,
        accessTokenProvider: authStorage.readToken,
      ),
      friendsSessionFactory:
          ({required ownerUserId, required onSessionRevoked}) {
            final socket = FriendsSocketClient(
              baseUrl: ApiConfig.baseUrl,
              accessTokenProvider: authStorage.readToken,
            );
            final relationsRepository = FriendRelationsRepository(
              apiClient: apiClient,
            );
            final messagingController = FriendsMessagingController(
              ownerUserId: ownerUserId,
              repository: FriendsRepository(apiClient: apiClient),
              localStore: friendsLocalStore,
              mediaUploader: FriendsMediaUploader(
                baseUrl: ApiConfig.baseUrl,
                tokenProvider: authStorage.readToken,
              ),
              socket: socket,
              onSessionRevoked: onSessionRevoked,
            );
            return FriendsFeatureSession(
              ownerUserId: ownerUserId,
              messagingController: messagingController,
              directoryController: FriendsDirectoryController(
                repository: relationsRepository,
                socket: socket,
              ),
              socket: socket,
              repository: relationsRepository,
            );
          },
      marketplaceSessionFactory:
          ({required ownerUserId, required onSessionRevoked}) {
            final socket = MarketplaceChatSocketClient(
              baseUrl: ApiConfig.baseUrl,
              accessTokenProvider: authStorage.readToken,
            );
            final messagingController = MarketplaceChatController(
              ownerUserId: ownerUserId,
              repository: MarketplaceChatRepository(apiClient),
              localStore: marketplaceLocalStore,
              mediaUploader: FriendsMediaUploader(
                baseUrl: ApiConfig.baseUrl,
                tokenProvider: authStorage.readToken,
              ),
              socket: socket,
              onSessionRevoked: onSessionRevoked,
              visibilityStore: conversationVisibilityStore,
            );
            return MarketplaceChatSession(
              ownerUserId: ownerUserId,
              controller: messagingController,
              socket: socket,
            );
          },
      consultationSessionFactory:
          ({required ownerUserId, required onSessionRevoked}) {
            return ConsultationMessagingSession(
              ownerUserId: ownerUserId,
              repository: ConsultationMessagingRepository(apiClient),
              socket: ConsultationRealtimeSocketClient(
                baseUrl: ApiConfig.baseUrl,
                accessTokenProvider: authStorage.readToken,
              ),
              onSessionRevoked: onSessionRevoked,
              visibilityStore: conversationVisibilityStore,
            );
          },
      mallNavigation: mallNavigation,
      profileNavigation: profileNavigation,
      notificationBadgeController:
          profileDependencies.notificationBadgeController,
      notificationNavigationRuntime: notificationNavigationRuntime,
      profileControllerFactory: (authController) => ProfileController(
        profileGateway: profileDependencies.profileGateway,
        walletGateway: profileDependencies.walletGateway,
        authController: authController,
      ),
    ),
  );
}
