import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../core/messaging/in_app_message_event.dart';
import '../../core/storage/conversation_visibility_store.dart';
import 'data/consultation_messaging_repository.dart';
import 'data/consultation_realtime_socket_client.dart';
import 'domain/chat_models.dart';
import 'domain/consultation_conversation_activity.dart';
import 'domain/consultation_conversation.dart';

class ConsultationMessagingSession extends ChangeNotifier
    implements ConsultationConversationActivity {
  ConsultationMessagingSession({
    required this.ownerUserId,
    required ConsultationMessagingRepositoryGateway repository,
    required ConsultationRealtimeGateway socket,
    required Future<void> Function() onSessionRevoked,
    ConversationVisibilityGateway? visibilityStore,
  }) : _repository = repository,
       _socket = socket,
       _onSessionRevoked = onSessionRevoked,
       _visibilityStore = visibilityStore;

  static const conversationPageSize = 20;

  final int ownerUserId;
  final ConsultationMessagingRepositoryGateway _repository;
  final ConsultationRealtimeGateway _socket;
  final Future<void> Function() _onSessionRevoked;
  final ConversationVisibilityGateway? _visibilityStore;
  final Queue<String> _recentMessageKeys = Queue<String>();
  final Set<String> _recentMessageKeySet = <String>{};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final _incomingMessageEvents = StreamController<InAppMessageEvent>.broadcast(
    sync: true,
  );

  int _totalUnreadCount = 0;
  List<ConsultationConversation> _allConversations = const [];
  final Set<String> _hiddenConversationIds = <String>{};
  String? _activeConversationId;
  String? _conversationError;
  String? _loadMoreError;
  Object? _lastError;
  bool _loadingConversations = true;
  bool _loadingMoreConversations = false;
  bool _visibilityLoaded = false;
  bool _started = false;
  bool _closed = false;
  int _conversationPage = 0;
  int _conversationTotalPages = 0;
  Future<void> _operation = Future<void>.value();

  int get totalUnreadCount => _totalUnreadCount;
  List<ConsultationConversation> get conversations => List.unmodifiable(
    _allConversations.where(
      (conversation) =>
          !_hiddenConversationIds.contains(conversation.conversationId),
    ),
  );
  String? get activeConversationId => _activeConversationId;
  String? get conversationError => _conversationError;
  String? get loadMoreError => _loadMoreError;
  Object? get lastError => _lastError;
  bool get loadingConversations => _loadingConversations;
  bool get loadingMoreConversations => _loadingMoreConversations;
  bool get hasMoreConversations => _conversationPage < _conversationTotalPages;
  bool get isConnected => _socket.isConnected;
  Stream<InAppMessageEvent> get incomingMessageEvents =>
      _incomingMessageEvents.stream;

  Future<void> start() => _enqueue(_start);

  Future<void> _start() async {
    if (_closed) return;
    await _loadVisibility();
    if (!_started) {
      _started = true;
      _subscriptions
        ..add(
          _socket.messages.listen(
            (message) => unawaited(_handleIncomingMessage(message)),
          ),
        )
        ..add(
          _socket.connectionChanges.listen((connected) {
            if (connected) unawaited(refreshUnreadCount());
            _notify();
          }),
        )
        ..add(_socket.errors.listen(_handleError))
        ..add(
          _socket.sessionRevoked.listen((_) {
            unawaited(_onSessionRevoked());
          }),
        );
      final extensionSubscription = _listenSessionExtensions();
      if (extensionSubscription != null) {
        _subscriptions.add(extensionSubscription);
      }
    }
    await _refreshAndConnect();
  }

  StreamSubscription<ChatSessionExtension>? _listenSessionExtensions() {
    final extensionSocket = _socket;
    if (extensionSocket is! ConsultationSessionExtensionRealtimeGateway) {
      return null;
    }
    final extensionGateway =
        extensionSocket as ConsultationSessionExtensionRealtimeGateway;
    return extensionGateway.sessionExtensions.listen(_handleSessionExtended);
  }

  void _handleSessionExtended(ChatSessionExtension extension) {
    if (_closed) return;
    final index = _allConversations.indexWhere(
      (item) => item.conversationId == extension.conversationId,
    );
    if (index < 0) return;
    final updated = [..._allConversations];
    updated[index] = updated[index].copyWith(
      status: extension.status,
      serviceEndAt: extension.serviceEndAt,
      paymentRequired: false,
    );
    _allConversations = _sorted(updated);
    _notify();
  }

  Future<void> resume() => _enqueue(() async {
    if (!_started) {
      await _start();
      return;
    }
    await _refreshAndConnect();
  });

  Future<void> _refreshAndConnect() async {
    await refresh();
    try {
      await _socket.connect();
    } on Object catch (error) {
      _handleError(error);
    }
  }

  Future<void> pause() => _enqueue(_socket.pause);

  Future<void> refresh() async {
    await Future.wait<void>([refreshConversations(), refreshUnreadCount()]);
  }

  Future<void> refreshConversations() async {
    if (_closed) return;
    _loadingConversations = true;
    _conversationError = null;
    _loadMoreError = null;
    _notify();
    try {
      final page = await _repository.loadConversations(
        pageSize: conversationPageSize,
      );
      await _restoreHiddenWithUnread(page.items);
      _allConversations = _sorted(page.items);
      _conversationPage = page.page;
      _conversationTotalPages = page.totalPages;
      _lastError = null;
    } on Object catch (error) {
      _conversationError = '$error';
      _lastError = error;
    } finally {
      _loadingConversations = false;
      _notify();
    }
  }

  Future<void> loadMoreConversations() async {
    if (_closed ||
        _loadingConversations ||
        _loadingMoreConversations ||
        !hasMoreConversations) {
      return;
    }
    _loadingMoreConversations = true;
    _loadMoreError = null;
    _notify();
    try {
      final page = await _repository.loadConversations(
        page: _conversationPage + 1,
        pageSize: conversationPageSize,
      );
      await _restoreHiddenWithUnread(page.items);
      final merged = <String, ConsultationConversation>{
        for (final conversation in _allConversations)
          conversation.conversationId: conversation,
        for (final conversation in page.items)
          conversation.conversationId: conversation,
      };
      _allConversations = _sorted(merged.values);
      _conversationPage = page.page;
      _conversationTotalPages = page.totalPages;
      _lastError = null;
    } on Object catch (error) {
      _loadMoreError = '$error';
      _lastError = error;
    } finally {
      _loadingMoreConversations = false;
      _notify();
    }
  }

  Future<void> refreshUnreadCount() async {
    if (_closed) return;
    try {
      final count = await _repository.loadUnreadCount();
      _lastError = null;
      if (_totalUnreadCount != count) {
        _totalUnreadCount = count;
        _notify();
      }
    } on Object catch (error) {
      _handleError(error);
    }
  }

  @override
  Future<void> openConversation(String conversationId) async {
    if (_closed || conversationId.isEmpty) return;
    _activeConversationId = conversationId;
    await markConversationRead(conversationId);
  }

  Future<ConsultationConversation?> resolveConversation(
    String conversationId,
  ) async {
    for (final conversation in _allConversations) {
      if (conversation.conversationId == conversationId) return conversation;
    }
    await refreshConversations();
    if (_closed) return null;
    for (final conversation in _allConversations) {
      if (conversation.conversationId == conversationId) return conversation;
    }
    return null;
  }

  Future<void> hideConversation(ConsultationConversation conversation) async {
    await markConversationRead(conversation.conversationId);
    _hiddenConversationIds.add(conversation.conversationId);
    await _visibilityStore?.hideConversation(
      ownerUserId: ownerUserId,
      scope: ConversationVisibilityScope.consultation,
      conversationId: conversation.conversationId,
    );
    _notify();
  }

  @override
  void closeConversation(String conversationId) {
    if (_activeConversationId != conversationId) return;
    _activeConversationId = null;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    if (_closed || conversationId.isEmpty) return;
    final index = _allConversations.indexWhere(
      (item) => item.conversationId == conversationId,
    );
    if (index >= 0 && _allConversations[index].unreadCount > 0) {
      final unreadCount = _allConversations[index].unreadCount;
      final updated = [..._allConversations];
      updated[index] = updated[index].copyWith(unreadCount: 0);
      _allConversations = updated;
      final nextUnreadCount = _totalUnreadCount - unreadCount;
      _totalUnreadCount = nextUnreadCount > 0 ? nextUnreadCount : 0;
      _notify();
    }
    try {
      await _repository.markConversationRead(conversationId);
      await refreshUnreadCount();
    } on Object catch (error) {
      _handleError(error);
    }
  }

  Future<void> _handleIncomingMessage(ChatMessage message) async {
    if (_closed || message.receiverId != ownerUserId) return;
    final messageKey = '${message.conversationId}:${message.id}';
    if (!_recentMessageKeySet.add(messageKey)) return;
    _recentMessageKeys.addLast(messageKey);
    if (_recentMessageKeys.length > 200) {
      _recentMessageKeySet.remove(_recentMessageKeys.removeFirst());
    }

    if (_hiddenConversationIds.remove(message.conversationId)) {
      unawaited(
        _visibilityStore?.restoreConversation(
              ownerUserId: ownerUserId,
              scope: ConversationVisibilityScope.consultation,
              conversationId: message.conversationId,
            ) ??
            Future<void>.value(),
      );
    }

    final index = _allConversations.indexWhere(
      (item) => item.conversationId == message.conversationId,
    );
    final isActive = _activeConversationId == message.conversationId;
    ConsultationConversation? resolvedConversation;
    if (index >= 0) {
      final conversation = _allConversations[index];
      final updated = [..._allConversations];
      resolvedConversation = conversation.copyWith(
        lastMessage: ConsultationConversationLastMessage.fromMessage(message),
        unreadCount: isActive ? 0 : conversation.unreadCount + 1,
      );
      updated[index] = resolvedConversation;
      _allConversations = _sorted(updated);
    } else {
      await refreshConversations();
      if (_closed) return;
      for (final conversation in _allConversations) {
        if (conversation.conversationId == message.conversationId) {
          resolvedConversation = conversation;
          break;
        }
      }
    }

    if (isActive) {
      _notify();
      unawaited(markConversationRead(message.conversationId));
      return;
    }
    _totalUnreadCount += 1;
    _notify();
    if (resolvedConversation == null) return;
    final title = resolvedConversation.doctorName.trim();
    _incomingMessageEvents.add(
      InAppMessageEvent(
        eventKey: 'consultation:${message.conversationId}:${message.id}',
        channel: InAppMessageChannel.consultation,
        conversationId: message.conversationId,
        senderId: message.senderId,
        title: title.isEmpty
            ? (message.senderName?.trim().isNotEmpty == true
                  ? message.senderName!.trim()
                  : '医生消息')
            : title,
        preview: inAppMessagePreview(
          messageType: message.type.wireValue,
          content: message.content,
        ),
        avatarUrl: resolvedConversation.doctorAvatarUrl,
        createdAt: message.createdAt,
      ),
    );
  }

  void _handleError(Object error) {
    if (_closed) return;
    _lastError = error;
    _notify();
  }

  Future<void> close() => _enqueue(() async {
    if (_closed) return;
    _closed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _socket.close();
    await _incomingMessageEvents.close();
    super.dispose();
  });

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _operation.then((_) => action(), onError: (_) => action());
    _operation = next;
    return next;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  List<ConsultationConversation> _sorted(
    Iterable<ConsultationConversation> conversations,
  ) {
    final sorted = conversations.toList(growable: false);
    sorted.sort((left, right) => right.sortTime.compareTo(left.sortTime));
    return sorted;
  }

  Future<void> _loadVisibility() async {
    if (_visibilityLoaded) return;
    _visibilityLoaded = true;
    final store = _visibilityStore;
    if (store == null) return;
    try {
      _hiddenConversationIds.addAll(
        await store.loadHiddenConversationIds(
          ownerUserId: ownerUserId,
          scope: ConversationVisibilityScope.consultation,
        ),
      );
    } on Object catch (error) {
      _lastError = error;
    }
  }

  Future<void> _restoreHiddenWithUnread(
    Iterable<ConsultationConversation> conversations,
  ) async {
    final store = _visibilityStore;
    final restored = conversations
        .where(
          (conversation) =>
              conversation.unreadCount > 0 &&
              _hiddenConversationIds.remove(conversation.conversationId),
        )
        .map((conversation) => conversation.conversationId)
        .toList(growable: false);
    if (store == null || restored.isEmpty) return;
    await Future.wait(
      restored.map(
        (conversationId) => store.restoreConversation(
          ownerUserId: ownerUserId,
          scope: ConversationVisibilityScope.consultation,
          conversationId: conversationId,
        ),
      ),
    );
  }
}
