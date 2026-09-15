import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/pets/data/pet_repository.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';

void main() {
  test('列表、分类树和详情使用固定 GET contract 与鉴权', () async {
    final requests = <http.Request>[];
    final repository = PetRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return switch (request.url.path) {
            '/pets/my' => _ok([_petJson(id: '12')]),
            '/pet-categories/tree' => _ok([
              {
                'id': '1',
                'name': '犬',
                'parentId': null,
                'sortOrder': 0,
                'children': [
                  {'id': 5, 'name': '金毛', 'parentId': 1, 'sortOrder': 0},
                ],
              },
            ]),
            '/pets/12' => _ok(_petJson(id: 12, name: '详情旺财')),
            _ => throw StateError('Unexpected request: ${request.url}'),
          };
        }),
        tokenProvider: () async => 'pet-token',
      ),
    );

    final pets = await repository.loadMyPets(categoryId: 1);
    final categories = await repository.loadCategoryTree();
    final detail = await repository.loadPet(12);

    expect(pets.single.id, 12);
    expect(requests.first.url.queryParameters, {'categoryId': '1'});
    expect(categories.single.children.single.name, '金毛');
    expect(detail.name, '详情旺财');
    expect(requests.map((request) => request.method), ['GET', 'GET', 'GET']);
    expect(requests.map((request) => request.url.path), [
      '/pets/my',
      '/pet-categories/tree',
      '/pets/12',
    ]);
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer pet-token',
      ),
      isTrue,
    );
  });

  test('创建、更新和删除使用固定路径、方法、JSON 与鉴权', () async {
    final requests = <http.Request>[];
    final repository = PetRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return switch ((request.method, request.url.path)) {
            ('POST', '/pets') => _ok(_petJson(id: 21)),
            ('PUT', '/pets/21') => _ok(_petJson(id: 21, name: '更新后')),
            ('DELETE', '/pets/21') => _okWithoutData(),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            ),
          };
        }),
        tokenProvider: () async => 'pet-token',
      ),
    );
    const draft = PetDraft(
      name: ' 旺财 ',
      avatarUrl: '',
      categoryId: 1,
      subCategoryId: null,
      gender: PetGender.male,
      birthDate: null,
      weightText: '10.5',
      isNeutered: true,
      vaccineCountText: '3',
    );

    final created = await repository.createPet(draft);
    final updated = await repository.updatePet(21, draft);
    await repository.deletePet(21);

    expect(created.id, 21);
    expect(updated.name, '更新后');
    expect(requests.map((request) => request.method), [
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect(requests.map((request) => request.url.path), [
      '/pets',
      '/pets/21',
      '/pets/21',
    ]);
    expect(jsonDecode(requests[0].body), {
      'name': '旺财',
      'categoryId': 1,
      'gender': 1,
      'weight': 10.5,
      'isNeutered': true,
      'vaccineCount': 3,
    });
    expect(jsonDecode(requests[1].body), jsonDecode(requests[0].body));
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer pet-token',
      ),
      isTrue,
    );
  });

  test('头像上传固定使用 file 和 pet-avatar 并解析响应', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pet-repository-test-',
    );
    final file = File('${directory.path}/pet.txt');
    await file.writeAsString('pet-image');
    final client = _MultipartCapturingClient();
    final repository = PetRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: client,
        tokenProvider: () async => 'upload-token',
      ),
    );

    try {
      final upload = await repository.uploadAvatar(
        filePath: file.path,
        filename: 'pet.txt',
      );

      expect(upload.url, '/uploads/pet.txt');
      expect(client.request?.method, 'POST');
      expect(client.request?.url.path, '/upload/image');
      expect(client.request?.headers['authorization'], 'Bearer upload-token');
      expect(client.body, contains('name="category"'));
      expect(client.body, contains('pet-avatar'));
      expect(client.body, contains('name="file"'));
      expect(client.body, contains('filename="pet.txt"'));
      expect(client.body, contains('pet-image'));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('错误列表形状时抛出 FormatException', () async {
    final repository = PetRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => _ok({'id': 1})),
        tokenProvider: () async => 'pet-token',
      ),
    );

    await expectLater(repository.loadMyPets(), throwsFormatException);
  });

  test('上传响应缺少 URL 时抛出 FormatException', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pet-upload-format-test-',
    );
    final file = File('${directory.path}/pet.txt');
    await file.writeAsString('pet-image');
    final repository = PetRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: _MultipartCapturingClient(
          responseData: const {
            'id': 21,
            'filename': 'stored-pet.txt',
            'originalName': 'pet.txt',
            'size': 9,
          },
        ),
        tokenProvider: () async => 'pet-token',
      ),
    );

    try {
      await expectLater(
        repository.uploadAvatar(filePath: file.path),
        throwsFormatException,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

Map<String, Object?> _petJson({required Object id, String name = '旺财'}) {
  return {
    'id': id,
    'name': name,
    'avatar': null,
    'categoryId': 1,
    'subCategoryId': null,
    'gender': 1,
    'birthDate': '2022-01-01',
    'weight': '10.50',
    'isNeutered': false,
    'vaccineCount': 2,
    'category': {'id': 1, 'name': '犬', 'parentId': null, 'sortOrder': 0},
    'subCategory': null,
    'ownerId': 8,
    'createdAt': '2025-01-01T08:00:00.000Z',
    'updatedAt': '2025-01-02T08:00:00.000Z',
  };
}

http.Response _ok(Object? data) {
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
  _MultipartCapturingClient({Map<String, Object?>? responseData})
    : responseData =
          responseData ??
          const {
            'id': '21',
            'url': '/uploads/pet.txt',
            'filename': 'stored-pet.txt',
            'originalName': 'pet.txt',
            'size': '9',
          };

  final Map<String, Object?> responseData;
  http.BaseRequest? request;
  String body = '';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    final bytes = await request.finalize().toBytes();
    body = utf8.decode(bytes);
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'code': 0, 'data': responseData}))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
