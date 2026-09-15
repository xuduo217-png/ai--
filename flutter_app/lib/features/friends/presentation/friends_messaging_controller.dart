import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/messaging/in_app_message_event.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../data/friends_media_uploader.dart';
import '../data/friends_local_store.dart';
import '../data/friends_repository.dart';
import '../data/friends_socket_client.dart';
import '../domain/friend_messaging_models.dart';
import '../domain/friend_media_content.dart';
import '../domain/friend_voice_content.dart';

typedef SessionRevokedCallback = Future<void> Function();

class FriendsMessagingController extends ChangeNotifier {
  FriendsMessagingController({
    required this.ownerUserId,
    String? currentUserAvatar,
    required FriendsRepositoryGateway repository,
    required FriendsLocalStore localStore,
    required FriendsSocketGateway socket,
    required SessionRevokedCallback onSessionRevoked,
    FriendsMediaUploaderGateway? mediaUploader,
  }) : _currentUserAvatar = _normalizeCurrentUserAvatar(currentUserAvatar),
       _repository = repository,
       _localStore = localStore,
       _socket = socket,
       _mediaUploader = mediaUploader,
       _onSessionRevoked = onSessionRevoked;

  static const int historyPageSize = 50;
  static const int maxHistoryConcurrency = 4;

  final int ownerUserId;
  String? _currentUserAvatar;
  final FriendsRepositoryGateway _repository;
  final FriendsLocalStore _localStore;
  final FriendsSocketGateway _socket;
  final FriendsMediaUploaderGateway? _mediaUploader;
  final SessionRevokedCallback _onSessionRevoked;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  final _incomingMessageEvents = StreamController<InAppMessageEvent>.broadcast(
    sync: true,
  );
  final Map<int, FriendshipSummary> _friendsById = {};

  List<FriendConversation> _conversations = const [];
  String _search = '';
  String? _activeConversationId;
  String? _errorMessage;
  int _totalUnreadCount = 0;
  int _temporarySequence = 0;
  bool _loading = true;
  bool _syncing = false;
  bool _started = false;
  bool _hasConnectedOnce = false;
  bool _closed = false;
  bool _notifierDisposed = false;
  bool _voiceTransferInProgress = false;
  final Set<String> _activeMediaTransferIds = <String>{};
  Future<void>? _closeOperation;

  List<FriendConversation> get conversations =>
      List<FriendConversation>.unmodifiable(_conversations);
  String get search => _search;
  String? get activeConversationId => _activeConversationId;
  String? get errorMessage => _errorMessage;
  int get totalUnreadCount => _totalUnreadCount;
  bool get loading => _loading;
  bool get syncing => _syncing;
  bool get connected => _socket.isConnected;
  bool get hasActiveMediaTransfer =>
      _voiceTransferInProgress || _activeMediaTransferIds.isNotEmpty;
  String? get currentUserAvatar => _currentUserAvatar;
  Stream<InAppMessageEvent> get incomingMessageEvents =>
      _incomingMessageEvents.stream;

  void updateCurrentUserAvatar(String? avatarUrl) {
    final nextAvatar = _normalizeCurrentUserAvatar(avatarUrl);
    if (_currentUserAvatar == nextAvatar) return;
    _currentUserAvatar = nextAvatar;
    _safeNotify();
  }

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    _loading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _localStore.open();
      await _localStore.failPendingMessages(ownerUserId);
      await _reloadLocal();
      _loading = false;
      _safeNotify();

