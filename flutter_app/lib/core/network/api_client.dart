import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path_util;

import '../config/api_config.dart';
import '../media/background_media_uploader.dart';
import '../media/video_thumbnail_service.dart';

typedef TokenProvider = Future<String?> Function();

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.validationErrors = const [],
  });

  final String message;
  final int? statusCode;
  final Object? code;
  final List<String> validationErrors;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required http.Client client,
    required TokenProvider tokenProvider,
    VideoThumbnailFileGenerator? videoThumbnailGenerator,
    BackgroundMediaUploadGateway? backgroundUploader,
  }) : _client = client,
       _tokenProvider = tokenProvider,
       _videoThumbnailGenerator = videoThumbnailGenerator,
       _backgroundUploader = backgroundUploader ?? BackgroundMediaUploader();

  final String baseUrl;
  final http.Client _client;
  final TokenProvider _tokenProvider;
  final VideoThumbnailFileGenerator? _videoThumbnailGenerator;
  final BackgroundMediaUploadGateway _backgroundUploader;

  Future<Object?> get(
    String path, {
    bool authenticated = true,
    Map<String, Object?> queryParameters = const {},
  }) {
    return _send(
      'GET',
      path,
      authenticated: authenticated,
      queryParameters: queryParameters,
    );
  }

  Future<Object?> post(
    String path, {
    Object? body = const <String, Object?>{},
    bool authenticated = false,
    bool allowBusinessFailure = false,
    Map<String, String> additionalHeaders = const {},
  }) {
    return _send(
      'POST',
      path,
      body: body,
      authenticated: authenticated,
      allowBusinessFailure: allowBusinessFailure,
      additionalHeaders: additionalHeaders,
    );
  }

  Future<Object?> put(
    String path, {
    Object? body = const <String, Object?>{},
    bool authenticated = true,
  }) {
    return _send('PUT', path, body: body, authenticated: authenticated);
  }

  Future<Object?> patch(
    String path, {
    Object? body = const <String, Object?>{},
    bool authenticated = true,
  }) {
    return _send('PATCH', path, body: body, authenticated: authenticated);
  }

  Future<Object?> delete(
    String path, {
    Object? body,
    bool authenticated = true,
    Map<String, Object?> queryParameters = const {},
  }) {
    return _send(
      'DELETE',
      path,
      body: body,
      authenticated: authenticated,
      queryParameters: queryParameters,
    );
  }

  Future<Object?> uploadFile(
    String path, {
    required String filePath,
    String fieldName = 'file',
    String? filename,
    Map<String, String> fields = const {},
    Map<String, String> additionalFiles = const {},
    bool authenticated = true,
  }) async {
    final contentType = _uploadContentType(filePath, filename);
    _validateUploadEndpoint(path, contentType);
    final uri = _buildUri(path);
    final headers = await _headers(
      authenticated: authenticated,
      includeContentType: false,
    );
    final uploadFiles = <BackgroundMediaUploadFile>[
      BackgroundMediaUploadFile(
        field: fieldName,
        path: filePath,
        fileName: filename ?? path_util.basename(filePath),
        mimeType: contentType.toString(),
      ),
    ];
    for (final file in additionalFiles.entries) {
      final additionalContentType = _uploadContentType(file.value, null);
      if (file.key == 'thumbnail' && additionalContentType.type != 'image') {
        throw const ApiException('视频封面必须是 JPG、PNG、GIF 或 WebP 图片');
      }
      uploadFiles.add(
        BackgroundMediaUploadFile(
          field: file.key,
          path: file.value,
          fileName: path_util.basename(file.value),
          mimeType: additionalContentType.toString(),
        ),
      );
    }

    try {
      final backgroundResponse = await _backgroundUploader.upload(
        uri: uri,
        headers: headers,
        fields: fields,
        files: uploadFiles,
      );
      if (backgroundResponse != null) {
        final payload = _handleResponse(
          http.Response(backgroundResponse.body, backgroundResponse.statusCode),
        );
        _validateUploadResponse(payload);
        return payload;
      }
    } on BackgroundMediaUploadException catch (error) {
      throw ApiException(error.message);
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields.addAll(fields);
    for (final file in uploadFiles) {
      request.files.add(
        await http.MultipartFile.fromPath(
          file.field,
          file.path,
          filename: file.fileName,
          contentType: MediaType.parse(file.mimeType),
        ),
      );
    }

    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(ApiConfig.uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final payload = _handleResponse(response);
      _validateUploadResponse(payload);
      return payload;
    } on TimeoutException catch (error) {
      throw ApiException(_networkErrorMessage(error));
    } on http.ClientException catch (error) {
      throw ApiException(_networkErrorMessage(error));
    }
  }

  Future<Object?> uploadVideo(
    String path, {
    required String filePath,
    String? filename,
    Map<String, String> fields = const {},
    bool authenticated = true,
  }) {
    return withGeneratedVideoThumbnail(
      videoPath: filePath,
      generator: _videoThumbnailGenerator,
      action: (thumbnailPath) => uploadFile(
        path,
        filePath: filePath,
        filename: filename,
        fields: fields,
        additionalFiles: {'thumbnail': ?thumbnailPath},
        authenticated: authenticated,
      ),
    );
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?> queryParameters = const {},
    required bool authenticated,
    bool allowBusinessFailure = false,
    Map<String, String> additionalHeaders = const {},
  }) async {
    final headers = {
      ...await _headers(authenticated: authenticated),
      ...additionalHeaders,
    };
    final uri = _buildUri(path, queryParameters: queryParameters);
    late final http.Response response;

    try {
      response = switch (method) {
        'GET' =>
          await _client.get(uri, headers: headers).timeout(ApiConfig.timeout),
        'POST' =>
          await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(ApiConfig.timeout),
        'PUT' =>
          await _client
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(ApiConfig.timeout),
        'PATCH' =>
          await _client
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(ApiConfig.timeout),
        'DELETE' =>
          await _client
              .delete(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(ApiConfig.timeout),
        _ => throw ArgumentError.value(method, 'method', '不支持的请求方法'),
      };
    } on TimeoutException catch (error) {
      throw ApiException(_networkErrorMessage(error));
    } on http.ClientException catch (error) {
      throw ApiException(_networkErrorMessage(error));
    }

    return _handleResponse(
      response,
      allowBusinessFailure: allowBusinessFailure,
    );
  }

  Future<Map<String, String>> _headers({
    required bool authenticated,
    bool includeContentType = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

    if (authenticated) {
      final token = await _tokenProvider();
      if (token == null || token.trim().isEmpty) {
        throw const ApiException('未登录，请先登录', statusCode: 401);
      }
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  Uri _buildUri(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final baseUri = Uri.parse('$normalizedBaseUrl$normalizedPath');
    if (queryParameters.isEmpty) {
      return baseUri;
    }
    return baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        for (final entry in queryParameters.entries)
          if (entry.value != null) entry.key: '${entry.value}',
      },
    );
  }

  Object? _handleResponse(
    http.Response response, {
    bool allowBusinessFailure = false,
  }) {
    final payload = _decodePayload(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toApiException(payload, statusCode: response.statusCode);
    }

    if (payload is Map<String, dynamic>) {
      final code = payload['code'];
      final success = payload['success'];
      final failed =
          (success == false && !allowBusinessFailure) ||
          (code != null && code != 0 && code.toString() != '0');

      if (failed) {
        throw _toApiException(payload, statusCode: response.statusCode);
      }

      if (payload.containsKey('data')) {
        final data = payload['data'];
        final pagination = _paginationFrom(payload);
        if (pagination != null) {
          return {'data': data, 'pagination': pagination};
        }
        return data;
      }
    }

    return payload;
  }

  Map<String, dynamic>? _paginationFrom(Map<String, dynamic> payload) {
    for (final key in const ['pagination', 'meta']) {
      final candidate = payload[key];
      if (candidate is Map &&
          candidate.keys.any(
            (field) => const {
              'total',
              'page',
              'pageSize',
              'limit',
              'totalPages',
            }.contains('$field'),
          )) {
        return candidate.map((key, value) => MapEntry('$key', value));
      }
    }
    if (payload.keys.any(
      (field) => const {
        'total',
        'page',
        'pageSize',
        'limit',
        'totalPages',
      }.contains(field),
    )) {
      return {
        for (final field in const [
          'total',
          'page',
          'pageSize',
          'limit',
          'totalPages',
        ])
          if (payload.containsKey(field)) field: payload[field],
      };
    }
    return null;
  }

  Object? _decodePayload(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      throw const ApiException('服务器返回了无法识别的数据');
    }
  }

  ApiException _toApiException(Object? payload, {required int statusCode}) {
    if (payload is Map<String, dynamic>) {
      final effectiveStatusCode = _errorStatusCode(payload, statusCode);
      final rawMessage = payload['message'];
      final validationErrors = switch (payload['validationErrors']) {
        final List<dynamic> errors => errors.map((item) => '$item').toList(),
        _ => switch (payload['details']) {
          final List<dynamic> details => details.map((item) {
            if (item is Map) {
              final product = '${item['productName'] ?? '商品'}';
              final sku = '${item['skuName'] ?? ''}'.trim();
              final available = item['available'];
              return '$product${sku.isEmpty ? '' : ' ($sku)'} 库存不足'
                  '${available == null ? '' : '，当前库存：$available'}';
            }
            return '$item';
          }).toList(),
          _ => const <String>[],
        },
      };
      final message = switch (rawMessage) {
        final String value when value.trim().isNotEmpty => value,
        final List<dynamic> values when values.isNotEmpty => '${values.first}',
        _ when validationErrors.isNotEmpty => validationErrors.first,
        _ => _httpErrorMessage(effectiveStatusCode),
      };

      return ApiException(
        message,
        statusCode: effectiveStatusCode,
        code: payload['code'] ?? payload['errorType'],
        validationErrors: validationErrors,
      );
    }

    return ApiException(_httpErrorMessage(statusCode), statusCode: statusCode);
  }

  int _errorStatusCode(Map<String, dynamic> payload, int fallbackStatusCode) {
    for (final candidate in [payload['statusCode'], payload['code']]) {
      final parsed = candidate is num
          ? candidate.toInt()
          : int.tryParse('${candidate ?? ''}');
      if (parsed != null && parsed >= 400 && parsed <= 599) return parsed;
    }
    return fallbackStatusCode;
  }

  String _networkErrorMessage(Object error) {
    if (error is TimeoutException) {
      return '请求超时，请检查网络后重试';
    }
    return '网络连接失败，请检查网络后重试';
  }

  String _httpErrorMessage(int statusCode) {
    return switch (statusCode) {
      401 => '手机号或密码错误',
      403 => '没有权限执行此操作',
      404 => '请求的资源不存在',
      >= 500 => '服务器开小差了，请稍后重试',
      _ => '请求失败，请稍后重试',
    };
  }
}

