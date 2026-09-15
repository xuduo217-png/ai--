import '../../../core/network/asset_url_resolver.dart';

Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}

List<dynamic> asJsonList(Object? value) {
  return value is List ? List<dynamic>.from(value) : const [];
}

Object? unwrapData(Object? value) {
  final map = asJsonMap(value);
  if (map.isNotEmpty && map.containsKey('data')) {
    return map['data'];
  }
  return value;
}

int jsonInt(Object? value, [int fallback = 0]) {
  return switch (value) {
    final int result => result,
    final num result => result.toInt(),
    final Object result => int.tryParse('$result') ?? fallback,
    null => fallback,
  };
}

double jsonDouble(Object? value, [double fallback = 0]) {
  return switch (value) {
    final num result => result.toDouble(),
    final Object result => double.tryParse('$result') ?? fallback,
    null => fallback,
  };
}

bool jsonBool(Object? value, [bool fallback = false]) {
  if (value == null) return fallback;
  return value == true || value == 1 || value == '1' || value == 'true';
}

String jsonString(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  return '$value';
}

String? jsonNullableString(Object? value) {
  final normalized = jsonString(value).trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? jsonDateTime(Object? value) {
  final normalized = jsonNullableString(value);
  return normalized == null ? null : DateTime.tryParse(normalized);
}

String resolveMallImage(String baseUrl, Object? value) {
  final path = jsonString(value).trim();
  if (path.isEmpty || path.startsWith('assets/')) return '';
  return resolveAssetUrl(path, assetBaseUrl: baseUrl);
}

Map<String, Object?> compactJson(Map<String, Object?> source) {
  return {
    for (final entry in source.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
