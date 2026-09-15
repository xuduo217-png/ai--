import 'dart:async';

import 'data/friend_relations_repository.dart';
import 'data/friends_socket_client.dart';
import 'presentation/friend_requests_controller.dart';
import 'presentation/friend_chat_blocks_controller.dart';
import 'presentation/friend_chat_controller.dart';
import 'presentation/friend_search_controller.dart';
import 'presentation/friends_directory_controller.dart';
import 'presentation/friends_messaging_controller.dart';
import 'domain/friend_messaging_models.dart';

class FriendsFeatureSession {
  FriendsFeatureSession({
    required this.ownerUserId,
    required this.messagingController,
    required this.directoryController,
    required this.socket,
    required this.repository,
  });

  final int ownerUserId;
  final FriendsMessagingController messagingController;
  final FriendsDirectoryController directoryController;
  final FriendsSocketClient socket;
  final FriendRelationsRepositoryGateway repository;

  bool _started = false;
  Future<void> _lifecycleOperation = Future<void>.value();
  Future<void>? _closeOperation;

  bool get hasActiveMediaTransfer => messagingController.hasActiveMediaTransfer;

  Future<void> start() => _enqueue(_start);

  Future<void> _start() async {
    if (_started || _closeOperation != null) return;
    _started = true;
    await Future.wait<void>([
      directoryController.start(),
      messagingController.start(),
    ]);
  }

  Future<void> resume() => _enqueue(_resume);

  Future<void> _resume() async {
    if (_closeOperation != null) return;
    if (!_started) {
      await _start();
      return;
    }
    await Future.wait<void>([
      messagingController.resume(),
      directoryController.resume(),
    ]);
  }

  Future<void> pause() => stop();

  void updateCurrentUserAvatar(String? avatarUrl) {
    messagingController.updateCurrentUserAvatar(avatarUrl);
  }

  Future<void> stop({bool clearLocalData = false}) =>
      _enqueue(() => _stop(clearLocalData: clearLocalData));

  Future<void> _stop({required bool clearLocalData}) async {
    _started = false;
    await directoryController.stop();
    await messagingController.stop(clearLocalData: clearLocalData);
  }

  Future<void> close({bool clearLocalData = false}) {
    return _closeOperation ??= _enqueue(
      () => _close(clearLocalData: clearLocalData),
    );
  }

  Future<void> _close({required bool clearLocalData}) async {
    await directoryController.stop();
    directoryController.dispose();
    await messagingController.close(clearLocalData: clearLocalData);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _lifecycleOperation.then(
      (_) => action(),
      onError: (_) => action(),
    );
    _lifecycleOperation = next;
    return next;
  }

  FriendRequestsController createFriendRequestsController() {
    return FriendRequestsController(
      repository: repository,
      socket: socket,
      onRequestResolved: directoryController.refreshAfterRequestChanged,
    );
  }

  FriendSearchController createFriendSearchController() {
    return FriendSearchController(
      ownerUserId: ownerUserId,
      repository: repository,
    );
  }

  FriendChatController createFriendChatController(FriendshipSummary friend) {
    return FriendChatController(
      messagingController: messagingController,
      friend: friend,
      relationsRepository: repository,
      directoryController: directoryController,
    );
  }

  FriendChatBlocksController createFriendChatBlocksController() {
    return FriendChatBlocksController(repository: repository);
  }
}
