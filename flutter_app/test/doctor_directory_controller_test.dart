import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/doctors/domain/doctor_models.dart';
import 'package:pet_hospital_flutter/features/doctors/presentation/doctor_directory_controller.dart';

void main() {
  test('金牌目录分页去重并将筛选条件传给每一页', () async {
    final gateway = _DoctorGateway()
      ..responses.add(
        Future.value(_page(ids: const [1, 2], page: 1, totalPages: 2)),
      )
      ..responses.add(
        Future.value(_page(ids: const [2, 3], page: 2, totalPages: 2)),
      );
    final controller = DoctorDirectoryController(
      gateway: gateway,
      goldOnly: true,
    );

    await controller.load();
    await controller.loadMore();

    expect(controller.doctors.map((doctor) => doctor.id), [1, 2, 3]);
    expect(controller.hasMore, isFalse);
    expect(gateway.queries, [(1, true), (2, true)]);
  });

  test('重复加载更多折叠为单个请求，失败后可以重试', () async {
    final pending = Completer<DoctorDirectoryPage>();
    final gateway = _DoctorGateway()
      ..responses.add(
        Future.value(_page(ids: const [1], page: 1, totalPages: 2)),
      )
      ..responses.add(pending.future);
    final controller = DoctorDirectoryController(
      gateway: gateway,
      goldOnly: false,
    );
    await controller.load();

    final first = controller.loadMore();
    final duplicate = controller.loadMore();
    expect(gateway.queries.where((query) => query.$1 == 2), hasLength(1));
    pending.completeError(StateError('offline'));
    await Future.wait([first, duplicate]);

    expect(controller.doctors.map((doctor) => doctor.id), [1]);
    expect(controller.loadMoreError, isNotNull);
    expect(controller.hasMore, isTrue);

    gateway.responses.add(
      Future.value(_page(ids: const [2], page: 2, totalPages: 2)),
    );
    await controller.loadMore();

    expect(controller.doctors.map((doctor) => doctor.id), [1, 2]);
    expect(controller.loadMoreError, isNull);
  });
}

DoctorDirectoryPage _page({
  required List<int> ids,
  required int page,
  required int totalPages,
}) {
  return DoctorDirectoryPage(
    items: ids.map(_doctor).toList(growable: false),
    page: page,
    totalPages: totalPages,
  );
}

DoctorProfile _doctor(int id) => DoctorProfile(
  id: id,
  name: '医生$id',
  avatarUrl: '',
  username: 'doctor-$id',
  specialty: '犬猫内科',
  description: '医生简介',
  experience: 8,
  rating: 4.8,
  consultationCount: 20,
  price: '20.00',
  isGold: true,
  online: true,
);

class _DoctorGateway implements DoctorDirectoryGateway {
  final List<Future<DoctorDirectoryPage>> responses = [];
  final List<(int, bool)> queries = [];

  @override
  Future<DoctorDirectoryPage> loadDoctors({
    required int page,
    required bool goldOnly,
  }) {
    queries.add((page, goldOnly));
    return responses.removeAt(0);
  }

  @override
  Future<DoctorProfile> loadDoctor(int doctorId) async => _doctor(doctorId);
}
