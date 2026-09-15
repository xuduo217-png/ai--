import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path_util;

import '../../../core/config/api_config.dart';
import '../../../core/media/background_media_uploader.dart';
import '../../../core/media/video_thumbnail_service.dart';
import '../../../core/network/api_client.dart';
import '../../mall/order/domain/order_models.dart';
import '../../mall/payment/domain/payment_models.dart';
import '../../mall/shared/mall_json.dart';
import '../domain/chat_models.dart';

abstract interface class ChatGateway {
  Future<ChatBootstrap> loadChat(int doctorId);

  Future<ChatBootstrap> refreshChat(int doctorId);

  Future<ChatBootstrap> loadOrderChat({
    required int doctorId,
    required int orderId,
    required bool viewOnly,
  });

  Future<void> purchasePackage({
    required int doctorId,
    required int serviceItemId,
    String? conversationId,
  });

  Future<ChatUploadResult> uploadMedia({
    required String path,
    required String fileName,
    required ChatMessageType type,
  });
}

abstract interface class ChatMessageRecallGateway {
  Future<ChatMessage> revokeMessage({
    required String conversationId,
    required int messageId,
  });
}

abstract interface class ChatPurchaseGateway {
  Future<double> loadWalletBalance();

  Future<ChatPackagePayment> purchasePackageForPayment({
    required int doctorId,
    required int serviceItemId,
    required PaymentChannel channel,
    required String idempotencyKey,
    String? conversationId,
  });

  Future<PaymentSdkResult> pay(String orderInfo);

  Future<ChatPackagePaymentStatus> loadPaymentStatus(String paymentNo);
}

