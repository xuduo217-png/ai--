import '../../../core/config/api_config.dart';
import '../../../core/network/asset_url_resolver.dart';

enum PetGender {
  unknown(0, '未知'),
  male(1, '弟弟'),
  female(2, '妹妹');

  const PetGender(this.wireValue, this.label);

  final int wireValue;
  final String label;

  static PetGender fromValue(Object? value) {
    return switch (_nullableInt(value)) {
      1 => PetGender.male,
      2 => PetGender.female,
      _ => PetGender.unknown,
    };
  }
}

class PetCategory {
  const PetCategory({
    required this.id,
    required this.name,
    required this.parentId,
    required this.sortOrder,
    this.children = const [],
  });

  factory PetCategory.fromJson(Map<String, Object?> json) {
    final childrenValue = json['children'];
    final children = childrenValue == null
        ? const <PetCategory>[]
        : _asList(childrenValue, 'pet category children')
              .map(
                (child) =>
                    PetCategory.fromJson(_asMap(child, 'pet category child')),
              )
              .toList(growable: false);
    return PetCategory(
      id: _requiredInt(json['id'], 'pet category id'),
      name: _requiredString(json['name'], 'pet category name'),
      parentId: _nullableInt(json['parentId']),
      sortOrder: _nullableInt(json['sortOrder']) ?? 0,
      children: children,
    );
  }

  final int id;
  final String name;
  final int? parentId;
  final int sortOrder;
  final List<PetCategory> children;
}

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.categoryId,
    required this.subCategoryId,
    required this.gender,
    required this.birthDate,
    required this.weight,
    required this.isNeutered,
    required this.vaccineCount,
    required this.category,
    required this.subCategory,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pet.fromJson(Map<String, Object?> json) {
    return Pet(
      id: _requiredInt(json['id'], 'pet id'),
      name: _requiredString(json['name'], 'pet name'),
      avatarUrl: _trimmedString(json['avatar'] ?? json['avatarUrl']),
      categoryId: _nullableInt(json['categoryId']),
      subCategoryId: _nullableInt(json['subCategoryId']),
      gender: PetGender.fromValue(json['gender']),
      birthDate: _nullableDateOnly(json['birthDate']),
      weight: _nullableDouble(json['weight']) ?? 0,
      isNeutered: _boolValue(json['isNeutered']),
      vaccineCount: _nullableInt(json['vaccineCount']) ?? 0,
      category: _nullableCategory(json['category']),
      subCategory: _nullableCategory(json['subCategory']),
      ownerId: _requiredInt(json['ownerId'], 'pet ownerId'),
      createdAt: _nullableDateTime(json['createdAt']),
      updatedAt: _nullableDateTime(json['updatedAt']),
    );
  }

  final int id;
  final String name;
  final String avatarUrl;
  final int? categoryId;
  final int? subCategoryId;
  final PetGender gender;
  final DateTime? birthDate;
  final double weight;
  final bool isNeutered;
  final int vaccineCount;
  final PetCategory? category;
  final PetCategory? subCategory;
  final int ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get genderLabel => gender.label;

  String get breedLabel {
    final labels = [category?.name, subCategory?.name]
        .whereType<String>()
        .where((label) => label.trim().isNotEmpty)
        .toList(growable: false);
    return labels.isEmpty ? '未知品种' : labels.join(' - ');
  }

  String get vaccineLabel =>
      vaccineCount > 0 ? '已接种 $vaccineCount 针疫苗' : '待接种疫苗';

  String resolvedAvatarUrl({String assetBaseUrl = ApiConfig.assetBaseUrl}) {
    return resolveAssetUrl(avatarUrl, assetBaseUrl: assetBaseUrl);
  }
}

class PetDraft {
  const PetDraft({
    required this.name,
    required this.avatarUrl,
    required this.categoryId,
    required this.subCategoryId,
    required this.gender,
    required this.birthDate,
    required this.weightText,
    required this.isNeutered,
    required this.vaccineCountText,
  });

  factory PetDraft.empty() {
    return const PetDraft(
      name: '',
      avatarUrl: '',
      categoryId: null,
      subCategoryId: null,
      gender: PetGender.male,
      birthDate: null,
      weightText: '',
      isNeutered: false,
      vaccineCountText: '0',
    );
  }

  factory PetDraft.fromPet(Pet pet) {
    return PetDraft(
      name: pet.name,
      avatarUrl: pet.avatarUrl,
      categoryId: pet.categoryId,
      subCategoryId: pet.subCategoryId,
      gender: pet.gender,
      birthDate: pet.birthDate,
      weightText: _formatDecimal(pet.weight),
      isNeutered: pet.isNeutered,
      vaccineCountText: '${pet.vaccineCount}',
    );
  }

