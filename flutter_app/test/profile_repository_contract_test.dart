import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/profile/data/profile_repository.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';

void main() {
  test('GET /users/me 使用 token 并解析当前用户资料', () async {
    late http.Request capturedRequest;
    final repository = ProfileRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          return _ok({
            'id': 8,
            'username': '小顾',
            'phone': '13800138000',
            'avatar': '/uploads/avatar.png',
            'gender': 2,
          });
        }),
        tokenProvider: () async => 'test-token',
      ),
    );

    final profile = await repository.loadProfile();

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/users/me');
    expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    expect(profile.displayName, '小顾');
    expect(profile.gender, UserGender.female);
  });

  test('资料更新和账号注销使用固定方法、路径、JSON 与鉴权', () async {
    final requests = <http.Request>[];
    final repository = ProfileRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return switch ((request.method, request.url.path)) {
            ('PUT', '/users/me') => _ok({
              'id': '8',
              'username': '小顾',
              'phone': '13800138000',
              'avatar': '/uploads/avatar.png',
              'gender': '2',
            }),
            ('DELETE', '/users/me') => _okWithoutData(),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            ),
          };
        }),
        tokenProvider: () async => 'test-token',
      ),
    );

    final profile = await repository.updateProfile(
      const ProfileUpdateInput(
        username: ' 小顾 ',
        avatarUrl: '/uploads/avatar.png',
        gender: UserGender.female,
      ),
    );
    await repository.deleteAccount();

    expect(profile.id, 8);
    expect(profile.displayName, '小顾');
    expect(profile.gender, UserGender.female);
    expect(requests.map((request) => request.method), ['PUT', 'DELETE']);
    expect(requests.map((request) => request.url.path), [
      '/users/me',
      '/users/me',
    ]);
    expect(jsonDecode(requests.first.body), {
      'username': '小顾',
      'avatar': '/uploads/avatar.png',
      'gender': 2,
    });
    expect(requests.last.body, isEmpty);
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer test-token',
      ),
      isTrue,
    );
  });

  test('头像上传固定使用 file 和 user-avatar 并解析已审计响应', () async {
    final directory = await Directory.systemTemp.createTemp(
      'profile-repository-test-',
    );
    final file = File('${directory.path}/avatar.txt');
    await file.writeAsString('image-content');
    final capturingClient = _MultipartCapturingClient();
    final repository = ProfileRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: capturingClient,
        tokenProvider: () async => 'upload-token',
      ),
    );

    try {
      final upload = await repository.uploadAvatar(
        filePath: file.path,
        filename: 'avatar.txt',
      );

      expect(upload.id, 21);
      expect(upload.url, '/uploads/avatar.txt');
      expect(upload.filename, 'stored-avatar.txt');
      expect(upload.originalName, 'avatar.txt');
      expect(upload.size, 13);
      expect(
        upload.resolvedUrl(assetBaseUrl: 'https://assets.example.test'),
        'https://assets.example.test/uploads/avatar.txt',
      );
      expect(capturingClient.request?.method, 'POST');
      expect(capturingClient.request?.url.path, '/upload/image');
      expect(
        capturingClient.request?.headers['authorization'],
        'Bearer upload-token',
      );
      expect(capturingClient.body, contains('name="category"'));
      expect(capturingClient.body, contains('user-avatar'));
      expect(capturingClient.body, contains('name="file"'));
      expect(capturingClient.body, contains('filename="avatar.txt"'));
      expect(capturingClient.body, contains('image-content'));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('固定响应缺少必需字段时抛出 FormatException', () async {
    final repository = ProfileRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => _ok({'id': 8, 'gender': 1})),
        tokenProvider: () async => 'test-token',
      ),
    );

    await expectLater(
      repository.updateProfile(const ProfileUpdateInput(username: '小顾')),
      throwsA(isA<FormatException>()),
    );
  });

  test('服务端业务错误保持为 ApiException', () async {
    final repository = ProfileRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'code': 'USERNAME_EXISTS',
              'message': '用户名已存在',
            }),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        ),
        tokenProvider: () async => 'test-token',
      ),
    );

    await expectLater(
      repository.updateProfile(const ProfileUpdateInput(username: '重复名称')),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'USERNAME_EXISTS')
            .having((error) => error.message, 'message', '用户名已存在'),
      ),
    );
  });
}

http.Response _ok(Map<String, Object?> data) {
  return http.Response(
    jsonEncode(<String, Object?>{'code': 0, 'data': data}),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

http.Response _okWithoutData() {
  return http.Response(
    jsonEncode(<String, Object?>{'code': 0, 'message': 'Success'}),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

class _MultipartCapturingClient extends http.BaseClient {
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
            'data': {
              'id': '21',
              'url': '/uploads/avatar.txt',
              'filename': 'stored-avatar.txt',
              'originalName': 'avatar.txt',
              'size': '13',
            },
          }),
        ),
      ),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
