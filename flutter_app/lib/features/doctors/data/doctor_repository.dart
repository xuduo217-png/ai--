import '../../../core/network/api_client.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../domain/doctor_models.dart';

class DoctorRepository implements DoctorDirectoryGateway {
  const DoctorRepository(this._apiClient);

  static const _pageSize = 10;

  final ApiClient _apiClient;

  @override
  Future<DoctorDirectoryPage> loadDoctors({
    required int page,
    required bool goldOnly,
  }) async {
    final payload = _asMap(
      await _apiClient.get(
        '/doctors',
        authenticated: false,
        queryParameters: {
          'page': page,
          'pageSize': _pageSize,
          'isActive': 1,
          'sortBy': 'rating',
          'sortOrder': 'DESC',
          if (goldOnly) 'isGoldDoctor': 1,
        },
      ),
    );
    final pagination = _asMapOrEmpty(payload['pagination']);
    final items = _asList(payload['data'])
        .map((item) => _parseDoctor(_asMap(item)))
        .where((doctor) => doctor.id > 0)
        .toList(growable: false);
    final resolvedPage = _toInt(pagination['page'], fallback: page);
    final total = _toInt(pagination['total']);
    final pageSize = _toInt(
      pagination['pageSize'] ?? pagination['limit'],
      fallback: _pageSize,
    );
    final totalPages = _toInt(
      pagination['totalPages'],
      fallback: pageSize > 0 ? (total / pageSize).ceil() : resolvedPage,
    );

    return DoctorDirectoryPage(
      items: items,
      page: resolvedPage,
      totalPages: totalPages,
    );
  }

  @override
  Future<DoctorProfile> loadDoctor(int doctorId) async {
    if (doctorId <= 0) throw const FormatException('医生信息不完整');
    return _parseDoctor(
      _asMap(await _apiClient.get('/doctors/$doctorId', authenticated: false)),
    );
  }

  DoctorProfile _parseDoctor(Map<String, dynamic> doctor) {
    final serviceItems = _asList(doctor['serviceItems']);
    final firstService = serviceItems.isEmpty
        ? const <String, dynamic>{}
        : _asMap(serviceItems.first);
    final specialty = '${doctor['specialty'] ?? ''}'.trim();
    final description = '${doctor['description'] ?? ''}'.trim();

    return DoctorProfile(
      id: _toInt(doctor['id']),
      name: '${doctor['name'] ?? ''}'.trim(),
      avatarUrl: _imageUrl('${doctor['avatar'] ?? ''}'),
      username: '${doctor['username'] ?? ''}'.trim(),
      specialty: specialty,
      description: description.isNotEmpty
          ? description
          : specialty.isNotEmpty
          ? specialty
          : '专业医生，提供优质的健康咨询服务',
      experience: _toInt(doctor['experience']),
      rating: _toDouble(doctor['rating']),
      consultationCount: _toInt(doctor['consultationCount']),
      price: _formatPrice(
        firstService['price'] ?? doctor['consultationPrice'] ?? 0,
      ),
      isGold: _toBool(doctor['isGoldDoctor']),
      online: '${doctor['onlineStatus'] ?? ''}'.toUpperCase() == 'ONLINE',
      hospitalName: _nestedName(doctor['hospital']),
      departmentName: _nestedName(doctor['department']),
    );
  }

  String _imageUrl(String value) {
    return resolveAssetUrl(value, assetBaseUrl: _apiClient.baseUrl);
  }

  String? _nestedName(Object? value) {
    final name = '${_asMapOrEmpty(value)['name'] ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }

  String _formatPrice(Object? value) {
    final price = _toDouble(value);
    return price.toStringAsFixed(2);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('服务器返回的数据格式不正确');
  }

  Map<String, dynamic> _asMapOrEmpty(Object? value) {
    try {
      return _asMap(value);
    } on FormatException {
      return const {};
    }
  }

  List<dynamic> _asList(Object? value) => value is List ? value : const [];

  int _toInt(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  bool _toBool(Object? value) =>
      value == true || value == 1 || value == '1' || value == 'true';
}