class ChatRepository
    implements ChatGateway, ChatPurchaseGateway, ChatMessageRecallGateway {
  ChatRepository({
    required ApiClient apiClient,
    required TokenProvider tokenProvider,
    required String baseUrl,
    PaymentGateway? paymentGateway,
    http.Client? uploadClient,
    VideoThumbnailFileGenerator? videoThumbnailGenerator,
    BackgroundMediaUploadGateway? backgroundUploader,
  }) : _apiClient = apiClient,
       _tokenProvider = tokenProvider,
       _baseUrl = baseUrl,
       _paymentGateway = paymentGateway,
       _uploadClient = uploadClient ?? http.Client(),
       _videoThumbnailGenerator = videoThumbnailGenerator,
       _backgroundUploader = backgroundUploader ?? BackgroundMediaUploader();

  final ApiClient _apiClient;
  final TokenProvider _tokenProvider;
  final String _baseUrl;
  final PaymentGateway? _paymentGateway;
  final http.Client _uploadClient;
  final VideoThumbnailFileGenerator? _videoThumbnailGenerator;
  final BackgroundMediaUploadGateway _backgroundUploader;

  @override
  Future<ChatBootstrap> loadChat(int doctorId) => _load(doctorId);

  @override
  Future<ChatBootstrap> refreshChat(int doctorId) => _load(doctorId);

  @override
  Future<ChatBootstrap> loadOrderChat({
    required int doctorId,
    required int orderId,
    required bool viewOnly,
  }) async {
    final results = await Future.wait<Object?>([
      _apiClient.get(
        '/chat/messages-by-order/$orderId',
        queryParameters: const {'page': 1, 'limit': 50},
      ),
      _apiClient.get('/doctors/$doctorId', authenticated: false),
      if (!viewOnly) _apiClient.get('/chat/check-can-send/$doctorId'),
    ]);
    final doctorResponse = _asMap(results[1]);
    final checkResponse = viewOnly
        ? const <String, dynamic>{}
        : _asMap(results[2]);
    final sessionJson = _asNullableMap(checkResponse['session']);
    final session = sessionJson == null
        ? null
        : ChatSession.fromJson(sessionJson);

    return ChatBootstrap(
      session: session,
      canSend:
          !viewOnly &&
          checkResponse['canSend'] == true &&
          session != null &&
          session.conversationId.isNotEmpty,
      messages: _parseMessages(results[0]),
      doctorOnline:
          '${doctorResponse['onlineStatus']}'.toUpperCase() == 'ONLINE',
      availablePackages: _parsePackages(sessionJson?['availablePackages']),
    );
  }

  Future<ChatBootstrap> _load(int doctorId) async {
    // 先确保首次咨询会话已创建，再检查发送权限，避免两个接口并发读取到不同状态。
    final sessionResponse = _asMap(
      await _apiClient.get('/chat/session/$doctorId'),
    );
    final results = await Future.wait<Object?>([
      _apiClient.get('/chat/check-can-send/$doctorId'),
      _apiClient.get('/doctors/$doctorId', authenticated: false),
    ]);

    final checkResponse = _asMap(results[0]);
    final doctorResponse = _asMap(results[1]);
    final directSession = sessionResponse['conversationId'] == null
        ? null
        : sessionResponse;
    final sessionJson =
        _asNullableMap(checkResponse['session']) ??
        _asNullableMap(sessionResponse['session']) ??
        directSession;
    final session = sessionJson == null
        ? null
        : ChatSession.fromJson(sessionJson);
    final packageSource = sessionJson?['availablePackages'];
    final packages = _parsePackages(packageSource);
    final messages = session == null || session.conversationId.isEmpty
        ? const <ChatMessage>[]
        : await _getMessages(session.conversationId);

    return ChatBootstrap(
      session: session,
      canSend:
          checkResponse['canSend'] == true &&
          session != null &&
          session.conversationId.isNotEmpty,
      messages: messages,
      doctorOnline:
          '${doctorResponse['onlineStatus']}'.toUpperCase() == 'ONLINE',
      availablePackages: packages,
    );
  }

  Future<List<ChatMessage>> _getMessages(String conversationId) async {
    final response = await _apiClient.get(
      '/chat/messages',
      queryParameters: {
        'conversationId': conversationId,
        'page': 1,
        'limit': 50,
      },
    );
    return _parseMessages(response);
  }

  @override
  Future<ChatMessage> revokeMessage({
    required String conversationId,
    required int messageId,
  }) async {
    final response = _asMap(
      await _apiClient.post(
        '/chat/messages/$messageId/revoke',
        authenticated: true,
        body: {'conversationId': conversationId},
      ),
    );
    final data = _asNullableMap(response['data']) ?? response;
    return ChatMessage.fromJson(_asMap(data['message'] ?? data));
  }

  List<ChatMessage> _parseMessages(Object? response) {
    final payload = _asMap(response);
    final rawMessages = payload['data'] is List
        ? payload['data'] as List
        : response is List
        ? response
        : const <Object?>[];

    final messages = rawMessages
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    messages.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime == 0 ? left.id.compareTo(right.id) : byTime;
    });
    return messages;
  }

  @override
  Future<void> purchasePackage({
    required int doctorId,
    required int serviceItemId,
    String? conversationId,
  }) async {
    throw const ApiException('请通过支付页面购买咨询套餐');
  }

  @override
  Future<double> loadWalletBalance() async {
    final payload = _asMap(
      unwrapData(await _apiClient.get('/shop/wallet/balance')),
    );
    return _toDouble(payload['balance']);
  }

  @override
  Future<ChatPackagePayment> purchasePackageForPayment({
    required int doctorId,
    required int serviceItemId,
    required PaymentChannel channel,
    required String idempotencyKey,
    String? conversationId,
  }) async {
    final payload = _asMap(
      await _apiClient.post(
        '/chat/orders',
        authenticated: true,
        body: {
          'doctorId': doctorId,
          'serviceItemId': serviceItemId,
          'paymentChannel': channel.wireValue,
          'idempotencyKey': idempotencyKey,
          if (conversationId != null && conversationId.isNotEmpty)
            'conversationId': conversationId,
        },
      ),
    );
    final order = _asMap(payload['order']);
    final payment = _asMap(payload['paymentParams']);
    final providerParams = _asMap(payment['paymentParams']);
    return ChatPackagePayment(
      orderId: _toInt(order['id']),
      orderStatus: ChatPackageOrderStatus.fromWire(order['status']),
      paymentNo: '${payment['paymentNo'] ?? ''}',
      alipayOrderString: _nonEmptyString(providerParams['alipayOrderString']),
    );
  }

  @override
  Future<PaymentSdkResult> pay(String orderInfo) {
    final gateway = _paymentGateway;
    if (gateway == null) {
      throw const ApiException('当前客户端未配置支付宝支付');
    }
    return gateway.pay(orderInfo);
  }

  @override
  Future<ChatPackagePaymentStatus> loadPaymentStatus(String paymentNo) async {
    final payload = _asMap(await _apiClient.get('/payment/query/$paymentNo'));
    return ChatPackagePaymentStatus.fromWire(payload['status']);
  }

  @override
  Future<ChatUploadResult> uploadMedia({
    required String path,
    required String fileName,
    required ChatMessageType type,
  }) async {
    final token = (await _tokenProvider())?.trim() ?? '';
    if (token.isEmpty) {
      throw const ApiException('未登录，请先登录', statusCode: 401);
    }

    final isVideo = type == ChatMessageType.video;
    if (isVideo) {
      return withGeneratedVideoThumbnail(
        videoPath: path,
        generator: _videoThumbnailGenerator,
        action: (thumbnailPath) => _uploadMediaRequest(
          path: path,
          fileName: fileName,
          token: token,
          isVideo: true,
          thumbnailPath: thumbnailPath,
        ),
      );
    }
    return _uploadMediaRequest(
      path: path,
      fileName: fileName,
      token: token,
      isVideo: false,
    );
  }

  Future<ChatUploadResult> _uploadMediaRequest({
    required String path,
    required String fileName,
    required String token,
    required bool isVideo,
    String? thumbnailPath,
  }) async {
    final uri = Uri.parse(
      isVideo
          ? '$_baseUrl/upload/file?category=chat-video'
          : '$_baseUrl/upload/image',
    );
    final uploadFiles = <BackgroundMediaUploadFile>[
      BackgroundMediaUploadFile(
        field: 'file',
        path: path,
        fileName: fileName,
        mimeType: _chatMediaContentType(
          path,
          fileName,
          isVideo: isVideo,
        ).toString(),
      ),
    ];
    if (thumbnailPath != null) {
      uploadFiles.add(
        BackgroundMediaUploadFile(
          field: 'thumbnail',
          path: thumbnailPath,
          fileName: '${fileName}_cover.jpg',
          mimeType: 'image/jpeg',
        ),
      );
    }

    final fields = <String, String>{if (!isVideo) 'category': 'chat'};
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
        return _parseUploadResponse(
          statusCode: backgroundResponse.statusCode,
          rawBody: backgroundResponse.body,
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

    late final http.StreamedResponse response;
    try {
      response = await _uploadClient
          .send(request)
          .timeout(ApiConfig.uploadTimeout);
    } on TimeoutException {
      throw const ApiException('媒体上传超时，请检查网络后重试');
    } on Object {
      throw const ApiException('媒体上传失败，请检查网络后重试');
    }

    return _parseUploadResponse(
      statusCode: response.statusCode,
      rawBody: await response.stream.bytesToString(),
    );
  }

  ChatUploadResult _parseUploadResponse({
    required int statusCode,
    required String rawBody,
  }) {
    late final Object? decoded;
    try {
      decoded = rawBody.trim().isEmpty ? null : jsonDecode(rawBody);
    } on FormatException {
      throw const ApiException('服务器返回了无法识别的上传结果');
    }

    final envelope = _asMap(decoded);
    final failed =
        statusCode < 200 ||
        statusCode >= 300 ||
        envelope['success'] == false ||
        (envelope['code'] != null && '${envelope['code']}' != '0');
    if (failed) {
      throw ApiException(
        '${envelope['message'] ?? '媒体上传失败，请稍后重试'}',
        statusCode: _chatUploadErrorStatusCode(envelope, statusCode),
        code: envelope['code'],
      );
    }

    final payload = _asNullableMap(envelope['data']) ?? envelope;
    final result = ChatUploadResult.fromJson(payload);
    if (result.url.isEmpty) {
      throw const ApiException('上传成功，但服务器未返回文件地址');
    }
    return result;
  }
}

