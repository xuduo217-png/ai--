import '../../../core/network/api_client.dart';
import '../domain/pet_models.dart';

class PetRepository implements PetGateway {
  const PetRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<Pet>> loadMyPets({int? categoryId}) async {
    final response = await _apiClient.get(
      '/pets/my',
      queryParameters: {'categoryId': categoryId},
    );
    return _asList(response, 'pet list response')
        .map((item) => Pet.fromJson(_asMap(item, 'pet list item')))
        .toList(growable: false);
  }

  @override
  Future<List<PetCategory>> loadCategoryTree() async {
    final response = await _apiClient.get('/pet-categories/tree');
    return _asList(response, 'pet category tree response')
        .map(
          (item) =>
              PetCategory.fromJson(_asMap(item, 'pet category tree item')),
        )
        .toList(growable: false);
  }

  @override
  Future<Pet> loadPet(int id) async {
    final response = await _apiClient.get('/pets/$id');
    return Pet.fromJson(_asMap(response, 'pet detail response'));
  }

  @override
  Future<Pet> createPet(PetDraft draft) async {
    final response = await _apiClient.post(
      '/pets',
      body: draft.toCreateJson(),
      authenticated: true,
    );
    return Pet.fromJson(_asMap(response, 'create pet response'));
  }

  @override
  Future<Pet> updatePet(int id, PetDraft draft) async {
    final response = await _apiClient.put(
      '/pets/$id',
      body: draft.toUpdateJson(),
    );
    return Pet.fromJson(_asMap(response, 'update pet response'));
  }

  @override
  Future<void> deletePet(int id) async {
    await _apiClient.delete('/pets/$id');
  }

  @override
  Future<PetImageUpload> uploadAvatar({
    required String filePath,
    String? filename,
  }) async {
    final response = await _apiClient.uploadFile(
      '/upload/image',
      filePath: filePath,
      fieldName: 'file',
      filename: filename,
      fields: const {'category': 'pet-avatar'},
      authenticated: true,
    );
    final json = _asMap(response, 'pet image upload response');
    return PetImageUpload(
      id: _nullableInt(json['id']),
      url: _requiredString(json['url'], 'upload url'),
      filename: _requiredString(json['filename'], 'upload filename'),
      originalName: _requiredString(
        json['originalName'],
        'upload originalName',
      ),
      size: _requiredInt(json['size'], 'upload size'),
    );
  }
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
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$name must be a non-empty string.');
}

int _requiredInt(Object? value, String name) {
  final parsed = _nullableInt(value);
  if (parsed != null) return parsed;
  throw FormatException('$name must be an integer.');
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
