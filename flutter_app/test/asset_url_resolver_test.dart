import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/config/api_config.dart';
import 'package:pet_hospital_flutter/core/network/asset_url_resolver.dart';

void main() {
  const baseUrl = 'https://assets.example.test/root/';

  group('resolveAssetUrl', () {
    test('拼接带或不带前导斜杠的相对地址', () {
      expect(
        resolveAssetUrl(
          '/uploads/a.jpg',
          assetBaseUrl: baseUrl,
          uploadBaseUrl: baseUrl,
        ),
        'https://assets.example.test/root/uploads/a.jpg',
      );
      expect(
        resolveAssetUrl(
          'uploads/a.jpg',
          assetBaseUrl: baseUrl,
          uploadBaseUrl: baseUrl,
        ),
        'https://assets.example.test/root/uploads/a.jpg',
      );
    });

    test('上传路径固定使用独立的静态资源地址', () {
      expect(
        resolveAssetUrl(
          '/uploads/a.jpg',
          assetBaseUrl: 'https://api.example.test',
        ),
        '${ApiConfig.assetBaseUrl}/uploads/a.jpg',
      );
    });

    test('完整 URL 和 query 保持不变', () {
      const value = 'https://cdn.example.test/a.jpg?size=2';
      expect(resolveAssetUrl(value, assetBaseUrl: baseUrl), value);
    });

    test('本地地址、data URI 与空值不拼接', () {
      expect(
        resolveAssetUrl('file:///tmp/a.jpg', assetBaseUrl: baseUrl),
        'file:///tmp/a.jpg',
      );
      expect(
        resolveAssetUrl('/var/mobile/a.jpg', assetBaseUrl: baseUrl),
        '/var/mobile/a.jpg',
      );
      expect(
        resolveAssetUrl('data:image/png;base64,AA==', assetBaseUrl: baseUrl),
        'data:image/png;base64,AA==',
      );
      expect(resolveAssetUrl('', assetBaseUrl: baseUrl), isEmpty);
    });

    test('去除连接处双斜杠并拒绝非法协议', () {
      expect(
        joinAssetUrl('https://example.test///', '///uploads/a.jpg'),
        'https://example.test/uploads/a.jpg',
      );
      expect(
        resolveAssetUrl('javascript:alert(1)', assetBaseUrl: baseUrl),
        isEmpty,
      );
    });
  });

  test('resolveLocalFile 只解析真实本地文件地址', () {
    expect(resolveLocalFile('file:///tmp/a.jpg')?.path, '/tmp/a.jpg');
    expect(resolveLocalFile('/data/user/0/a.jpg')?.path, '/data/user/0/a.jpg');
    expect(resolveLocalFile('/uploads/a.jpg'), isNull);
    expect(resolveLocalFile('https://example.test/a.jpg'), isNull);
  });
}