MediaType _uploadContentType(String filePath, String? filename) {
  final candidates = [filePath, filename];
  final extensions = candidates
      .map(
        (candidate) =>
            path_util.extension(candidate?.trim() ?? '').toLowerCase(),
      )
      .where((extension) => extension.isNotEmpty)
      .toList(growable: false);
  if (extensions.any(const {'.heic', '.heif'}.contains)) {
    throw const ApiException('暂不支持 HEIC/HEIF，请选择 JPG、PNG、GIF 或 WebP 图片');
  }

  for (final candidate in candidates) {
    final value = candidate?.trim() ?? '';
    if (value.isEmpty) continue;
    final mimeType = switch (path_util.extension(value).toLowerCase()) {
      '.jpg' || '.jpeg' || '.jpe' || '.jfif' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.pdf' => 'application/pdf',
      '.mp4' || '.m4v' => 'video/mp4',
      '.mpeg' || '.mpg' => 'video/mpeg',
      '.mov' => 'video/quicktime',
      '.avi' => 'video/x-msvideo',
      '.wmv' => 'video/x-ms-wmv',
      '.webm' => 'video/webm',
      '.mp3' => 'audio/mpeg',
      '.m4a' => 'audio/x-m4a',
      '.aac' => 'audio/aac',
      '.amr' => 'audio/amr',
      '.ogg' => 'audio/ogg',
      '.wav' => 'audio/wav',
      _ => null,
    };
    if (mimeType != null) return MediaType.parse(mimeType);
  }
  throw const ApiException(
    '暂不支持该文件格式，请选择 JPG、PNG、GIF、WebP、PDF、MP4、MOV、MPEG、AVI、WMV、WebM、MP3、M4A、AAC、AMR、OGG 或 WAV 文件',
  );
}

void _validateUploadEndpoint(String requestPath, MediaType contentType) {
  final endpoint = Uri.parse(requestPath).path;
  if (endpoint.endsWith('/upload/image') && contentType.type != 'image') {
    throw const ApiException('图片上传仅支持 JPG、PNG、GIF 或 WebP 格式');
  }
  if (endpoint.endsWith('/upload/file') && contentType.type == 'image') {
    throw const ApiException('图片请使用图片上传入口');
  }
}

void _validateUploadResponse(Object? payload) {
  if (payload is Map) {
    final url = '${payload['url'] ?? ''}'.trim();
    if (url.isNotEmpty) return;
  }
  throw const ApiException('上传成功，但服务器未返回文件地址');
}
