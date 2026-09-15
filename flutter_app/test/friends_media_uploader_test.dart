import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pet_hospital_flutter/core/media/background_media_uploader.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_media_uploader.dart';

void main() {
  late Directory directory;
  late File mediaFile;
  late File thumbnailFile;
  late File voiceFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('friends-upload-test-');
    mediaFile = await File('${directory.path}/media.mp4').writeAsBytes([1, 2]);
    thumbnailFile = await File(
      '${directory.path}/cover.jpg',
    ).writeAsBytes([3, 4]);
    voiceFile = await File('${directory.path}/voice.m4a').writeAsBytes([5, 6]);
  });

  tearDown(() => directory.delete(recursive: true));

  test('图片上传使用 Bearer、chat 分类和正确 MIME', () async {
    final client = _RecordingClient(_successResponse());
    final uploader = FriendsMediaUploader(
      baseUrl: 'https://example.test/',
      tokenProvider: () async => ' token ',
      client: client,
    );

    final result = await uploader.uploadImage(
      filePath: mediaFile.path,
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
    );

    final request = client.request!;
    expect(request.url.toString(), 'https://example.test/upload/image');
    expect(request.headers['Authorization'], 'Bearer token');
    expect(request.headers.containsKey('Content-Type'), isFalse);
    expect(request.fields['category'], 'chat');
    expect(request.files.single.field, 'file');
    expect(request.files.single.filename, 'photo.jpg');
    expect(request.files.single.contentType.toString(), 'image/jpeg');
    expect(result.url, '/uploads/media.mp4');
  });

  test('视频上传包含 category query 和服务端允许的 MIME', () async {
    final client = _RecordingClient(_successResponse());
    final uploader = FriendsMediaUploader(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: client,
    );

    final result = await uploader.uploadVideo(
      filePath: mediaFile.path,
      fileName: 'video.mp4',
      mimeType: 'video/mp4',
      thumbnailPath: thumbnailFile.path,
    );

    final request = client.request!;
    expect(request.url.queryParameters['category'], 'chat-video');
    expect(request.headers['Authorization'], 'Bearer token');
    expect(request.files.map((file) => file.field), ['file', 'thumbnail']);
    expect(request.files[0].contentType.toString(), 'video/mp4');
    expect(request.files[1].contentType.toString(), 'image/jpeg');
    expect(result.thumbnail, '/uploads/thumbnails/media.jpg');
  });

  test('大媒体使用原生后台上传响应，不重复走 HTTP', () async {
    final client = _RecordingClient(_successResponse());
    final backgroundUploader = _CompletedBackgroundUploader(
      const BackgroundMediaUploadResponse(
        statusCode: 201,
        body: '{"code":0,"data":{"url":"/uploads/background.mp4"}}',
      ),
    );
    final uploader = FriendsMediaUploader(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: client,
      backgroundUploader: backgroundUploader,
    );

    final result = await uploader.uploadVideo(
      filePath: mediaFile.path,
      fileName: 'video.mp4',
      mimeType: 'video/mp4',
      thumbnailPath: thumbnailFile.path,
    );

    expect(result.url, '/uploads/background.mp4');
    expect(client.request, isNull);
    expect(backgroundUploader.uri?.queryParameters['category'], 'chat-video');
    expect(backgroundUploader.files.map((file) => file.field), [
      'file',
      'thumbnail',
    ]);
  });

  test('视频未提供封面时自动抽帧并在上传后清理临时文件', () async {
    final generatedThumbnail = await File(
      '${directory.path}/generated-cover.jpg',
    ).writeAsBytes([7, 8]);
    final client = _RecordingClient(_successResponse());
    final uploader = FriendsMediaUploader(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: client,
      videoThumbnailGenerator: (path) async {
        expect(path, mediaFile.path);
        return generatedThumbnail.path;
      },
    );

    await uploader.uploadVideo(
      filePath: mediaFile.path,
      fileName: 'video.mp4',
      mimeType: 'video/mp4',
    );

    expect(client.request!.files.map((file) => file.field), [
      'file',
      'thumbnail',
    ]);
    expect(await generatedThumbnail.exists(), isFalse);
  });

  test('语音上传使用 Bearer、chat-voice 分类和 M4A MIME', () async {
    final client = _RecordingClient(_successResponse());
    final uploader = FriendsMediaUploader(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: client,
    );

    await uploader.uploadVoice(
      filePath: voiceFile.path,
      fileName: 'voice.m4a',
      mimeType: 'audio/x-m4a',
    );

    final request = client.request!;
    expect(request.url.path, '/upload/file');
    expect(request.url.queryParameters['category'], 'chat-voice');
    expect(request.headers['Authorization'], 'Bearer token');
    expect(request.files.single.field, 'file');
    expect(request.files.single.filename, 'voice.m4a');
    expect(request.files.single.contentType.toString(), 'audio/x-m4a');
  });

  test('缺少 Token 或响应 URL 时拒绝上传结果', () async {
    final noToken = FriendsMediaUploader(
      baseUrl: 'https://example.test',
      tokenProvider: () async => null,
      client: _RecordingClient(_successResponse()),
    );
    expect(
      () => noToken.uploadImage(
        filePath: mediaFile.path,
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
      ),
      throwsA(isA<ApiException>()),
    );

    final invalid = FriendsMediaUploader(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: _RecordingClient(
        http.StreamedResponse(
          Stream.value(utf8.encode('{"code":0,"data":{}}')),
          200,
        ),
      ),
    );
    expect(
      () => invalid.uploadImage(
        filePath: mediaFile.path,
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('文件地址'),
        ),
      ),
    );
  });

  test('上传前拒绝 HEIC 和后端不支持的媒体格式', () async {
    final client = _RecordingClient(_successResponse());
    final uploader = FriendsMediaUploader(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: client,
    );

    await expectLater(
      uploader.uploadImage(
        filePath: mediaFile.path,
        fileName: 'photo.heic',
        mimeType: 'image/heic',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('HEIC/HEIF'),
        ),
      ),
    );
    await expectLater(
      uploader.uploadVideo(
        filePath: mediaFile.path,
        fileName: 'video.3gp',
        mimeType: 'video/3gpp',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('视频仅支持'),
        ),
      ),
    );
    expect(client.request, isNull);
  });

  test('HTTP 200 业务失败保留响应体中的真实状态码', () async {
    final uploader = FriendsMediaUploader(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: _RecordingClient(
        http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'success': false,
                'code': 'UNSUPPORTED_MEDIA_TYPE',
                'statusCode': 415,
                'message': '不支持的媒体格式',
              }),
            ),
          ),
          200,
        ),
      ),
    );

    await expectLater(
      uploader.uploadImage(
        filePath: mediaFile.path,
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 415)
            .having((error) => error.code, 'code', 'UNSUPPORTED_MEDIA_TYPE'),
      ),
    );
  });
}

http.StreamedResponse _successResponse() {
  return http.StreamedResponse(
    Stream.value(
      utf8.encode(
        jsonEncode({
          'code': 0,
          'data': {
            'url': '/uploads/media.mp4',
            'thumbnail': '/uploads/thumbnails/media.jpg',
            'width': 640,
            'height': 480,
            'size': 2,
            'originalName': 'media.mp4',
          },
        }),
      ),
    ),
    200,
  );
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.response);

  final http.StreamedResponse response;
  http.MultipartRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request as http.MultipartRequest;
    return response;
  }
}

class _CompletedBackgroundUploader implements BackgroundMediaUploadGateway {
  _CompletedBackgroundUploader(this.response);

  final BackgroundMediaUploadResponse response;
  Uri? uri;
  List<BackgroundMediaUploadFile> files = const [];

  @override
  Future<BackgroundMediaUploadResponse?> upload({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<BackgroundMediaUploadFile> files,
  }) async {
    this.uri = uri;
    this.files = files;
    return response;
  }
}
