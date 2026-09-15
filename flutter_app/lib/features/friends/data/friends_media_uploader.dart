import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path_util;

import '../../../core/config/api_config.dart';
import '../../../core/media/background_media_uploader.dart';
import '../../../core/media/video_thumbnail_service.dart';
import '../../../core/network/api_client.dart';

class FriendsMediaUploadResult {
  const FriendsMediaUploadResult({
    required this.url,
    this.thumbnail,
    this.width,
    this.height,
    this.size,
    this.originalName,
  });

  final String url;
  final String? thumbnail;
  final int? width;
  final int? height;
  final int? size;
  final String? originalName;
}

abstract interface class FriendsMediaUploaderGateway {
  Future<FriendsMediaUploadResult> uploadImage({
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  Future<FriendsMediaUploadResult> uploadVideo({
    required String filePath,
    required String fileName,
    required String mimeType,
    String? thumbnailPath,
  });

  Future<FriendsMediaUploadResult> uploadVoice({
    required String filePath,
    required String fileName,
    required String mimeType,
  });
}

class FriendsMediaUploader implements FriendsMediaUploaderGateway {
  FriendsMediaUploader({
    required String baseUrl,
    required TokenProvider tokenProvider,
    http.Client? client,
    VideoThumbnailFileGenerator? videoThumbnailGenerator,
    BackgroundMediaUploadGateway? backgroundUploader,
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _tokenProvider = tokenProvider,
       _client = client ?? http.Client(),
       _videoThumbnailGenerator = videoThumbnailGenerator,
       _backgroundUploader = backgroundUploader ?? BackgroundMediaUploader();

  final String _baseUrl;
  final TokenProvider _tokenProvider;
  final http.Client _client;
  final VideoThumbnailFileGenerator? _videoThumbnailGenerator;
  final BackgroundMediaUploadGateway _backgroundUploader;

  @override
  Future<FriendsMediaUploadResult> uploadImage({
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    final contentType = _validatedContentType(
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      allowedMimeTypes: _imageMimeTypes,
      allowedExtensions: _imageExtensions,
      unsupportedMessage: '图片仅支持 JPG、PNG、GIF 或 WebP 格式',
    );
    return _upload(
      uri: Uri.parse('$_baseUrl/upload/image'),
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
      fields: const {'category': 'chat'},
    );
  }

  @override
  Future<FriendsMediaUploadResult> uploadVideo({
    required String filePath,
    required String fileName,
    required String mimeType,
    String? thumbnailPath,
  }) async {
    final contentType = _validatedContentType(
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      allowedMimeTypes: _videoMimeTypes,
      allowedExtensions: _videoExtensions,
      unsupportedMessage: '视频仅支持 MP4、M4V、MOV、MPEG、AVI、WMV 或 WebM 格式',
    );
    final providedThumbnail = thumbnailPath?.trim();
    if (providedThumbnail != null &&
        providedThumbnail.isNotEmpty &&
        await File(providedThumbnail).exists()) {
      return _upload(
        uri: Uri.parse('$_baseUrl/upload/file?category=chat-video'),
        filePath: filePath,
        fileName: fileName,
        contentType: contentType,
        thumbnailPath: providedThumbnail,
      );
    }

    return withGeneratedVideoThumbnail(
      videoPath: filePath,
      generator: _videoThumbnailGenerator,
      action: (generatedThumbnailPath) => _upload(
        uri: Uri.parse('$_baseUrl/upload/file?category=chat-video'),
        filePath: filePath,
        fileName: fileName,
        contentType: contentType,
        thumbnailPath: generatedThumbnailPath,
      ),
    );
  }

  @override
  Future<FriendsMediaUploadResult> uploadVoice({
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    final contentType = _validatedContentType(
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      allowedMimeTypes: _audioMimeTypes,
      allowedExtensions: _audioExtensions,
      unsupportedMessage: '语音仅支持 MP3、M4A、AAC、AMR、OGG、WAV 或 WebM 格式',
    );
    return _upload(
      uri: Uri.parse('$_baseUrl/upload/file?category=chat-voice'),
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
    );
  }

  Future<FriendsMediaUploadResult> _upload({
    required Uri uri,
    required String filePath,
    required String fileName,
    Map<String, String> fields = const {},
    String? thumbnailPath,
    required MediaType contentType,
  }) async {
    final token = (await _tokenProvider())?.trim() ?? '';
    if (token.isEmpty) {
      throw const ApiException('未登录，请先登录', statusCode: 401);
    }

    final uploadFiles = <BackgroundMediaUploadFile>[
      BackgroundMediaUploadFile(
        field: 'file',
        path: filePath,
        fileName: fileName,
        mimeType: contentType.toString(),
      ),
    ];
    if (thumbnailPath != null &&
        thumbnailPath.trim().isNotEmpty &&
        await File(thumbnailPath).exists()) {
      uploadFiles.add(
        BackgroundMediaUploadFile(
          field: 'thumbnail',
          path: thumbnailPath,
          fileName: '${fileName}_cover.jpg',
          mimeType: 'image/jpeg',
        ),
      );
    }

    try {
      final backgroundResponse = await _backgroundUploader.upload(
        uri: uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        fields: fields,
        files: uploadFiles,
      );
      if (backgroundResponse != null) {
        return _parseResponse(
          http.Response(backgroundResponse.body, backgroundResponse.statusCode),
        );
      }
    } on BackgroundMediaUploadException catch (error) {
      throw ApiException(error.message);
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
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
      final fileSize = await File(filePath).length();
      _debugLog(
        'POST $uri file=$fileName mime=$contentType size=$fileSize '
        'thumbnail=${request.files.length > 1}',
      );
      final streamed = await _client
          .send(request)
          .timeout(ApiConfig.uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      _debugLog('POST $uri -> ${response.statusCode} body=${response.body}');
      return _parseResponse(response);
    } on ApiException catch (error, stackTrace) {
      _debugLog('POST $uri failed: $error', error, stackTrace);
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      _debugLog('POST $uri timed out', error, stackTrace);
      throw const ApiException('媒体上传超时，请检查网络后重试');
    } on Object catch (error, stackTrace) {
      _debugLog('POST $uri failed: $error', error, stackTrace);
      throw const ApiException('媒体上传失败，请检查网络后重试');
    }
  }

  FriendsMediaUploadResult _parseResponse(http.Response response) {
    Object? decoded;
    try {
      decoded = response.body.trim().isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('服务器返回了无法识别的上传结果');
    }
    final envelope = _asMap(decoded);
    final failed =
        response.statusCode < 200 ||
        response.statusCode >= 300 ||
        envelope['success'] == false ||
        (envelope['code'] != null && '${envelope['code']}' != '0');
    if (failed) {
      throw ApiException(
        _optionalString(envelope['message']) ?? '媒体上传失败，请稍后重试',
        statusCode: _errorStatusCode(envelope, response.statusCode),
        code: envelope['code'],
      );
    }

    final payload = _asMap(envelope['data']).isNotEmpty
        ? _asMap(envelope['data'])
        : envelope;
    final url = _optionalString(payload['url']);
    if (url == null) {
      throw const ApiException('上传成功，但服务器未返回文件地址');
    }
    return FriendsMediaUploadResult(
      url: url,
      thumbnail: _optionalString(payload['thumbnail']),
      width: _positiveInt(payload['width']),
      height: _positiveInt(payload['height']),
      size: _positiveInt(payload['size']),
      originalName: _optionalString(payload['originalName']),
    );
  }
}

const _imageMimeTypes = {'image/jpeg', 'image/png', 'image/gif', 'image/webp'};
const _imageExtensions = {
  '.jpg',
  '.jpeg',
  '.jpe',
  '.jfif',
  '.png',
  '.gif',
  '.webp',
};

const _videoMimeTypes = {
  'video/mp4',
  'video/x-m4v',
  'video/quicktime',
  'video/mpeg',
  'video/x-msvideo',
  'video/avi',
  'video/vnd.avi',
  'video/x-ms-wmv',
  'video/x-ms-asf',
  'video/webm',
};
const _videoExtensions = {
  '.mp4',
  '.m4v',
  '.mov',
  '.mpeg',
  '.mpg',
  '.avi',
  '.wmv',
  '.webm',
};

const _audioMimeTypes = {
  'audio/mp4',
  'audio/mpeg',
  'audio/aac',
  'audio/x-m4a',
  'audio/amr',
  'audio/ogg',
  'audio/wav',
  'audio/x-wav',
  'audio/webm',
};
const _audioExtensions = {
  '.mp3',
  '.m4a',
  '.aac',
  '.amr',
  '.ogg',
  '.wav',
  '.webm',
};

MediaType _validatedContentType({
  required String filePath,
  required String fileName,
  required String mimeType,
  required Set<String> allowedMimeTypes,
  required Set<String> allowedExtensions,
  required String unsupportedMessage,
}) {
  final extensions = [fileName, filePath]
      .map((candidate) => path_util.extension(candidate).toLowerCase())
      .where((extension) => extension.isNotEmpty)
      .toList(growable: false);
  final normalizedMimeType = mimeType.trim().toLowerCase();
  if (extensions.any(const {'.heic', '.heif'}.contains) ||
      const {'image/heic', 'image/heif'}.contains(normalizedMimeType)) {
    throw const ApiException('暂不支持 HEIC/HEIF，请选择 JPG、PNG、GIF 或 WebP 图片');
  }
  if (extensions.isEmpty || !allowedExtensions.contains(extensions.first)) {
    throw ApiException(unsupportedMessage);
  }

  late final MediaType parsed;
  try {
    parsed = MediaType.parse(normalizedMimeType);
  } on FormatException {
    throw ApiException(unsupportedMessage);
  }
  final baseMimeType = '${parsed.type}/${parsed.subtype}'.toLowerCase();
  if (!allowedMimeTypes.contains(baseMimeType)) {
    throw ApiException(unsupportedMessage);
  }
  return parsed;
}

int _errorStatusCode(Map<String, Object?> payload, int fallbackStatusCode) {
  for (final candidate in [payload['statusCode'], payload['code']]) {
    final parsed = candidate is num
        ? candidate.toInt()
        : int.tryParse('${candidate ?? ''}');
    if (parsed != null && parsed >= 400 && parsed <= 599) return parsed;
  }
  return fallbackStatusCode;
}

void _debugLog(String message, [Object? error, StackTrace? stackTrace]) {
  if (!kDebugMode) return;
  debugPrint('[FriendsMediaUploader] $message');
  if (error != null) debugPrint('[FriendsMediaUploader] error=$error');
  if (stackTrace != null) {
    debugPrintStack(
      label: '[FriendsMediaUploader] stackTrace',
      stackTrace: stackTrace,
    );
  }
}

Map<String, Object?> _asMap(Object? value) {
  return value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};
}

String? _optionalString(Object? value) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty ? null : text;
}

int? _positiveInt(Object? value) {
  final number = switch (value) {
    final int value => value,
    final num value => value.round(),
    _ => int.tryParse('$value'),
  };
  return number != null && number > 0 ? number : null;
}