      _listenToSocket();
      await _socket.connect();
      await _socket.fetchOfflineMessages();
      await _syncFriendsAndRecentHistory();
      await _syncPendingReads();
      await _refreshServerUnreadCount();
    } on Object catch (error) {
      _errorMessage = _readableError(error, '消息同步失败，下拉可重试');
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
      await _syncFriendsAndRecentHistory();
      await _syncPendingReads();
      await _refreshServerUnreadCount();
    } on Object catch (error) {
      _errorMessage = _readableError(error, '刷新失败，请稍后重试');
      await _reloadLocal();
      await _refreshLocalUnreadCount();
    } finally {
      _syncing = false;
      _safeNotify();
    }
  }

  Future<void> revokeMessage(
    FriendshipSummary friend,
    FriendMessage message,
  ) async {
    final messageId = message.messageId;
    if (messageId == null || !canRevokeMessage(message)) {
      throw StateError('该消息已超过可撤回时间');
    }
    final recallRepository = _repository is FriendsMessageRecallGateway
        ? _repository as FriendsMessageRecallGateway
        : null;
    if (recallRepository == null) {
      throw StateError('当前聊天暂不支持撤回');
    }
    final revoked = await recallRepository.revokeMessage(messageId: messageId);
    await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: revoked,
      friend: friend,
      incrementUnread: false,
      restoreHidden: false,
    );
    await _reloadLocal();
  }

  bool canRevokeMessage(FriendMessage message) {
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

  Future<void> resume() async {
    if (_closed) return;
    try {
      await _socket.connect();
      await _socket.fetchOfflineMessages();
      await _syncPendingReads();
      await _refreshServerUnreadCount();
      await _reloadLocal();
    } on Object catch (error) {
      _errorMessage = _readableError(error, '消息连接恢复失败');
      _safeNotify();
    }
  }

  Future<void> updateSearch(String value) async {
    final normalized = value.trim();
    if (_search == normalized) return;
    _search = normalized;
    await _reloadLocal();
  }

  FriendshipSummary friendForConversation(FriendConversation conversation) {
    return _friendsById[conversation.friendId] ??
        FriendshipSummary(
          friendId: conversation.friendId,
          friendName: conversation.friendName,
          friendAvatar: conversation.friendAvatar,
          friendSignature: conversation.friendSignature,
          serverConversationId: conversation.conversationId,
          lastChatAt: conversation.lastMessageAt,
        );
  }

  Future<void> updateFriendSummary(FriendshipSummary friend) async {
    _friendsById[friend.friendId] = friend;
    await _localStore.upsertConversationFromFriend(
      ownerUserId: ownerUserId,
      friend: friend,
    );
    await _reloadLocal();
  }

  Future<void> removeFriend(int friendId) async {
    final friend = _friendsById.remove(friendId);
    final conversationId =
        friend?.conversationIdFor(ownerUserId) ??
        buildFriendConversationId(ownerUserId, friendId);
    await _localStore.deleteConversationData(ownerUserId, conversationId);
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
    await _reloadLocal();
    await _refreshLocalUnreadCount();
  }

  Future<List<FriendMessage>> loadMessages(
    String conversationId, {
    int limit = historyPageSize,
  }) {
    return _localStore.getMessages(ownerUserId, conversationId, limit: limit);
  }

  Future<int> messageCount(String conversationId) {
    return _localStore.getMessageCount(ownerUserId, conversationId);
  }

  Future<FriendPage<FriendMessage>> syncConversation(
    FriendshipSummary friend, {
    required int page,
  }) async {
    _friendsById[friend.friendId] = friend;
    final result = await _repository.loadMessageHistory(
      friendId: friend.friendId,
      page: page,
      pageSize: historyPageSize,
    );
    await _localStore.persistMessages(
      ownerUserId: ownerUserId,
      messages: result.items,
      friend: friend,
      countIncomingUnread: true,
      restoreHidden: false,
    );
    if (_activeConversationId == friend.conversationIdFor(ownerUserId)) {
      await _markConversationRead(friend.conversationIdFor(ownerUserId));
    }
    await _reloadLocal();
    await _refreshLocalUnreadCount();
    return result;
  }

  Future<void> setActiveConversation(FriendshipSummary friend) async {
    final conversationId = friend.conversationIdFor(ownerUserId);
    _friendsById[friend.friendId] = friend;
    _activeConversationId = conversationId;
    await _markConversationRead(conversationId);
  }

  void clearActiveConversation(String conversationId) {
    if (_activeConversationId != conversationId) return;
    _activeConversationId = null;
    _safeNotify();
  }

  Future<void> hideConversation(FriendConversation conversation) async {
    await _markConversationRead(conversation.conversationId);
    await _localStore.hideConversation(
      ownerUserId,
      conversation.conversationId,
    );
    await _reloadLocal();
    await _refreshLocalUnreadCount();
  }

  Future<String?> sendText(
    FriendshipSummary friend,
    String rawContent, {
    String? tempMessageId,
  }) async {
    final content = rawContent.trim();
    if (content.isEmpty) return null;
    if (content.length > 500) {
      throw ArgumentError.value(content, 'content', '消息最多 500 字');
    }
    _errorMessage = null;

    final conversationId = friend.conversationIdFor(ownerUserId);
    final temporaryId = tempMessageId ?? _nextTempMessageId();
    final now = DateTime.now().toUtc();
    final optimistic = FriendMessage(
      tempMessageId: temporaryId,
      conversationId: conversationId,
      senderId: ownerUserId,
      receiverId: friend.friendId,
      messageType: 'text',
      content: content,
      sendStatus: MessageSendStatus.sending,
      isRead: false,
      readSynced: true,
      createdAt: now,
      updatedAt: now,
    );
    _friendsById[friend.friendId] = friend;
    await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: optimistic,
      friend: friend,
      incrementUnread: false,
      restoreHidden: true,
    );
    await _reloadLocal();

    await _sendPersistedMessage(optimistic, friend);
    return temporaryId;
  }

  Future<void> retryMessage(
    FriendshipSummary friend,
    FriendMessage message,
  ) async {
    final tempMessageId = message.tempMessageId;
    if (tempMessageId == null ||
        message.sendStatus != MessageSendStatus.failed) {
      return;
    }
    _errorMessage = null;
    if (message.messageType == 'voice') {
      final nextTempMessageId = _nextTempMessageId();
      await _localStore.updateMediaMessage(
        ownerUserId: ownerUserId,
        tempMessageId: tempMessageId,
        nextTempMessageId: nextTempMessageId,
        sendStatus: MessageSendStatus.sending,
        mediaStage: MediaTransferStage.draft,
      );
      final retrying = message.copyWith(
        tempMessageId: nextTempMessageId,
        sendStatus: MessageSendStatus.sending,
        mediaStage: MediaTransferStage.draft,
      );
      await _reloadLocal();
      await _continueVoiceSend(retrying, friend);
      return;
    }
    if (message.messageType == 'image' || message.messageType == 'video') {
      final nextTempMessageId = _nextTempMessageId();
      await _localStore.updateMediaMessage(
        ownerUserId: ownerUserId,
        tempMessageId: tempMessageId,
        nextTempMessageId: nextTempMessageId,
        sendStatus: MessageSendStatus.sending,
        mediaStage: MediaTransferStage.draft,
      );
      final retrying = message.copyWith(
        tempMessageId: nextTempMessageId,
        sendStatus: MessageSendStatus.sending,
        mediaStage: MediaTransferStage.draft,
      );
      await _reloadLocal();
      await _continueMediaSend(retrying, friend);
      return;
    }

    await _localStore.markMessageSending(ownerUserId, tempMessageId);
    await _reloadLocal();
    await _sendPersistedMessage(
      message.copyWith(sendStatus: MessageSendStatus.sending),
      friend,
    );
  }

  Future<String> sendMedia(
    FriendshipSummary friend,
    FriendMediaSendRequest request,
  ) async {
    _errorMessage = null;
    if (_mediaUploader == null) {
      throw StateError('媒体上传服务尚未配置');
    }
    final localFile = resolveLocalFile(request.localFilePath);
    if (localFile == null || !await localFile.exists()) {
      throw StateError('文件已失效，请重新选择');
    }

    final temporaryId = _nextTempMessageId();
    final now = DateTime.now().toUtc();
    final optimistic = FriendMessage(
      tempMessageId: temporaryId,
      conversationId: friend.conversationIdFor(ownerUserId),
      senderId: ownerUserId,
      receiverId: friend.friendId,
      messageType: request.type.name,
      content: request.localContent.toMessageContent(),
      sendStatus: MessageSendStatus.sending,
      isRead: false,
      readSynced: true,
      createdAt: now,
      updatedAt: now,
      localFilePath: request.localFilePath,
      localThumbnailPath: request.localThumbnailPath,
      localFileExists: true,
      mediaStage: MediaTransferStage.draft,
    );
    _friendsById[friend.friendId] = friend;
    await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: optimistic,
      friend: friend,
      incrementUnread: false,
      restoreHidden: true,
    );
    await _reloadLocal();
    await _continueMediaSend(optimistic, friend);
    return temporaryId;
  }

  Future<String> sendVoice(
    FriendshipSummary friend,
    FriendVoiceSendRequest request,
  ) async {
    _errorMessage = null;
    if (_mediaUploader == null) {
      throw StateError('语音上传服务尚未配置');
    }
    final duration = normalizeFriendVoiceDuration(request.duration);
    if (duration < 1) {
      throw ArgumentError.value(request.duration, 'duration', '录音时间不足 1 秒');
    }
    final localFile = resolveLocalFile(request.localFilePath);
    if (localFile == null || !await localFile.exists()) {
      throw StateError('语音文件不存在，请重新录制');
    }

    final temporaryId = _nextTempMessageId();
    final now = DateTime.now().toUtc();
    final optimistic = FriendMessage(
      tempMessageId: temporaryId,
      conversationId: friend.conversationIdFor(ownerUserId),
      senderId: ownerUserId,
      receiverId: friend.friendId,
      messageType: 'voice',
      content: FriendVoiceContent(
        url: request.localFilePath,
        duration: duration,
      ).toMessageContent(),
      sendStatus: MessageSendStatus.sending,
      isRead: false,
      readSynced: true,
      createdAt: now,
      updatedAt: now,
      localFilePath: request.localFilePath,
      localFileExists: true,
      mediaStage: MediaTransferStage.draft,
    );
    _friendsById[friend.friendId] = friend;
    await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: optimistic,
      friend: friend,
      incrementUnread: false,
      restoreHidden: true,
    );
    await _reloadLocal();
    await _continueVoiceSend(optimistic, friend, fileName: request.fileName);
    return temporaryId;
  }

  Future<void> _continueVoiceSend(
    FriendMessage message,
    FriendshipSummary friend, {
    String? fileName,
  }) async {
    final tempMessageId = message.tempMessageId!;
    if (_voiceTransferInProgress) {
      await _localStore.markMessageFailed(ownerUserId, tempMessageId);
      _errorMessage = '已有语音正在发送，请稍后重试';
      await _reloadLocal();
      return;
    }
    _voiceTransferInProgress = true;
    _activeMediaTransferIds.add(tempMessageId);
    var voice = FriendVoiceContent.parse(message.content);
    try {
      if (voice == null || !voice.canPlay || voice.duration < 1) {
        throw StateError('语音消息内容无效');
      }

      if (!_isServerMediaUrl(voice.url)) {
        final localFile = resolveLocalFile(message.localFilePath ?? voice.url);
        if (localFile == null || !await localFile.exists()) {
          await _localStore.updateMediaMessage(
            ownerUserId: ownerUserId,
            tempMessageId: tempMessageId,
            localFileExists: false,
          );
          throw StateError('语音文件不存在，请重新录制');
        }
        final uploader = _mediaUploader;
        if (uploader == null) throw StateError('语音上传服务尚未配置');

        await _localStore.updateMediaMessage(
          ownerUserId: ownerUserId,
          tempMessageId: tempMessageId,
          mediaStage: MediaTransferStage.uploading,
        );
        await _reloadLocal();

        final upload = await uploader.uploadVoice(
          filePath: localFile.path,
          fileName: fileName ?? _fallbackVoiceFileName(localFile.path),
          mimeType: friendVoiceMimeType,
        );
        voice = FriendVoiceContent(url: upload.url, duration: voice.duration);
        final remoteContent = voice.toMessageContent();
        await _localStore.updateMediaMessage(
          ownerUserId: ownerUserId,
          tempMessageId: tempMessageId,
          content: remoteContent,
          mediaStage: MediaTransferStage.readyToSend,
        );
        message = message.copyWith(
          content: remoteContent,
          mediaStage: MediaTransferStage.readyToSend,
        );
      }

      await _localStore.updateMediaMessage(
        ownerUserId: ownerUserId,
        tempMessageId: tempMessageId,
        sendStatus: MessageSendStatus.sending,
        mediaStage: MediaTransferStage.sending,
      );
      await _reloadLocal();
      await _sendPersistedMessage(
        message.copyWith(
          sendStatus: MessageSendStatus.sending,
          mediaStage: MediaTransferStage.sending,
        ),
        friend,
      );
    } on Object catch (error) {
      await _localStore.markMessageFailed(ownerUserId, tempMessageId);
      _errorMessage = _readableError(error, '语音发送失败，点击可重试');
      await _reloadLocal();
    } finally {
      _voiceTransferInProgress = false;
      _activeMediaTransferIds.remove(tempMessageId);
    }
  }

  Future<void> _continueMediaSend(
    FriendMessage message,
    FriendshipSummary friend,
  ) async {
    final tempMessageId = message.tempMessageId!;
    final mediaType = message.messageType == 'video'
        ? FriendMediaType.video
        : FriendMediaType.image;
    _activeMediaTransferIds.add(tempMessageId);
    var media = FriendMediaContent.parse(message.content, type: mediaType);
    try {
      if (media == null || !media.canDisplay) {
        throw StateError('媒体消息内容无效');
      }

      if (!_isServerMediaUrl(media.url)) {
        final localFile = resolveLocalFile(message.localFilePath ?? media.url);
        if (localFile == null || !await localFile.exists()) {
          await _localStore.updateMediaMessage(
            ownerUserId: ownerUserId,
            tempMessageId: tempMessageId,
            localFileExists: false,
          );
          throw StateError('文件已失效，请重新选择');
        }
        final uploader = _mediaUploader;
        if (uploader == null) throw StateError('媒体上传服务尚未配置');

        await _localStore.updateMediaMessage(
          ownerUserId: ownerUserId,
          tempMessageId: tempMessageId,
          mediaStage: MediaTransferStage.uploading,
        );
        await _reloadLocal();

        final uploadMimeType = _mediaUploadMimeType(mediaType, media.mimeType);
        final upload = mediaType == FriendMediaType.video
            ? await uploader.uploadVideo(
                filePath: localFile.path,
                fileName: media.fileName ?? _fallbackFileName(mediaType),
                mimeType: uploadMimeType,
                thumbnailPath: resolveLocalFile(
                  message.localThumbnailPath,
                )?.path,
              )
            : await uploader.uploadImage(
                filePath: localFile.path,
                fileName: media.fileName ?? _fallbackFileName(mediaType),
                mimeType: uploadMimeType,
              );
        media = FriendMediaContent(
          url: upload.url,
          thumbnail: upload.thumbnail,
          width: upload.width ?? media.width,
          height: upload.height ?? media.height,
          duration: media.duration,
          size: upload.size ?? media.size,
          fileName: upload.originalName ?? media.fileName,
          mimeType: media.mimeType,
        );
        final remoteContent = media.toMessageContent();
        await _localStore.updateMediaMessage(
          ownerUserId: ownerUserId,
          tempMessageId: tempMessageId,
          content: remoteContent,
          mediaStage: MediaTransferStage.readyToSend,
        );
        message = message.copyWith(
          content: remoteContent,
          mediaStage: MediaTransferStage.readyToSend,
        );
      }

      await _localStore.updateMediaMessage(
        ownerUserId: ownerUserId,
        tempMessageId: tempMessageId,
        sendStatus: MessageSendStatus.sending,
        mediaStage: MediaTransferStage.sending,
      );
      await _reloadLocal();
      await _sendPersistedMessage(
        message.copyWith(
          sendStatus: MessageSendStatus.sending,
          mediaStage: MediaTransferStage.sending,
        ),
        friend,
      );
    } on Object catch (error) {
      await _localStore.markMessageFailed(ownerUserId, tempMessageId);
      _errorMessage = _readableError(error, '媒体发送失败，点击可重试');
      await _reloadLocal();
    } finally {
      _activeMediaTransferIds.remove(tempMessageId);
    }
  }

  Future<void> _sendPersistedMessage(
    FriendMessage message,
    FriendshipSummary friend,
  ) async {
    final tempMessageId = message.tempMessageId!;
    try {
      final ack = message.messageType == 'text'
          ? await _socket.sendTextMessage(
              receiverId: friend.friendId,
              content: message.content,
              tempMessageId: tempMessageId,
            )
          : await _socket.sendMessage(
              receiverId: friend.friendId,
              messageType: message.messageType,
              content: message.content,
              tempMessageId: tempMessageId,
            );
      if (!ack.success || ack.messageId == null) {
        throw StateError(ack.errorMessage ?? '消息发送失败');
      }
      await _localStore.acknowledgeMessage(
        ownerUserId: ownerUserId,
        tempMessageId: tempMessageId,
        messageId: ack.messageId!,
        serverMessage: ack.message,
      );
    } on Object catch (error) {
      await _localStore.markMessageFailed(ownerUserId, tempMessageId);
      _errorMessage = _readableError(error, '消息发送失败，点击可重试');
    }
    await _reloadLocal();
  }

  Future<void> _syncFriendsAndRecentHistory() async {
    final friends = <FriendshipSummary>[];
    var pageNumber = 1;
    while (true) {
      final page = await _repository.loadFriends(
        page: pageNumber,
        pageSize: historyPageSize,
      );
      friends.addAll(page.items);
      if (!page.hasMore) break;
      pageNumber += 1;
    }

    final recentFriends = friends
        .where((friend) => friend.lastChatAt != null)
        .toList(growable: false);
    for (final friend in friends) {
      _friendsById[friend.friendId] = friend;
    }
    for (final friend in recentFriends) {
      await _localStore.upsertConversationFromFriend(
        ownerUserId: ownerUserId,
        friend: friend,
      );
    }

    Object? firstHistoryError;
    for (
      var index = 0;
      index < recentFriends.length;
      index += maxHistoryConcurrency
    ) {
      final end = (index + maxHistoryConcurrency).clamp(
        0,
        recentFriends.length,
      );
      final batch = recentFriends.sublist(index, end);
      await Future.wait<void>(
        batch.map((friend) async {
          try {
            final history = await _repository.loadMessageHistory(
              friendId: friend.friendId,
              page: 1,
              pageSize: historyPageSize,
            );
            await _localStore.persistMessages(
              ownerUserId: ownerUserId,
              messages: history.items,
              friend: friend,
              countIncomingUnread: true,
              restoreHidden: false,
            );
          } on Object catch (error) {
            firstHistoryError ??= error;
          }
        }),
      );
    }

    await _reloadLocal();
    await _refreshLocalUnreadCount();
    if (firstHistoryError != null) {
      _errorMessage = _readableError(firstHistoryError!, '部分会话同步失败，可下拉重试');
    }
  }

  void _listenToSocket() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _socket.messages.listen((message) {
        unawaited(_handleIncomingMessage(message));
      }),
      _socket.acknowledgements.listen((ack) {
        unawaited(_handleAcknowledgement(ack));
      }),
      _socket.readReceipts.listen((receipt) {
        unawaited(_handleReadReceipt(receipt));
      }),
      _socket.friendshipDeleted.listen((event) {
        unawaited(_handleFriendshipDeleted(event));
      }),
      _socket.sessionRevoked.listen((_) {
        unawaited(_handleSessionRevoked());
      }),
      _socket.connectionChanges.listen((connected) {
        if (!connected) {
          _safeNotify();
          return;
        }
        if (_hasConnectedOnce) {
          unawaited(_recoverAfterReconnect());
        }
        _hasConnectedOnce = true;
        _safeNotify();
      }),
      _socket.errors.listen((error) {
        _errorMessage = _readableError(error, '消息连接异常');
        _safeNotify();
      }),
    ]);
  }

  Future<void> _handleIncomingMessage(FriendMessage message) async {
    if (_closed) return;
    final friendId = message.senderId == ownerUserId
        ? message.receiverId
        : message.senderId;
    final friend =
        _friendsById[friendId] ??
        FriendshipSummary(
          friendId: friendId,
          friendName: '用户$friendId',
          serverConversationId: message.conversationId,
          lastChatAt: message.createdAt,
        );
    final isActive = _activeConversationId == message.conversationId;
    final persisted = await _localStore.persistMessage(
      ownerUserId: ownerUserId,
      message: message,
      friend: friend,
      incrementUnread: message.isIncomingFor(ownerUserId) && !isActive,
      restoreHidden: true,
    );

    if (isActive && message.isIncomingFor(ownerUserId)) {
      await _markConversationRead(message.conversationId);
    } else {
      _totalUnreadCount = persisted.totalUnreadCount;
      await _reloadLocal();
    }

    if (message.deliveryMode == 'offline' && message.messageId != null) {
      try {
        await _socket.acknowledgeOfflineMessages([message.messageId!]);
      } on Object catch (error) {
        _errorMessage = _readableError(error, '离线消息确认失败，将在重连后重试');
        _safeNotify();
      }
    }
    if (!_closed &&
        persisted.inserted &&
        message.isIncomingFor(ownerUserId) &&
        !isActive) {
      _incomingMessageEvents.add(
        InAppMessageEvent(
          eventKey: 'friend:${message.localKey}',
          channel: InAppMessageChannel.friend,
          conversationId: message.conversationId,
          senderId: friendId,
          title: friend.displayName,
          preview: inAppMessagePreview(
            messageType: message.messageType,
            content: message.content,
          ),
          avatarUrl: friend.friendAvatar,
          createdAt: message.createdAt,
          isOffline: message.deliveryMode == 'offline',
        ),
      );
    }
  }

  Future<void> _handleAcknowledgement(FriendMessageAck ack) async {
    if (!ack.success || ack.messageId == null) {
      await _localStore.markMessageFailed(ownerUserId, ack.tempMessageId);
    } else {
      await _localStore.acknowledgeMessage(
        ownerUserId: ownerUserId,
        tempMessageId: ack.tempMessageId,
        messageId: ack.messageId!,
        serverMessage: ack.message,
      );
    }
    await _reloadLocal();
  }

  Future<void> _handleReadReceipt(FriendReadReceipt receipt) async {
    await _localStore.applyReadReceipt(ownerUserId, receipt.messageId);
    _safeNotify();
  }

  Future<void> _handleFriendshipDeleted(FriendshipDeletedEvent event) async {
    await removeFriend(event.friendId);
  }

  Future<void> _handleSessionRevoked() async {
    await stop(clearLocalData: true);
    await _onSessionRevoked();
  }

  Future<void> _recoverAfterReconnect() async {
    if (!_started || _closed) return;
    try {
      await _socket.fetchOfflineMessages();
      await _syncPendingReads();
      await _refreshServerUnreadCount();
      await _reloadLocal();
    } on Object catch (error) {
      _errorMessage = _readableError(error, '重连后的消息同步失败');
      _safeNotify();
    }
  }

  Future<void> _markConversationRead(String conversationId) async {
    await _localStore.markConversationRead(
      ownerUserId: ownerUserId,
      conversationId: conversationId,
    );
    await _refreshLocalUnreadCount();
    await _reloadLocal();
    await _syncPendingReads(conversationId: conversationId);
  }

  Future<void> _syncPendingReads({String? conversationId}) async {
    final messages = await _localStore.getPendingReadMessages(ownerUserId);
    for (final message in messages) {
      if (conversationId != null && message.conversationId != conversationId) {
        continue;
      }
      final messageId = message.messageId;
      if (messageId == null) continue;
      var synchronized = false;
      if (_socket.isConnected) {
        try {
          await _socket.markMessageRead(
            messageId: messageId,
            conversationId: message.conversationId,
          );
          synchronized = true;
        } on Object {
          // REST 是已读上报的备用通道。
        }
      }
      if (!synchronized) {
        try {
          await _repository.markMessageRead(
            messageId: messageId,
            conversationId: message.conversationId,
          );
          synchronized = true;
        } on Object {
          // 保留 read_synced=false，重连后再次补发。
        }
      }
      if (synchronized) {
        await _localStore.markReadSynced(ownerUserId, messageId);
      }
    }
  }

  Future<void> _refreshServerUnreadCount() async {
    _totalUnreadCount = await _repository.loadUnreadCount();
    _safeNotify();
  }

  Future<void> _refreshLocalUnreadCount() async {
    _totalUnreadCount = await _localStore.getTotalUnreadCount(ownerUserId);
    _safeNotify();
  }

  Future<void> _reloadLocal() async {
    _conversations = await _localStore.getConversations(
      ownerUserId,
      search: _search,
    );
    for (final conversation in _conversations) {
      _friendsById.putIfAbsent(
        conversation.friendId,
        () => friendForConversation(conversation),
      );
    }
    _safeNotify();
  }

  String _nextTempMessageId() {
    _temporarySequence += 1;
    return 'flutter_${ownerUserId}_${DateTime.now().microsecondsSinceEpoch}_$_temporarySequence';
  }

  Future<void> stop({bool clearLocalData = false}) async {
    if (!_started && !clearLocalData) return;
    _started = false;
    _hasConnectedOnce = false;
    _activeConversationId = null;
    final subscriptions = List<StreamSubscription<Object?>>.from(
      _subscriptions,
    );
    _subscriptions.clear();
    await Future.wait<void>(subscriptions.map((item) => item.cancel()));
    await _socket.stop();
    if (clearLocalData) {
      await _localStore.clearOwnerData(ownerUserId);
      _conversations = const [];
      _friendsById.clear();
      _totalUnreadCount = 0;
    }
    _safeNotify();
  }

  Future<void> close({bool clearLocalData = false}) {
    return _closeOperation ??= _close(clearLocalData: clearLocalData);
  }

  Future<void> _close({required bool clearLocalData}) async {
    await stop(clearLocalData: clearLocalData);
    await _socket.dispose();
    _closed = true;
    await _incomingMessageEvents.close();
  }

  @override
  void dispose() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    unawaited(close());
    super.dispose();
  }

  void _safeNotify() {
    if (!_closed && !_notifierDisposed) notifyListeners();
  }
}

