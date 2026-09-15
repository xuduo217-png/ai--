class HomeSnapshot {
  const HomeSnapshot({
    this.menuIcons = const {},
    this.bannerImageUrl = '',
    this.scrollingAnnouncement = '',
    this.doctors = const [],
    this.activities = const [],
    this.consultations = const [],
  });

  final Map<String, String> menuIcons;
  final String bannerImageUrl;
  final String scrollingAnnouncement;
  final List<HomeDoctor> doctors;
  final List<HomeActivity> activities;
  final List<HomeConsultation> consultations;
}

class HomeDoctor {
  const HomeDoctor({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.specialty,
    required this.experience,
    required this.price,
    required this.isGold,
    required this.username,
  });

  final int id;
  final String name;
  final String avatarUrl;
  final String specialty;
  final int experience;
  final String price;
  final bool isGold;
  final String username;
}

class HomeActivity {
  const HomeActivity({
    required this.id,
    required this.title,
    required this.coverImageUrl,
    required this.status,
    required this.activityType,
  });

  final int id;
  final String title;
  final String coverImageUrl;
  final String status;
  final String activityType;
}

class HomeConsultation {
  const HomeConsultation({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorAvatarUrl,
    required this.status,
    required this.paidAt,
    this.serviceStartAt,
    this.serviceEndAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  final int id;
  final int doctorId;
  final String doctorName;
  final String doctorAvatarUrl;
  final String status;
  final DateTime? paidAt;
  final DateTime? serviceStartAt;
  final DateTime? serviceEndAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

abstract interface class HomeGateway {
  Future<HomeSnapshot> loadHome({required bool authenticated});
}
