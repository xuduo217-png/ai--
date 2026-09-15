import '../../pets/domain/pet_models.dart';

enum LostFoundRecordType {
  lost('LOST', '走失'),
  adoption('ADOPTION', '领养');

  const LostFoundRecordType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static LostFoundRecordType fromValue(Object? value) {
    return value == 'ADOPTION'
        ? LostFoundRecordType.adoption
        : LostFoundRecordType.lost;
  }
}

class LostFoundUser {
  const LostFoundUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatarUrl,
  });

  factory LostFoundUser.fromJson(Map<String, Object?> json) {
    return LostFoundUser(
      id: _toInt(json['id']),
      username: _text(json['username']),
      nickname: _text(json['nickname']),
      avatarUrl: _text(json['avatar'] ?? json['avatarUrl']),
    );
  }

  final int id;
  final String username;
  final String nickname;
  final String avatarUrl;

  String get displayName {
    if (nickname.isNotEmpty) return nickname;
    if (username.isNotEmpty) return username;
    return '匿名用户';
  }
}

class LostFoundPet {
  const LostFoundPet({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.categoryName,
    required this.subCategoryName,
  });

  factory LostFoundPet.fromJson(Map<String, Object?> json) {
    final category = _mapOrEmpty(json['category']);
    final subCategory = _mapOrEmpty(json['subCategory']);
    return LostFoundPet(
      id: _toInt(json['id']),
      name: _text(json['name']),
      avatarUrl: _text(json['avatar'] ?? json['avatarUrl']),
      categoryName: _text(category['name']),
      subCategoryName: _text(subCategory['name']),
    );
  }

  final int id;
  final String name;
  final String avatarUrl;
  final String categoryName;
  final String subCategoryName;

  String get breedLabel {
    return [
      categoryName,
      subCategoryName,
    ].where((value) => value.isNotEmpty).join(' · ');
  }
}

class LostFoundRecord {
  const LostFoundRecord({
    required this.id,
    required this.petId,
    required this.publisherId,
    required this.pet,
    required this.publisher,
    required this.recordType,
    required this.contactName,
    required this.contactPhone,
    required this.description,
    required this.images,
    required this.videoUrl,
    required this.videoCoverUrl,
    required this.isPinned,
    required this.isFound,
    required this.foundAt,
    required this.createdAt,
    required this.updatedAt,
    this.petName = '',
    this.petCategory = '',
    this.petBreed = '',
  });

  factory LostFoundRecord.fromJson(Map<String, Object?> json) {
    final images = _list(
      json['images'],
    ).map(_text).where((value) => value.isNotEmpty).toList(growable: false);
    final petValue = json['pet'];
    final publisherValue = json['publisher'];
    return LostFoundRecord(
      id: _toInt(json['id']),
      petId: _nullableInt(json['petId']),
      publisherId: _toInt(json['publisherId']),
      pet: petValue is Map ? LostFoundPet.fromJson(_map(petValue)) : null,
      publisher: publisherValue is Map
          ? LostFoundUser.fromJson(_map(publisherValue))
          : null,
      recordType: LostFoundRecordType.fromValue(json['recordType']),
      contactName: _text(json['contactName']),
      contactPhone: _text(json['contactPhone']),
      description: _text(json['description']),
      images: images,
      videoUrl: _text(json['video']),
      videoCoverUrl: _text(json['videoCover']),
      isPinned: _toBool(json['isPinned']),
      isFound: _toBool(json['isFound']),
      foundAt: _date(json['foundAt']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      petName: _text(json['petName']),
      petCategory: _text(json['petCategory']),
      petBreed: _text(json['petBreed']),
    );
  }

  final int id;
  final int? petId;
  final int publisherId;
  final LostFoundPet? pet;
  final LostFoundUser? publisher;
  final LostFoundRecordType recordType;
  final String contactName;
  final String contactPhone;
  final String description;
  final List<String> images;
  final String videoUrl;
  final String videoCoverUrl;
  final bool isPinned;
  final bool isFound;
  final DateTime? foundAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String petName;
  final String petCategory;
  final String petBreed;

  String get displayPetName {
    final snapshotName = petName.trim();
    if (snapshotName.isNotEmpty) return snapshotName;
    return pet?.name.trim() ?? '';
  }

  String get breedLabel {
    final snapshot = [
      petCategory.trim(),
      petBreed.trim(),
    ].where((value) => value.isNotEmpty).join(' · ');
    if (snapshot.isNotEmpty) return snapshot;
    return pet?.breedLabel ?? '';
  }

  String get title {
    if (displayPetName.isNotEmpty) return displayPetName;
    return recordType == LostFoundRecordType.adoption ? '待领养宠物' : '走失宠物';
  }

  String get statusLabel {
    if (recordType == LostFoundRecordType.adoption) return '等待领养';
    return isFound ? '已找回' : '寻找中';
  }

  String get coverUrl {
    if (images.isNotEmpty) return images.first;
    final petAvatar = pet?.avatarUrl.trim() ?? '';
    if (petAvatar.isNotEmpty) return petAvatar;
    return videoCoverUrl;
  }

  LostFoundRecord copyWith({bool? isFound}) {
    return LostFoundRecord(
      id: id,
      petId: petId,
      publisherId: publisherId,
      pet: pet,
      publisher: publisher,
      recordType: recordType,
      contactName: contactName,
      contactPhone: contactPhone,
      description: description,
      images: images,
      videoUrl: videoUrl,
      videoCoverUrl: videoCoverUrl,
      isPinned: isPinned,
      isFound: isFound ?? this.isFound,
      foundAt: foundAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      petName: petName,
      petCategory: petCategory,
      petBreed: petBreed,
    );
  }
}

class LostFoundComment {
  const LostFoundComment({
    required this.id,
    required this.lostFoundId,
    required this.userId,
    required this.content,
    required this.parentId,
    required this.likeCount,
    required this.createdAt,
    required this.user,
    required this.replies,
  });

