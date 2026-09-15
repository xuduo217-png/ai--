import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundMediaUploadFile {
  const BackgroundMediaUploadFile({
    required this.field,
    required this.path,
    required this.fileName,
    required this.mimeType,
  });

  final String field;
  final String path;
  final String fileName;
  final String mimeType;

  Map<String, String> toMap() => {
    'field': field,
    'path': path,
    'fileName': fileName,
    'mimeType': mimeType,
  };
}

class BackgroundMediaUploadResponse {
  const BackgroundMediaUploadResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class BackgroundMediaUploadException implements Exception {
  const BackgroundMediaUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class BackgroundMediaUploadGateway {
  /// 返回 null 表示当前平台未接入原生后台上传，应回退到调用方的普通 HTTP 上传。
  Future<BackgroundMediaUploadResponse?> upload({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<BackgroundMediaUploadFile> files,
  });
}

class BackgroundMediaUploader implements BackgroundMediaUploadGateway {
  BackgroundMediaUploader({
    MethodChannel? channel,
    Duration pollInterval = _defaultPollInterval,
    int largeMediaThreshold = _defaultLargeMediaThreshold,
  }) : assert(!pollInterval.isNegative),
       assert(largeMediaThreshold > 0),
       _channel = channel ?? _defaultChannel,
       _pollInterval = pollInterval,
       _largeMediaThreshold = largeMediaThreshold;

  static const _defaultLargeMediaThreshold = 5 * 1024 * 1024;
  static const _defaultPollInterval = Duration(seconds: 1);
  static const _defaultChannel = MethodChannel(
    'com.good.pet.hospital/background_media_upload',
  );

  final MethodChannel _channel;
  final Duration _pollInterval;
  final int _largeMediaThreshold;

  @override
  Future<BackgroundMediaUploadResponse?> upload({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<BackgroundMediaUploadFile> files,
  }) async {
    if (kIsWeb || files.isEmpty || !await _shouldUseBackgroundUpload(files)) {
      return null;
    }

    final taskId = await _taskId(uri, headers, fields, files);
    try {
      final scheduledTaskId = await _channel.invokeMethod<String>('enqueue', {
        'taskId': taskId,
        'url': uri.toString(),
        'headers': headers,
        'fields': fields,
        'files': files.map((file) => file.toMap()).toList(growable: false),
      });
      if (scheduledTaskId == null || scheduledTaskId.isEmpty) {
        return null;
      }
      return await _awaitCompletion(scheduledTaskId);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      final message = error.message?.trim();
      throw BackgroundMediaUploadException(
        message == null || message.isEmpty ? '无法启动媒体后台上传，请稍后重试' : message,
      );
    }
  }

  Future<bool> _shouldUseBackgroundUpload(
    List<BackgroundMediaUploadFile> files,
  ) async {
    var totalSize = 0;
    for (final file in files) {
      final localFile = File(file.path);
      if (!await localFile.exists()) return false;
      totalSize += await localFile.length();
    }
    return totalSize >= _largeMediaThreshold;
  }

  Future<String> _taskId(
    Uri uri,
    Map<String, String> headers,
    Map<String, String> fields,
    List<BackgroundMediaUploadFile> files,
  ) async {
    final identity = StringBuffer(uri.toString())
      ..write('|')
      ..writeAll(
        headers.entries.map((entry) => '${entry.key}=${entry.value}'),
        '&',
      )
      ..write('|')
      ..writeAll(
        fields.entries.map((entry) => '${entry.key}=${entry.value}'),
        '&',
      );
    for (final file in files) {
      final stat = await File(file.path).stat();
      identity
        ..write('|')
        ..write(file.field)
        ..write('|')
        ..write(file.path)
        ..write('|')
        ..write(stat.size)
        ..write('|')
        ..write(stat.modified.microsecondsSinceEpoch);
    }
    return 'media_${_fnv1a(identity.toString())}';
  }

  Future<BackgroundMediaUploadResponse> _awaitCompletion(String taskId) async {
    while (true) {
      await Future<void>.delayed(_pollInterval);
      final raw = await _channel.invokeMethod<Object?>('status', {
        'taskId': taskId,
      });
      if (raw is! Map) continue;
      final state = '${raw['state'] ?? ''}';
      if (state == 'completed') {
        return BackgroundMediaUploadResponse(
          statusCode: _toInt(raw['statusCode']),
          body: '${raw['body'] ?? ''}',
        );
      }
      if (state == 'failed') {
        final message = '${raw['message'] ?? ''}'.trim();
        throw BackgroundMediaUploadException(
          message.isEmpty ? '媒体后台上传失败，请检查网络后重试' : message,
        );
      }
    }
  }
}

int _toInt(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  _ => int.tryParse('$value') ?? 0,
};

String _fnv1a(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toUnsigned(32).toRadixString(16);
}
