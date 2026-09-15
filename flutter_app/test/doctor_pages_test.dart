import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/doctors/domain/doctor_models.dart';
import 'package:pet_hospital_flutter/features/doctors/presentation/pages/doctor_list_page.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';
import 'package:pet_hospital_flutter/features/home/domain/home_models.dart';
import 'package:pet_hospital_flutter/features/home/presentation/home_page.dart';
import 'package:pet_hospital_flutter/features/mall/domain/mall_models.dart';

void main() {
  testWidgets('首页金牌咨询进入金牌医生列表，游客咨询沿用登录拦截', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _HomeDoctorGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: gateway,
          mallGateway: _MallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('medical-home-feature-gold-doctor')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gold-doctor-list-page')), findsOneWidget);
    expect(find.text('金牌医生'), findsOneWidget);
    expect(gateway.queries, [(1, true)]);
    expect(
      tester.getSize(find.byKey(const ValueKey('doctor-card-9'))).height,
      lessThan(90),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('doctor-action-9'))).width,
      68,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('doctor-consult-9'))),
      const Size(68, 26),
    );

    await tester.tap(find.byKey(const ValueKey('doctor-consult-9')));
    await tester.pumpAndSettle();

    expect(find.text('请先登录'), findsOneWidget);
    expect(find.text('登录后即可发起咨询'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('医生列表卡片进入详情并可发起咨询', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _HomeDoctorGateway();
    DoctorProfile? consultedDoctor;

    await tester.pumpWidget(
      MaterialApp(
        home: DoctorListPage(
          gateway: gateway,
          goldOnly: true,
          onConsult: (doctor) => consultedDoctor = doctor,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('doctor-card-9')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('doctor-detail-page')), findsOneWidget);
    expect(find.text('擅长犬猫常见病诊疗'), findsOneWidget);
    expect(find.text('谷德宠物医院'), findsOneWidget);
    expect(find.text('内科'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('doctor-detail-consult')));
    await tester.pump();

    expect(consultedDoctor?.id, 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('医生详情只展示当前医生的付费历史咨询', (tester) async {
    final gateway = _HomeDoctorHistoryGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: DoctorListPage(
          gateway: gateway,
          goldOnly: true,
          onConsult: (_) {},
          consultationGateway: gateway,
          authenticated: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('doctor-card-9')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('doctor-consultation-history-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('doctor-consultation-71')),
      findsOneWidget,
    );
    expect(find.text('服务中'), findsOneWidget);
    expect(gateway.consultationDoctorIds, [9]);
    expect(tester.takeException(), isNull);
  });
}

const _doctor = DoctorProfile(
  id: 9,
  name: '林医生',
  avatarUrl: '',
  username: 'doctor-lin',
  specialty: '犬猫内科',
  description: '擅长犬猫常见病诊疗',
  experience: 12,
  rating: 4.9,
  consultationCount: 86,
  price: '38.50',
  isGold: true,
  online: true,
  hospitalName: '谷德宠物医院',
  departmentName: '内科',
);

class _HomeDoctorGateway implements HomeGateway, DoctorDirectoryGateway {
  final List<(int, bool)> queries = [];

  @override
  Future<HomeSnapshot> loadHome({required bool authenticated}) async =>
      const HomeSnapshot();

  @override
  Future<DoctorDirectoryPage> loadDoctors({
    required int page,
    required bool goldOnly,
  }) async {
    queries.add((page, goldOnly));
    return const DoctorDirectoryPage(items: [_doctor], page: 1, totalPages: 1);
  }

  @override
  Future<DoctorProfile> loadDoctor(int doctorId) async => _doctor;
}

class _HomeDoctorHistoryGateway extends _HomeDoctorGateway
    implements HealthGateway {
  final List<int> consultationDoctorIds = [];

  @override
  Future<ConsultationPage> loadHealthConsultations({
    int? doctorId,
    int page = 1,
    int pageSize = 20,
  }) async {
    consultationDoctorIds.add(doctorId ?? 0);
    return const ConsultationPage(
      items: [
        HealthConsultation(
          id: 71,
          doctorId: 9,
          doctorName: '林医生',
          doctorAvatarUrl: '',
          status: 'ACTIVE',
          lastMessage: '请描述宠物目前的症状',
        ),
      ],
      page: 1,
      totalPages: 1,
      total: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _MallGateway implements MallGateway {
  @override
  Future<void> addToCart({
    required int productId,
    required int? skuId,
    required int quantity,
  }) async {}

  @override
  Future<bool> loadCartBadge() async => false;

  @override
  Future<MallSnapshot> loadMall({required bool authenticated}) async =>
      const MallSnapshot();

  @override
  Future<MallProduct> loadProduct(int productId) => throw UnimplementedError();
}
