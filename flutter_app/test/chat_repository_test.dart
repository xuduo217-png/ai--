import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_hospital_flutter/core/media/background_media_uploader.dart';
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/chat/data/chat_repository.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';

void main() {
  test('首次咨询先创建会话再检查发送权限', () async {
    var sessionCreated = false;
    var checkStartedBeforeSessionCreated = false;
    final requestedPaths = <String>[];
    final session = <String, Object?>{
      'conversationId': 'first-conversation',
      'userId': 8,
      'doctorId': 2,
      'status': 'FREE',
      'autoReplyCount': 0,
      'maxFreeReplies': 3,
    };
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      final data = switch (request.url.path) {
        '/chat/session/2' => await (() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          sessionCreated = true;
          return session;
        })(),
        '/chat/check-can-send/2' => (() {
          checkStartedBeforeSessionCreated = !sessionCreated;
          return <String, Object?>{'canSend': true};
        })(),
        '/doctors/2' => <String, Object?>{'onlineStatus': 'ONLINE'},
        '/chat/messages' => <Object?>[],
        _ => throw StateError('unexpected request: ${request.url}'),
      };
      return http.Response(
        jsonEncode({'code': 0, 'data': data, 'message': 'Success'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repository = ChatRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: client,
        tokenProvider: () async => 'test-token',
      ),
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
    );

    final result = await repository.loadChat(2);

    expect(requestedPaths.first, '/chat/session/2');
    expect(checkStartedBeforeSessionCreated, isFalse);
    expect(result.session?.conversationId, 'first-conversation');
    expect(result.canSend, isTrue);
    expect(result.doctorOnline, isTrue);
  });

  test('咨询套餐支付提交渠道与幂等键并解析支付参数', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/chat/orders');
      expect(request.headers['authorization'], 'Bearer test-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {
        'doctorId': 2,
        'serviceItemId': 5,
        'paymentChannel': 'alipay',
        'idempotencyKey': '550e8400-e29b-41d4-a716-446655440000',
        'conversationId': 'conversation-1',
      });
      return http.Response(
        jsonEncode({
          'code': 0,
          'data': {
            'order': {'id': 200, 'status': 'PENDING'},
            'paymentParams': {
              'paymentNo': 'PAY_200',
              'paymentParams': {'alipayOrderString': 'signed-order'},
            },
          },
        }),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repository = ChatRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: client,
        tokenProvider: () async => 'test-token',
      ),
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
    );

    final payment = await repository.purchasePackageForPayment(
      doctorId: 2,
      serviceItemId: 5,
      channel: PaymentChannel.alipay,
      idempotencyKey: '550e8400-e29b-41d4-a716-446655440000',
      conversationId: 'conversation-1',
    );

    expect(payment.orderId, 200);
    expect(payment.orderStatus, ChatPackageOrderStatus.pending);
    expect(payment.paymentNo, 'PAY_200');
    expect(payment.alipayOrderString, 'signed-order');
  });

  test('咨询支付正确解析钱包业务响应中的余额', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/shop/wallet/balance');
      expect(request.headers['authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode({
          'code': 0,
          'data': {
            'success': true,
            'data': {
              'balance': 88.5,
              'pendingBalance': 12,
              'withdrawalFrozenBalance': 3,
            },
          },
          'message': '操作成功',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repository = ChatRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: client,
        tokenProvider: () async => 'test-token',
      ),
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
    );

    expect(await repository.loadWalletBalance(), 88.5);
  });

  test('医患消息撤回携带会话标识并解析占位消息', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/chat/messages/91/revoke');
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(jsonDecode(request.body), {'conversationId': 'conversation-1'});
      return http.Response(
        jsonEncode({
          'code': 0,
          'data': {
            'message': {
              'id': 91,
              'conversationId': 'conversation-1',
              'senderId': 8,
              'senderType': 'user',
              'receiverId': 2,
              'receiverType': 'doctor',
              'content': '消息已撤回',
              'type': 'TEXT',
              'isAutoReply': false,
              'isRead': true,
              'isRevoked': true,
              'revokedAt': '2026-08-12T10:01:00.000Z',
              'createdAt': '2026-08-12T10:00:00.000Z',
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repository = ChatRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: client,
        tokenProvider: () async => 'test-token',
      ),
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
    );

    final message = await repository.revokeMessage(
      conversationId: 'conversation-1',
      messageId: 91,
    );

    expect(message.id, 91);
    expect(message.isRevoked, isTrue);
    expect(message.content, '消息已撤回');
  });

  test('已结束咨询仅请求订单消息与医生状态', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.startsWith('/chat/')) {
        expect(request.headers['authorization'], 'Bearer test-token');
      }
      final data = switch (request.url.path) {
        '/chat/messages-by-order/71' => {
          'data': [
            {
              'id': 91,
              'conversationId': '8_2',
              'senderId': 2,
              'receiverId': 8,
              'content': '历史订单消息',
              'type': 'TEXT',
              'isAutoReply': false,
              'isRead': true,
              'orderId': 71,
              'createdAt': '2026-07-20T10:00:00.000Z',
            },
          ],
        },
        '/doctors/2' => {'onlineStatus': 'OFFLINE'},
        _ => throw StateError('unexpected request: ${request.url}'),
      };
      return http.Response(
        jsonEncode({'code': 0, 'data': data, 'message': 'Success'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: client,
      tokenProvider: () async => 'test-token',
    );

    final result = await ChatRepository(
      apiClient: apiClient,
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
      uploadClient: client,
    ).loadOrderChat(doctorId: 2, orderId: 71, viewOnly: true);

    expect(
      requestedPaths,
      unorderedEquals(['/chat/messages-by-order/71', '/doctors/2']),
    );
    expect(result.messages.single.content, '历史订单消息');
    expect(result.messages.single.orderId, 71);
    expect(result.session, isNull);
    expect(result.canSend, isFalse);
  });

  test('问诊图片上传携带正确 MIME 和 chat 分类', () async {
    final directory = await Directory.systemTemp.createTemp('chat-image-test-');
    final image = await File(
      '${directory.path}/consultation.jpg',
    ).writeAsBytes([1, 2]);
    final uploadClient = _RecordingUploadClient(
      responseBody: const {
        'code': 0,
        'data': {'url': '/uploads/consultation.jpg'},
      },
    );
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{}', 200)),
      tokenProvider: () async => 'test-token',
    );
    final repository = ChatRepository(
      apiClient: apiClient,
      tokenProvider: () async => ' test-token ',
      baseUrl: 'https://example.test',
      uploadClient: uploadClient,
    );

    try {
      final result = await repository.uploadMedia(
        path: image.path,
        fileName: 'consultation.jpg',
        type: ChatMessageType.image,
      );

      final request = uploadClient.request!;
      expect(request.url.path, '/upload/image');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.fields['category'], 'chat');
      expect(request.files.single.contentType.toString(), 'image/jpeg');
      expect(result.url, '/uploads/consultation.jpg');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('问诊大媒体使用原生后台上传响应，不重复走 HTTP', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chat-background-test-',
    );
    final image = await File(
      '${directory.path}/consultation.jpg',
    ).writeAsBytes([1, 2]);
    final uploadClient = _RecordingUploadClient();
    final backgroundUploader = _CompletedBackgroundUploader(
      const BackgroundMediaUploadResponse(
        statusCode: 201,
        body: '{"code":0,"data":{"url":"/uploads/background.jpg"}}',
      ),
    );
    final repository = ChatRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: () async => 'test-token',
      ),
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
      uploadClient: uploadClient,
      backgroundUploader: backgroundUploader,
    );

    try {
      final result = await repository.uploadMedia(
        path: image.path,
        fileName: 'consultation.jpg',
        type: ChatMessageType.image,
      );

      expect(result.url, '/uploads/background.jpg');
      expect(uploadClient.request, isNull);
      expect(backgroundUploader.uri?.path, '/upload/image');
      expect(backgroundUploader.fields, {'category': 'chat'});
      expect(backgroundUploader.files.single.mimeType, 'image/jpeg');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('问诊上传在请求前拒绝 HEIC/HEIF', () async {
    final uploadClient = _RecordingUploadClient();
    final repository = ChatRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: () async => 'test-token',
      ),
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
      uploadClient: uploadClient,
    );

    await expectLater(
      repository.uploadMedia(
        path: '/tmp/consultation.heic',
        fileName: 'consultation.heic',
        type: ChatMessageType.image,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('HEIC/HEIF'),
        ),
      ),
    );
    expect(uploadClient.request, isNull);
  });

  test('问诊媒体上传保留 HTTP 200 业务失败的真实错误', () async {
    final directory = await Directory.systemTemp.createTemp('chat-error-test-');
    final image = await File(
      '${directory.path}/consultation.jpg',
    ).writeAsBytes([1, 2]);
    final uploadClient = _RecordingUploadClient(
      responseBody: const {
        'success': false,
        'code': 400,
        'statusCode': 400,
        'message': '只支持上传图片文件',
      },
    );
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{}', 200)),
      tokenProvider: () async => 'test-token',
    );
    final repository = ChatRepository(
      apiClient: apiClient,
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
      uploadClient: uploadClient,
    );

    try {
      await expectLater(
        repository.uploadMedia(
          path: image.path,
          fileName: 'consultation.jpg',
          type: ChatMessageType.image,
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.message, 'message', '只支持上传图片文件')
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.code, 'code', 400),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('问诊视频上传携带本地生成的封面', () async {
    final directory = await Directory.systemTemp.createTemp('chat-video-test-');
    final video = await File(
      '${directory.path}/consultation.mp4',
    ).writeAsBytes([1, 2]);
    final thumbnail = await File(
      '${directory.path}/consultation-cover.jpg',
    ).writeAsBytes([3, 4]);
    final uploadClient = _RecordingUploadClient();
    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{}', 200)),
      tokenProvider: () async => 'test-token',
    );
    final repository = ChatRepository(
      apiClient: apiClient,
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
      uploadClient: uploadClient,
      videoThumbnailGenerator: (_) async => thumbnail.path,
    );

    try {
      final result = await repository.uploadMedia(
        path: video.path,
        fileName: 'consultation.mp4',
        type: ChatMessageType.video,
      );

      expect(
        uploadClient.request!.url.queryParameters['category'],
        'chat-video',
      );
      expect(uploadClient.request!.files.map((file) => file.field), [
        'file',
        'thumbnail',
      ]);
      expect(
        uploadClient.request!.files.first.contentType.toString(),
        'video/mp4',
      );
      expect(
        uploadClient.request!.files.last.contentType.toString(),
        'image/jpeg',
      );
      expect(result.thumbnail, '/uploads/thumbnails/consultation.jpg');
      expect(await thumbnail.exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

class _RecordingUploadClient extends http.BaseClient {
  _RecordingUploadClient({
    this.responseBody = const {
      'code': 0,
      'data': {
        'url': '/uploads/consultation.mp4',
        'thumbnail': '/uploads/thumbnails/consultation.jpg',
      },
    },
  });

  final Map<String, Object?> responseBody;
  http.MultipartRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request as http.MultipartRequest;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(responseBody))),
      200,
    );
  }
}

class _CompletedBackgroundUploader implements BackgroundMediaUploadGateway {
  _CompletedBackgroundUploader(this.response);

  final BackgroundMediaUploadResponse response;
  Uri? uri;
  Map<String, String> fields = const {};
  List<BackgroundMediaUploadFile> files = const [];

  @override
  Future<BackgroundMediaUploadResponse?> upload({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<BackgroundMediaUploadFile> files,
  }) async {
    this.uri = uri;
    this.fields = fields;
    this.files = files;
    return response;
  }
}
