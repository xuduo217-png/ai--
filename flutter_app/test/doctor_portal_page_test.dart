import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/messaging/in_app_message_banner_controller.dart';
import 'package:pet_hospital_flutter/core/messaging/in_app_message_event.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/core/widgets/in_app_message_banner.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/chat/data/chat_repository.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/chat/presentation/chat_controller.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/domain/doctor_portal_models.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/navigation/doctor_portal_navigation_runtime.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/presentation/doctor_home_page.dart';
import 'package:pet_hospital_flutter/features/doctor_portal/presentation/doctor_patient_record_page.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';
import 'package:pet_hospital_flutter/features/pets/presentation/pages/pet_page_chrome.dart';

void main() {
  testWidgets('医生工作台展示咨询、收入、我的三栏并复用 ChatPage', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authController = AuthController(
      gateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DoctorHomePage(
          authController: authController,
          session: _session,
          gateway: _DoctorGateway(),
          chatGateway: _ChatGateway(),
          connectChatRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('doctor-portal-background')),
    );
    final backgroundGradient =
        (background.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(backgroundGradient.colors, const [
      Color(0xFFDEE9FF),
      Color(0xFFFAFBFF),
    ]);

    expect(find.text('咨询管理'), findsOneWidget);
    expect(tester.widget<Text>(find.text('咨询管理')).style?.fontSize, 20);
    expect(find.text('及时处理用户的付费咨询'), findsNothing);
    expect(find.text('进行中'), findsNWidgets(2));
    expect(find.text('已过期'), findsOneWidget);
    expect(find.text('林女士'), findsOneWidget);
    expect(find.text('暂无消息'), findsOneWidget);
    expect(tester.widget<Text>(find.text('暂无消息')).style?.fontSize, 14);
    expect(find.text('在线复诊'), findsOneWidget);
    expect(find.text('咨询'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(tester.widget<Text>(find.text('收入')).style?.fontSize, 11);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('doctor-bottom-tab-bar')), findsOneWidget);

    final tabBar = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('doctor-bottom-tab-bar')),
    );
    final tabBarDecoration = tabBar.decoration as BoxDecoration;
    expect(tabBarDecoration.color, Colors.white);
    expect(
      tabBarDecoration.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(10),
        topRight: Radius.circular(10),
      ),
    );
    expect(tabBarDecoration.boxShadow?.single.offset, const Offset(0, -5));
    expect(tabBarDecoration.boxShadow?.single.blurRadius, 10);

    final consultationIconSlot = find.byKey(
      const ValueKey('doctor-tab-consultations-icon-slot'),
    );
    final consultationLabel = find.byKey(
      const ValueKey('doctor-tab-consultations-label'),
    );
    final incomeLabel = find.byKey(const ValueKey('doctor-tab-income-label'));
    expect(tester.getSize(consultationIconSlot), const Size.square(29));
    expect(
      tester.getTopLeft(consultationLabel).dy -
          tester.getBottomLeft(consultationIconSlot).dy,
      closeTo(1, 0.1),
    );
    final consultationLabelWidget = tester.widget<Text>(consultationLabel);
    expect(consultationLabelWidget.style?.fontSize, 11);
    expect(consultationLabelWidget.style?.height, 1.15);
    expect(consultationLabelWidget.style?.color, const Color(0xFF3B82F6));
    expect(
      tester.widget<Text>(incomeLabel).style?.color,
      const Color(0xFF6B7280),
    );

    await tester.tap(find.byKey(const ValueKey('doctor-consultation-4')));
    await tester.pumpAndSettle();

    expect(find.text('林女士'), findsOneWidget);
    expect(find.text('正在咨询'), findsOneWidget);
    expect(find.text('医生您好'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-composer')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-patient-record-entry')));
    await tester.pumpAndSettle();

    expect(find.text('用户健康档案'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('patient-record-background')),
      findsOneWidget,
    );
    expect(find.text('共 1 只宠物'), findsOneWidget);
    expect(find.text('团团'), findsOneWidget);
    expect(find.text('食欲下降'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('patient-history-entry')));
    await tester.pumpAndSettle();
    expect(find.text('历史咨询'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('patient-history-background')),
      findsOneWidget,
    );
    expect(find.text('首次咨询'), findsOneWidget);
    expect(find.text('呕吐两次'), findsOneWidget);
    expect(find.text('2 条'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('patient-history-2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('patient-history-detail-background')),
      findsOneWidget,
    );
    expect(find.text('用户：昨晚开始呕吐'), findsOneWidget);
    expect(find.text('医生：先暂停喂食两小时'), findsOneWidget);
    expect(
      tester.getCenter(find.text('用户：昨晚开始呕吐')).dx,
      lessThan(tester.getCenter(find.text('医生：先暂停喂食两小时')).dx),
    );
    expect(find.byKey(const ValueKey('chat-composer')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pet-page-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pet-page-back')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('patient-ai-report-9')),
    );
    await tester.tap(find.byKey(const ValueKey('patient-ai-report-9')));
    await tester.pumpAndSettle();
    expect(find.text('AI 问诊报告'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('patient-ai-report-background')),
      findsOneWidget,
    );
    expect(find.text('食欲下降'), findsOneWidget);
    expect(find.text('报告信息'), findsOneWidget);
    expect(find.text('报告描述'), findsOneWidget);
    expect(find.text('风险提示'), findsOneWidget);
    expect(find.text('西医诊断'), findsOneWidget);
    expect(find.text('用户悉知'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pet-page-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('健康概览'));
    await tester.pumpAndSettle();
    expect(find.text('3 针'), findsOneWidget);
    expect(find.text('2 次'), findsOneWidget);
    expect(find.text('1 次'), findsOneWidget);
    expect(find.text('接种计划正常'), findsOneWidget);

    await tester.tap(find.text('护理建议'));
    await tester.pumpAndSettle();
    expect(find.text('每周梳毛 2 次'), findsOneWidget);

    await tester.tap(find.text('健康档案'));
    await tester.pumpAndSettle();
    expect(find.text('谷德动物医院'), findsOneWidget);
    expect(find.text('2026-08-01  09:00-10:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('patient-appointment-6')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('patient-health-record-detail-background')),
      findsOneWidget,
    );
    expect(find.text('狂犬疫苗加强针接种'), findsOneWidget);
    expect(find.text('体温正常，已完成接种'), findsOneWidget);
    expect(find.text('接种后观察 30 分钟'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pet-page-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pet-page-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doctor-tab-income')));
    await tester.pumpAndSettle();

    expect(find.text('收入统计'), findsOneWidget);
    expect(find.text('总收入'), findsOneWidget);
    expect(find.text('¥520.50'), findsOneWidget);
    expect(find.text('已完成 18 次咨询'), findsOneWidget);
    expect(find.text('林女士 - 在线复诊'), findsOneWidget);
    expect(find.text('待结算'), findsOneWidget);
    expect(tester.widget<Text>(find.text('总收入')).style?.fontSize, 13);
    expect(tester.widget<Text>(find.text('¥520.50')).style?.fontSize, 28);
    expect(
      find.byKey(const ValueKey('doctor-income-overview')),
      findsOneWidget,
    );

    final incomeOverview = tester.widget<Container>(
      find.byKey(const ValueKey('doctor-income-overview')),
    );
    final incomeGradient =
        (incomeOverview.decoration as BoxDecoration).gradient!
            as LinearGradient;
    expect(incomeGradient.colors, const [
      Color(0xFF7E97FA),
      Color(0xFF6480F9),
      Color(0xFF6481F9),
    ]);
    expect(incomeOverview.constraints?.minHeight, 94);
    expect(incomeOverview.constraints?.maxHeight, double.infinity);

    await tester.tap(find.byKey(const ValueKey('doctor-tab-profile')));
    await tester.pumpAndSettle();

    expect(find.text('个人中心'), findsOneWidget);
    expect(find.text('张晶'), findsOneWidget);
    expect(find.text('谷德动物医院 · 内科'), findsOneWidget);
    expect(find.text('专长：犬猫内科、皮肤病'), findsOneWidget);
    expect(find.text('从业'), findsOneWidget);
    expect(find.text('8年'), findsOneWidget);
    expect(find.text('咨询'), findsNWidgets(2));
    expect(find.text('126人'), findsOneWidget);
    expect(find.text('执业中'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
    expect(find.byKey(const ValueKey('doctor-profile-card')), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(tester.widget<Text>(find.text('个人中心')).style?.fontSize, 20);
    expect(tester.widget<Text>(find.text('个人中心')).textAlign, TextAlign.center);

    final profileCard = tester.widget<Container>(
      find.byKey(const ValueKey('doctor-profile-card')),
    );
    final profileGradient =
        (profileCard.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(profileGradient.colors, const [Colors.white, Color(0xFFF9FAFB)]);

    await tester.tap(find.byKey(const ValueKey('doctor-online-switch')));
    await tester.pumpAndSettle();

    expect(find.text('谷德动物医院 · 内科'), findsOneWidget);
    expect(find.text('离线'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('医生聊天发送消息时使用用户作为 receiverId', () async {
    final doctorGateway = _DoctorGateway();
    final controller = ChatController(
      gateway: _ChatGateway(),
      target: const ChatTarget(doctorId: 7, name: '林女士', avatarUrl: ''),
      currentUserId: 7,
      accessToken: 'doctor-token',
      receiverId: 12,
      bootstrapLoader: ({required refresh}) => doctorGateway.loadDoctorChat(
        consultation: doctorGateway.consultation,
        doctorId: 7,
      ),
      connectRealtime: false,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    controller.sendText('请问宠物现在的状态如何？');

    expect(controller.messages.last.receiverId, 12);
  });

  testWidgets('医生咨询列表和底部咨询入口展示未读角标', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authController = AuthController(
      gateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.3),
          ),
          child: DoctorHomePage(
            authController: authController,
            session: _session,
            gateway: _DoctorGateway(unreadCount: 3),
            chatGateway: _ChatGateway(),
            connectChatRealtime: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardBadge = find.byKey(
      const ValueKey('doctor-consultation-unread-4'),
    );
    final tabBadge = find.byKey(
      const ValueKey('doctor-tab-consultations-unread-badge'),
    );
    expect(cardBadge, findsOneWidget);
    expect(tabBadge, findsOneWidget);
    expect(
      find.descendant(of: cardBadge, matching: find.text('3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBadge, matching: find.text('3')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('医生点击顶部消息提示后进入对应咨询', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authController = AuthController(
      gateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );
    final bannerController = InAppMessageBannerController();
    final navigationRuntime = DoctorPortalNavigationRuntime();
    addTearDown(bannerController.dispose);
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => InAppMessageOverlayHost(
          controller: bannerController,
          onMessageTap: (event) async {
            opened = await navigationRuntime.openConsultation(
              event.conversationId,
            );
          },
          child: child ?? const SizedBox.shrink(),
        ),
        home: DoctorHomePage(
          authController: authController,
          session: _session,
          gateway: _DoctorGateway(serviceEndAt: DateTime(2099)),
          chatGateway: _ChatGateway(),
          connectChatRealtime: false,
          messageNavigationRuntime: navigationRuntime,
        ),
      ),
    );
    await tester.pumpAndSettle();

    bannerController.show(
      InAppMessageEvent(
        eventKey: 'doctor-consultation:12_7:9',
        channel: InAppMessageChannel.consultation,
        conversationId: '12_7',
        senderId: 12,
        title: '林女士',
        preview: '宠物刚刚吐了',
        createdAt: DateTime(2026, 8, 15, 10),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('in-app-message-banner')), findsOneWidget);
    expect(find.text('宠物刚刚吐了'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('in-app-message-banner')));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.byKey(const ValueKey('chat-composer')), findsOneWidget);
    expect(find.text('林女士'), findsOneWidget);
    expect(find.text('医生您好'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('医生三栏在 320 宽度和 1.3 倍字体下无布局溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authController = AuthController(
      gateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.3),
          ),
          child: DoctorHomePage(
            authController: authController,
            session: _session,
            gateway: _DoctorGateway(),
            chatGateway: _ChatGateway(),
            connectChatRealtime: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('doctor-tab-income')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('doctor-tab-profile')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('用户健康档案在小屏和大字体下可切换全部视图', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _DoctorGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.3),
          ),
          child: DoctorPatientRecordPage(
            gateway: gateway,
            consultation: gateway.consultation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('食欲下降'), findsOneWidget);
    expect(find.byType(PetGradientBackground), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.labelColor, petPrimaryColor);
    expect(tabBar.dividerColor, Colors.transparent);
    expect(tester.takeException(), isNull);

    final patientTabs = find.byKey(const ValueKey('patient-record-tabs'));
    final initialTabsTop = tester.getTopLeft(patientTabs).dy;
    await tester.drag(
      find.byKey(const ValueKey('patient-record-scroll')),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    final pinnedTabsTop = tester.getTopLeft(patientTabs).dy;
    expect(pinnedTabsTop, lessThan(initialTabsTop));
    await tester.drag(
      find.byKey(const ValueKey('patient-record-scroll')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(patientTabs).dy, closeTo(pinnedTabsTop, 1));

    await tester.drag(
      find.byKey(const ValueKey('patient-record-scroll')),
      const Offset(0, 320),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(patientTabs).dy, greaterThan(pinnedTabsTop));

    await tester.tap(find.text('健康概览'));
    await tester.pumpAndSettle();
    expect(find.text('3 针'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('patient-health-metric-deworming')),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('patient-health-overview-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('2 次'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('patient-health-metric-checkup')),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('patient-health-overview-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('1 次'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('护理建议'));
    await tester.tap(find.text('护理建议'));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);
    await tester.scrollUntilVisible(
      find.text('每周梳毛 2 次'),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('patient-care-advice-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('每周梳毛 2 次'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('健康档案'));
    await tester.tap(find.text('健康档案'));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 3);
    expect(find.text('谷德动物医院'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('医生工作台三栏保持 RN 视觉基线', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authController = AuthController(
      gateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: DoctorHomePage(
          authController: authController,
          session: _session,
          gateway: _DoctorGateway(),
          chatGateway: _ChatGateway(),
          connectChatRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DoctorHomePage),
      matchesGoldenFile('goldens/doctor_portal_consultations.png'),
    );

    await tester.tap(find.byKey(const ValueKey('doctor-tab-income')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DoctorHomePage),
      matchesGoldenFile('goldens/doctor_portal_income.png'),
    );

    await tester.tap(find.byKey(const ValueKey('doctor-tab-profile')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DoctorHomePage),
      matchesGoldenFile('goldens/doctor_portal_profile.png'),
    );
  });
}

const _session = AuthSession(
  accessToken: 'doctor-token',
  accountType: AccountType.doctor,
  profile: {'id': 7, 'name': '张晶'},
);

class _DoctorGateway implements DoctorPortalGateway {
  _DoctorGateway({this.unreadCount = 0, DateTime? serviceEndAt})
    : consultation = DoctorConsultation(
        id: 4,
        conversationId: '12_7',
        userId: 12,
        userName: '林女士',
        userAvatarUrl: '',
        doctorId: 7,
        status: DoctorConsultationStatus.paid,
        orderId: 31,
        serviceItemName: '在线复诊',
        serviceStartAt: DateTime(2026, 7, 27, 8),
        serviceEndAt: serviceEndAt ?? DateTime(2026, 7, 28, 8),
        lastMessageAt: DateTime(2026, 7, 27, 9),
      );

  final int unreadCount;
  final DoctorConsultation consultation;

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Future<DoctorConsultationPage> loadConsultations({
    required int doctorId,
    required DoctorConsultationStatus status,
    int page = 1,
    int pageSize = 20,
  }) async => DoctorConsultationPage(
    items: [consultation.copyWith(unreadCount: unreadCount)],
    total: 1,
    page: 1,
    pageSize: 20,
    totalPages: 1,
    totalUnreadCount: unreadCount,
  );

  @override
  Future<DoctorIncomeSnapshot> loadIncome({
    int page = 1,
    int pageSize = 10,
  }) async => DoctorIncomeSnapshot(
    stats: const DoctorIncomeStats(
      today: 29.9,
      thisWeek: 80,
      thisMonth: 160,
      total: 520.5,
      consultationCount: 18,
    ),
    records: DoctorIncomePage(
      items: [
        DoctorIncomeRecord(
          id: '31',
          consultationId: 'CO20260727001',
          amount: 29.9,
          status: 'paid',
          createdAt: DateTime(2026, 7, 27, 8, 30),
          userName: '林女士',
          serviceName: '在线复诊',
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    ),
  );

  @override
  Future<DoctorIncomePage> loadIncomeRecords({
    required int page,
    int pageSize = 10,
  }) async => (await loadIncome()).records;

  @override
  Future<DoctorPortalProfile> loadProfile() async => _profile;

  @override
  Future<DoctorPortalProfile> updateOnlineStatus(bool online) async =>
      DoctorPortalProfile(
        id: _profile.id,
        name: _profile.name,
        phone: _profile.phone,
        avatarUrl: _profile.avatarUrl,
        specialty: _profile.specialty,
        experienceYears: _profile.experienceYears,
        consultationCount: _profile.consultationCount,
        isActive: _profile.isActive,
        isGoldDoctor: _profile.isGoldDoctor,
        isOnline: online,
        hospitalName: '',
        departmentName: '',
      );

  @override
  Future<ChatBootstrap> loadDoctorChat({
    required DoctorConsultation consultation,
    required int doctorId,
  }) async => ChatBootstrap(
    session: ChatSession(
      conversationId: consultation.conversationId,
      userId: consultation.userId,
      doctorId: doctorId,
      status: ChatSessionStatus.paid,
      serviceStartAt: consultation.serviceStartAt,
      serviceEndAt: consultation.serviceEndAt,
    ),
    canSend: true,
    messages: [
      ChatMessage(
        id: 8,
        conversationId: consultation.conversationId,
        senderId: consultation.userId,
        receiverId: doctorId,
        content: '医生您好',
        type: ChatMessageType.text,
        isAutoReply: false,
        isRead: false,
        createdAt: DateTime(2026, 7, 27, 9),
      ),
    ],
    doctorOnline: true,
    availablePackages: const [],
  );

  @override
  Future<DoctorPatientRecord> loadPatientRecord(String conversationId) async =>
      DoctorPatientRecord.fromJson({
        'user': {'id': 12, 'name': '林女士', 'avatar': ''},
        'petCount': 1,
        'pets': [
          {
            'id': 31,
            'name': '团团',
            'avatar': '',
            'ownerId': 12,
            'gender': 2,
            'birthDate': '2024-02-01',
            'weight': 4.2,
            'isNeutered': true,
            'vaccineCount': 3,
            'createdAt': '2024-02-01T00:00:00.000Z',
            'updatedAt': '2026-01-10T00:00:00.000Z',
            'vaccination': {
              'count': 3,
              'lastAt': '2026-01-10',
              'nextAt': '2027-01-10',
            },
            'healthStats': {
              'vaccine': {
                'count': 3,
                'lastAt': '2026-01-10',
                'nextAt': '2027-01-10',
              },
              'deworming': {
                'count': 2,
                'lastAt': '2026-06-01',
                'nextAt': '2026-09-01',
              },
              'checkup': {
                'count': 1,
                'lastAt': '2026-03-15',
                'nextAt': '2027-03-15',
              },
            },
          },
        ],
      });

  @override
  Future<DoctorHistoryPage> loadPatientHistory({
    required String conversationId,
    int page = 1,
    int pageSize = 20,
  }) async => DoctorHistoryPage(
    items: [
      DoctorHistorySession(
        id: 2,
        conversationId: 'history-1',
        status: DoctorConsultationStatus.expired,
        serviceItemName: '首次咨询',
        messageCount: 2,
        lastMessage: '呕吐两次',
        serviceStartAt: DateTime(2026, 7, 10, 9),
      ),
    ],
    total: 1,
    page: 1,
    pageSize: pageSize,
    totalPages: 1,
  );

  @override
  Future<DoctorHistoryMessagePage> loadPatientHistoryMessages({
    required String conversationId,
    required String historyConversationId,
    int page = 1,
    int pageSize = 50,
  }) async => DoctorHistoryMessagePage(
    items: [
      ChatMessage(
        id: 1,
        conversationId: historyConversationId,
        senderId: 7,
        senderType: 'user',
        receiverId: 7,
        receiverType: 'doctor',
        content: '用户：昨晚开始呕吐',
        type: ChatMessageType.text,
        isAutoReply: false,
        isRead: true,
        createdAt: DateTime(2026, 7, 10, 9),
      ),
      ChatMessage(
        id: 2,
        conversationId: historyConversationId,
        senderId: 7,
        senderType: 'doctor',
        receiverId: 7,
        receiverType: 'user',
        content: '医生：先暂停喂食两小时',
        type: ChatMessageType.text,
        isAutoReply: false,
        isRead: true,
        createdAt: DateTime(2026, 7, 10, 9, 2),
      ),
    ],
    total: 2,
    page: 1,
    pageSize: pageSize,
    totalPages: 1,
  );

  @override
  Future<AiDiagnosisPage> loadPatientAiReports({
    required String conversationId,
    required int petId,
    int page = 1,
    int pageSize = 20,
  }) async => AiDiagnosisPage(
    items: [
      await loadPatientAiReport(conversationId: conversationId, reportId: 9),
    ],
    page: 1,
    totalPages: 1,
    total: 1,
  );

  @override
  Future<AiDiagnosisReport> loadPatientAiReport({
    required String conversationId,
    required int reportId,
  }) async => AiDiagnosisReport.fromJson({
    'id': reportId,
    'petId': 31,
    'status': 'COMPLETED',
    'symptoms': '食欲下降',
    'diagnosisImages': <String>[],
    'basicInfo': <String, Object?>{},
    'westernDiagnosis': <String, Object?>{},
    'tcmDiagnosis': <Object?>[],
    'createdAt': '2026-07-20T08:00:00.000Z',
  });

  @override
  Future<PetCarePlanState> loadPatientCarePlan({
    required String conversationId,
    required int petId,
  }) async => PetCarePlanState.fromJson({
    'id': petId,
    'name': '团团',
    'avatar': '',
    'ownerId': 12,
    'gender': 2,
    'birthDate': '2024-02-01',
    'weight': 4.2,
    'isNeutered': true,
    'vaccineCount': 3,
    'createdAt': '2024-02-01T00:00:00.000Z',
    'updatedAt': '2026-07-20T08:00:00.000Z',
    'carePlanStatus': 'COMPLETED',
    'carePlanGeneratedAt': '2026-07-20T08:00:00.000Z',
    'carePlan': {
      'nutrition_plan': <String, Object?>{},
      'care_plan': {
        'grooming': ['每周梳毛 2 次'],
        'medical': ['每月检查耳道'],
        'exercise': ['每天散步 30 分钟'],
        'vaccination': ['按年度计划接种'],
        'environment': ['保持居住环境干燥'],
      },
    },
  });

  @override
  Future<AppointmentPage> loadPatientAppointments({
    required String conversationId,
    required int petId,
    int page = 1,
    int pageSize = 20,
  }) async => AppointmentPage(
    items: [
      await loadPatientAppointment(
        conversationId: conversationId,
        appointmentId: 6,
      ),
    ],
    page: 1,
    totalPages: 1,
    total: 1,
  );

  @override
  Future<HealthAppointment> loadPatientAppointment({
    required String conversationId,
    required int appointmentId,
  }) async => HealthAppointment.fromJson({
    'id': appointmentId,
    'type': 'vaccine',
    'status': 'confirmed',
    'appointmentDate': '2026-08-01',
    'timeSlot': '09:00-10:00',
    'petId': 31,
    'hospitalId': 2,
    'hospital': {'id': 2, 'name': '谷德动物医院', 'address': '深圳市南山区宠物路 1 号'},
    'doctor': {'name': '张晶'},
    'operationContent': '狂犬疫苗加强针接种',
    'detailContent': '<p>体温正常，已完成接种</p>',
    'notes': '接种后观察 30 分钟',
  });
}

const _profile = DoctorPortalProfile(
  id: 7,
  name: '张晶',
  phone: '13800138000',
  avatarUrl: '',
  specialty: '犬猫内科、皮肤病',
  experienceYears: 8,
  consultationCount: 126,
  isActive: true,
  isGoldDoctor: true,
  isOnline: true,
  hospitalName: '谷德动物医院',
  departmentName: '内科',
);

class _ChatGateway implements ChatGateway {
  @override
  Future<ChatBootstrap> loadChat(int doctorId) => throw UnimplementedError();

  @override
  Future<ChatBootstrap> refreshChat(int doctorId) => throw UnimplementedError();

  @override
  Future<ChatBootstrap> loadOrderChat({
    required int doctorId,
    required int orderId,
    required bool viewOnly,
  }) => throw UnimplementedError();

  @override
  Future<void> purchasePackage({
    required int doctorId,
    required int serviceItemId,
    String? conversationId,
  }) async {}

  @override
  Future<ChatUploadResult> uploadMedia({
    required String path,
    required String fileName,
    required ChatMessageType type,
  }) async => const ChatUploadResult(url: '/uploads/chat.jpg');
}

class _SessionStore implements SessionStore {
  @override
  Future<void> clearSession() async {}

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<String?> readToken() async => _session.accessToken;

  @override
  Future<void> saveSession(AuthSession session) async {}
}

class _AuthGateway implements AuthGateway {
  @override
  Future<AuthSession> login({
    required String phone,
    required String password,
    required AccountType accountType,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> register({
    required String phone,
    required String code,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
    required AccountType accountType,
  }) async {}

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async =>
      savedSession;

  @override
  Future<int> sendCode({
    required String phone,
    required String type,
    AccountType accountType = AccountType.user,
  }) async => 120;

  @override
  Future<void> verifyRegisterCode({
    required String phone,
    required String code,
  }) async {}

  @override
  Future<void> verifyResetPasswordCode({
    required String phone,
    required String code,
    required AccountType accountType,
  }) async {}
}
