import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/friend_relations_repository.dart';
import '../data/friends_socket_client.dart';
import '../domain/friend_relation_models.dart';

class FriendRequestsController extends ChangeNotifier {
  FriendRequestsController({
    required FriendRelationsRepositoryGateway repository,
    required FriendRelationsSocketGateway socket,
    required Future<void> Function({required bool accepted}) onRequestResolved,
  }) : _repository = repository,
       _socket = socket,
       _onRequestResolved = onRequestResolved;

  static const pageSize = 20;

  final FriendRelationsRepositoryGateway _repository;
  final FriendRelationsSocketGateway _socket;
  final Future<void> Function({required bool accepted}) _onRequestResolved;
  final Set<int> _processingIds = {};

  StreamSubscription<FriendRequest>? _newRequestSubscription;
  List<FriendRequest> _requests = const [];
  String? _errorMessage;
  String? _notice;
  int _nextPage = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _started = false;
  bool _disposed = false;

  List<FriendRequest> get requests =>
      List<FriendRequest>.unmodifiable(_requests);
  String? get errorMessage => _errorMessage;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  bool isProcessing(int requestId) => _processingIds.contains(requestId);

  String? takeNotice() {
    final value = _notice;
    _notice = null;
    return value;
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _newRequestSubscription = _socket.newFriendRequests.listen((_) {
      unawaited(refresh());
    });
    await _loadFirstPage(isRefresh: false);
  }

  Future<void> refresh() => _loadFirstPage(isRefresh: true);

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _loading || _disposed) return;
    _loadingMore = true;
    _safeNotify();
    try {
      final page = await _repository.loadFriendRequests(
        status: FriendRequestStatus.pending,
        page: _nextPage,
        pageSize: pageSize,
      );
      final byId = {for (final request in _requests) request.id: request};
      for (final request in page.items) {
        byId[request.id] = request;
      }
      _requests = byId.values.toList(growable: false)..sort(_newestFirst);
      _nextPage = page.page + 1;
      _hasMore = page.hasMore;
      _errorMessage = null;
    } on Object catch (error) {
      _errorMessage = _readableError(error, '更多申请加载失败');
    } finally {
      _loadingMore = false;
      _safeNotify();
    }
  }

  Future<bool> accept(FriendRequest request) async {
    if (_processingIds.contains(request.id)) return false;
    _processingIds.add(request.id);
    _safeNotify();
    try {
      await _repository.acceptFriendRequest(requestId: request.id);
      _requests = _requests
          .where((item) => item.id != request.id)
          .toList(growable: false);
      _notice = '已接受 ${request.requesterName} 的好友申请';
      await _onRequestResolved(accepted: true);
      return true;
    } on Object catch (error) {
      _notice = _readableError(error, '接受好友申请失败');
      return false;
    } finally {
      _processingIds.remove(request.id);
      _safeNotify();
    }
  }

  Future<bool> reject(FriendRequest request) async {
    if (_processingIds.contains(request.id)) return false;
    _processingIds.add(request.id);
    _safeNotify();
    try {
      await _repository.rejectFriendRequest(requestId: request.id);
      _requests = _requests
          .where((item) => item.id != request.id)
          .toList(growable: false);
      _notice = '已拒绝好友申请';
      await _onRequestResolved(accepted: false);
      return true;
    } on Object catch (error) {
      _notice = _readableError(error, '拒绝好友申请失败');
      return false;
    } finally {
      _processingIds.remove(request.id);
      _safeNotify();
    }
  }

  Future<void> _loadFirstPage({required bool isRefresh}) async {
    if (_disposed || _refreshing) return;
    _refreshing = isRefresh;
    if (!isRefresh && _requests.isEmpty) _loading = true;
    _errorMessage = null;
    _safeNotify();
    try {
      final page = await _repository.loadFriendRequests(
        status: FriendRequestStatus.pending,
        page: 1,
        pageSize: pageSize,
      );
      final byId = <int, FriendRequest>{};
      for (final request in page.items) {
        byId[request.id] = request;
      }
      _requests = byId.values.toList(growable: false)..sort(_newestFirst);
      _nextPage = 2;
      _hasMore = page.hasMore;
    } on Object catch (error) {
      _errorMessage = _readableError(error, '好友申请加载失败，请重试');
    } finally {
      _loading = false;
      _refreshing = false;
      _safeNotify();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_newRequestSubscription?.cancel());
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}

int _newestFirst(FriendRequest first, FriendRequest second) =>
    second.createdAt.compareTo(first.createdAt);

String _readableError(Object error, String fallback) {
  final text = error.toString().trim();
  if (text.isEmpty) return fallback;
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Bad state: ', '');
}
