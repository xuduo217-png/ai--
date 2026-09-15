import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/notification_models.dart';

abstract interface class NotificationPollHandle {
  void cancel();
}

typedef NotificationPollFactory =
    NotificationPollHandle Function(
      Duration interval,
      void Function() callback,
    );

class NotificationBadgeMutation {
  const NotificationBadgeMutation._({
    required this.previousValue,
    required this.revision,
  });

  final int previousValue;
  final int revision;
}

class NotificationBadgeController extends ChangeNotifier
    implements ValueListenable<int> {
  NotificationBadgeController({
    required NotificationGateway gateway,
    Duration pollInterval = const Duration(seconds: 60),
    NotificationPollFactory? timerFactory,
  }) : _gateway = gateway,
       _pollInterval = pollInterval,
       _timerFactory = timerFactory ?? _createTimer;

  final NotificationGateway _gateway;
  final Duration _pollInterval;
  final NotificationPollFactory _timerFactory;

  @override
  int get value => _value;
  int _value = 0;

  int? get ownerUserId => _ownerUserId;
  int? _ownerUserId;

  String? get errorMessage => _errorMessage;
  String? _errorMessage;

  NotificationPollHandle? _timer;
  Future<void>? _activeRefresh;
  int _generation = 0;
  int _revision = 0;
  bool _foreground = true;
  bool _started = false;
  bool _disposed = false;

  Future<void> start(int ownerUserId) {
    if (_disposed || ownerUserId <= 0) return Future<void>.value();
    if (_started && _ownerUserId == ownerUserId) {
      return _activeRefresh ?? Future<void>.value();
    }
    _generation += 1;
    _ownerUserId = ownerUserId;
    _started = true;
    _foreground = true;
    _activeRefresh = null;
    _errorMessage = null;
    _setValue(0);
    _schedulePolling();
    return refresh();
  }

  Future<void> refresh() {
    if (_disposed || !_started || _ownerUserId == null) {
      return Future<void>.value();
    }
    final active = _activeRefresh;
    if (active != null) return active;
    final generation = _generation;
    final ownerUserId = _ownerUserId;
    late final Future<void> operation;
    operation = _runRefresh(generation, ownerUserId!).whenComplete(() {
      if (_activeRefresh == operation) _activeRefresh = null;
    });
    _activeRefresh = operation;
    return operation;
  }

  Future<void> _runRefresh(int generation, int ownerUserId) async {
    try {
      final count = await _gateway.loadUnreadCount();
      if (!_isCurrent(generation, ownerUserId)) return;
      _errorMessage = null;
      _setValue(count);
    } on Object {
      if (!_isCurrent(generation, ownerUserId)) return;
      _errorMessage = '通知角标同步失败，请稍后重试';
      _notify();
    }
  }

  void pause() {
    if (_disposed) return;
    _foreground = false;
    _cancelTimer();
  }

  Future<void> resume() {
    if (_disposed || !_started || _ownerUserId == null) {
      return Future<void>.value();
    }
    _foreground = true;
    _schedulePolling();
    return refresh();
  }

  void deactivate() {
    if (_disposed) return;
    _generation += 1;
    _started = false;
    _ownerUserId = null;
    _activeRefresh = null;
    _errorMessage = null;
    _cancelTimer();
    _setValue(0);
  }

  void setLocalCount(int count) {
    if (_disposed) return;
    _setValue(count < 0 ? 0 : count);
  }

  NotificationBadgeMutation applyLocalDelta(int delta) {
    final previous = _value;
    _setValue(_value + delta < 0 ? 0 : _value + delta);
    return NotificationBadgeMutation._(
      previousValue: previous,
      revision: _revision,
    );
  }

  NotificationBadgeMutation markAllReadLocally() {
    final previous = _value;
    _setValue(0);
    return NotificationBadgeMutation._(
      previousValue: previous,
      revision: _revision,
    );
  }

  void rollback(NotificationBadgeMutation mutation) {
    if (_disposed || _revision != mutation.revision) return;
    _setValue(mutation.previousValue);
  }

  void _schedulePolling() {
    _cancelTimer();
    if (!_foreground || !_started || _ownerUserId == null) return;
    _timer = _timerFactory(_pollInterval, () => unawaited(refresh()));
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  bool _isCurrent(int generation, int ownerUserId) {
    return !_disposed &&
        _started &&
        generation == _generation &&
        ownerUserId == _ownerUserId;
  }

  void _setValue(int value) {
    final normalized = value < 0 ? 0 : value;
    _revision += 1;
    if (_value == normalized) return;
    _value = normalized;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _cancelTimer();
    super.dispose();
  }
}

class _TimerPollHandle implements NotificationPollHandle {
  const _TimerPollHandle(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

NotificationPollHandle _createTimer(
  Duration interval,
  void Function() callback,
) {
  return _TimerPollHandle(Timer.periodic(interval, (_) => callback()));
}
