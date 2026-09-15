import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../friends/domain/friend_relation_models.dart';
import '../domain/nearby_models.dart';

typedef NearbyFriendRequestSender =
    Future<SendFriendRequestResult> Function({
      required int receiverId,
      required String message,
    });

enum NearbyViewState {
  loading,
  ready,
  permissionRequired,
  permissionDeniedForever,
  locationServiceDisabled,
  error,
}

class NearbyController extends ChangeNotifier {
  NearbyController({
    required NearbyGateway gateway,
    required NearbyLocationGateway locationGateway,
    this.sendFriendRequest,
  }) : _gateway = gateway,
       _locationGateway = locationGateway;

  final NearbyGateway _gateway;
  final NearbyLocationGateway _locationGateway;
  final NearbyFriendRequestSender? sendFriendRequest;

  NearbyViewState viewState = NearbyViewState.loading;
  NearbyLocationPermissionStatus permission =
      NearbyLocationPermissionStatus.denied;
  NearbyDistanceRange selectedDistance = NearbyDistanceRange.fiveKilometers;
  NearbyCoordinate? currentLocation;
  List<NearbyUser> users = const [];
  bool discoveryEnabled = true;
  bool refreshing = false;
  bool loadingMore = false;
  bool locating = false;
  bool updatingDiscovery = false;
  String? errorMessage;

  int _currentPage = 0;
  int _totalPages = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _locationRequestInFlight = false;
  final Set<int> _pendingRequestUserIds = <int>{};
  final Set<int> _sendingRequestUserIds = <int>{};

  bool get hasMore => _currentPage < _totalPages;

  bool isFriendRequestPending(int userId) =>
      _pendingRequestUserIds.contains(userId);

  bool isSendingFriendRequest(int userId) =>
      _sendingRequestUserIds.contains(userId);

  Future<void> initialize() async {
    viewState = NearbyViewState.loading;
    errorMessage = null;
    _notify();
    try {
      final settings = await _gateway.loadNearbySettings();
      if (_disposed) return;
      discoveryEnabled = settings.discoveryEnabled;
      currentLocation = settings.currentLocation;
      await _resolveLocationAccess(loadWhenGranted: true);
    } on Object catch (error) {
      if (_disposed) return;
      _handleLocationFailure(error, '附近数据加载失败，请稍后重试');
    }
  }

  Future<void> requestLocationPermission() async {
    if (locating) return;
    locating = true;
    errorMessage = null;
    _notify();
    try {
      permission = await _locationGateway.checkPermission();
      if (_disposed) return;
      if (permission == NearbyLocationPermissionStatus.denied) {
        permission = await _locationGateway.requestPermission();
        if (_disposed) return;
      }
      if (permission == NearbyLocationPermissionStatus.deniedForever) {
        viewState = NearbyViewState.permissionDeniedForever;
        return;
      }
      if (permission != NearbyLocationPermissionStatus.granted) {
        viewState = NearbyViewState.permissionRequired;
        return;
      }
      await _locateAndLoad();
    } on Object catch (error) {
      _handleLocationFailure(error, '获取位置失败，请稍后重试');
    } finally {
      if (!_disposed) {
        locating = false;
        _notify();
      }
    }
  }