  final String name;
  final String avatarUrl;
  final int? categoryId;
  final int? subCategoryId;
  final PetGender gender;
  final DateTime? birthDate;
  final String weightText;
  final bool isNeutered;
  final String vaccineCountText;

  PetDraft copyWith({
    String? name,
    String? avatarUrl,
    int? categoryId,
    bool clearCategoryId = false,
    int? subCategoryId,
    bool clearSubCategoryId = false,
    PetGender? gender,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? weightText,
    bool? isNeutered,
    String? vaccineCountText,
  }) {
    return PetDraft(
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
      subCategoryId: clearSubCategoryId
          ? null
          : subCategoryId ?? this.subCategoryId,
      gender: gender ?? this.gender,
      birthDate: clearBirthDate ? null : birthDate ?? this.birthDate,
      weightText: weightText ?? this.weightText,
      isNeutered: isNeutered ?? this.isNeutered,
      vaccineCountText: vaccineCountText ?? this.vaccineCountText,
    );
  }

  Map<String, Object?> toCreateJson() => _toJson();

  Map<String, Object?> toUpdateJson() => _toJson();

  Map<String, Object?> _toJson() {
    final normalizedAvatar = avatarUrl.trim();
    final weight = double.tryParse(weightText.trim());
    final vaccineCount = int.tryParse(vaccineCountText.trim());
    return <String, Object?>{
      'name': name.trim(),
      if (normalizedAvatar.isNotEmpty) 'avatar': normalizedAvatar,
      'categoryId': ?categoryId,
      'subCategoryId': ?subCategoryId,
      'gender': gender.wireValue,
      if (birthDate != null) 'birthDate': formatPetDate(birthDate!),
      'weight': ?weight,
      'isNeutered': isNeutered,
      'vaccineCount': ?vaccineCount,
    };
  }
}

class PetImageUpload {
  const PetImageUpload({
    required this.id,
    required this.url,
    required this.filename,
    required this.originalName,
    required this.size,
  });

  final int? id;
  final String url;
  final String filename;
  final String originalName;
  final int size;

  String resolvedUrl({String assetBaseUrl = ApiConfig.assetBaseUrl}) {
    return resolveAssetUrl(url, assetBaseUrl: assetBaseUrl);
  }
}

abstract interface class PetGateway {
  Future<List<Pet>> loadMyPets({int? categoryId});

  Future<List<PetCategory>> loadCategoryTree();

  Future<Pet> loadPet(int id);

  Future<Pet> createPet(PetDraft draft);

  Future<Pet> updatePet(int id, PetDraft draft);

  Future<void> deletePet(int id);

  Future<PetImageUpload> uploadAvatar({
    required String filePath,
    String? filename,
  });
}

String formatPetAge(DateTime? birthDate, {DateTime? now}) {
  if (birthDate == null) return '未知';
  final todayValue = now ?? DateTime.now();
  final today = DateTime(todayValue.year, todayValue.month, todayValue.day);
  final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
  if (birth.isAfter(today)) return '未知年龄';

  var years = today.year - birth.year;
  var months = today.month - birth.month;
  if (today.day < birth.day) months -= 1;
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  if (years < 1) return '$months 个月';
  if (years == 1 && months > 0) return '$years 岁 $months 个月';
  return '$years 岁';
}

String formatPetDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final month = '${normalized.month}'.padLeft(2, '0');
  final day = '${normalized.day}'.padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

PetCategory? _nullableCategory(Object? value) {
  if (value == null) return null;
  return PetCategory.fromJson(_asMap(value, 'pet category'));
}

Map<String, Object?> _asMap(Object? value, String name) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw FormatException('$name must be a JSON object.');
}

List<Object?> _asList(Object? value, String name) {
  if (value is List) return value;
  throw FormatException('$name must be a JSON array.');
}

String _requiredString(Object? value, String name) {
  final result = _trimmedString(value);
  if (result.isNotEmpty) return result;
  throw FormatException('$name must be a non-empty string.');
}

String _trimmedString(Object? value) {
  return value is String ? value.trim() : '';
}

int _requiredInt(Object? value, String name) {
  final result = _nullableInt(value);
  if (result != null) return result;
  throw FormatException('$name must be an integer.');
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

double? _nullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}

DateTime? _nullableDateOnly(Object? value) {
  final raw = _trimmedString(value);
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw const FormatException('pet birthDate is invalid.');
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _nullableDateTime(Object? value) {
  final raw = _trimmedString(value);
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw const FormatException('pet date is invalid.');
  return parsed;
}

String _formatDecimal(double value) {
  if (value == value.roundToDouble()) return '${value.toInt()}';
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
