import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/friend_messaging_models.dart';
import '../domain/friend_media_content.dart';
import '../domain/friend_relation_models.dart';
import '../data/friend_relations_repository.dart';
import 'friend_voice_controller.dart';
import 'friend_voice_gateways.dart';
import 'friend_media_controller.dart';
import 'friends_messaging_controller.dart';
import 'friends_directory_controller.dart';

class FriendChatController extends ChangeNotifier {
  FriendChatController({
    required FriendsMessagingController messagingController,
    required FriendshipSummary friend,
    FriendRelationsRepositoryGateway? relationsRepository,
    FriendsDirectoryController? directoryController,
    FriendMediaController? mediaController,
    FriendVoiceController? voiceController,
  }) : _messagingController = messagingController,
       _friend = friend,
       _relationsRepository = relationsRepository,
       _directoryController = directoryController,
       _relationshipLoading = relationsRepository != null,
       _mediaController = mediaController ?? FriendMediaController(),
       _voiceController =
           voiceController ??
           FriendVoiceController(
             onSend: (request) =>
                 messagingController.sendVoice(friend, request),
           ) {
    _messagingController.addListener(_handleMessagingChanged);
    _directoryController?.addListener(_handleDirectoryChanged);
  }

  final FriendsMessagingController _messagingController;
  final FriendMediaController _mediaController;
  final FriendVoiceController _voiceController;
  final FriendRelationsRepositoryGateway? _relationsRepository;
  final FriendsDirectoryController? _directoryController;
  FriendshipSummary _friend;

  List<FriendMessage> _messages = const [];
  String? _notice;
  int _visibleLimit = FriendsMessagingController.historyPageSize;
  int _nextRemotePage = 2;
  bool _remoteHasMore = true;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _initialized = false;
  bool _routeVisible = true;
  bool _disposed = false;
  bool _relationshipLoading;
  bool _operationInProgress = false;
  FriendRelationshipSummary? _relationship;

  List<FriendMessage> get messages =>
      List<FriendMessage>.unmodifiable(_messages);
  String get conversationId =>
      friend.conversationIdFor(_messagingController.ownerUserId);
  int get currentUserId => _messagingController.ownerUserId;
  String? get currentUserAvatar => _messagingController.currentUserAvatar;
  bool get loading => _loading;
  bool get loadingOlder => _loadingOlder;
  bool get hasMore => _remoteHasMore || _messages.length >= _visibleLimit;
  FriendVoiceController get voiceController => _voiceController;
  FriendshipSummary get friend => _friend;
  bool get supportsRelationshipActions => _relationsRepository != null;
  bool get relationshipReady =>
      _relationsRepository == null || _relationship != null;
  bool get relationshipLoading => _relationshipLoading;
  bool get operationInProgress => _operationInProgress;
  bool get isFriend => _relationship?.isFriend ?? true;
  bool get blockedByMe => _relationship?.blockedByMe ?? false;
  bool get canSendMessage {
    if (_relationsRepository != null && _relationship == null) return false;
    return _relationship?.canSendMessage ?? true;
  }

  String get unavailableMessage {
    if (_relationshipLoading) return '正在确认好友关系';
    if (blockedByMe) return '已拉黑对方，无法发送消息';
    if (!isFriend) return '你们已不是好友，无法发送消息';
    return '当前无法发送消息';
  }

  String? takeNotice() {
    final value = _notice;
    _notice = null;
    return value;
  }

