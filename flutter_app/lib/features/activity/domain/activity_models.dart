enum ActivityStatus {
  upcoming('UPCOMING', '未开始'),
  ongoing('ONGOING', '进行中'),
  expired('EXPIRED', '已结束');

  const ActivityStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ActivityStatus fromWire(Object? value) {
    return values.firstWhere(
      (status) => status.wireValue == '$value'.toUpperCase(),
      orElse: () => ActivityStatus.upcoming,
    );
  }
}

enum ActivityType {
  offline('OFFLINE', '线下活动'),
  online('ONLINE', '投票活动');

  const ActivityType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ActivityType fromWire(Object? value) {
    return '$value'.toUpperCase() == 'ONLINE'
        ? ActivityType.online
        : ActivityType.offline;
  }
}

class ActivityHospital {
  const ActivityHospital({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.address,
    required this.phone,
  });

  final int id;
  final String name;
  final String logoUrl;
  final String address;
  final String phone;
}

class ActivityVoteOption {
  const ActivityVoteOption({
    required this.id,
    required this.activityId,
    required this.imageUrl,
    required this.videoUrl,
    required this.videoCoverUrl,
    required this.title,
    required this.description,
    required this.voteCount,
    required this.sortOrder,
    this.ownerUserId,
  });

  final int id;
  final int activityId;
  final String imageUrl;
  final String videoUrl;
  final String videoCoverUrl;
  final String title;
  final String description;
  final int voteCount;
  final int sortOrder;
  final int? ownerUserId;

  bool get hasImage => imageUrl.isNotEmpty;
  bool get hasVideo => videoUrl.isNotEmpty;
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.summary,
    required this.description,
    required this.coverImageUrl,
    required this.sharePosterImageUrl,
    required this.sharePosterTitle,
    required this.sharePosterDescription,
    required this.hospitalId,
    required this.hospitalName,
    required this.registrationCount,
    required this.status,
    required this.activityType,
    required this.voteOptions,
    required this.isRegistered,
    required this.canRegister,
    required this.createdAt,
    required this.updatedAt,
    this.hospital,
  });

  final int id;
  final String title;
  final DateTime? startTime;
  final DateTime? endTime;
  final String location;
  final String summary;
  final String description;
  final String coverImageUrl;
  final String sharePosterImageUrl;
  final String sharePosterTitle;
  final String sharePosterDescription;
  final int hospitalId;
  final String hospitalName;
  final int registrationCount;
  final ActivityStatus status;
  final ActivityType activityType;
  final List<ActivityVoteOption> voteOptions;
  final bool isRegistered;
  final bool canRegister;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ActivityHospital? hospital;

  bool get isOnline => activityType == ActivityType.online;
  bool get isExpired => status == ActivityStatus.expired;
}

class ActivityPage {
  const ActivityPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<ActivityItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
}

class ActivityParticipant {
  const ActivityParticipant({
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.registeredAt,
  });

  final int userId;
  final String userName;
  final String userAvatarUrl;
  final DateTime? registeredAt;
}

class ActivityParticipantPage {
  const ActivityParticipantPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<ActivityParticipant> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
}

class ActivityCommentUser {
  const ActivityCommentUser({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
  });

  final int id;
  final String nickname;
  final String avatarUrl;
}

class ActivityComment {
  const ActivityComment({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    required this.replies,
    this.voteOptionId,
    this.parentId,
    this.user,
  });

  final int id;
  final int activityId;
  final int? voteOptionId;
  final int userId;
  final String content;
  final int? parentId;
  final int likeCount;
  final DateTime? createdAt;
  final ActivityCommentUser? user;
  final List<ActivityComment> replies;
}

class ActivityCommentPage {
  const ActivityCommentPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<ActivityComment> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
}

class ActivityVoteOptionDraft {
  const ActivityVoteOptionDraft({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.videoUrl,
    required this.videoCoverUrl,
  });

  final String title;
  final String description;
  final String imageUrl;
  final String videoUrl;
  final String videoCoverUrl;

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'image': imageUrl.trim(),
    'video': videoUrl.trim(),
    'videoCover': videoCoverUrl.trim(),
  };
}

class ActivityMediaUpload {
  const ActivityMediaUpload({required this.url, this.thumbnailUrl = ''});

  final String url;
  final String thumbnailUrl;
}

class ActivityActionResult<T> {
  const ActivityActionResult({
    required this.success,
    required this.message,
    this.data,
  });

  final bool success;
  final String message;
  final T? data;
}

abstract interface class ActivityGateway {
  Future<ActivityPage> loadActivities({
    required bool authenticated,
    required ActivityStatus status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  });

  Future<ActivityItem> loadActivityDetail(
    int activityId, {
    required bool authenticated,
  });

  Future<ActivityParticipantPage> loadActivityParticipants(
    int activityId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  });

  Future<ActivityCommentPage> loadActivityComments(
    int activityId, {
    required bool authenticated,
    int? voteOptionId,
    int page = 1,
    int pageSize = 20,
  });

  Future<ActivityComment> createActivityComment(
    int activityId, {
    required String content,
    int? voteOptionId,
    int? parentId,
  });

  Future<ActivityActionResult<void>> registerActivity(
    int activityId, {
    required String phone,
  });

  Future<ActivityActionResult<void>> voteActivity(
    int activityId, {
    required int optionId,
  });

  Future<ActivityActionResult<ActivityVoteOption>> createActivityVoteOption(
    int activityId,
    ActivityVoteOptionDraft draft,
  );

  Future<ActivityActionResult<ActivityVoteOption>> updateActivityVoteOption(
    int activityId,
    int optionId,
    ActivityVoteOptionDraft draft,
  );

  Future<ActivityActionResult<void>> deleteActivityVoteOption(
    int activityId,
    int optionId,
  );

  Future<ActivityMediaUpload> uploadActivityImage({
    required String filePath,
    String? filename,
  });

  Future<ActivityMediaUpload> uploadActivityVideo({
    required String filePath,
    String? filename,
  });

  Future<void> reportActivityContent({
    required String targetType,
    required int targetId,
    required String reason,
    String description = '',
  });

  Future<void> blockActivityUser(int userId, {String reason = ''});
}
