class EmergencyCenterConfig {
  const EmergencyCenterConfig({
    required this.emergencyTime,
    required this.emergencyHotline,
  });

  static const fallback = EmergencyCenterConfig(
    emergencyTime: '24小时在线',
    emergencyHotline: '400-000-0000',
  );

  final String emergencyTime;
  final String emergencyHotline;
}

class AidGuideCategory {
  const AidGuideCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.guideCount,
    this.iconUrl = '',
  });

  final int id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final int guideCount;
  final String iconUrl;
}

class AidGuide {
  const AidGuide({
    required this.id,
    required this.title,
    required this.content,
    required this.categoryId,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    this.iconUrl = '',
    this.category,
    this.publishedAt,
  });

  final int id;
  final String title;
  final String content;
  final int categoryId;
  final String status;
  final int sortOrder;
  final DateTime createdAt;
  final String iconUrl;
  final AidGuideCategory? category;
  final DateTime? publishedAt;

  DateTime get displayDate => publishedAt ?? createdAt;
}

class NearbyHospital {
  const NearbyHospital({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.businessStatusText,
    required this.distance,
    this.logoUrl = '',
  });

  final int id;
  final String name;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;
  final String businessStatusText;
  final double distance;
  final String logoUrl;
}

abstract interface class EmergencyGateway {
  Future<EmergencyCenterConfig> loadEmergencyConfig();

  Future<List<AidGuide>> loadAidGuides({int? categoryId});

  Future<List<AidGuideCategory>> loadAidGuideCategories();

  Future<AidGuide> loadAidGuide(int guideId);

  Future<List<NearbyHospital>> loadNearbyHospitals({
    required double latitude,
    required double longitude,
    int limit = 10,
  });
}
