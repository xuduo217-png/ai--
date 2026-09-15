import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/messaging/in_app_message_event.dart';
import '../../chat/data/consultation_realtime_socket_client.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/domain/consultation_conversation_activity.dart';
import '../domain/doctor_portal_models.dart';

class DoctorConsultationsController extends ChangeNotifier
    implements ConsultationConversationActivity {
  DoctorConsultationsController({
    required DoctorPortalGateway gateway,
    required this.doctorId,
    ConsultationRealtimeGateway? realtime,
    Future<void> Function()? onSessionRevoked,
  }) : _gateway = gateway,
       _realtime = realtime,
       _onSessionRevoked = onSessionRevoked;

  final DoctorPortalGateway _gateway;
  final ConsultationRealtimeGateway? _realtime;
  final Future<void> Function()? _onSessionRevoked;
  final int doctorId;
  final Queue<String> _recentMessageKeys = Queue<String>();
  final Set<String> _recentMessageKeySet = <String>{};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final _incomingMessageEvents = StreamController<InAppMessageEvent>.broadcast(
    sync: true,
  );

  DoctorConsultationStatus _status = DoctorConsultationStatus.paid;
  List<DoctorConsultation> _consultations = const [];
  String? _activeConversationId;
  int _totalUnreadCount = 0;
  bool _loading = false;
  bool _refreshing = false;
  bool _started = false;
  bool _disposed = false;
  String? _error;
  int _requestGeneration = 0;

  DoctorConsultationStatus get status => _status;
  List<DoctorConsultation> get consultations => _consultations;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  int get totalUnreadCount => _totalUnreadCount;
  bool get isConnected => _realtime?.isConnected == true;
  Stream<InAppMessageEvent> get incomingMessageEvents =>
      _incomingMessageEvents.stream;

  Future<void> start() async {
    if (_disposed) return;
    if (!_started) {
      _started = true;
      final realtime = _realtime;
      if (realtime != null) {
        _subscriptions
          ..add(
            realtime.messages.listen(
              (message) => unawaited(_handleIncomingMessage(message)),
            ),
          )
          ..add(realtime.connectionChanges.listen((_) => _notify()))
          ..add(realtime.errors.listen(_handleRealtimeError))
          ..add(
            realtime.sessionRevoked.listen((_) {
              final callback = _onSessionRevoked;
              if (callback != null) unawaited(callback());
            }),
          );
        final extensionSubscription = _listenSessionExtensions(realtime);
        if (extensionSubscription != null) {
          _subscriptions.add(extensionSubscription);
        }
      }
    }
    await load();
    await _connectRealtime();
  }

  StreamSubscription<ChatSessionExtension>? _listenSessionExtensions(
    ConsultationRealtimeGateway realtime,
  ) {
    if (realtime is! ConsultationSessionExtensionRealtimeGateway) {
      return null;
    }
    final extensionGateway =
        realtime as ConsultationSessionExtensionRealtimeGateway;
    return extensionGateway.sessionExtensions.listen(_handleSessionExtended);
  }

  void _handleSessionExtended(ChatSessionExtension extension) {
    if (_disposed || extension.doctorId != doctorId) return;
    final index = _consultations.indexWhere(
      (item) => item.conversationId == extension.conversationId,
    );
    if (index < 0) return;
    final updated = [..._consultations];
    updated[index] = updated[index].copyWith(
      status: DoctorConsultationStatus.fromWire(extension.status.name),
      serviceEndAt: extension.serviceEndAt,
    );
    _consultations = _sorted(updated);
    _notify();
  }

  Future<void> pause() async {
    if (_disposed) return;
    try {
      await _realtime?.pause();
    } on Object catch (error) {
      _handleRealtimeError(error);
    }
  }

  Future<void> resume() async {
    if (_disposed) return;
    if (!_started) {
      await start();
      return;
    }
    await load(refresh: true);
    await _connectRealtime();
  }

  Future<void> load({bool refresh = false}) async {
    final generation = ++_requestGeneration;
    if (refresh) {
      _refreshing = true;
    } else {
      _loading = true;
    }
    _error = null;
    notifyListeners();
    try {
      final page = await _gateway.loadConsultations(
        doctorId: doctorId,
        status: _status,
      );
      if (generation != _requestGeneration) return;
      _consultations = _sorted(page.items);
      _totalUnreadCount = page.totalUnreadCount;
    } on Object catch (error) {
      if (generation != _requestGeneration) return;
      _error = _errorMessage(error, '咨询列表加载失败，请稍后重试');
    } finally {
      if (generation == _requestGeneration) {
        _loading = false;
        _refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectStatus(DoctorConsultationStatus status) async {
    if (status == _status || status == DoctorConsultationStatus.unknown) return;
    _status = status;
    _consultations = const [];
    await load();
  }

  Future<DoctorConsultation?> resolveConsultation(
    String conversationId, {
    bool refresh = false,
  }) async {
    if (_disposed || conversationId.isEmpty) return null;
    if (!refresh) {
      for (final consultation in _consultations) {
        if (consultation.conversationId == conversationId) return consultation;
      }
    }

    final statuses = <DoctorConsultationStatus>[
      _status,
      if (_status != DoctorConsultationStatus.paid)
        DoctorConsultationStatus.paid,
      if (_status != DoctorConsultationStatus.expired)
        DoctorConsultationStatus.expired,
    ];
    for (final status in statuses) {
      try {
        final page = await _gateway.loadConsultations(
          doctorId: doctorId,
          status: status,
        );
        if (_disposed) return null;
        _totalUnreadCount = page.totalUnreadCount;
        if (status == _status) {
          _consultations = _sorted(page.items);
        }
        _notify();
        for (final consultation in page.items) {
          if (consultation.conversationId == conversationId) {
            return consultation;
          }
        }
      } on Object catch (error) {
        _handleRealtimeError(error);
      }
    }
    return null;
  }

  @override
  Future<void> openConversation(String conversationId) async {
    if (_disposed || conversationId.isEmpty) return;
    _activeConversationId = conversationId;
    await markConversationRead(conversationId);
  }

  @override
  void closeConversation(String conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    if (_disposed || conversationId.isEmpty) return;
    final index = _consultations.indexWhere(
      (item) => item.conversationId == conversationId,
    );
    if (index >= 0 && _consultations[index].unreadCount > 0) {
      final unreadCount = _consultations[index].unreadCount;
      final updated = [..._consultations];
      updated[index] = updated[index].copyWith(unreadCount: 0);
      _consultations = updated;
      _totalUnreadCount = (_totalUnreadCount - unreadCount).clamp(0, 1 << 31);
      _notify();
    }
    try {
      await _gateway.markConversationRead(conversationId);
    } on Object catch (error) {
      _handleRealtimeError(error);
    }
  }

  Future<void> _connectRealtime() async {
    try {
      await _realtime?.connect();
    } on Object catch (error) {
      _handleRealtimeError(error);
    }
  }

  Future<void> _handleIncomingMessage(ChatMessage message) async {
    if (_disposed || message.receiverId != doctorId) return;
    final messageKey = '${message.conversationId}:${message.id}';
    if (!_recentMessageKeySet.add(messageKey)) return;
    _recentMessageKeys.addLast(messageKey);
    if (_recentMessageKeys.length > 200) {
      _recentMessageKeySet.remove(_recentMessageKeys.removeFirst());
    }

    var index = _consultations.indexWhere(
      (item) => item.conversationId == message.conversationId,
    );
    final wasMissing = index < 0;
    DoctorConsultation? resolvedConsultation;
    if (index < 0) {
      resolvedConsultation = await resolveConsultation(
        message.conversationId,
        refresh: true,
      );
      if (_disposed) return;
      index = _consultations.indexWhere(
        (item) => item.conversationId == message.conversationId,
      );
    }

    final isActive = _activeConversationId == message.conversationId;
    if (index < 0) {
      if (!isActive) _publishIncomingMessage(message, resolvedConsultation);
      return;
    }
    if (wasMissing) {
      final consultation = _consultations[index];
      if (isActive) {
        unawaited(markConversationRead(message.conversationId));
      } else {
        _publishIncomingMessage(message, consultation);
      }
      return;
    }
    final consultation = _consultations[index];
    final updated = [..._consultations];
    updated[index] = consultation.copyWith(
      lastMessage: _messagePreview(message),
      lastMessageAt: message.createdAt,
      unreadCount: isActive ? 0 : consultation.unreadCount + 1,
    );
    _consultations = _sorted(updated);
    if (!isActive) _totalUnreadCount += 1;
    _notify();
    if (isActive) {
      unawaited(markConversationRead(message.conversationId));
    } else {
      _publishIncomingMessage(message, updated[index]);
    }
  }

  void _publishIncomingMessage(
    ChatMessage message,
    DoctorConsultation? consultation,
  ) {
    final userName = consultation?.userName.trim();
    final senderName = message.senderName?.trim();
    _incomingMessageEvents.add(
      InAppMessageEvent(
        eventKey: 'doctor-consultation:${message.conversationId}:${message.id}',
        channel: InAppMessageChannel.consultation,
        conversationId: message.conversationId,
        senderId: message.senderId,
        title: userName?.isNotEmpty == true
            ? userName!
            : senderName?.isNotEmpty == true
            ? senderName!
            : '用户消息',
        preview: inAppMessagePreview(
          messageType: message.type.wireValue,
          content: message.content,
        ),
        avatarUrl: consultation?.userAvatarUrl,
        createdAt: message.createdAt,
      ),
    );
  }

  void _handleRealtimeError(Object error) {
    if (_disposed) return;
    _error = _errorMessage(error, '消息实时同步失败');
    _notify();
  }

  List<DoctorConsultation> _sorted(Iterable<DoctorConsultation> consultations) {
    final sorted = consultations.toList(growable: false);
    sorted.sort((left, right) {
      final byTime = right.sortTime.compareTo(left.sortTime);
      return byTime == 0
          ? right.conversationId.compareTo(left.conversationId)
          : byTime;
    });
    return sorted;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    unawaited(_realtime?.close());
    unawaited(_incomingMessageEvents.close());
    super.dispose();
  }
}

String _messagePreview(ChatMessage message) {
  return switch (message.type) {
    ChatMessageType.image => '[图片]',
    ChatMessageType.video => '[视频]',
    ChatMessageType.paymentSuccess => '[支付成功]',
    ChatMessageType.paymentPrompt => '[待支付]',
    _ => message.content,
  };
}

class DoctorIncomeController extends ChangeNotifier {
  DoctorIncomeController({required DoctorPortalGateway gateway})
    : _gateway = gateway;

  final DoctorPortalGateway _gateway;

  DoctorIncomeStats? _stats;
  List<DoctorIncomeRecord> _records = const [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _requestGeneration = 0;

  DoctorIncomeStats? get stats => _stats;
  List<DoctorIncomeRecord> get records => _records;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get hasLoaded => _stats != null;

  Future<void> load({bool refresh = false}) async {
    final generation = ++_requestGeneration;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _gateway.loadIncome();
      if (generation != _requestGeneration) return;
      _stats = snapshot.stats;
      _records = snapshot.records.items;
      _page = snapshot.records.page;
      _hasMore = snapshot.records.hasMore;
    } on Object catch (error) {
      if (generation != _requestGeneration) return;
      _error = _errorMessage(error, '收入数据加载失败，请稍后重试');
    } finally {
      if (generation == _requestGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final next = await _gateway.loadIncomeRecords(page: _page + 1);
      _records = [..._records, ...next.items];
      _page = next.page;
      _hasMore = next.hasMore;
    } on Object catch (error) {
      _error = _errorMessage(error, '收入明细加载失败，请稍后重试');
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}

class DoctorProfileController extends ChangeNotifier {
  DoctorProfileController({required DoctorPortalGateway gateway})
    : _gateway = gateway;

  final DoctorPortalGateway _gateway;

  DoctorPortalProfile? _profile;
  bool _loading = false;
  bool _updatingOnlineStatus = false;
  String? _error;
  String? _notice;

  DoctorPortalProfile? get profile => _profile;
  bool get loading => _loading;
  bool get updatingOnlineStatus => _updatingOnlineStatus;
  String? get error => _error;
  bool get hasLoaded => _profile != null;

  String? takeNotice() {
    final value = _notice;
    _notice = null;
    return value;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _gateway.loadProfile();
    } on Object catch (error) {
      _error = _errorMessage(error, '医生资料加载失败，请稍后重试');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateOnlineStatus(bool online) async {
    if (_updatingOnlineStatus || _profile?.isOnline == online) return;
    _updatingOnlineStatus = true;
    notifyListeners();
    try {
      final updated = await _gateway.updateOnlineStatus(online);
      _profile = _profile?.copyWith(isOnline: updated.isOnline) ?? updated;
      _notice = online ? '已切换为在线接诊' : '已切换为离线状态';
    } on Object catch (error) {
      _notice = _errorMessage(error, '在线状态更新失败，请稍后重试');
    } finally {
      _updatingOnlineStatus = false;
      notifyListeners();
    }
  }
}

String _errorMessage(Object error, String fallback) {
  final text = '$error'.trim();
  return text.isEmpty || text == 'Exception' ? fallback : text;
}
