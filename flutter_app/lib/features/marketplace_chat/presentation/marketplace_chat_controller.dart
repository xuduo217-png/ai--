import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/messaging/in_app_message_event.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../../../core/storage/conversation_visibility_store.dart';
import '../../friends/data/friends_media_uploader.dart';
import '../../friends/domain/friend_messaging_models.dart';
import '../../friends/domain/friend_media_content.dart';
import '../../friends/domain/friend_voice_content.dart';
import '../data/marketplace_chat_local_store.dart';
import '../data/marketplace_chat_repository.dart';
import '../data/marketplace_chat_socket_client.dart';
import '../domain/marketplace_chat_models.dart';

typedef MarketplaceSessionRevokedCallback = Future<void> Function();

class MarketplaceChatController extends ChangeNotifier {
  MarketplaceChatController({
    required this.ownerUserId,
    required MarketplaceChatRepositoryGateway repository,
    required MarketplaceChatLocalStore localStore,
    required MarketplaceChatSocketGateway socket,
    required MarketplaceSessionRevokedCallback onSessionRevoked,
    FriendsMediaUploaderGateway? mediaUploader,
    String? currentUserAvatar,
    ConversationVisibilityGateway? visibilityStore,
  }) : _repository = repository,
       _localStore = localStore,
       _socket = socket,
       _onSessionRevoked = onSessionRevoked,
       _mediaUploader = mediaUploader,
       _visibilityStore = visibilityStore,
       _currentUserAvatar = currentUserAvatar;

  static const pageSize = 50;

  final int ownerUserId;
  final MarketplaceChatRepositoryGateway _repository;
  final MarketplaceChatLocalStore _localStore;
  final MarketplaceChatSocketGateway _socket;
  final MarketplaceSessionRevokedCallback _onSessionRevoked;
  final FriendsMediaUploaderGateway? _mediaUploader;
  final ConversationVisibilityGateway? _visibilityStore;
  String? _currentUserAvatar;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  final _incomingMessageEvents = StreamController<InAppMessageEvent>.broadcast(
    sync: true,
  );
  final Set<String> _hiddenConversationIds = <String>{};
  List<MarketplaceConversation> _conversations = const [];
  String _search = '';
  String? _activeConversationId;
  String? _errorMessage;
  int _totalUnreadCount = 0;
  int _temporarySequence = 0;
  bool _loading = true;
  bool _loadingMoreConversations = false;
  bool _visibilityLoaded = false;
  bool _syncing = false;
  bool _started = false;
  bool _closed = false;
  bool _disposed = false;
  final Set<String> _activeMediaTransferKeys = <String>{};
  int _conversationPage = 0;
  int _conversationTotalPages = 0;

  List<MarketplaceConversation> get conversations =>
      List.unmodifiable(_conversations);
  String get search => _search;
  String? get activeConversationId => _activeConversationId;
  String? get errorMessage => _errorMessage;
  int get totalUnreadCount => _totalUnreadCount;
  bool get loading => _loading;
  bool get loadingMoreConversations => _loadingMoreConversations;
  bool get hasMoreConversations => _conversationPage < _conversationTotalPages;
  bool get syncing => _syncing;
  bool get connected => _socket.isConnected;
  bool get hasActiveMediaTransfer => _activeMediaTransferKeys.isNotEmpty;
  String? get currentUserAvatar => _currentUserAvatar;
  Stream<InAppMessageEvent> get incomingMessageEvents =>
      _incomingMessageEvents.stream;

