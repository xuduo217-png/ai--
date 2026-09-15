import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/settings/data/settings_repository.dart';
import 'package:pet_hospital_flutter/features/settings/domain/settings_models.dart';

void main() {
  test('联系方式使用公开接口并解析实际 configValue 字段', () async {
    late http.Request captured;
    final repository = SettingsRepository(
      apiClient: _apiClient((request) async {
        captured = request;
        return _jsonResponse({
          'data': {
            'configKey': 'contact_info',
            'configValue': {
              'hotline': ' 400-123-4567 ',
              'wechatQrCode': '/uploads/contact.png',
              'workingHours': ' 周一至周日 9:00-21:00 ',
            },
          },
        });
      }),
    );

    final info = await repository.loadContactInfo();

    expect(captured.url.path, '/system-configs/contact_info');
    expect(captured.headers, isNot(contains('Authorization')));
    expect(info.hotline, '400-123-4567');
    expect(info.wechatQrCode, '/uploads/contact.png');
    expect(info.workingHours, '周一至周日 9:00-21:00');
  });

  test('联系方式配置为空时返回可安全渲染的空模型', () async {
    final repository = SettingsRepository(
      apiClient: _apiClient(
        (_) async => _jsonResponse({
          'data': {'configKey': 'contact_info', 'configValue': null},
        }),
      ),
    );

    expect(await repository.loadContactInfo(), ContactInfo.empty);
  });

  test('系统文章使用强类型公开路径并接受服务端 null', () async {
    late http.Request captured;
    final repository = SettingsRepository(
      apiClient: _apiClient((request) async {
        captured = request;
        return _jsonResponse({'data': null});
      }),
    );

    final article = await repository.loadArticle(SystemArticleType.privacy);

    expect(article, isNull);
    expect(captured.url.path, '/system-articles/privacy');
    expect(captured.headers, isNot(contains('Authorization')));
  });

  test('系统文章严格解析 id/type/content 并保留 HTML', () async {
    final repository = SettingsRepository(
      apiClient: _apiClient(
        (_) async => _jsonResponse({
          'data': {
            'id': 9,
            'type': 'user_agreement',
            'content': '<p>协议正文</p>',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-02T00:00:00.000Z',
          },
        }),
      ),
    );

    final article = await repository.loadArticle(
      SystemArticleType.userAgreement,
    );

    expect(article?.id, 9);
    expect(article?.type, SystemArticleType.userAgreement);
    expect(article?.html, '<p>协议正文</p>');
  });

  test('系统文章类型与请求不一致时拒绝静默展示', () async {
    final repository = SettingsRepository(
      apiClient: _apiClient(
        (_) async => _jsonResponse({
          'data': {'id': 9, 'type': 'about_us', 'content': '<p>错误文章</p>'},
        }),
      ),
    );

    await expectLater(
      repository.loadArticle(SystemArticleType.privacy),
      throwsFormatException,
    );
  });
}

http.Response _jsonResponse(Object? body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

ApiClient _apiClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  return ApiClient(
    baseUrl: 'https://api.example.com',
    client: MockClient(handler),
    tokenProvider: () async => 'must-not-be-read',
  );
}
