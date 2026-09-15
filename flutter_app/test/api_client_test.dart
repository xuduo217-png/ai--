import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/media/background_media_uploader.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';

void main() {
  test('解包服务端 code=0 的 data 数据', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 0,
            'data': {'access_token': 'token'},
            'message': 'Success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      tokenProvider: () async => null,
    );

    final result = await client.post('/auth/login/phone');

    expect(result, {'access_token': 'token'});
  });

  test('将业务失败响应转换为 ApiException', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'code': 'INVALID_CODE',
            'message': '验证码错误或已过期',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      tokenProvider: () async => null,
    );

    expect(
      () => client.post('/auth/verify-code'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '验证码错误或已过期',
        ),
      ),
    );
  });

  test('HTTP 200 业务失败使用响应体中的真实状态码', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': false,
              'code': 'FILE_TOO_LARGE',
              'statusCode': 413,
              'message': '文件过大',
            }),
          ),
          200,
        ),
      ),
      tokenProvider: () async => null,
    );

    await expectLater(
      client.post('/upload/image'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 413)
            .having((error) => error.code, 'code', 'FILE_TOO_LARGE'),
      ),
    );
  });

  test('认证请求自动添加 Bearer token', () async {
    late http.Request capturedRequest;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'code': 0, 'data': {}}), 200);
      }),
      tokenProvider: () async => 'saved-token',
    );

    await client.get('/auth/profile');

    expect(capturedRequest.headers['authorization'], 'Bearer saved-token');
  });

  test('GET 请求会编码查询参数并跳过空值', () async {
    late http.Request capturedRequest;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'code': 0, 'data': []}), 200);
      }),
      tokenProvider: () async => null,
    );

    await client.get(
      '/doctors',
      authenticated: false,
      queryParameters: const {
        'isGoldDoctor': 1,
        'showOnHome': true,
        'keyword': null,
      },
    );

    expect(capturedRequest.url.path, '/doctors');
    expect(capturedRequest.url.queryParameters, {
      'isGoldDoctor': '1',
      'showOnHome': 'true',
    });
  });

  test('PUT、PATCH、DELETE 使用正确方法、JSON 请求体和鉴权', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://example.test/api/',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {'ok': true},
          }),
          200,
        );
      }),
      tokenProvider: () async => ' saved-token ',
    );

    await client.put('/resource/1', body: const {'name': '新名称'});
    await client.patch('resource/1/status', body: const {'active': true});
    await client.delete(
      '/resource/1',
      body: const {'reason': '测试'},
      queryParameters: const {'force': true, 'empty': null},
    );

    expect(requests.map((request) => request.method), [
      'PUT',
      'PATCH',
      'DELETE',
    ]);
    expect(requests[0].url.path, '/api/resource/1');
    expect(jsonDecode(requests[0].body), {'name': '新名称'});
    expect(jsonDecode(requests[1].body), {'active': true});
    expect(requests[2].url.queryParameters, {'force': 'true'});
    expect(jsonDecode(requests[2].body), {'reason': '测试'});
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer saved-token',
      ),
      isTrue,
    );
  });

  test('保留服务端分页 envelope，供 Repository 读取列表与分页', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 0,
            'data': [
              {'id': 1},
            ],
            'pagination': {
              'total': 9,
              'page': 2,
              'pageSize': 1,
              'totalPages': 9,
            },
          }),
          200,
        ),
      ),
      tokenProvider: () async => null,
    );

    final result = await client.get('/items', authenticated: false);

    expect(result, {
      'data': [
        {'id': 1},
      ],
      'pagination': {'total': 9, 'page': 2, 'pageSize': 1, 'totalPages': 9},
    });
  });

  test('兼容分页字段与 data 同级的列表响应', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'id': 2},
            ],
            'total': 5,
            'page': 1,
            'pageSize': 1,
            'totalPages': 5,
          }),
          200,
        ),
      ),
      tokenProvider: () async => null,
    );

    final result = await client.get('/favorites', authenticated: false);

    expect(result, {
      'data': [
        {'id': 2},
      ],
      'pagination': {'total': 5, 'page': 1, 'pageSize': 1, 'totalPages': 5},
    });
  });

  test('multipart 上传附带 token、字段和文件', () async {
    final directory = await Directory.systemTemp.createTemp('api-client-test-');
    final file = File('${directory.path}/avatar.jpg');
    await file.writeAsString('image-content');
    final capturingClient = _CapturingClient();
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: capturingClient,
      tokenProvider: () async => 'upload-token',
    );

    try {
      final result = await client.uploadFile(
        '/upload/image',
        filePath: file.path,
        filename: 'renamed.jpg',
        fields: const {'category': 'avatar'},
      );

      expect(result, {'url': '/uploads/renamed.jpg'});
      final request = capturingClient.request!;
      expect(request.method, 'POST');
      expect(request.url.path, '/upload/image');
      expect(request.headers['authorization'], 'Bearer upload-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(capturingClient.body, contains('name="category"'));
      expect(capturingClient.body, contains('avatar'));
      expect(capturingClient.body, contains('filename="renamed.jpg"'));
      expect(
        capturingClient.body.toLowerCase(),
        contains('content-type: image/jpeg'),
      );
      expect(capturingClient.body, contains('image-content'));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('通用上传命中原生后台路径后不重复发送 HTTP 请求', () async {
    final directory = await Directory.systemTemp.createTemp('api-client-test-');
    final file = await File(
      '${directory.path}/activity.jpg',
    ).writeAsString('image-content');
    final capturingClient = _CapturingClient();
    final backgroundUploader = _FakeBackgroundUploader(
      response: const BackgroundMediaUploadResponse(
        statusCode: 200,
        body: '{"code":0,"data":{"url":"/uploads/activity.jpg"}}',
      ),
    );
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: capturingClient,
      tokenProvider: () async => 'upload-token',
      backgroundUploader: backgroundUploader,
    );

    try {
      final result = await client.uploadFile(
        '/upload/image',
        filePath: file.path,
        filename: 'renamed.jpg',
        fields: const {'category': 'activity-vote-option'},
      );

      expect(result, {'url': '/uploads/activity.jpg'});
      expect(capturingClient.request, isNull);
      expect(backgroundUploader.callCount, 1);
      expect(backgroundUploader.uri?.path, '/upload/image');
      expect(
        backgroundUploader.headers['Authorization'],
        'Bearer upload-token',
      );
      expect(backgroundUploader.fields, {'category': 'activity-vote-option'});
      expect(backgroundUploader.files, hasLength(1));
      expect(backgroundUploader.files.single.field, 'file');
      expect(backgroundUploader.files.single.fileName, 'renamed.jpg');
      expect(backgroundUploader.files.single.mimeType, 'image/jpeg');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('通用视频后台上传携带封面并清理临时文件', () async {
    final directory = await Directory.systemTemp.createTemp('api-video-test-');
    final video = await File(
      '${directory.path}/activity.mp4',
    ).writeAsString('video-content');
    final thumbnail = await File(
      '${directory.path}/activity-cover.jpg',
    ).writeAsString('cover-content');
    final capturingClient = _CapturingClient();
    final backgroundUploader = _FakeBackgroundUploader(
      response: const BackgroundMediaUploadResponse(
        statusCode: 200,
        body: '{"code":0,"data":{"url":"/uploads/activity.mp4"}}',
      ),
    );
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: capturingClient,
      tokenProvider: () async => 'upload-token',
      videoThumbnailGenerator: (_) async => thumbnail.path,
      backgroundUploader: backgroundUploader,
    );

    try {
      await client.uploadVideo(
        '/upload/file',
        filePath: video.path,
        fields: const {'category': 'activity-vote-option-video'},
      );

      expect(capturingClient.request, isNull);
      expect(backgroundUploader.files.map((file) => file.field), [
        'file',
        'thumbnail',
      ]);
      expect(backgroundUploader.files.last.mimeType, 'image/jpeg');
      expect(await thumbnail.exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('原生后台上传失败转换为 ApiException', () async {
    final directory = await Directory.systemTemp.createTemp('api-client-test-');
    final file = await File(
      '${directory.path}/evidence.jpg',
    ).writeAsString('image-content');
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: _CapturingClient(),
      tokenProvider: () async => 'upload-token',
      backgroundUploader: _FakeBackgroundUploader(
        error: const BackgroundMediaUploadException('后台上传服务不可用'),
      ),
    );

    try {
      await expectLater(
        client.uploadFile('/upload/image', filePath: file.path),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            '后台上传服务不可用',
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('multipart 视频上传按文件扩展名设置服务端允许的 MIME', () async {
    final directory = await Directory.systemTemp.createTemp('api-client-test-');
    final file = File('${directory.path}/community-video.mov');
    await file.writeAsBytes([1, 2, 3]);
    final capturingClient = _CapturingClient(
      responseUrl: '/uploads/community-video.mov',
    );
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: capturingClient,
      tokenProvider: () async => 'upload-token',
    );

    try {
      final result = await client.uploadFile(
        '/upload/file',
        filePath: file.path,
        fields: const {'category': 'community-post'},
      );

      expect(result, {'url': '/uploads/community-video.mov'});
      expect(
        capturingClient.body.toLowerCase(),
        contains('content-type: video/quicktime'),
      );
      expect(capturingClient.body, contains('community-post'));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('上传前拒绝 HEIC、未知格式和错误的上传端点', () async {
    final capturingClient = _CapturingClient();
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: capturingClient,
      tokenProvider: () async => 'upload-token',
    );

    await expectLater(
      client.uploadFile(
        '/upload/image',
        filePath: '/tmp/photo.heic',
        filename: 'photo.jpg',
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
      client.uploadFile('/upload/image', filePath: '/tmp/photo.bmp'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('暂不支持该文件格式'),
        ),
      ),
    );
    await expectLater(
      client.uploadFile('/upload/image', filePath: '/tmp/video.mp4'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('图片上传仅支持'),
        ),
      ),
    );
    expect(capturingClient.request, isNull);
  });

  test('上传响应缺少 URL 时按失败处理', () async {
    final directory = await Directory.systemTemp.createTemp('api-client-test-');
    final file = await File('${directory.path}/avatar.jpg').writeAsBytes([1]);
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: _CapturingClient(responseUrl: ''),
      tokenProvider: () async => 'upload-token',
    );

    try {
      await expectLater(
        client.uploadFile('/upload/image', filePath: file.path),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('文件地址'),
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('视频上传携带本地封面并在完成后清理临时文件', () async {
    final directory = await Directory.systemTemp.createTemp('api-video-test-');
    final video = await File(
      '${directory.path}/community-video.mp4',
    ).writeAsString('video-content');
    final thumbnail = await File(
      '${directory.path}/community-cover.jpg',
    ).writeAsString('cover-content');
    final capturingClient = _CapturingClient(
      responseUrl: '/uploads/community-video.mp4',
    );
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: capturingClient,
      tokenProvider: () async => 'upload-token',
      videoThumbnailGenerator: (path) async {
        expect(path, video.path);
        return thumbnail.path;
      },
    );

    try {
      await client.uploadVideo(
        '/upload/file',
        filePath: video.path,
        fields: const {'category': 'community-post'},
      );

      expect(capturingClient.body, contains('name="file"'));
      expect(capturingClient.body, contains('name="thumbnail"'));
      expect(capturingClient.body, contains('cover-content'));
      expect(capturingClient.body.toLowerCase(), contains('image/jpeg'));
      expect(await thumbnail.exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('本地视频抽帧失败时仍上传视频交给服务端兜底', () async {
    final directory = await Directory.systemTemp.createTemp('api-video-test-');
    final video = await File(
      '${directory.path}/fallback-video.mp4',
    ).writeAsString('video-content');
    final capturingClient = _CapturingClient(
      responseUrl: '/uploads/fallback-video.mp4',
    );
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: capturingClient,
      tokenProvider: () async => 'upload-token',
      videoThumbnailGenerator: (_) async => throw StateError('抽帧失败'),
    );

    try {
      await client.uploadVideo('/upload/file', filePath: video.path);

      expect(capturingClient.body, contains('name="file"'));
      expect(capturingClient.body, isNot(contains('name="thumbnail"')));
      expect(capturingClient.body, contains('video-content'));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('未提供 token 时认证请求不会发出网络调用', () async {
    var called = false;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
      tokenProvider: () async => '  ',
    );

    await expectLater(
      client.get('/protected'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', '未登录，请先登录'),
      ),
    );
    expect(called, isFalse);
  });

  test('HTTP 错误保留业务 code 和校验错误', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'VALIDATION_FAILED',
              'validationErrors': ['库存不足', 'SKU 已下架'],
            }),
          ),
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      tokenProvider: () async => null,
    );

    await expectLater(
      client.post('/orders'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'VALIDATION_FAILED')
            .having((error) => error.message, 'message', '库存不足')
            .having((error) => error.validationErrors, 'validationErrors', [
              '库存不足',
              'SKU 已下架',
            ]),
      ),
    );
  });
}

class _CapturingClient extends http.BaseClient {
  _CapturingClient({this.responseUrl = '/uploads/renamed.jpg'});

  final String responseUrl;
  http.BaseRequest? request;
  String body = '';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    final bytes = await request.finalize().toBytes();
    body = utf8.decode(bytes);
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'code': 0,
            'data': {'url': responseUrl},
          }),
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _FakeBackgroundUploader implements BackgroundMediaUploadGateway {
  _FakeBackgroundUploader({this.response, this.error});

  final BackgroundMediaUploadResponse? response;
  final BackgroundMediaUploadException? error;
  int callCount = 0;
  Uri? uri;
  Map<String, String> headers = const {};
  Map<String, String> fields = const {};
  List<BackgroundMediaUploadFile> files = const [];

  @override
  Future<BackgroundMediaUploadResponse?> upload({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<BackgroundMediaUploadFile> files,
  }) async {
    callCount++;
    this.uri = uri;
    this.headers = Map.unmodifiable(headers);
    this.fields = Map.unmodifiable(fields);
    this.files = List.unmodifiable(files);
    if (error case final error?) throw error;
    return response;
  }
}