  factory LostFoundComment.fromJson(Map<String, Object?> json) {
    final userValue = json['user'];
    return LostFoundComment(
      id: _toInt(json['id']),
      lostFoundId: _toInt(json['lostFoundId']),
      userId: _toInt(json['userId']),
      content: _text(json['content']),
      parentId: _nullableInt(json['parentId']),
      likeCount: _toInt(json['likeCount']),
      createdAt: _date(json['createdAt']),
      user: userValue is Map ? LostFoundUser.fromJson(_map(userValue)) : null,
      replies: _list(json['replies'])
          .whereType<Map>()
          .map((item) => LostFoundComment.fromJson(_map(item)))
          .toList(growable: false),
    );
  }

  final int id;
  final int lostFoundId;
  final int userId;
  final String content;
  final int? parentId;
  final int likeCount;
  final DateTime? createdAt;
  final LostFoundUser? user;
  final List<LostFoundComment> replies;
}

class LostFoundPage {
  const LostFoundPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<LostFoundRecord> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
}

class LostFoundCommentPage {
  const LostFoundCommentPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<LostFoundComment> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
}

class LostFoundDraft {
  const LostFoundDraft({
    required this.petId,
    required this.recordType,
    required this.contactName,
    required this.contactPhone,
    required this.description,
    this.images = const [],
    this.videoUrl = '',
    this.videoCoverUrl = '',
    this.isFound = false,
    this.petName = '',
    this.petCategory = '',
    this.petBreed = '',
  });

  factory LostFoundDraft.fromRecord(LostFoundRecord record) {
    return LostFoundDraft(
      petId: record.petId,
      recordType: record.recordType,
      contactName: record.contactName,
      contactPhone: record.contactPhone,
      description: record.description,
      images: record.images,
      videoUrl: record.videoUrl,
      videoCoverUrl: record.videoCoverUrl,
      isFound: record.isFound,
      petName: record.displayPetName,
      petCategory: record.petCategory.isNotEmpty
          ? record.petCategory
          : record.pet?.categoryName ?? '',
      petBreed: record.petBreed.isNotEmpty
          ? record.petBreed
          : record.pet?.subCategoryName ?? '',
    );
  }

  final int? petId;
  final LostFoundRecordType recordType;
  final String contactName;
  final String contactPhone;
  final String description;
  final List<String> images;
  final String videoUrl;
  final String videoCoverUrl;
  final bool isFound;
  final String petName;
  final String petCategory;
  final String petBreed;

  bool get usesProfilePet => petId != null && petId! > 0;

