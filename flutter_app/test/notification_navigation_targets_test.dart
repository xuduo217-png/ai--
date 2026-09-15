import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/core/platform/external_uri_launcher.dart';
import 'package:pet_hospital_flutter/features/appointments/data/appointment_repository.dart';
import 'package:pet_hospital_flutter/features/appointments/domain/appointment_models.dart';
import 'package:pet_hospital_flutter/features/appointments/presentation/pages/appointment_detail_page.dart';
import 'package:pet_hospital_flutter/features/community/domain/community_models.dart';
import 'package:pet_hospital_flutter/features/community/presentation/pages/community_profile_page.dart';
import 'package:pet_hospital_flutter/features/community/presentation/pages/post_detail_page.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/health_record_pages.dart';
import 'package:pet_hospital_flutter/features/mall/navigation/mall_dependencies.dart';
import 'package:pet_hospital_flutter/features/mall/navigation/mall_navigation_coordinator.dart';
import 'package:pet_hospital_flutter/features/notifications/navigation/notification_navigation_runtime.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_dependencies.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_navigation_coordinator.dart';
import 'package:pet_hospital_flutter/features/profile/navigation/profile_routes.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';

void main() {
  group('new notification destination protocol', () {
    test('distinguishes standard and health appointments', () {
      final standard = parseProfileNotificationDestination(
        const ProfileNotificationAction(
          actionType: 'appointment',
          actionData: {'appointmentId': 11, 'appointmentKind': 'standard'},
        ),
      );
      final health = parseProfileNotificationDestination(
        const ProfileNotificationAction(
          actionType: 'appointment',
          actionData: {'appointmentId': 12, 'appointmentKind': 'health'},
        ),
      );
      final legacy = parseProfileNotificationDestination(
        const ProfileNotificationAction(
          actionType: 'appointment',
          actionData: {'appointmentId': 13},
        ),
      );

      expect((standard as ProfileAppointmentDestination).appointmentId, 11);
      expect((health as ProfileHealthAppointmentDestination).appointmentId, 12);
      expect(legacy, isA<ProfileUnsupportedDestination>());
    });

    test('parses every new page target and external URL', () {
      final cases = <ProfileNotificationAction, Type>{
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {
            'path': 'PostDetail',
            'params': {'postId': 21},
          },
        ): ProfileCommunityPostDestination,
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {
            'path': 'UserProfile',
            'params': {'userId': 22},
          },
        ): ProfileCommunityUserDestination,
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {
            'path': 'Chat',
            'params': {'conversationId': 'consultation-23'},
          },
        ): ProfileChatDestination,
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {'path': 'Home'},
        ): ProfileHomeDestination,
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {'path': 'MyWallet'},
        ): ProfileWalletDestination,
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {'path': 'MyIncome'},
        ): ProfileWalletDestination,
        const ProfileNotificationAction(
          actionType: 'page',
          actionData: {
            'path': 'WalletWithdrawalDetail',
            'params': {'withdrawalId': 25},
          },
        ): ProfileWalletWithdrawalDetailDestination,
        const ProfileNotificationAction(
          actionType: 'url',
          actionData: {'url': 'https://example.test/news/24'},
        ): ProfileUrlDestination,
      };

      for (final entry in cases.entries) {
        expect(
          parseProfileNotificationDestination(entry.key).runtimeType,
          entry.value,
        );
      }
    });
  });

  test(
    'standard appointment repository loads and parses the detail endpoint',
    () async {
      Uri? requestedUri;
      final repository = AppointmentRepository(
        ApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            requestedUri = request.url;
            return http.Response(
              jsonEncode({
                'code': 0,
                'data': {
                  'id': 31,
                  'type': 'vaccine',
                  'status': 'confirmed',
                  'appointmentTime': '2026-08-01T02:30:00.000Z',
                  'symptoms': '精神不佳',
                  'pet': {'id': 5, 'name': '豆包'},
                  'hospital': {
                    'id': 6,
                    'name': '谷德宠物医院',
                    'address': '健康路 1 号',
                    'phone': '010-12345678',
                  },
                  'doctor': {'id': 7, 'name': '张医生', 'specialty': '内科'},
                },
              }),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }),
          tokenProvider: () async => 'token',
        ),
      );

      final appointment = await repository.loadAppointment(31);

      expect(requestedUri?.path, '/appointments/31');
      expect(appointment.status, AppointmentStatus.confirmed);
      expect(appointment.petName, '豆包');
      expect(appointment.doctorName, '张医生');
    },
  );

  testWidgets('coordinator opens appointment and community target pages', (
    tester,
  ) async {
    final coordinator = ProfileNavigationCoordinator(
      _dependencies(
        appointmentGateway: _AppointmentGateway(),
        healthGateway: _HealthGateway(),
        communityGateway: _CommunityGateway(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ListView(
              children: [
                _button(
                  'standard-appointment',
                  () => coordinator.openDestination(
                    context,
                    const ProfileAppointmentDestination(31),
                  ),
                ),
                _button(
                  'health-appointment',
                  () => coordinator.openDestination(
                    context,
                    const ProfileHealthAppointmentDestination(32),
                  ),
                ),
                _button(
                  'community-post',
                  () => coordinator.openDestination(
                    context,
                    const ProfileCommunityPostDestination(33),
                  ),
                ),
                _button(
                  'community-user',
                  () => coordinator.openDestination(
                    context,
                    const ProfileCommunityUserDestination(34),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final target in const [
      ('standard-appointment', AppointmentDetailPage),
      ('health-appointment', HealthRecordDetailPage),
      ('community-post', CommunityPostDetailPage),
      ('community-user', CommunityProfilePage),
    ]) {
      await tester.tap(find.byKey(ValueKey(target.$1)));
      await tester.pumpAndSettle();
      expect(find.byType(target.$2), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('coordinator delegates chat and safe web URL targets', (
    tester,
  ) async {
    final runtime = NotificationNavigationRuntime();
    final launcher = _ExternalUriLauncher();
    String? openedConversationId;
    runtime.bindConsultationHandler((conversationId) async {
      openedConversationId = conversationId;
      return true;
    });
    final coordinator = ProfileNavigationCoordinator(
      _dependencies(
        notificationNavigationRuntime: runtime,
        externalUriLauncher: launcher,
        contentBaseUrl: 'https://api.example.test',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                _button(
                  'chat',
                  () => coordinator.openDestination(
                    context,
                    const ProfileChatDestination('consultation-41'),
                  ),
                ),
                _button(
                  'url',
                  () => coordinator.openDestination(
                    context,
                    const ProfileUrlDestination('/news/42'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('chat')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('url')));
    await tester.pump();

    expect(openedConversationId, 'consultation-41');
    expect(launcher.openedUri, Uri.parse('https://api.example.test/news/42'));
  });
}

Widget _button(String key, Future<void> Function() onPressed) {
  return FilledButton(
    key: ValueKey(key),
    onPressed: () => unawaited(onPressed()),
    child: Text(key),
  );
}

ProfileDependencies _dependencies({
  AppointmentGateway? appointmentGateway,
  HealthGateway? healthGateway,
  CommunityGateway? communityGateway,
  NotificationNavigationRuntime? notificationNavigationRuntime,
  ExternalUriLauncher? externalUriLauncher,
  String? contentBaseUrl,
}) {
  return ProfileDependencies(
    profileGateway: _UnusedProfileGateway(),
    walletGateway: _UnusedWalletGateway(),
    mallNavigation: MallNavigationCoordinator(_UnusedMallDependencies()),
    appointmentGateway: appointmentGateway,
    healthGateway: healthGateway,
    communityGateway: communityGateway,
    notificationNavigationRuntime: notificationNavigationRuntime,
    externalUriLauncher: externalUriLauncher,
    contentBaseUrl: contentBaseUrl,
    currentUserIdProvider: () => 7,
  );
}

class _AppointmentGateway implements AppointmentGateway {
  @override
  Future<AppointmentDetail> loadAppointment(int appointmentId) async {
    return AppointmentDetail(
      id: appointmentId,
      type: AppointmentType.checkup,
      status: AppointmentStatus.confirmed,
      appointmentTime: DateTime(2026, 8, 1, 10, 30),
      petName: '豆包',
      hospitalName: '谷德宠物医院',
    );
  }
}

class _HealthGateway implements HealthGateway {
  @override
  Future<HealthAppointment> loadAppointment(int appointmentId) async {
    return HealthAppointment(
      id: appointmentId,
      type: HealthAppointmentType.vaccine,
      status: HealthAppointmentStatus.completed,
      appointmentDate: '2026-08-01',
      timeSlot: '10:30',
      petId: 5,
      hospitalId: 6,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CommunityGateway implements CommunityGateway {
  @override
  Future<CommunityPost> loadCommunityPost(
    int postId, {
    required bool authenticated,
  }) async {
    return CommunityPost.fromJson({
      'id': postId,
      'userId': 34,
      'content': '帖子内容',
      'user': {'id': 34, 'nickname': '社区用户'},
    });
  }

  @override
  Future<CommunityPage<CommunityComment>> loadCommunityComments(
    int postId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
  }) async {
    return CommunityPage(
      items: const [],
      total: 0,
      page: page,
      pageSize: pageSize,
      totalPages: 0,
    );
  }

  @override
  Future<CommunityProfile> loadCommunityProfile(
    int userId, {
    required bool authenticated,
  }) async {
    return CommunityProfile.fromJson({
      'user': {'id': userId, 'nickname': '社区用户'},
      'stats': const <String, Object?>{},
      'relationship': const <String, Object?>{},
    });
  }

  @override
  Future<List<CommunityPost>> loadCommunityUserPosts(
    int userId, {
    required bool authenticated,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExternalUriLauncher implements ExternalUriLauncher {
  Uri? openedUri;

  @override
  Future<bool> canLaunch(Uri uri) async => true;

  @override
  Future<bool> launch(Uri uri) async {
    openedUri = uri;
    return true;
  }
}

class _UnusedWalletGateway implements WalletSummaryGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedProfileGateway implements ProfileGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedMallDependencies implements MallDependencies {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