  Future<void> resumeAfterSettings() async {
    if (locating) return;
    locating = true;
    _notify();
    try {
      await _resolveLocationAccess(loadWhenGranted: true);
    } on Object catch (error) {
      _handleLocationFailure(error, '获取位置失败，请稍后重试');
    } finally {
      if (!_disposed) {
        locating = false;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    if (refreshing || currentLocation == null) return;
    refreshing = true;
    errorMessage = null;
    _notify();
    try {
      await _loadPage(1, replace: true);
    } on Object catch (error) {
      errorMessage = _readableError(error, '刷新失败，请稍后重试');
    } finally {
      if (!_disposed) {
        refreshing = false;
        _notify();
      }
    }
  }

  Future<void> refreshLocation() async {
    if (permission != NearbyLocationPermissionStatus.granted) {
      return requestLocationPermission();
    }
    if (locating) return;
    locating = true;
    errorMessage = null;
    _notify();
    try {
      await _locateAndLoad();
    } on Object catch (error) {
      _handleLocationFailure(error, '位置更新失败，请稍后重试', fatal: false);
    } finally {
      if (!_disposed) {
        locating = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || refreshing || !hasMore || currentLocation == null) {
      return;
    }
    loadingMore = true;
    _notify();
    try {
      await _loadPage(_currentPage + 1, replace: false);
    } on Object catch (error) {
      errorMessage = _readableError(error, '加载更多失败，请稍后重试');
    } finally {
      if (!_disposed) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> selectDistance(NearbyDistanceRange distance) async {
    if (distance == selectedDistance) return;
    selectedDistance = distance;
    users = const [];
    _currentPage = 0;
    _totalPages = 0;
    viewState = NearbyViewState.loading;
    errorMessage = null;
    _notify();
    try {
      await _loadPage(1, replace: true);
    } on Object catch (error) {
      _setError(_readableError(error, '附近数据加载失败，请稍后重试'));
    }
  }

  Future<bool?> toggleDiscovery(bool enabled) async {
    if (updatingDiscovery || enabled == discoveryEnabled) return null;
    updatingDiscovery = true;
    errorMessage = null;
    _notify();
    try {
      discoveryEnabled = await _gateway.updateNearbyDiscovery(enabled);
      if (!discoveryEnabled) {
        users = const [];
        _currentPage = 0;
        _totalPages = 0;
      } else if (currentLocation != null) {
        await _loadPage(1, replace: true);
      }
      return discoveryEnabled;
    } on Object catch (error) {
      errorMessage = _readableError(error, '发现设置更新失败，请稍后重试');
      return null;
    } finally {
      if (!_disposed) {
        updatingDiscovery = false;
        _notify();
      }
    }
  }

  Future<SendFriendRequestResult?> addFriend(NearbyUser user) async {
    final sender = sendFriendRequest;
    if (sender == null ||
        user.isFriend ||
        isFriendRequestPending(user.userId) ||
        isSendingFriendRequest(user.userId)) {
      return null;
    }
    _sendingRequestUserIds.add(user.userId);
    errorMessage = null;
    _notify();
    try {
      final result = await sender(
        receiverId: user.userId,
        message: '你好，我想和你交个朋友',
      );
      switch (result.status) {
        case SendFriendRequestStatus.sent:
        case SendFriendRequestStatus.outgoingPending:
          _pendingRequestUserIds.add(user.userId);
        case SendFriendRequestStatus.alreadyFriends:
          users = users
              .map(
                (item) => item.userId == user.userId
                    ? item.copyWith(isFriend: true)
                    : item,
              )
              .toList(growable: false);
        case SendFriendRequestStatus.incomingPending:
        case SendFriendRequestStatus.self:
          break;
      }
      return result;
    } on Object catch (error) {
      errorMessage = _readableError(error, '好友申请发送失败，请稍后重试');
      return null;
    } finally {
      if (!_disposed) {
        _sendingRequestUserIds.remove(user.userId);
        _notify();
      }
    }
  }

  Future<void> openAppSettings() => _locationGateway.openAppSettings();

  Future<void> openLocationSettings() =>
      _locationGateway.openLocationSettings();

  Future<void> _resolveLocationAccess({required bool loadWhenGranted}) async {
    permission = await _locationGateway.checkPermission();
    if (_disposed) return;
    viewState = switch (permission) {
      NearbyLocationPermissionStatus.granted => NearbyViewState.ready,
      NearbyLocationPermissionStatus.denied =>
        NearbyViewState.permissionRequired,
      NearbyLocationPermissionStatus.deniedForever =>
        NearbyViewState.permissionDeniedForever,
    };
    _notify();
    if (loadWhenGranted &&
        permission == NearbyLocationPermissionStatus.granted) {
      await _locateAndLoad();
    }
  }

  Future<void> _locateAndLoad() async {
    if (_disposed) return;
    final generation = ++_generation;
    _locationRequestInFlight = true;
    late final NearbyCoordinate location;
    try {
      location = await _locationGateway.getCurrentLocation();
    } finally {
      _locationRequestInFlight = false;
    }
    if (_disposed || generation != _generation) return;
    currentLocation = location;
    await _gateway.updateNearbyLocation(location);
    if (_disposed || generation != _generation) return;
    await _loadPage(1, replace: true, generation: generation);
  }

  Future<void> _loadPage(
    int page, {
    required bool replace,
    int? generation,
  }) async {
    final location = currentLocation;
    if (location == null) {
      viewState = NearbyViewState.permissionRequired;
      _notify();
      return;
    }
    final requestGeneration = generation ?? ++_generation;
    final result = await _gateway.loadNearbyUsers(
      location: location,
      distance: selectedDistance,
      page: page,
    );
    if (_disposed || requestGeneration != _generation) return;
    users = replace ? result.items : [...users, ...result.items];
    _currentPage = result.page;
    _totalPages = result.totalPages;
    viewState = NearbyViewState.ready;
    errorMessage = null;
    _notify();
  }

  void _setError(String message) {
    errorMessage = message;
    viewState = NearbyViewState.error;
    _notify();
  }

  void _handleLocationFailure(
    Object error,
    String fallback, {
    bool fatal = true,
  }) {
    if (error is PlatformException && error.code == 'location_disabled') {
      errorMessage = null;
      viewState = NearbyViewState.locationServiceDisabled;
      _notify();
      return;
    }
    final message = _readableError(error, fallback);
    if (fatal) {
      _setError(message);
      return;
    }
    errorMessage = message;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    final locationGateway = _locationGateway;
    if (_locationRequestInFlight &&
        locationGateway is CancellableNearbyLocationGateway) {
      unawaited(
        locationGateway.cancelCurrentLocation().catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

String _readableError(Object error, String fallback) {
  final text = error.toString().trim();
  if (text.isEmpty) return fallback;
  return text
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .replaceFirst('TimeoutException: ', '')
      .trim();
}