  String? validate() {
    if (!usesProfilePet) {
      if (petName.trim().isEmpty) return '请输入宠物名称';
      if (petName.trim().length > 50) return '宠物名称最多50个字符';
      if (petCategory.trim().isEmpty) return '请输入宠物类别';
      if (petCategory.trim().length > 50) return '宠物类别最多50个字符';
      if (petBreed.trim().isEmpty) return '请输入宠物品种';
      if (petBreed.trim().length > 100) return '宠物品种最多100个字符';
    }
    final normalizedName = contactName.trim();
    if (normalizedName.isEmpty) return '请输入联系人姓名';
    if (normalizedName.length < 2 || normalizedName.length > 20) {
      return '联系人姓名应为2-20个字符';
    }
    final normalizedPhone = contactPhone.trim();
    if (normalizedPhone.isEmpty) return '请输入联系电话';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(normalizedPhone)) {
      return '请输入正确的手机号码';
    }
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) return '请输入描述信息';
    if (normalizedDescription.length < 10 ||
        normalizedDescription.length > 500) {
      return '描述信息应为10-500个字符';
    }
    if (images.length > 9) return '最多只能上传9张图片';
    return null;
  }

  Map<String, Object?> toJson() {
    return {
      'petId': usesProfilePet ? petId : null,
      if (!usesProfilePet) ...{
        'petName': petName.trim(),
        'petCategory': petCategory.trim(),
        'petBreed': petBreed.trim(),
      },
      'recordType': recordType.wireValue,
      'contactName': contactName.trim(),
      'contactPhone': contactPhone.trim(),
      'description': description.trim(),
      'images': images,
      'video': videoUrl.trim().isEmpty ? null : videoUrl.trim(),
      'videoCover': videoCoverUrl.trim().isEmpty ? null : videoCoverUrl.trim(),
      'isFound': isFound,
    };
  }
}

class LostFoundMediaUpload {
  const LostFoundMediaUpload({required this.url, this.thumbnailUrl = ''});

  final String url;
  final String thumbnailUrl;
}

enum LostFoundReportReason {
  harassment('HARASSMENT', '骚扰辱骂'),
  pornography('PORNOGRAPHY', '色情低俗'),
  violence('VIOLENCE', '暴力血腥'),
  fraud('FRAUD', '诈骗欺诈'),
  spam('SPAM', '垃圾广告'),
  illegal('ILLEGAL', '违法违规'),
  misinformation('MISINFORMATION', '虚假误导'),
  other('OTHER', '其他问题');

  const LostFoundReportReason(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

abstract interface class LostFoundGateway {
  Future<LostFoundPage> loadLostFoundRecords({
    required bool authenticated,
    LostFoundRecordType? recordType,
    bool? isFound,
    int? publisherId,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  });

  Future<LostFoundRecord> loadLostFoundRecord(
    int id, {
    required bool authenticated,
  });

  Future<List<Pet>> loadLostFoundPets();

  Future<LostFoundRecord> createLostFoundRecord(LostFoundDraft draft);

  Future<LostFoundRecord> updateLostFoundRecord(int id, LostFoundDraft draft);

  Future<LostFoundRecord> markLostFoundRecordFound(int id);

  Future<void> deleteLostFoundRecord(int id);

  Future<LostFoundCommentPage> loadLostFoundComments(
    int lostFoundId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  });

  Future<LostFoundComment> createLostFoundComment(
    int lostFoundId, {
    required String content,
    int? parentId,
  });

  Future<LostFoundMediaUpload> uploadLostFoundImage({
    required String filePath,
    String? filename,
  });

  Future<LostFoundMediaUpload> uploadLostFoundVideo({
    required String filePath,
    String? filename,
  });

  Future<void> reportLostFoundContent({
    required String targetType,
    required int targetId,
    required LostFoundReportReason reason,
    String description = '',
  });

  Future<void> blockLostFoundUser(int userId, {String reason = ''});
}

String formatLostFoundTime(DateTime? value, {DateTime? now}) {
  if (value == null) return '';
  final reference = now ?? DateTime.now();
  final difference = reference.difference(value.toLocal());
  if (difference.inDays <= 0) return '今天';
  if (difference.inDays == 1) return '昨天';
  if (difference.inDays < 7) return '${difference.inDays}天前';
  if (difference.inDays < 30) return '${difference.inDays ~/ 7}周前';
  return '${value.year}/${value.month}/${value.day}';
}

Map<String, Object?> _map(Map value) {
  return value.map((key, value) => MapEntry('$key', value));
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? _map(value) : const <String, Object?>{};
}

List<Object?> _list(Object? value) {
  return value is List ? value.cast<Object?>() : const <Object?>[];
}

String _text(Object? value) => value == null ? '' : '$value'.trim();

int _toInt(Object? value) {
  return switch (value) {
    final int current => current,
    final num current => current.toInt(),
    _ => int.tryParse('$value') ?? 0,
  };
}

int? _nullableInt(Object? value) {
  if (value == null || '$value'.trim().isEmpty) return null;
  final parsed = _toInt(value);
  return parsed == 0 ? null : parsed;
}

bool _toBool(Object? value) {
  return value == true || value == 1 || '$value'.toLowerCase() == 'true';
}

DateTime? _date(Object? value) {
  return value == null ? null : DateTime.tryParse('$value');
}