MediaType _chatMediaContentType(
  String filePath,
  String fileName, {
  required bool isVideo,
}) {
  final extensions = [fileName, filePath]
      .map((candidate) => path_util.extension(candidate).toLowerCase())
      .where((extension) => extension.isNotEmpty)
      .toList(growable: false);
  if (extensions.any(const {'.heic', '.heif'}.contains)) {
    throw const ApiException('暂不支持 HEIC/HEIF，请选择 JPG、PNG、GIF 或 WebP 图片');
  }

  for (final extension in extensions) {
    final mimeType = switch (extension) {
      '.jpg' || '.jpeg' || '.jpe' || '.jfif' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.mp4' || '.m4v' => 'video/mp4',
      '.mpeg' || '.mpg' => 'video/mpeg',
      '.mov' => 'video/quicktime',
      '.avi' => 'video/x-msvideo',
      '.wmv' => 'video/x-ms-wmv',
      '.webm' => 'video/webm',
      _ => null,
    };
    if (mimeType == null) continue;
    if (isVideo != mimeType.startsWith('video/')) {
      throw ApiException(
        isVideo
            ? '视频仅支持 MP4、M4V、MOV、MPEG、AVI、WMV 或 WebM 格式'
            : '图片仅支持 JPG、PNG、GIF 或 WebP 格式',
      );
    }
    return MediaType.parse(mimeType);
  }
  throw ApiException(
    isVideo
        ? '视频仅支持 MP4、M4V、MOV、MPEG、AVI、WMV 或 WebM 格式'
        : '图片仅支持 JPG、PNG、GIF 或 WebP 格式',
  );
}

int _chatUploadErrorStatusCode(
  Map<String, dynamic> payload,
  int fallbackStatusCode,
) {
  for (final candidate in [payload['statusCode'], payload['code']]) {
    final parsed = candidate is num
        ? candidate.toInt()
        : int.tryParse('${candidate ?? ''}');
    if (parsed != null && parsed >= 400 && parsed <= 599) return parsed;
  }
  return fallbackStatusCode;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic>? _asNullableMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _nonEmptyString(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

int _toInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

double _toDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;

List<ChatPackage> _parsePackages(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => ChatPackage.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
