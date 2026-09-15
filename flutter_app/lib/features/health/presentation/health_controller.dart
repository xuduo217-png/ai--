import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../pets/domain/pet_models.dart';
import '../domain/health_models.dart';

class HealthController extends ChangeNotifier {
  HealthController({required HealthGateway gateway}) : _gateway = gateway;

  final HealthGateway _gateway;

  List<Pet> pets = const [];
  Pet? selectedPet;
  PetHealthStats stats = PetHealthStats.empty;
  List<HealthAppointment> appointments = const [];
  bool loading = true;
  bool refreshingPet = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;

  Future<void> initialize() async {
    loading = true;
    error = null;
    _notify();
    try {
      pets = await _gateway.loadHealthPets();
      if (_disposed) return;
      selectedPet = pets.firstOrNull;
      if (selectedPet != null) await _loadSelectedPet();
    } on Object {
      if (_disposed) return;
      error = '营养师数据加载失败，请稍后重试';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    if (selectedPet == null) return initialize();
    await _loadSelectedPet();
  }

  Future<void> selectPet(Pet pet) async {
    if (_disposed || selectedPet?.id == pet.id) return;
    selectedPet = pet;
    await _loadSelectedPet();
  }

  Future<void> _loadSelectedPet() async {
    final pet = selectedPet;
    if (pet == null) return;
    final generation = ++_generation;
    refreshingPet = true;
    error = null;
    _notify();
    try {
      final result = await Future.wait<Object>([
        _gateway.loadPetHealthStats(pet.id),
        _gateway.loadAppointments(petId: pet.id, pageSize: 100),
      ]);
      if (_disposed || generation != _generation) return;
      stats = result[0] as PetHealthStats;
      appointments = (result[1] as AppointmentPage).items;
    } on Object {
      if (_disposed || generation != _generation) return;
      error = '当前宠物的健康数据加载失败';
    } finally {
      if (!_disposed && generation == _generation) {
        refreshingPet = false;
        _notify();
      }
    }
  }

  HealthAppointment? activeAppointmentFor(HealthAppointmentType type) {
    for (final appointment in appointments) {
      if (appointment.type == type && appointment.isActive) return appointment;
    }
    return null;
  }

  List<HealthAppointment> get completedRecords => appointments
      .where((item) => item.status == HealthAppointmentStatus.completed)
      .toList(growable: false);

  Future<HealthAppointment> createAppointment({
    required HealthAppointmentType type,
    required HealthHospital hospital,
    required DateTime date,
    required String timeSlot,
    String notes = '',
  }) async {
    final pet = selectedPet;
    if (pet == null) throw StateError('请先选择宠物');
    final created = await _gateway.createAppointment(
      petId: pet.id,
      hospitalId: hospital.id,
      type: type,
      appointmentDate: formatPetDate(date),
      timeSlot: timeSlot,
      notes: notes,
    );
    await _loadSelectedPet();
    return created;
  }

  Future<void> cancelAppointment(int appointmentId) async {
    await _gateway.cancelAppointment(appointmentId);
    await _loadSelectedPet();
  }

  Future<List<HealthHospital>> loadHospitals() {
    return _gateway.loadHealthHospitals();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

class CarePlanController extends ChangeNotifier {
  CarePlanController({required HealthGateway gateway, required this.petId})
    : _gateway = gateway;

  final HealthGateway _gateway;
  final int petId;
  PetCarePlanState? state;
  bool loading = true;
  bool generating = false;
  String? error;
  Timer? _pollTimer;
  bool _disposed = false;

  Future<void> load() async {
    loading = state == null;
    error = null;
    _notify();
    try {
      state = await _gateway.loadCarePlan(petId);
      if (_disposed) return;
      if (state?.status == CarePlanStatus.generating) {
        _schedulePoll();
      }
    } on Object {
      if (!_disposed) error = '护理方案加载失败，请稍后重试';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> generate() async {
    if (generating) return;
    generating = true;
    error = null;
    _notify();
    try {
      await _gateway.generateCarePlan(petId);
      await load();
    } on Object {
      if (!_disposed) error = '护理方案生成失败，请稍后重试';
    } finally {
      if (!_disposed) {
        generating = false;
        _notify();
      }
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 3), load);
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

class AiDiagnosisListController extends ChangeNotifier {
  AiDiagnosisListController({required HealthGateway gateway})
    : _gateway = gateway;

  final HealthGateway _gateway;
  List<Pet> pets = const [];
  List<AiDiagnosisReport> reports = const [];
  int? selectedPetId;
  bool loading = true;
  String? error;
  bool _disposed = false;

  Future<void> initialize() async {
    loading = true;
    error = null;
    _notify();
    try {
      pets = await _gateway.loadHealthPets();
      if (selectedPetId == null && pets.isNotEmpty) {
        selectedPetId = pets.first.id;
      } else if (!pets.any((pet) => pet.id == selectedPetId)) {
        selectedPetId = pets.firstOrNull?.id;
      }
      await _loadReports();
    } on Object {
      if (!_disposed) error = 'AI 问诊记录加载失败，请稍后重试';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> selectPet(int? petId) async {
    // 创建返回、下拉刷新和失败重试都可能传入当前宠物，仍需重新请求列表。
    selectedPetId = petId;
    loading = true;
    error = null;
    _notify();
    try {
      await _loadReports();
    } on Object {
      if (!_disposed) error = 'AI 问诊记录加载失败，请稍后重试';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _loadReports() async {
    reports = (await _gateway.loadAiDiagnosisReports(
      petId: selectedPetId,
      pageSize: 100,
    )).items;
  }

  Pet? petFor(int petId) {
    for (final pet in pets) {
      if (pet.id == petId) return pet;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

class HealthArticleListController extends ChangeNotifier {
  HealthArticleListController({required HealthGateway gateway})
    : _gateway = gateway;

  final HealthGateway _gateway;
  List<HealthArticleCategory> categories = const [];
  List<HealthArticle> articles = const [];
  int? selectedCategoryId;
  bool loading = true;
  String? error;
  bool _disposed = false;

  Future<void> initialize() async {
    loading = true;
    error = null;
    _notify();
    try {
      final result = await Future.wait<Object>([
        _gateway.loadHealthArticleCategories(),
        _gateway.loadHealthArticles(pageSize: 100),
      ]);
      categories = result[0] as List<HealthArticleCategory>;
      articles = (result[1] as HealthArticlePage).items;
    } on Object {
      if (!_disposed) error = '健康知识加载失败，请稍后重试';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> selectCategory(int? categoryId) async {
    if (selectedCategoryId == categoryId && !loading) return;
    selectedCategoryId = categoryId;
    loading = true;
    error = null;
    _notify();
    try {
      articles = (await _gateway.loadHealthArticles(
        categoryId: categoryId,
        pageSize: 100,
      )).items;
    } on Object {
      if (!_disposed) error = '当前分类加载失败，请稍后重试';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

class ConsultationListController extends ChangeNotifier {
  ConsultationListController({required HealthGateway gateway, this.doctorId})
    : _gateway = gateway;

  final HealthGateway _gateway;
  final int? doctorId;
  List<HealthConsultation> consultations = const [];
  bool loading = true;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      consultations = (await _gateway.loadHealthConsultations(
        doctorId: doctorId,
        pageSize: 100,
      )).items;
    } on Object {
      if (!_disposed) error = '历史咨询加载失败，请稍后重试';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