  void updateCurrentUserAvatar(String? avatar) {
    final next = avatar?.trim().isEmpty == true ? null : avatar?.trim();
    if (next == _currentUserAvatar) return;
    _currentUserAvatar = next;
    _safeNotify();
  }

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    _loading = true;
    _safeNotify();
    try {
      await _localStore.open();
      await _loadVisibility();
      await _localStore.failPendingMessages(ownerUserId);
      await _reloadLocal();
      _listenToSocket();
      await _socket.connect();
      await _socket.fetchOfflineMessages();
      await _syncConversations();
      await _refreshUnreadCount();
    } on Object catch (error) {
      _errorMessage = _readable(error, '商城消息同步失败');
      await _refreshLocalUnreadCount();
    } finally {
      _loading = false;
      _syncing = false;
      _safeNotify();
    }
  }

  Future<void> refresh() async {
    if (_closed || _syncing) return;
    _syncing = true;
    _errorMessage = null;
    _safeNotify();
    try {
      await _socket.connect();
      await _socket.fetchOfflineMessages();
      await _syncConversations();
      await _refreshUnreadCount();
    } on Object catch (error) {
      _errorMessage = _readable(error, '商城消息刷新失败');
      await _reloadLocal();
    } finally {
      _syncing = false;
      _safeNotify();
    }
  }

  Future<void> resume() async {
    if (_closed) return;
    try {
      await _socket.connect();
      await _socket.fetchOfflineMessages();
      await _syncConversations();
      await _refreshUnreadCount();
    } on Object catch (error) {
      _errorMessage = _readable(error, '商城消息连接恢复失败');
      _safeNotify();
    }
  }

  Future<void> updateSearch(String value) async {
    _search = value.trim();
    await _reloadLocal();
  }

  Future<MarketplaceConversation> openProductConversation(int productId) async {
    final conversation = await _repository.openConversation(productId);
    await _restoreConversation(conversation.conversationId);
    await _localStore.persistConversation(ownerUserId, conversation);
    await _reloadLocal();
    return conversation;
  }

  MarketplaceConversation? conversationFor(String conversationId) {
    for (final conversation in _conversations) {
      if (conversation.conversationId == conversationId) return conversation;
    }
    return null;
  }

  Future<MarketplaceConversation?> resolveConversation(
    String conversationId,
  ) async {
    final current = conversationFor(conversationId);
    if (current != null) return current;
    try {
      final conversation = await _repository.loadConversation(conversationId);
      await _localStore.persistConversation(ownerUserId, conversation);
      await _reloadLocal();
      return conversation;
    } on Object catch (error) {
      _errorMessage = _readable(error, '会话信息加载失败');
      _safeNotify();
      return null;
    }
  }

  Future<MarketplaceConversation> refreshConversation(
    String conversationId,
  ) async {
    final conversation = await _repository.loadConversation(conversationId);
    await _localStore.persistConversation(ownerUserId, conversation);
    await _reloadLocal();
    return conversation;
  }

  Future<List<FriendMessage>> loadMessages(
    String conversationId, {
    int limit = pageSize,
  }) {
    return _localStore.loadMessages(ownerUserId, conversationId, limit: limit);
  }

  Future<int> messageCount(String conversationId) =>
      _localStore.messageCount(ownerUserId, conversationId);

  bool canRevoke(FriendMessage message) {
    if (message.senderId != ownerUserId ||
        message.messageId == null ||
        message.sendStatus != MessageSendStatus.sent ||
        message.isRevoked ||
        !const {
          'text',
          'image',
          'video',
          'voice',
        }.contains(message.messageType)) {
      return false;
    }
    final elapsed = DateTime.now().toUtc().difference(
      message.createdAt.toUtc(),
    );
    return !elapsed.isNegative && elapsed <= const Duration(minutes: 2);
  }

  Future<void> revokeMessage(
    MarketplaceConversation conversation,
    FriendMessage message,
  ) async {
    final messageId = message.messageId;
    if (messageId == null || !canRevoke(message)) {
      throw StateError('该消息已超过可撤回时间');
    }
    final recallRepository = _repository is MarketplaceMessageRecallGateway
        ? _repository as MarketplaceMessageRecallGateway
        : null;
    if (recallRepository == null) {
      throw StateError('当前聊天暂不支持撤回');
    }
    final revoked = await recallRepository.revokeMessage(messageId);
    await _applyRevokedMessage(revoked, conversation);
  }

  Future<void> syncConversation(
    MarketplaceConversation conversation, {
    int page = 1,
  }) async {
    final result = await _repository.loadMessages(
      conversationId: conversation.conversationId,
      page: page,
      pageSize: pageSize,
    );
    for (final message in result.items) {
      await _localStore.persistMessage(
        ownerUserId: ownerUserId,
        message: message,
      );
    }
    await _localStore.persistConversation(ownerUserId, conversation);
    if (_activeConversationId == conversation.conversationId) {
      await markConversationRead(conversation);
    }
    await _reloadLocal();
    return;
  }

  Future<void> setActiveConversation(
    MarketplaceConversation conversation,
  ) async {
    _activeConversationId = conversation.conversationId;
    await markConversationRead(conversation);
    _safeNotify();
  }

  void clearActiveConversation(String conversationId) {
    if (_activeConversationId != conversationId) return;
    _activeConversationId = null;
    _safeNotify();
  }

  Future<void> markConversationRead(
    MarketplaceConversation conversation,
  ) async {
    final changed = await _localStore.markConversationRead(
      ownerUserId,
      conversation.conversationId,
    );
    for (final message in changed) {
      final messageId = message.messageId;
      if (messageId == null || messageId.isEmpty) continue;
      try {
        await _socket.markMessageRead(
          messageId: messageId,
          conversationId: conversation.conversationId,
        );
      } on Object {
        try {
          await _repository.markMessageRead(
            messageId: messageId,
            conversationId: conversation.conversationId,
          );
        } on Object {
          // The next sync will retry an unread message if the network is down.
        }
      }
    }
    if (changed.isEmpty) {
      try {
        await _repository.markConversationRead(conversation.conversationId);
      } on Object {
        // Local read state remains useful while the app is offline.
      }
    }
    await _reloadLocal();
    await _refreshLocalUnreadCount();
  }

  Future<void> hideConversation(MarketplaceConversation conversation) async {
    await markConversationRead(conversation);
    _hiddenConversationIds.add(conversation.conversationId);
    await _visibilityStore?.hideConversation(
      ownerUserId: ownerUserId,
      scope: ConversationVisibilityScope.marketplace,
      conversationId: conversation.conversationId,
    );
    await _reloadLocal();
  }

  Future<void> loadMoreConversations() async {
    if (_closed ||
        _loading ||
        _syncing ||
        _loadingMoreConversations ||
        !hasMoreConversations) {
      return;
    }
    _loadingMoreConversations = true;
    _safeNotify();
    try {
      final result = await _repository.loadConversations(
        page: _conversationPage + 1,
        pageSize: pageSize,
      );
      await _restoreHiddenWithUnread(result.items);
      await _localStore.persistConversations(ownerUserId, result.items);
      _conversationPage = result.page;
      _conversationTotalPages = result.totalPages;
      _errorMessage = null;
      await _reloadLocal();
    } on Object catch (error) {
      _errorMessage = _readable(error, '商城消息加载更多失败');
    } finally {
      _loadingMoreConversations = false;
      _safeNotify();
    }
  }

  Future<void> sendText(
    MarketplaceConversation conversation,
    String raw,
  ) async {
    final content = raw.trim();
    if (content.isEmpty) return;
    if (content.length > 500) throw ArgumentError('文字消息最多500字符');
    final message = _optimisticMessage(
      conversation,
      messageType: 'text',
      content: content,
    );
    await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: message,
    );
    await _updateConversation(message, conversation);
    await _reloadLocal();
    await _sendPersisted(message, conversation);
  }

  Future<void> sendMedia(
    MarketplaceConversation conversation,
    FriendMediaSendRequest request,
  ) async {
    final file = resolveLocalFile(request.localFilePath);
    if (file == null || !await file.exists()) throw StateError('文件已失效，请重新选择');
    final message = _optimisticMessage(
      conversation,
      messageType: request.type.name,
      content: request.localContent.toMessageContent(),
      localFilePath: request.localFilePath,
      localThumbnailPath: request.localThumbnailPath,
      mediaStage: MediaTransferStage.draft,
    );
    await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: message,
    );
    await _updateConversation(message, conversation);
    await _reloadLocal();
    await _uploadAndSendMedia(message, conversation, request);
  }

  Future<void> sendVoice(
    MarketplaceConversation conversation,
    FriendVoiceSendRequest request,
  ) async {
    final file = resolveLocalFile(request.localFilePath);
    if (file == null || !await file.exists()) throw StateError('语音文件不存在，请重新录制');
    final message = _optimisticMessage(
      conversation,
      messageType: 'voice',
      content: request.localContent.toMessageContent(),
      localFilePath: request.localFilePath,
      mediaStage: MediaTransferStage.draft,
    );
    await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: message,
    );
    await _updateConversation(message, conversation);
    await _reloadLocal();
    await _uploadAndSendVoice(message, conversation, request);
  }

  Future<void> retry(
    MarketplaceConversation conversation,
    FriendMessage message,
  ) async {
    if (message.sendStatus != MessageSendStatus.failed) return;
    if (message.messageType == 'text') {
      final retrying = message.copyWith(sendStatus: MessageSendStatus.sending);
      await _localStore.replaceMessage(
        ownerUserId: ownerUserId,
        previousLocalKey: message.localKey,
        message: retrying,
      );
      await _sendPersisted(retrying, conversation);
      return;
    }
    final localPath = message.localFilePath;
    final file = resolveLocalFile(localPath);
    if (file == null || !await file.exists()) throw StateError('本地文件已失效，请重新选择');
    final content = FriendMediaContent.parse(message.content);
    if (message.messageType == 'voice') {
      final voice = FriendVoiceContent.parse(message.content);
      await sendVoice(
        conversation,
        FriendVoiceSendRequest(
          localFilePath: file.path,
          duration: voice?.duration ?? 1,
          fileName: file.uri.pathSegments.last,
          size: await file.length(),
        ),
      );
    } else {
      await sendMedia(
        conversation,
        FriendMediaSendRequest(
          type: message.messageType == 'video'
              ? FriendMediaType.video
              : FriendMediaType.image,
          localFilePath: file.path,
          localThumbnailPath: message.localThumbnailPath,
          fileName: content?.fileName ?? file.uri.pathSegments.last,
          mimeType: content?.mimeType ?? 'image/jpeg',
          size: content?.size ?? await file.length(),
          width: content?.width,
          height: content?.height,
          duration: content?.duration,
        ),
      );
    }
  }

  Future<void> reportMessage(FriendMessage message, {String? description}) =>
      _repository.reportMessage(
        message.messageId ?? message.localKey,
        description: description,
      );

  Future<void> blockPeer(MarketplaceConversation conversation) async {
    await _repository.blockUser(conversation.peer.id);
    _errorMessage = '已屏蔽对方';
    _safeNotify();
  }

  Future<void> _uploadAndSendMedia(
    FriendMessage message,
    MarketplaceConversation conversation,
    FriendMediaSendRequest request,
  ) async {
    final uploader = _mediaUploader;
    if (uploader == null) throw StateError('媒体上传服务尚未配置');
    _activeMediaTransferKeys.add(message.localKey);
    try {
      final result = request.type == FriendMediaType.image
          ? await uploader.uploadImage(
              filePath: request.localFilePath,
              fileName: request.fileName,
              mimeType: request.mimeType,
            )
          : await uploader.uploadVideo(
              filePath: request.localFilePath,
              fileName: request.fileName,
              mimeType: request.mimeType,
              thumbnailPath: request.localThumbnailPath,
            );
      final content = FriendMediaContent(
        url: result.url,
        thumbnail: result.thumbnail,
        width: result.width ?? request.width,
        height: result.height ?? request.height,
        duration: request.duration,
        size: result.size ?? request.size,
        fileName: request.fileName,
        mimeType: request.mimeType,
      );
      final ready = message.copyWith(
        content: content.toMessageContent(),
        mediaStage: MediaTransferStage.readyToSend,
      );
      await _localStore.replaceMessage(
        ownerUserId: ownerUserId,
        previousLocalKey: message.localKey,
        message: ready,
      );
      await _sendPersisted(ready, conversation);
    } on Object {
      await _markFailed(message);
      rethrow;
    } finally {
      _activeMediaTransferKeys.remove(message.localKey);
    }
  }

  Future<void> _uploadAndSendVoice(
    FriendMessage message,
    MarketplaceConversation conversation,
    FriendVoiceSendRequest request,
  ) async {
    final uploader = _mediaUploader;
    if (uploader == null) throw StateError('媒体上传服务尚未配置');
    _activeMediaTransferKeys.add(message.localKey);
    try {
      final result = await uploader.uploadVoice(
        filePath: request.localFilePath,
        fileName: request.fileName,
        mimeType: request.mimeType,
      );
      final ready = message.copyWith(
        content: FriendVoiceContent(
          url: result.url,
          duration: request.duration,
        ).toMessageContent(),
        mediaStage: MediaTransferStage.readyToSend,
      );
      await _localStore.replaceMessage(
        ownerUserId: ownerUserId,
        previousLocalKey: message.localKey,
        message: ready,
      );
      await _sendPersisted(ready, conversation);
    } on Object {
      await _markFailed(message);
      rethrow;
    } finally {
      _activeMediaTransferKeys.remove(message.localKey);
    }
  }

  Future<void> _sendPersisted(
    FriendMessage message,
    MarketplaceConversation conversation,
  ) async {
    final tempId = message.tempMessageId ?? message.localKey;
    try {
      final ack = await _socket.sendMessage(
        conversationId: conversation.conversationId,
        messageType: message.messageType,
        content: message.content,
        tempMessageId: tempId,
      );
      final serverMessage =
          ack.message ?? _serverMessage(message, ack.messageId);
      await _localStore.replaceMessage(
        ownerUserId: ownerUserId,
        previousLocalKey: message.localKey,
        message: serverMessage,
      );
      await _updateConversation(serverMessage, conversation);
      await _reloadLocal();
    } on Object {
      await _markFailed(message);
      rethrow;
    }
  }

  Future<void> _handleIncoming(FriendMessage message) async {
    await _restoreConversation(message.conversationId);
    MarketplaceConversation? conversation = conversationFor(
      message.conversationId,
    );
    if (conversation == null) {
      try {
        conversation = await _repository.loadConversation(
          message.conversationId,
        );
      } on Object catch (error) {
        _errorMessage = _readable(error, '收到商城消息，但会话信息加载失败');
        _safeNotify();
        return;
      }
    }
    if (message.isRevoked) {
      await _applyRevokedMessage(message, conversation);
      return;
    }
    final active = _activeConversationId == message.conversationId;
    final incoming = message.receiverId == ownerUserId;
    final normalized = active && incoming
        ? message.copyWith(isRead: true)
        : message;
    await _localStore.persistConversation(ownerUserId, conversation);
    final inserted = await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: normalized,
    );
    await _updateConversation(
      normalized,
      conversation,
      unreadIncrement: inserted && incoming && !active,
    );
    if (active && incoming && normalized.messageId != null) {
      try {
        await _socket.markMessageRead(
          messageId: normalized.messageId!,
          conversationId: normalized.conversationId,
        );
      } on Object {
        // Local read state is retained until the next sync.
      }
    }
    if (message.deliveryMode == 'offline') {
      await _socket.acknowledgeOfflineMessages([
        message.messageId ?? message.localKey,
      ]);
    }
    await _reloadLocal();
    if (!_closed && inserted && incoming && !active) {
      _incomingMessageEvents.add(
        InAppMessageEvent(
          eventKey: 'marketplace:${message.localKey}',
          channel: InAppMessageChannel.marketplace,
          conversationId: message.conversationId,
          senderId: message.senderId,
          title: conversation.peer.nickname,
          preview: inAppMessagePreview(
            messageType: message.messageType,
            content: message.content,
          ),
          avatarUrl: conversation.peer.avatar,
          createdAt: message.createdAt,
          isOffline: message.deliveryMode == 'offline',
        ),
      );
    }
  }

  Future<void> _applyRevokedMessage(
    FriendMessage message,
    MarketplaceConversation conversation,
  ) async {
    final removedUnread = await _localStore.applyRevokedMessage(
      ownerUserId: ownerUserId,
      message: message,
    );
    final current =
        conversationFor(conversation.conversationId) ?? conversation;
    final updated = current.copyWith(
      lastMessage: current.lastMessage?.messageId == message.messageId
          ? MarketplaceLastMessage.fromMessage(message)
          : current.lastMessage,
      unreadCount: removedUnread && current.unreadCount > 0
          ? current.unreadCount - 1
          : current.unreadCount,
      updatedAt: current.updatedAt,
    );
    await _localStore.persistConversation(ownerUserId, updated);
    await _reloadLocal();
  }

  void _listenToSocket() {
    _subscriptions.add(
      _socket.messages.listen((message) => unawaited(_handleIncoming(message))),
    );
    _subscriptions.add(
      _socket.sessionRevoked.listen((_) => unawaited(_onSessionRevoked())),
    );
    _subscriptions.add(
      _socket.readReceipts.listen(
        (receipt) => unawaited(_handleReadReceipt(receipt)),
      ),
    );
    _subscriptions.add(_socket.connectionChanges.listen((_) => _safeNotify()));
    _subscriptions.add(
      _socket.errors.listen((error) {
        _errorMessage = _readable(error, '商城聊天连接异常');
        _safeNotify();
      }),
    );
  }

  Future<void> _handleReadReceipt(FriendReadReceipt receipt) async {
    if (receipt.readerId == ownerUserId) return;
    final changed = await _localStore.markMessageReadById(
      ownerUserId,
      receipt.messageId,
    );
    if (changed) await _reloadLocal();
  }

  Future<void> _syncConversations() async {
    final result = await _repository.loadConversations(
      page: 1,
      pageSize: pageSize,
    );
    await _restoreHiddenWithUnread(result.items);
    await _localStore.persistConversations(ownerUserId, result.items);
    _conversationPage = result.page;
    _conversationTotalPages = result.totalPages;
    await _reloadLocal();
  }

  Future<void> _reloadLocal() async {
    if (_closed) return;
    _conversations =
        (await _localStore.loadConversations(ownerUserId, search: _search))
            .where(
              (conversation) =>
                  !_hiddenConversationIds.contains(conversation.conversationId),
            )
            .toList(growable: false);
    await _refreshLocalUnreadCount();
    _safeNotify();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      _totalUnreadCount = await _repository.loadUnreadCount();
    } on Object {
      await _refreshLocalUnreadCount();
    }
    _safeNotify();
  }

  Future<void> _refreshLocalUnreadCount() async {
    _totalUnreadCount = await _localStore.totalUnreadCount(
      ownerUserId,
      excludedConversationIds: _hiddenConversationIds,
    );
  }

  Future<void> _loadVisibility() async {
    if (_visibilityLoaded) return;
    _visibilityLoaded = true;
    final store = _visibilityStore;
    if (store == null) return;
    _hiddenConversationIds.addAll(
      await store.loadHiddenConversationIds(
        ownerUserId: ownerUserId,
        scope: ConversationVisibilityScope.marketplace,
      ),
    );
  }

  Future<void> _restoreConversation(String conversationId) async {
    if (!_hiddenConversationIds.remove(conversationId)) return;
    await _visibilityStore?.restoreConversation(
      ownerUserId: ownerUserId,
      scope: ConversationVisibilityScope.marketplace,
      conversationId: conversationId,
    );
  }

  Future<void> _restoreHiddenWithUnread(
    Iterable<MarketplaceConversation> conversations,
  ) async {
    await Future.wait(
      conversations
          .where((conversation) => conversation.unreadCount > 0)
          .map(
            (conversation) => _restoreConversation(conversation.conversationId),
          ),
    );
  }

  FriendMessage _optimisticMessage(
    MarketplaceConversation conversation, {
    required String messageType,
    required String content,
    String? localFilePath,
    String? localThumbnailPath,
    MediaTransferStage mediaStage = MediaTransferStage.none,
  }) {
    final now = DateTime.now().toUtc();
    return FriendMessage(
      conversationId: conversation.conversationId,
      senderId: ownerUserId,
      receiverId: conversation.peer.id,
      messageType: messageType,
      content: content,
      sendStatus: MessageSendStatus.sending,
      isRead: false,
      readSynced: true,
      createdAt: now,
      updatedAt: now,
      tempMessageId: _nextTempMessageId(),
      localFilePath: localFilePath,
      localThumbnailPath: localThumbnailPath,
      localFileExists: localFilePath != null,
      mediaStage: mediaStage,
    );
  }

  FriendMessage _serverMessage(FriendMessage message, String? messageId) {
    final now = DateTime.now().toUtc();
    return FriendMessage(
      messageId: messageId,
      conversationId: message.conversationId,
      senderId: message.senderId,
      receiverId: message.receiverId,
      messageType: message.messageType,
      content: message.content,
      sendStatus: MessageSendStatus.sent,
      isRead: false,
      readSynced: true,
      createdAt: message.createdAt,
      updatedAt: now,
      localFilePath: message.localFilePath,
      localThumbnailPath: message.localThumbnailPath,
      localFileExists: message.localFileExists,
      mediaStage: message.messageType == 'text'
          ? MediaTransferStage.none
          : MediaTransferStage.sent,
    );
  }

  Future<void> _markFailed(FriendMessage message) async {
    final failed = message.copyWith(
      sendStatus: MessageSendStatus.failed,
      mediaStage: message.messageType == 'text'
          ? MediaTransferStage.none
          : MediaTransferStage.failed,
    );
    await _localStore.replaceMessage(
      ownerUserId: ownerUserId,
      previousLocalKey: message.localKey,
      message: failed,
    );
    await _reloadLocal();
  }

  Future<void> _updateConversation(
    FriendMessage message,
    MarketplaceConversation conversation, {
    bool? unreadIncrement,
  }) async {
    final current =
        conversationFor(conversation.conversationId) ?? conversation;
    final increment =
        unreadIncrement ??
        (message.receiverId == ownerUserId && message.senderId != ownerUserId);
    final updated = current.copyWith(
      lastMessage: MarketplaceLastMessage.fromMessage(message),
      unreadCount: _activeConversationId == current.conversationId
          ? 0
          : (current.unreadCount + (increment ? 1 : 0)),
      updatedAt: message.createdAt,
    );
    await _localStore.persistConversation(ownerUserId, updated);
  }

  String _nextTempMessageId() =>
      'marketplace_${ownerUserId}_${DateTime.now().microsecondsSinceEpoch}_${_temporarySequence++}';

  Future<void> stop({bool clearLocalData = false}) async {
    if (!_started) return;
    _started = false;
    await _socket.stop();
    if (clearLocalData) await _localStore.clearOwner(ownerUserId);
  }

  Future<void> close({bool clearLocalData = false}) async {
    if (_closed) return;
    _closed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _socket.dispose();
    if (clearLocalData) await _localStore.clearOwner(ownerUserId);
    await _localStore.close();
    await _incomingMessageEvents.close();
    dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}

String _readable(Object error, String fallback) {
  final text = '$error'.replaceFirst('Exception: ', '').trim();
  return text.isEmpty ? fallback : text;
}
