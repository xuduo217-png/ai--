import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/emergency_models.dart';
import '../platform/emergency_location_gateway.dart';

enum NearbyHospitalsViewState { guide, loading, blocked, empty, list, error }

typedef ConfirmLocationUse = Future<bool> Function();

class EmergencyController extends ChangeNotifier {
  EmergencyController({
    required EmergencyGateway gateway,
    required EmergencyLocationGateway locationGateway,
  }) : _gateway = gateway,
       _locationGateway = locationGateway;

  final EmergencyGateway _gateway;
  final EmergencyLocationGateway _locationGateway;

  EmergencyCenterConfig config = EmergencyCenterConfig.fallback;
  List<AidGuide> guides = const [];
  List<NearbyHospital> hospitals = const [];
  bool loadingGuides = true;
  NearbyHospitalsViewState nearbyState = NearbyHospitalsViewState.guide;
  String? guideError;
  String? locationError;
  Future<void>? _nearbyLoadInFlight;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    final locationGateway = _locationGateway;
    if (locationGateway is CancellableEmergencyLocationGateway) {
      unawaited(
        locationGateway.cancelCurrentPosition().catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  Future<void> initialize() async {
    await Future.wait([_loadConfig(), loadGuides(), refreshGrantedLocation()]);
  }

  Future<void> _loadConfig() async {
    try {
      config = await _gateway.loadEmergencyConfig();
    } on Object {
      config = EmergencyCenterConfig.fallback;
    }
    notifyListeners();
  }

  Future<void> loadGuides() async {
    loadingGuides = true;
    guideError = null;
    notifyListeners();
    try {
      guides = await _gateway.loadAidGuides();
    } on Object {
      guides = const [];
      guideError = '急救指南加载失败，请稍后重试';
    } finally {
      loadingGuides = false;
      notifyListeners();
    }
  }

  Future<void> refreshGrantedLocation() async {
    try {
      final status = await _locationGateway.checkPermission();
      if (status == EmergencyLocationPermission.granted) {
        await _loadNearbyHospitals();
      }
    } on Object {
      // 平台能力不可用时保留主动触发入口。
    }
  }

  Future<void> requestNearbyHospitals(ConfirmLocationUse confirmUse) async {
    locationError = null;
    try {
      var status = await _locationGateway.checkPermission();
      if (status == EmergencyLocationPermission.blocked) {
        nearbyState = NearbyHospitalsViewState.blocked;
        notifyListeners();
        return;
      }
      if (status == EmergencyLocationPermission.denied) {
        final confirmed = await confirmUse();
        if (!confirmed) return;
        status = await _locationGateway.requestPermission();
      }
      if (status == EmergencyLocationPermission.granted) {
        await _loadNearbyHospitals();
      } else {
        nearbyState = status == EmergencyLocationPermission.blocked
            ? NearbyHospitalsViewState.blocked
            : NearbyHospitalsViewState.guide;
        locationError = status == EmergencyLocationPermission.denied
            ? '位置权限未授予，暂时无法查找附近医院'
            : null;
        notifyListeners();
      }
    } on Object {
      nearbyState = NearbyHospitalsViewState.error;
      locationError = '定位服务暂不可用，请检查系统定位设置后重试';
      notifyListeners();
    }
  }

  Future<bool> openLocationSettings() => _locationGateway.openSettings();

  Future<void> _loadNearbyHospitals() {
    final inFlight = _nearbyLoadInFlight;
    if (inFlight != null) return inFlight;
    final load = _loadNearbyHospitalsInternal();
    _nearbyLoadInFlight = load;
    return load.whenComplete(() {
      if (identical(_nearbyLoadInFlight, load)) {
        _nearbyLoadInFlight = null;
      }
    });
  }

  Future<void> _loadNearbyHospitalsInternal() async {
    nearbyState = NearbyHospitalsViewState.loading;
    locationError = null;
    notifyListeners();
    late final EmergencyPosition position;
    try {
      position = await _locationGateway.getCurrentPosition();
    } on Object {
      if (_disposed) return;
      hospitals = const [];
      nearbyState = NearbyHospitalsViewState.error;
      locationError = '当前位置获取失败，请检查定位服务后重试';
      notifyListeners();
      return;
    }
    if (_disposed) return;
    try {
      hospitals = await _gateway.loadNearbyHospitals(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      nearbyState = hospitals.isEmpty
          ? NearbyHospitalsViewState.empty
          : NearbyHospitalsViewState.list;
    } on Object {
      if (_disposed) return;
      hospitals = const [];
      nearbyState = NearbyHospitalsViewState.error;
      locationError = '附近医院加载失败，请稍后重试';
    }
    if (_disposed) return;
    notifyListeners();
  }
}

class AidGuideListController extends ChangeNotifier {
  AidGuideListController(this._gateway);

  final EmergencyGateway _gateway;

  List<AidGuideCategory> categories = const [];
  List<AidGuide> guides = const [];
  int? selectedCategoryId;
  bool loading = true;
  String? error;

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await Future.wait<Object>([
        _gateway.loadAidGuideCategories(),
        _gateway.loadAidGuides(),
      ]);
      categories = result[0] as List<AidGuideCategory>;
      guides = result[1] as List<AidGuide>;
    } on Object {
      error = '急救指南加载失败，请稍后重试';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectCategory(int? categoryId) async {
    if (selectedCategoryId == categoryId && !loading) return;
    selectedCategoryId = categoryId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      guides = await _gateway.loadAidGuides(categoryId: categoryId);
    } on Object {
      guides = const [];
      error = '当前分类加载失败，请稍后重试';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    error = null;
    try {
      final result = await Future.wait<Object>([
        _gateway.loadAidGuideCategories(),
        _gateway.loadAidGuides(categoryId: selectedCategoryId),
      ]);
      categories = result[0] as List<AidGuideCategory>;
      guides = result[1] as List<AidGuide>;
    } on Object {
      error = '急救指南刷新失败，请稍后重试';
    }
    notifyListeners();
  }
}