String? _normalizeCurrentUserAvatar(String? avatarUrl) {
  final value = avatarUrl?.trim() ?? '';
  return value.isEmpty ? null : value;
}

bool _isServerMediaUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty || value.startsWith('data:') || isLocalMediaPath(value)) {
    return false;
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return false;
  return !uri.hasScheme || uri.scheme == 'http' || uri.scheme == 'https';
}

String _fallbackFileName(FriendMediaType type) {
  final extension = type == FriendMediaType.video ? 'mp4' : 'jpg';
  return 'friend_media_${DateTime.now().millisecondsSinceEpoch}.$extension';
}

String _mediaUploadMimeType(FriendMediaType type, String? rawMimeType) {
  final mimeType = rawMimeType?.trim() ?? '';
  if (mimeType.isNotEmpty) return mimeType;
  return type == FriendMediaType.video ? 'video/mp4' : 'image/jpeg';
}

String _fallbackVoiceFileName(String filePath) {
  final uri = Uri.tryParse(filePath);
  final segments = uri?.pathSegments ?? const <String>[];
  final rawName = segments.isEmpty ? '' : segments.last.trim();
  if (rawName.toLowerCase().endsWith('.m4a')) return rawName;
  return 'friend_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

String _readableError(Object error, String fallback) {
  final value = error.toString().trim();
  if (value.isEmpty || value == 'Exception') return fallback;
  return value
      .replaceFirst('Exception: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('ApiException: ', '');
}
