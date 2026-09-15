import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_client.dart';
import '../domain/chat_models.dart';
import '../domain/consultation_conversation_activity.dart';
import '../../mall/order/domain/order_models.dart';
import '../../mall/payment/domain/payment_models.dart';
import '../../mall/payment/presentation/payment_controller.dart';
import '../../mall/payment/presentation/payment_sheet_session.dart';

typedef ChatBootstrapLoader =
    Future<ChatBootstrap> Function({required bool refresh});
typedef ChatPaymentIdempotencyKeyFactory = String Function();
typedef ChatSessionExtensionRequest =
    Future<ChatSessionExtension> Function({
      required String conversationId,
      required int minutes,
      required String idempotencyKey,
    });

class ChatController extends ChangeNotifier implements PaymentSheetSession {
  ChatController({
    required ChatGateway gateway,
    ChatPurchaseGateway? purchaseGateway,
    required this.target,
    required this.currentUserId,
    required this.accessToken,
    this.currentUserType = 'user',
    this.currentUserAvatar = '',
    this.connectRealtime = true,
    this.historyOrderId,
    this.viewOnly = false,
    this.consultationSession,
    this.receiverId,
    this.bootstrapLoader,
    this.headerStatusText,
    this.headerStatusActive,
    PaymentDelay? paymentDelay,
    ChatPaymentIdempotencyKeyFactory? paymentIdempotencyKeyFactory,
    this.extendSessionRequest,
  }) : _gateway = gateway,
       _purchaseGateway =
           purchaseGateway ??
           (gateway is ChatPurchaseGateway
               ? gateway as ChatPurchaseGateway
               : null),
       _paymentDelay = paymentDelay ?? Future<void>.delayed,
       _paymentIdempotencyKeyFactory = paymentIdempotencyKeyFactory ?? _uuidV4;

  final ChatGateway _gateway;
  final ChatPurchaseGateway? _purchaseGateway;
  final PaymentDelay _paymentDelay;
  final ChatPaymentIdempotencyKeyFactory _paymentIdempotencyKeyFactory;
  final ChatSessionExtensionRequest? extendSessionRequest;
  final ChatTarget target;
  final int currentUserId;
  final String currentUserType;
  final String currentUserAvatar;
  final String accessToken;
  final bool connectRealtime;
  final int? historyOrderId;
  final bool viewOnly;
  final ConsultationConversationActivity? consultationSession;
  final int? receiverId;
  final ChatBootstrapLoader? bootstrapLoader;
  final String? headerStatusText;
  final bool? headerStatusActive;

  final List<ChatMessage> _messages = [];
  ChatSocketClient? _socket;
  Timer? _sessionTimer;
  ChatSession? _session;
  List<ChatPackage> _availablePackages = const [];
  bool _loading = true;
  bool _connected = false;
  bool _canSend = false;
  bool _paymentRequired = false;
  bool _doctorOnline = false;
  bool _purchasing = false;
  bool _extendingSession = false;
  bool _sendingMedia = false;
  bool _expiredBannerDismissed = false;
  bool _routeVisible = true;
  Duration? _remaining;
  String? _notice;
  bool _disposed = false;
  ChatPackage? _pendingPackage;
  String? _paymentIdempotencyKey;
  String? _extensionIdempotencyKey;
  int? _extensionIdempotencyMinutes;
  int? _lastAppliedSessionExtensionId;

  static const _paymentConfirmationInterval = Duration(seconds: 2);
  static const _paymentConfirmationAttempts = 5;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatSession? get session => _session;
  List<ChatPackage> get availablePackages => _availablePackages;
  @override
  bool get loading => _loading || _purchasing;
  bool get connected => _connected;
  bool get canSend => _canSend;
  bool get paymentRequired => _paymentRequired;
  bool get doctorOnline => _doctorOnline;
  bool get purchasing => _purchasing;
  bool get extendingSession => _extendingSession;
  bool get sendingMedia => _sendingMedia;
  Duration? get remaining => _remaining;
  bool get isHistoryMode => historyOrderId != null;
  @override
  bool walletLoading = false;
  @override
  double walletBalance = 0;
  @override
  String? walletErrorMessage;
  bool get showExpiredBanner =>
      !isHistoryMode &&
      !_expiredBannerDismissed &&
      _paymentRequired &&
      _availablePackages.isNotEmpty;

