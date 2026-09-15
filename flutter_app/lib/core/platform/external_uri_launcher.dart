import 'package:flutter/services.dart';

import '../config/api_config.dart';
import '../network/asset_url_resolver.dart';

abstract interface class ExternalUriLauncher {
  /// Capability hint only. Package visibility can produce false negatives, so
  /// user-initiated actions should still call [launch] directly.
  Future<bool> canLaunch(Uri uri);

  Future<bool> launch(Uri uri);
}

class MethodChannelExternalUriLauncher implements ExternalUriLauncher {
  const MethodChannelExternalUriLauncher({
    MethodChannel channel = const MethodChannel(
      'com.good.pet.hospital/external_uri',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> canLaunch(Uri uri) {
    return _invoke('canLaunchUri', uri);
  }

  @override
  Future<bool> launch(Uri uri) {
    return _invoke('launchUri', uri);
  }

  Future<bool> _invoke(String method, Uri uri) async {
    if (!_isAllowedExternalUri(uri)) return false;
    try {
      return await _channel.invokeMethod<bool>(method, {
            'uri': uri.toString(),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

Uri? resolveSafeWebUri(String value, {required String baseUrl}) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;

  final rawUri = Uri.tryParse(normalized);
  final baseUri = Uri.tryParse(baseUrl.trim());
  if (rawUri == null || baseUri == null || !_isWebUri(baseUri)) return null;

  if (!rawUri.hasScheme &&
      rawUri.path.replaceFirst(RegExp(r'^/+'), '').startsWith('uploads/')) {
    final uploadUrl = joinAssetUrl(ApiConfig.assetBaseUrl, normalized);
    final uploadUri = Uri.tryParse(uploadUrl);
    return uploadUri != null && _isWebUri(uploadUri) ? uploadUri : null;
  }

  final origin = Uri(
    scheme: baseUri.scheme,
    host: baseUri.host,
    port: baseUri.hasPort ? baseUri.port : null,
    path: '/',
  );
  final resolved = rawUri.hasScheme ? rawUri : origin.resolveUri(rawUri);
  return _isWebUri(resolved) ? resolved : null;
}

bool _isAllowedExternalUri(Uri uri) {
  return _isWebUri(uri) ||
      (uri.scheme.toLowerCase() == 'tel' && uri.path.trim().isNotEmpty);
}

bool _isWebUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}
