import 'dart:io';

import '../config/api_config.dart';

const _localPathPrefixes = <String>[
  '/data/',
  '/var/',
  '/private/',
  '/tmp/',
  '/storage/',
  '/sdcard/',
  '/Users/',
  '/home/',
];

String resolveAssetUrl(
  String? rawValue, {
  String assetBaseUrl = ApiConfig.assetBaseUrl,
  String uploadBaseUrl = ApiConfig.assetBaseUrl,
}) {
  final value = rawValue?.trim() ?? '';
  if (value.isEmpty) return '';
  if (isLocalMediaPath(value) || value.startsWith('data:')) return value;

  final uri = Uri.tryParse(value);
  if (uri == null) return '';
  if (uri.hasScheme) {
    return uri.scheme == 'http' || uri.scheme == 'https' ? value : '';
  }
  final normalizedPath = value.replaceFirst(RegExp(r'^/+'), '');
  final effectiveBaseUrl = normalizedPath.startsWith('uploads/')
      ? uploadBaseUrl
      : assetBaseUrl;
  return joinAssetUrl(effectiveBaseUrl, value);
}

File? resolveLocalFile(String? rawValue) {
  final value = rawValue?.trim() ?? '';
  if (!isLocalMediaPath(value)) return null;
  if (value.startsWith('file://')) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'file') return null;
    try {
      return File.fromUri(uri);
    } on ArgumentError {
      return null;
    }
  }
  return File(value);
}

bool isLocalMediaPath(String? rawValue) {
  final value = rawValue?.trim() ?? '';
  if (value.isEmpty) return false;
  if (value.startsWith('file://')) return true;
  if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) return true;
  return _localPathPrefixes.any(value.startsWith);
}

String joinAssetUrl(String baseUrl, String assetPath) {
  final normalizedBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  final normalizedPath = assetPath.trim().replaceFirst(RegExp(r'^/+'), '');
  if (normalizedBase.isEmpty || normalizedPath.isEmpty) return '';

  final baseUri = Uri.tryParse(normalizedBase);
  if (baseUri == null ||
      !baseUri.hasScheme ||
      (baseUri.scheme != 'http' && baseUri.scheme != 'https')) {
    return '';
  }
  return '$normalizedBase/$normalizedPath';
}