  bool get canExtendSession {
    final endAt = _session?.serviceEndAt;
    return currentUserType == 'doctor' &&
        !viewOnly &&
        extendSessionRequest != null &&
        _session?.status == ChatSessionStatus.paid &&
        endAt != null &&
        endAt.isAfter(DateTime.now()) &&
        !_extendingSession;
  }

  String get inputHint {
    if (_loading) return '正在连接...';
    if (viewOnly) return '咨询已结束';
    if (!_canSend) return '请先购买套餐';
    if (!_connected) return '正在连接...';
    return '输入消息...';
  }

  String? takeNotice() {
    final value = _notice;
    _notice = null;
    return value;
  }

  Future<void> initialize() async {
    _loading = true;
    _notify();
    try {
      final bootstrap = await _loadBootstrap();
      _applyBootstrap(bootstrap, replaceMessages: true);
      await _activateCurrentConversation();
      _connectSocket();
    } on Object catch (error) {
      _notice = _messageFromError(error, fallback: '聊天加载失败，请稍后重试');
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    try {
      final previousConversationId = _session?.conversationId;
      final bootstrap = await _loadBootstrap(refresh: true);
      final nextConversationId = bootstrap.session?.conversationId;
      final conversationChanged =
          previousConversationId != null &&
          previousConversationId.isNotEmpty &&
          nextConversationId != null &&
          nextConversationId.isNotEmpty &&
          nextConversationId != previousConversationId;
      if (conversationChanged) {
        consultationSession?.closeConversation(previousConversationId);
      }
      _applyBootstrap(bootstrap, replaceMessages: conversationChanged);
      await _activateCurrentConversation();
      if (conversationChanged) {
        _socket?.dispose();
        _socket = null;
        _connectSocket();
      } else {
        final socket = _socket;
        if (socket == null) {
          _connectSocket();
        } else {
          socket.reconnect();
        }
      }
      _notify();
    } on Object catch (error) {
      _notice = _messageFromError(error, fallback: '消息同步失败');
      _notify();
    }
  }

  void dismissExpiredBanner() {
    _expiredBannerDismissed = true;
    _notify();
  }

  Future<void> extendSession(int minutes) async {
    if (!const {5, 10, 15, 30}.contains(minutes) || !canExtendSession) {
      return;
    }
    final request = extendSessionRequest;
    final conversationId = _session?.conversationId;
    if (request == null || conversationId == null || conversationId.isEmpty) {
      return;
    }
    _extendingSession = true;
    _notify();
    try {
      final extension = await request(
        conversationId: conversationId,
        minutes: minutes,
        idempotencyKey: _extensionIdempotencyKeyFor(minutes),
      );
      _extensionIdempotencyKey = null;
      _extensionIdempotencyMinutes = null;
      _applySessionExtension(extension);
      _notice = '咨询时间已延长 $minutes 分钟';
    } on Object catch (error) {
      _notice = _messageFromError(error, fallback: '延长咨询时间失败，请稍后重试');
    } finally {
      _extendingSession = false;
      _notify();
    }
  }

  String _extensionIdempotencyKeyFor(int minutes) {
    if (_extensionIdempotencyKey == null ||
        _extensionIdempotencyMinutes != minutes) {
      _extensionIdempotencyKey = _paymentIdempotencyKeyFactory();
      _extensionIdempotencyMinutes = minutes;
    }
    return _extensionIdempotencyKey!;
  }

  void setRouteVisible(bool visible) {
    if (_routeVisible == visible || _disposed) return;
    _routeVisible = visible;
    if (visible) {
      unawaited(_activateCurrentConversation());
      return;
    }
    final conversationId = _session?.conversationId;
    if (conversationId != null) {
      consultationSession?.closeConversation(conversationId);
    }
  }

  void handleAppResumed() {
    if (_disposed || _purchasing || _paymentRequired) return;
    unawaited(refresh());
  }

  void beginPurchase(ChatPackage package) {
    final samePackage = _pendingPackage?.id == package.id;
    _pendingPackage = package;
    if (!samePackage || _paymentIdempotencyKey == null) {
      _paymentIdempotencyKey = _paymentIdempotencyKeyFactory();
    }
    walletErrorMessage = null;
  }

  @override
  Future<void> loadWalletBalance() async {
    final gateway = _purchaseGateway;
    if (gateway == null) {
      walletBalance = 0;
      walletErrorMessage = '支付服务暂不可用';
      return;
    }
    walletLoading = true;
    walletErrorMessage = null;
    try {
      walletBalance = await gateway.loadWalletBalance();
    } on Object catch (error) {
      walletBalance = 0;
      walletErrorMessage = '$error';
    } finally {
      walletLoading = false;
      _notify();
    }
  }

  @override
  Future<PaymentFlowResult> submit(PaymentChannel channel) async {
    final package = _pendingPackage;
    final gateway = _purchaseGateway;
    if (isHistoryMode || package == null || gateway == null) {
      return const PaymentFlowResult(PaymentFlowStatus.unavailable, '支付服务暂不可用');
    }
    if (channel == PaymentChannel.wechat) {
      return const PaymentFlowResult(PaymentFlowStatus.unavailable, '微信支付暂未开放');
    }
    if (channel == PaymentChannel.balance && walletErrorMessage != null) {
      return const PaymentFlowResult(
        PaymentFlowStatus.unavailable,
        '余额加载失败，请重试',
      );
    }
    if (channel == PaymentChannel.balance && walletBalance < package.price) {
      return const PaymentFlowResult(
        PaymentFlowStatus.insufficientBalance,
        '余额不足，请选择其他支付方式',
      );
    }
    if (_purchasing) {
      return const PaymentFlowResult(PaymentFlowStatus.processing, '支付正在处理中');
    }

    _purchasing = true;
    _notify();
    try {
      final payment = await gateway.purchasePackageForPayment(
        doctorId: target.doctorId,
        serviceItemId: package.id,
        channel: channel,
        idempotencyKey: _paymentIdempotencyKey ??=
            _paymentIdempotencyKeyFactory(),
        conversationId: _session?.conversationId,
      );

      if (payment.paid || channel == PaymentChannel.balance) {
        if (payment.paid || await _confirmPayment(gateway, payment.paymentNo)) {
          await _completePurchase();
          return const PaymentFlowResult(
            PaymentFlowStatus.success,
            '支付成功，可以继续咨询',
          );
        }
        return const PaymentFlowResult(
          PaymentFlowStatus.processing,
          '支付结果确认中，请稍后重新进入咨询查看',
        );
      }

      final orderInfo = payment.alipayOrderString;
      if (orderInfo == null || orderInfo.isEmpty) {
        return const PaymentFlowResult(
          PaymentFlowStatus.failed,
          '后端未返回可用的支付宝支付参数',
        );
      }
      final sdkResult = await gateway.pay(orderInfo);
      if (sdkResult.status == PaymentSdkStatus.cancelled) {
        return const PaymentFlowResult(
          PaymentFlowStatus.cancelled,
          '已取消支付，咨询订单已保留',
        );
      }
      if (sdkResult.status == PaymentSdkStatus.networkError) {
        return const PaymentFlowResult(
          PaymentFlowStatus.networkError,
          '网络连接异常，请稍后重新进入咨询确认结果',
        );
      }
      if (sdkResult.status == PaymentSdkStatus.failed) {
        return PaymentFlowResult(
          PaymentFlowStatus.failed,
          sdkResult.memo.trim().isEmpty ? '支付失败，请稍后重试' : sdkResult.memo,
        );
      }

      final status = await _confirmPaymentStatus(gateway, payment.paymentNo);
      if (status.paid) {
        await _completePurchase();
        return const PaymentFlowResult(
          PaymentFlowStatus.success,
          '支付成功，可以继续咨询',
        );
      }
      if (status.terminal) {
        return const PaymentFlowResult(
          PaymentFlowStatus.failed,
          '支付未完成，请重新发起购买',
        );
      }
      return const PaymentFlowResult(
        PaymentFlowStatus.processing,
        '支付结果确认中，请稍后重新进入咨询查看',
      );
    } on Object catch (error) {
      return PaymentFlowResult(
        PaymentFlowStatus.failed,
        _messageFromError(error, fallback: '购买失败，请稍后重试'),
      );
    } finally {
      _purchasing = false;
      _notify();
    }
  }

  Future<bool> _confirmPayment(
    ChatPurchaseGateway gateway,
    String paymentNo,
  ) async {
    if (paymentNo.isEmpty) return false;
    return (await _confirmPaymentStatus(gateway, paymentNo)).paid;
  }

  Future<ChatPackagePaymentStatus> _confirmPaymentStatus(
    ChatPurchaseGateway gateway,
    String paymentNo,
  ) async {
    var latest = ChatPackagePaymentStatus.unknown;
    for (
      var attempt = 0;
      attempt < _paymentConfirmationAttempts;
      attempt += 1
    ) {
      try {
        latest = await gateway.loadPaymentStatus(paymentNo);
        if (latest.terminal) return latest;
      } on Object {
        // 单次查单失败不终止最终状态确认。
      }
      if (attempt < _paymentConfirmationAttempts - 1) {
        await _paymentDelay(_paymentConfirmationInterval);
      }
    }
    return latest;
  }

  Future<void> _completePurchase() async {
    final previousConversationId = _session?.conversationId;
    final bootstrap = await _gateway.refreshChat(target.doctorId);
    final nextConversationId = bootstrap.session?.conversationId;
    final conversationChanged =
        previousConversationId != null &&
        previousConversationId.isNotEmpty &&
        nextConversationId != null &&
        nextConversationId.isNotEmpty &&
        nextConversationId != previousConversationId;
    if (conversationChanged) {
      consultationSession?.closeConversation(previousConversationId);
    }
    _applyBootstrap(bootstrap, replaceMessages: conversationChanged);
    await _activateCurrentConversation();
    _expiredBannerDismissed = false;
    _pendingPackage = null;
    _paymentIdempotencyKey = null;
    if (conversationChanged) {
      _socket?.dispose();
      _socket = null;
      _connectSocket();
    } else {
      _socket?.reconnect();
    }
  }

  void sendText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty || !_canSend) return;
    _sendOptimistic(content: text, type: ChatMessageType.text);
  }

  bool canRevoke(ChatMessage message) {
    if (viewOnly ||
        message.senderId != currentUserId ||
        message.senderType != currentUserType ||
        message.id <= 0 ||
        message.pending ||
        message.failed ||
        message.isRevoked ||
        message.isAutoReply ||
        !const {
          ChatMessageType.text,
          ChatMessageType.image,
          ChatMessageType.video,
        }.contains(message.type)) {
      return false;
    }
    final elapsed = DateTime.now().difference(message.createdAt);
    return !elapsed.isNegative && elapsed <= const Duration(minutes: 2);
  }

  Future<bool> revokeMessage(ChatMessage message) async {
    final conversationId = _session?.conversationId;
    if (conversationId == null || !canRevoke(message)) {
      _notice = '该消息已超过可撤回时间';
      _notify();
      return false;
    }
    final recallGateway = _gateway is ChatMessageRecallGateway
        ? _gateway as ChatMessageRecallGateway
        : null;
    if (recallGateway == null) {
      _notice = '当前聊天暂不支持撤回';
      _notify();
      return false;
    }
    try {
      final revoked = await recallGateway.revokeMessage(
        conversationId: conversationId,
        messageId: message.id,
      );
      _applyRevokedMessage(revoked);
      _notice = '消息已撤回';
      _notify();
      return true;
    } on Object catch (error) {
      _notice = _messageFromError(error, fallback: '消息撤回失败');
      _notify();
      return false;
    }
  }

  Future<void> sendMedia({
    required String path,
    required String fileName,
    required ChatMessageType type,
  }) async {
    if (!_canSend || _sendingMedia) return;
    final conversationId = _session?.conversationId;
    if (conversationId == null || conversationId.isEmpty) {
      _notice = '会话尚未建立，请稍后重试';
      _notify();
      return;
    }

    final tempId = -DateTime.now().microsecondsSinceEpoch;
    final temporary = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUserId,
      senderType: currentUserType,
      receiverId: receiverId ?? target.doctorId,
      receiverType: currentUserType == 'doctor' ? 'user' : 'doctor',
      content: '',
      type: type,
      isAutoReply: false,
      isRead: false,
      createdAt: DateTime.now(),
      localMediaPath: path,
      pending: true,
    );
    _addMessage(temporary);
    _sendingMedia = true;
    _notify();

    try {
      final upload = await _gateway.uploadMedia(
        path: path,
        fileName: fileName,
        type: type,
      );
      final content = ChatMediaContent(
        url: upload.url,
        thumbnail: upload.thumbnail,
        width: upload.width,
        height: upload.height,
        size: upload.size,
        fileName: upload.originalName ?? fileName,
      ).toMessageContent();
      _replaceMessage(
        tempId,
        temporary.copyWith(content: content, pending: true),
      );
      _emitMessage(tempId: tempId, content: content, type: type);
    } on Object catch (error) {
      _markFailed(tempId);
      _notice = _messageFromError(error, fallback: '媒体发送失败，请重试');
    } finally {
      _sendingMedia = false;
      _notify();
    }
  }

  void _sendOptimistic({
    required String content,
    required ChatMessageType type,
  }) {
    final conversationId = _session?.conversationId;
    if (conversationId == null || conversationId.isEmpty) {
      _notice = '会话尚未建立，请稍后重试';
      _notify();
      return;
    }

    final tempId = -DateTime.now().microsecondsSinceEpoch;
    _addMessage(
      ChatMessage(
        id: tempId,
        conversationId: conversationId,
        senderId: currentUserId,
        senderType: currentUserType,
        receiverId: receiverId ?? target.doctorId,
        receiverType: currentUserType == 'doctor' ? 'user' : 'doctor',
        content: content,
        type: type,
        isAutoReply: false,
        isRead: false,
        createdAt: DateTime.now(),
        pending: true,
      ),
    );
    _notify();
    _emitMessage(tempId: tempId, content: content, type: type);
  }

  void _emitMessage({
    required int tempId,
    required String content,
    required ChatMessageType type,
  }) {
    _socket?.sendMessage(
      content: content,
      type: type,
      onAcknowledged: (message) {
        _replaceMessage(tempId, message);
        _notify();
      },
      onFailed: (message) {
        _markFailed(tempId);
        if (message.contains('免费咨询次数已用完')) {
          _canSend = false;
          _paymentRequired = true;
        }
        _notice = message;
        _notify();
      },
    );
  }

  void _applyBootstrap(
    ChatBootstrap bootstrap, {
    required bool replaceMessages,
  }) {
    _session = bootstrap.session;
    _canSend = bootstrap.canSend && !viewOnly;
    _doctorOnline = bootstrap.doctorOnline;
    _availablePackages = bootstrap.availablePackages.isNotEmpty
        ? bootstrap.availablePackages
        : bootstrap.session?.availablePackages ?? const [];
    _paymentRequired = _bootstrapRequiresPayment(bootstrap);
    if (replaceMessages) {
      _messages
        ..clear()
        ..addAll(bootstrap.messages);
    } else {
      for (final message in bootstrap.messages) {
        _addMessage(message);
      }
    }
    _sortMessages();
    _startSessionTimer();
  }

  void _connectSocket() {
    if (!connectRealtime || viewOnly) return;
    final conversationId = _session?.conversationId;
    if (conversationId == null || conversationId.isEmpty || _socket != null) {
      return;
    }
    _socket = ChatSocketClient(
      serverUrl: ApiConfig.baseUrl,
      accessToken: accessToken,
      doctorId: target.doctorId,
      conversationId: conversationId,
      onMessage: _handleIncomingMessage,
      onMessageRevoked: _applyRevokedMessage,
      onConnectedChanged: (connected) {
        _connected = connected;
        _notify();
      },
      onPaymentRequired: (payload) {
        _canSend = false;
        _paymentRequired = true;
        final message = _messageFromPayload(payload);
        if (message != null) {
          _addMessage(message);
          if (message.packages.isNotEmpty) {
            _availablePackages = message.packages;
          }
        }
        _notify();
      },
      onSessionExpired: (_) {
        _canSend = false;
        _paymentRequired = true;
        _session = _session?.copyWith(status: ChatSessionStatus.expired);
        _expiredBannerDismissed = false;
        _notify();
      },
      onSessionExtended: _applySessionExtension,
      onDoctorStatusChanged: (online) {
        _doctorOnline = online;
        _notify();
      },
      onError: (message) {
        _notice = message;
        _notify();
      },
    )..connect();
  }

  void _applySessionExtension(ChatSessionExtension extension) {
    if (_session?.conversationId != extension.conversationId) return;
    if (_lastAppliedSessionExtensionId == extension.extensionId) return;
    _lastAppliedSessionExtensionId = extension.extensionId;
    _session = _session?.copyWith(
      status: extension.status,
      serviceEndAt: extension.serviceEndAt,
      paymentRequired: false,
    );
    _canSend = !viewOnly && extension.status == ChatSessionStatus.paid;
    _paymentRequired = false;
    _expiredBannerDismissed = true;
    _startSessionTimer();
    _notify();
  }

  Future<ChatBootstrap> _loadBootstrap({bool refresh = false}) {
    final loader = bootstrapLoader;
    if (loader != null) return loader(refresh: refresh);
    final orderId = historyOrderId;
    if (orderId != null) {
      return _gateway.loadOrderChat(
        doctorId: target.doctorId,
        orderId: orderId,
        viewOnly: viewOnly,
      );
    }
    return refresh
        ? _gateway.refreshChat(target.doctorId)
        : _gateway.loadChat(target.doctorId);
  }

  void _handleIncomingMessage(ChatMessage message) {
    final optimisticIndex = _messages.indexWhere(
      (candidate) =>
          candidate.pending &&
          candidate.senderId == currentUserId &&
          candidate.type == message.type &&
          candidate.content == message.content,
    );
    if (optimisticIndex >= 0) {
      _messages[optimisticIndex] = message;
    } else {
      _addMessage(message);
    }
    if (message.type == ChatMessageType.paymentPrompt) {
      _canSend = false;
      _paymentRequired = true;
      if (message.packages.isNotEmpty) {
        _availablePackages = message.packages;
      }
      _expiredBannerDismissed = false;
    }
    _sortMessages();
    if (_routeVisible && message.receiverId == currentUserId) {
      unawaited(
        consultationSession?.markConversationRead(message.conversationId),
      );
    }
    _notify();
  }

  void _applyRevokedMessage(ChatMessage message) {
    final index = _messages.indexWhere(
      (candidate) => candidate.id == message.id,
    );
    if (index < 0) {
      _addMessage(message);
    } else {
      _messages[index] = message;
      _sortMessages();
    }
    _notify();
  }

  Future<void> _activateCurrentConversation() async {
    if (isHistoryMode || !_routeVisible) return;
    final conversationId = _session?.conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    await consultationSession?.openConversation(conversationId);
  }

  void _addMessage(ChatMessage message) {
    final duplicate = _messages.any((candidate) {
      if (candidate.id == message.id) return true;
      if (candidate.conversationId != message.conversationId ||
          candidate.senderId != message.senderId ||
          candidate.type != message.type ||
          candidate.content != message.content) {
        return false;
      }
      return candidate.createdAt.difference(message.createdAt).abs() <
          const Duration(minutes: 5);
    });
    if (!duplicate) {
      _messages.add(message);
      _sortMessages();
    }
  }

  void _replaceMessage(int id, ChatMessage replacement) {
    final index = _messages.indexWhere((message) => message.id == id);
    if (index < 0) {
      _addMessage(replacement);
      return;
    }
    _messages[index] = replacement;
    _sortMessages();
  }

  void _markFailed(int id) {
    final index = _messages.indexWhere((message) => message.id == id);
    if (index < 0) return;
    _messages[index] = _messages[index].copyWith(pending: false, failed: true);
  }

  void _sortMessages() {
    _messages.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime == 0 ? left.id.compareTo(right.id) : byTime;
    });
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    final session = _session;
    if (session?.status != ChatSessionStatus.paid) {
      _remaining = null;
      return;
    }
    _updateRemaining();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
      _notify();
    });
  }

  void _updateRemaining() {
    final end = _session?.serviceEndAt;
    if (end != null) {
      final difference = end.difference(DateTime.now());
      _remaining = difference.isNegative ? Duration.zero : difference;
    } else {
      final current = _remaining?.inSeconds ?? _session?.remainingSeconds ?? 0;
      _remaining = Duration(seconds: current > 0 ? current - 1 : 0);
    }
    if ((_remaining?.inSeconds ?? 1) <= 0) {
      _canSend = false;
      _paymentRequired = true;
      _sessionTimer?.cancel();
    }
  }

  bool _bootstrapRequiresPayment(ChatBootstrap bootstrap) {
    if (isHistoryMode || viewOnly || bootstrap.canSend) return false;
    if (bootstrap.session?.paymentRequired == true) return true;
    if (bootstrap.messages.any(
      (message) => message.type == ChatMessageType.paymentPrompt,
    )) {
      return true;
    }
    return _availablePackages.isNotEmpty;
  }

  ChatMessage? _messageFromPayload(Object? payload) {
    if (payload is! Map) return null;
    final json = Map<String, dynamic>.from(payload);
    if (json['id'] == null) return null;
    return ChatMessage.fromJson(json);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final conversationId = _session?.conversationId;
    if (conversationId != null) {
      consultationSession?.closeConversation(conversationId);
    }
    _sessionTimer?.cancel();
    _socket?.dispose();
    super.dispose();
  }
}

String _messageFromError(Object error, {required String fallback}) {
  final text = '$error'.trim();
  return text.isEmpty || text == 'Exception' ? fallback : text;
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
