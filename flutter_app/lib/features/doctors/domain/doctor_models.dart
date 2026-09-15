class DoctorProfile {
  const DoctorProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.username,
    required this.specialty,
    required this.description,
    required this.experience,
    required this.rating,
    required this.consultationCount,
    required this.price,
    required this.isGold,
    required this.online,
    this.hospitalName,
    this.departmentName,
  });

  final int id;
  final String name;
  final String avatarUrl;
  final String username;
  final String specialty;
  final String description;
  final int experience;
  final double rating;
  final int consultationCount;
  final String price;
  final bool isGold;
  final bool online;
  final String? hospitalName;
  final String? departmentName;
}

class DoctorDirectoryPage {
  const DoctorDirectoryPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<DoctorProfile> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

abstract interface class DoctorDirectoryGateway {
  Future<DoctorDirectoryPage> loadDoctors({
    required int page,
    required bool goldOnly,
  });

  Future<DoctorProfile> loadDoctor(int doctorId);
}
