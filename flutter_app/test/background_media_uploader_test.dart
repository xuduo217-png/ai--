import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/background_media_uploader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/background_media_upload');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('大文件走原生后台通道并读取完成响应', () async {
    final directory = await Directory.systemTemp.createTemp(
      'background-media-upload-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/video.mp4').writeAsBytes([1]);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'enqueue') {
            return (call.arguments as Map<Object?, Object?>)['taskId'];
          }
          if (call.method == 'status') {
            return <String, Object?>{
              'state': 'completed',
              'statusCode': 201,
              'body': '{"code":0}',
            };
          }
          throw MissingPluginException();
        });

    final response =
        await BackgroundMediaUploader(
          channel: channel,
          largeMediaThreshold: 1,
          pollInterval: Duration.zero,
        ).upload(
          uri: Uri.parse(
            'https://example.test/upload/file?category=chat-video',
          ),
          headers: const {'Authorization': 'Bearer token'},
          fields: const {'category': 'chat'},
          files: [
            BackgroundMediaUploadFile(
              field: 'file',
              path: file.path,
              fileName: 'video.mp4',
              mimeType: 'video/mp4',
            ),
          ],
        );

    expect(response?.statusCode, 201);
    expect(response?.body, '{"code":0}');
    expect(calls.map((call) => call.method), ['enqueue', 'status']);
    final enqueue = calls.first.arguments as Map<Object?, Object?>;
    expect(
      enqueue['url'],
      'https://example.test/upload/file?category=chat-video',
    );
    expect(enqueue['headers'], {'Authorization': 'Bearer token'});
  });

  test('小文件保持普通 HTTP 上传回退路径', () async {
    final directory = await Directory.systemTemp.createTemp(
      'background-media-upload-small-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/image.jpg').writeAsBytes([1]);

    final response =
        await BackgroundMediaUploader(
          channel: channel,
          largeMediaThreshold: 1024,
          pollInterval: Duration.zero,
        ).upload(
          uri: Uri.parse('https://example.test/upload/image'),
          headers: const {},
          fields: const {},
          files: [
            BackgroundMediaUploadFile(
              field: 'file',
              path: file.path,
              fileName: 'image.jpg',
              mimeType: 'image/jpeg',
            ),
          ],
        );

    expect(response, isNull);
  });

  test('原生后台服务启动失败时转换为统一上传异常', () async {
    final directory = await Directory.systemTemp.createTemp(
      'background-media-upload-error-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/video.mp4').writeAsBytes([1]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'enqueue_failed', message: '后台服务不可用');
        });

    await expectLater(
      BackgroundMediaUploader(
        channel: channel,
        largeMediaThreshold: 1,
        pollInterval: Duration.zero,
      ).upload(
        uri: Uri.parse('https://example.test/upload/file'),
        headers: const {},
        fields: const {},
        files: [
          BackgroundMediaUploadFile(
            field: 'file',
            path: file.path,
            fileName: 'video.mp4',
            mimeType: 'video/mp4',
          ),
        ],
      ),
      throwsA(
        isA<BackgroundMediaUploadException>().having(
          (error) => error.message,
          'message',
          '后台服务不可用',
        ),
      ),
    );
  });

  test('不同登录身份使用不同的后台任务标识', () async {
    final directory = await Directory.systemTemp.createTemp(
      'background-media-upload-identity-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/image.jpg').writeAsBytes([1]);
    final taskIds = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'enqueue') {
            final taskId = (call.arguments as Map<Object?, Object?>)['taskId']!;
            taskIds.add('$taskId');
            return taskId;
          }
          return <String, Object?>{
            'state': 'completed',
            'statusCode': 200,
            'body': '{"code":0}',
          };
        });
    final uploader = BackgroundMediaUploader(
      channel: channel,
      largeMediaThreshold: 1,
      pollInterval: Duration.zero,
    );

    for (final token in const ['first-token', 'second-token']) {
      await uploader.upload(
        uri: Uri.parse('https://example.test/upload/image'),
        headers: {'Authorization': 'Bearer $token'},
        fields: const {'category': 'user-avatar'},
        files: [
          BackgroundMediaUploadFile(
            field: 'file',
            path: file.path,
            fileName: 'image.jpg',
            mimeType: 'image/jpeg',
          ),
        ],
      );
    }

    expect(taskIds, hasLength(2));
    expect(taskIds[0], isNot(taskIds[1]));
  });
}
