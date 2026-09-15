import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';
import 'package:pet_hospital_flutter/features/health/presentation/health_controller.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';

void main() {
  test('营养师控制器默认选择首只宠物并在切换后刷新对应数据', () async {
    final gateway = _HealthGateway();
    final controller = HealthController(gateway: gateway);

    await controller.initialize();

    expect(controller.selectedPet?.name, '团子');
    expect(controller.stats.vaccine.count, 1);
    expect(gateway.statsPetIds, [8]);
    expect(gateway.appointmentPetIds, [8]);

    await controller.selectPet(gateway.pets.last);

    expect(controller.selectedPet?.name, '豆包');
    expect(controller.stats.vaccine.count, 2);
    expect(gateway.statsPetIds, [8, 9]);
    expect(gateway.appointmentPetIds, [8, 9]);
  });

  test('预约成功后使用当前宠物并重新加载健康数据', () async {
    final gateway = _HealthGateway();
    final controller = HealthController(gateway: gateway);
    await controller.initialize();

    await controller.createAppointment(
      type: HealthAppointmentType.checkup,
      hospital: const HealthHospital(id: 3, name: '谷德宠物医院'),
      date: DateTime(2026, 7, 30),
      timeSlot: '10:00-11:00',
      notes: '年度体检',
    );

    expect(gateway.createdPetId, 8);
    expect(gateway.createdType, HealthAppointmentType.checkup);
    expect(gateway.createdDate, '2026-07-30');
    expect(gateway.statsPetIds, [8, 8]);
  });
  test('AI 问诊创建后刷新同一宠物，立即读取生成中记录并可刷新完成状态', () async {
    final gateway = _HealthGateway();
    final controller = AiDiagnosisListController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.reports, isEmpty);

    gateway.reportStatus = 'PROCESSING';
    await controller.selectPet(controller.selectedPetId);
    expect(gateway.reportPetIds, [8, 8]);
    expect(controller.reports.single.status, AiDiagnosisStatus.processing);

    gateway.reportStatus = 'COMPLETED';
    await controller.selectPet(controller.selectedPetId);
    expect(controller.reports.single.status, AiDiagnosisStatus.completed);
    expect(gateway.reportPetIds, [8, 8, 8]);
  });

  test('AI 问诊同一宠物加载失败后可以重试，切换宠物仍使用新 ID', () async {
    final gateway = _HealthGateway()..failReports = true;
    final controller = AiDiagnosisListController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.error, isNotNull);

    gateway.failReports = false;
    gateway.reportStatus = 'PROCESSING';
    await controller.selectPet(controller.selectedPetId);
    expect(controller.error, isNull);
    expect(controller.reports.single.petId, 8);
    await controller.selectPet(9);
    expect(controller.reports.single.petId, 9);
    expect(gateway.reportPetIds, [8, 8, 9]);
  });
}

class _HealthGateway implements HealthGateway {
  String? reportStatus;
  bool failReports = false;
  final List<int?> reportPetIds = [];

  @override
  Future<AiDiagnosisPage> loadAiDiagnosisReports({
    int? petId,
    int page = 1,
    int pageSize = 20,
  }) async {
    reportPetIds.add(petId);
    if (failReports) throw StateError('模拟加载失败');
    final items = reportStatus == null
        ? <AiDiagnosisReport>[]
        : [
            AiDiagnosisReport.fromJson({
              'id': 91,
              'petId': petId,
              'status': reportStatus,
              'symptoms': '精神不振',
            }),
          ];
    return AiDiagnosisPage(
      items: items,
      page: page,
      totalPages: 1,
      total: items.length,
    );
  }

  final pets = [_pet(8, '团子'), _pet(9, '豆包')];
  final List<int> statsPetIds = [];
  final List<int> appointmentPetIds = [];
  int? createdPetId;
  HealthAppointmentType? createdType;
  String? createdDate;

  @override
  Future<List<Pet>> loadHealthPets() async => pets;

  @override
  Future<PetHealthStats> loadPetHealthStats(int petId) async {
    statsPetIds.add(petId);
    return PetHealthStats(
      vaccine: HealthMetric(count: petId == 8 ? 1 : 2),
      deworming: const HealthMetric(count: 3),
      checkup: const HealthMetric(count: 1),
    );
  }

  @override
  Future<AppointmentPage> loadAppointments({
    required int petId,
    int page = 1,
    int pageSize = 20,
    HealthAppointmentType? type,
    HealthAppointmentStatus? status,
  }) async {
    appointmentPetIds.add(petId);
    return const AppointmentPage(items: [], page: 1, totalPages: 1, total: 0);
  }

  @override
  Future<HealthAppointment> createAppointment({
    required int petId,
    required int hospitalId,
    required HealthAppointmentType type,
    required String appointmentDate,
    required String timeSlot,
    String notes = '',
  }) async {
    createdPetId = petId;
    createdType = type;
    createdDate = appointmentDate;
    return HealthAppointment(
      id: 21,
      type: type,
      status: HealthAppointmentStatus.pending,
      appointmentDate: appointmentDate,
      timeSlot: timeSlot,
      petId: petId,
      hospitalId: hospitalId,
      notes: notes,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Pet _pet(int id, String name) => Pet(
  id: id,
  name: name,
  avatarUrl: '',
  categoryId: 1,
  subCategoryId: 2,
  gender: PetGender.male,
  birthDate: DateTime(2024, 1, 1),
  weight: 5.5,
  isNeutered: true,
  vaccineCount: 2,
  category: const PetCategory(id: 1, name: '猫', parentId: null, sortOrder: 1),
  subCategory: const PetCategory(id: 2, name: '英短', parentId: 1, sortOrder: 1),
  ownerId: 5,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 7, 1),
);