  String? takeVoiceNotice() => _voiceController.takeNotice();

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    if (_relationsRepository != null) {
      unawaited(refreshRelationship());
    }
    try {
      if (_routeVisible) {
        await _messagingController.setActiveConversation(friend);
      }
      await _reloadMessages();
      _loading = false;
      _safeNotify();

      final page = await _messagingController.syncConversation(friend, page: 1);
      _remoteHasMore = page.hasMore;
      _nextRemotePage = 2;
      await _reloadMessages();
    } on Object catch (error) {
      _notice = _messageFromError(error, '消息同步失败');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> loadOlder() async {
    if (_loadingOlder || !hasMore || _disposed) return;
    _loadingOlder = true;
    _safeNotify();
    try {
      if (_remoteHasMore) {
        final page = await _messagingController.syncConversation(
          friend,
          page: _nextRemotePage,
        );
        _remoteHasMore = page.hasMore;
        _nextRemotePage += 1;
      }
      _visibleLimit += FriendsMessagingController.historyPageSize;
      await _reloadMessages();
      final total = await _messagingController.messageCount(conversationId);
      if (_messages.length >= total && !_remoteHasMore) {
        _remoteHasMore = false;
      }
    } on Object catch (error) {
      _notice = _messageFromError(error, '更早消息加载失败');
    } finally {
      _loadingOlder = false;
      _safeNotify();
    }
  }

  Future<void> sendText(String text) async {
    if (!_ensureCanSend()) return;
    try {
      await _messagingController.sendText(friend, text);
      _captureMessagingNotice();
    } on Object catch (error) {
      _notice = _messageFromError(error, '消息发送失败');
      _safeNotify();
    }
  }

  Future<List<FriendMediaSendRequest>> pickMedia({
    BuildContext? context,
  }) async {
    if (!_ensureCanSend()) return const [];
    try {
      return await _mediaController.pickMedia(context: context);
    } on Object catch (error) {
      _notice = _messageFromError(error, '无法选择图片或视频');
      _safeNotify();
      return const [];
    }
  }

  Future<FriendMediaSendRequest?> pickImage(
    ImageSource source, {
    BuildContext? context,
  }) async {
    if (!_ensureCanSend()) return null;
    try {
      return await _mediaController.pickImage(source, context: context);
    } on Object catch (error) {
      _notice = _messageFromError(error, '无法访问系统相册或相机');
      _safeNotify();
      return null;
    }
  }

  Future<FriendMediaSendRequest?> captureMedia({BuildContext? context}) async {
    if (!_ensureCanSend()) return null;
    try {
      return await _mediaController.captureMedia(context: context);
    } on Object catch (error) {
      _notice = _messageFromError(error, '无法访问系统相机');
      _safeNotify();
      return null;
    }
  }

  @Deprecated(
    'Use captureMedia because the camera can return photos or videos.',
  )
  Future<FriendMediaSendRequest?> takePhoto({BuildContext? context}) {
    return captureMedia(context: context);
  }

  Future<FriendMediaSendRequest?> pickVideo({BuildContext? context}) async {
    if (!_ensureCanSend()) return null;
    try {
      return await _mediaController.pickVideo(context: context);
    } on Object catch (error) {
      _notice = _messageFromError(error, '无法选择视频');
      _safeNotify();
      return null;
    }
  }

  Future<void> sendMedia(FriendMediaSendRequest draft) async {
    if (!_ensureCanSend()) return;
    try {
      await _messagingController.sendMedia(friend, draft);
      _captureMessagingNotice();
    } on Object catch (error) {
      _notice = _messageFromError(error, '媒体发送失败');
      _safeNotify();
    }
  }

  Future<void> retry(FriendMessage message) async {
    if (!_ensureCanSend()) return;
    try {
      await _messagingController.retryMessage(friend, message);
      _captureMessagingNotice();
    } on Object catch (error) {
      _notice = _messageFromError(error, '消息重试失败');
      _safeNotify();
    }
  }

  bool canRevoke(FriendMessage message) =>
      _messagingController.canRevokeMessage(message);

  Future<bool> revoke(FriendMessage message) async {
    try {
      await _voiceController.stopAll();
      await _messagingController.revokeMessage(friend, message);
      _notice = '消息已撤回';
      await _reloadMessages();
      return true;
    } on Object catch (error) {
      _notice = _messageFromError(error, '消息撤回失败');
      _safeNotify();
      return false;
    }
  }

  Future<FriendVoiceStartOutcome> beginVoiceRecording() {
    if (!_ensureCanSend()) {
      return Future<FriendVoiceStartOutcome>.value(
        FriendVoiceStartOutcome.ignored,
      );
    }
    return _voiceController.beginHold();
  }

  Future<FriendMicrophonePermissionStatus> requestVoicePermission() {
    return _voiceController.requestPermission();
  }

  Future<bool> openVoiceSettings() => _voiceController.openSettings();

  Future<void> finishVoiceRecording() async {
    if (!_ensureCanSend()) {
      await _voiceController.cancelHold();
      return;
    }
    await _voiceController.finishHold();
  }

  Future<void> cancelVoiceRecording() => _voiceController.cancelHold();

  Future<void> toggleVoicePlayback(FriendMessage message) {
    return _voiceController.togglePlayback(
      message,
      isMine: message.senderId == currentUserId,
    );
  }

  Future<void> stopVoiceActivity() => _voiceController.stopAll();

  void setRouteVisible(bool visible) {
    if (_routeVisible == visible || _disposed) return;
    _routeVisible = visible;
    if (!_initialized) return;
    if (visible) {
      unawaited(_messagingController.setActiveConversation(friend));
      if (_relationsRepository != null) unawaited(refreshRelationship());
    } else {
      _messagingController.clearActiveConversation(conversationId);
    }
  }

  Future<void> refreshRelationship({bool showError = true}) async {
    final repository = _relationsRepository;
    if (repository == null || _disposed) return;
    _relationshipLoading = true;
    _safeNotify();
    try {
      _relationship = await repository.loadRelationshipSummary(
        targetUserId: friend.friendId,
      );
    } on Object catch (error) {
      if (showError) {
        _notice = _messageFromError(error, '好友关系状态加载失败');
      }
    } finally {
      _relationshipLoading = false;
      _safeNotify();
    }
  }

  Future<bool> updateRemark(String rawRemark) async {
    final repository = _relationsRepository;
    if (repository == null || _operationInProgress || !isFriend) return false;
    final remark = rawRemark.trim();
    if (remark.isEmpty) {
      _notice = '备注名不能为空';
      _safeNotify();
      return false;
    }
    if (remark.length > 100) {
      _notice = '备注名最多 100 字';
      _safeNotify();
      return false;
    }
    return _runOperation(() async {
      final directory = _directoryController;
      if (directory != null) {
        await directory.updateRemark(friend, remark);
        _friend =
            directory.friendById(friend.friendId) ??
            friend.copyWith(remark: remark);
      } else {
        await repository.updateFriendRemark(
          friendId: friend.friendId,
          remark: remark,
        );
        _friend = friend.copyWith(remark: remark);
      }
      await _messagingController.updateFriendSummary(friend);
    }, fallback: '备注修改失败');
  }

  Future<bool> deleteFriend() async {
    final repository = _relationsRepository;
    if (repository == null || _operationInProgress || !isFriend) return false;
    return _runOperation(() async {
      final friendId = friend.friendId;
      final directory = _directoryController;
      if (directory != null) {
        await directory.deleteFriend(friend);
      } else {
        await repository.deleteFriend(friendId: friendId);
      }
      await _messagingController.removeFriend(friendId);
      _relationship =
          (_relationship ??
                  const FriendRelationshipSummary(
                    isFriend: false,
                    outgoingPending: false,
                    incomingPending: false,
                  ))
              .copyWith(isFriend: false, canSendMessage: false);
    }, fallback: '删除好友失败');
  }

  Future<bool> blockFriendChat() async {
    final repository = _relationsRepository;
    if (repository == null || _operationInProgress || !isFriend) return false;
    return _runOperation(() async {
      await _voiceController.stopAll();
      await repository.blockFriendChat(blockedUserId: friend.friendId);
      _relationship =
          (_relationship ??
                  const FriendRelationshipSummary(
                    isFriend: true,
                    outgoingPending: false,
                    incomingPending: false,
                  ))
              .copyWith(blockedByMe: true, canSendMessage: false);
      _safeNotify();
      await refreshRelationship(showError: false);
    }, fallback: '拉黑失败');
  }

  Future<bool> unblockFriendChat() async {
    final repository = _relationsRepository;
    if (repository == null || _operationInProgress || !blockedByMe) {
      return false;
    }
    return _runOperation(() async {
      await repository.unblockFriendChat(blockedUserId: friend.friendId);
      _relationship =
          (_relationship ??
                  const FriendRelationshipSummary(
                    isFriend: false,
                    outgoingPending: false,
                    incomingPending: false,
                  ))
              .copyWith(blockedByMe: false, canSendMessage: false);
      _safeNotify();
      await refreshRelationship(showError: false);
    }, fallback: '解除拉黑失败');
  }

  void _handleMessagingChanged() {
    _safeNotify();
    if (!_initialized) return;
    unawaited(_reloadMessages());
  }

  void _handleDirectoryChanged() {
    final directory = _directoryController;
    if (directory == null || _disposed) return;
    final updated = directory.friendById(friend.friendId);
    if (updated != null) {
      _friend = updated;
    } else if (!directory.loading && directory.errorMessage == null) {
      _relationship =
          (_relationship ??
                  const FriendRelationshipSummary(
                    isFriend: false,
                    outgoingPending: false,
                    incomingPending: false,
                  ))
              .copyWith(isFriend: false, canSendMessage: false);
    }
    _safeNotify();
  }

  bool _ensureCanSend() {
    if (canSendMessage) return true;
    _notice = unavailableMessage;
    _safeNotify();
    return false;
  }

  Future<bool> _runOperation(
    Future<void> Function() action, {
    required String fallback,
  }) async {
    _operationInProgress = true;
    _safeNotify();
    try {
      await action();
      return true;
    } on Object catch (error) {
      _notice = _messageFromError(error, fallback);
      return false;
    } finally {
      _operationInProgress = false;
      _safeNotify();
    }
  }

  void _captureMessagingNotice() {
    final error = _messagingController.errorMessage;
    if (error == null || error.trim().isEmpty) return;
    _notice = _messageFromError(error, '消息操作失败');
    _safeNotify();
  }

  Future<void> _reloadMessages() async {
    final messages = await _messagingController.loadMessages(
      conversationId,
      limit: _visibleLimit,
    );
    if (_disposed) return;
    _messages = messages;
    _safeNotify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _messagingController.removeListener(_handleMessagingChanged);
    _directoryController?.removeListener(_handleDirectoryChanged);
    _messagingController.clearActiveConversation(conversationId);
    _voiceController.dispose();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}

String _messageFromError(Object error, String fallback) {
  final value = error.toString().trim();
  if (value.isEmpty) return fallback;
  return value
      .replaceFirst('Exception: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Bad state: ', '');
}
