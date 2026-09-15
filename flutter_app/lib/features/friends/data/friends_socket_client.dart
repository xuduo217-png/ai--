import 'dart:async';

import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_relation_models.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef AccessTokenProvider = Future<String?> Function();
typedef FriendsSocketTransportFactory =
    FriendsSocketTransport Function(String url, Map<String, dynamic> options);

abstract interface class FriendsSocketGateway {
  bool get isConnected;
  Stream<FriendMessage> get messages;
  Stream<FriendMessageAck> get acknowledgements;
  Stream<FriendReadReceipt> get readReceipts;
  Stream<FriendshipDeletedEvent> get friendshipDeleted;
  Stream<SessionRevokedEvent> get sessionRevoked;
  Stream<bool> get connectionChanges;
  Stream<Object> get errors;

  Future<void> connect();
  Future<FriendMessageAck> sendMessage({
    required int receiverId,
    required String messageType,
    required String content,
    required String tempMessageId,
  });
  Future<FriendMessageAck> sendTextMessage({
    required int receiverId,
    required String content,
    required String tempMessageId,
  });
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  });
  Future<void> fetchOfflineMessages();
  Future<void> acknowledgeOfflineMessages(List<String> messageIds);
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class FriendRelationsSocketGateway {
  Stream<FriendRequest> get newFriendRequests;
  Stream<FriendRequestAcceptedEvent> get acceptedFriendRequests;
  Stream<FriendRequestRejectedEvent> get rejectedFriendRequests;
  Stream<FriendshipDeletedEvent> get deletedFriendships;
}

abstract interface class FriendsSocketTransport {
  bool get connected;
  void on(String event, void Function(dynamic data) handler);
  void off(String event, void Function(dynamic data) handler);
  void connect();
  void emit(String event, [dynamic data]);
  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic data) ack,
  });
  void disconnect();
  void dispose();
}

class FriendsSocketEvents {
  const FriendsSocketEvents._();

  static const connect = 'connect';
  static const disconnect = 'disconnect';
  static const connectError = 'connect_error';
  static const join = 'friends:join';
  static const leave = 'friends:leave';
  static const sendMessage = 'friends:message:send';
  static const newMessage = 'friends:message:new';
  static const revokedMessage = 'friends:message:revoked';
  static const messageAck = 'friends:message:ack';
  static const markRead = 'friends:message:read';
  static const readReceipt = 'friends:read:receipt';
  static const fetchOffline = 'friends:offline:fetch';
  static const acknowledgeOffline = 'friends:offline:ack';
  static const deletedFriendship = 'friends:friendship:deleted';
  static const newFriendRequest = 'friends:request:new';
  static const acceptedFriendRequest = 'friends:request:accepted';
  static const rejectedFriendRequest = 'friends:request:rejected';
  static const revokedSession = 'auth:session:revoked';
}

class FriendsSocketPayloadMapper {
  const FriendsSocketPayloadMapper._();

  static FriendMessage message(dynamic payload) {
    return FriendMessage.fromJson(_payloadMap(payload, 'message'));
  }

  static FriendMessageAck messageAck(
    dynamic payload, {
    String? fallbackTempMessageId,
  }) {
    final json = _payloadMap(payload, 'message acknowledgement');
    final nestedMessage = json['message'];
    final message = nestedMessage is Map
        ? Map<String, Object?>.from(nestedMessage)
        : const <String, Object?>{};
    final messageId =
        json['messageId'] ?? message['messageId'] ?? message['id'];
    final tempMessageId =
        json['tempMessageId'] ??
        message['tempMessageId'] ??
        fallbackTempMessageId;
    final success = json['success'] != false;
    if (tempMessageId == null || (success && messageId == null)) {
      throw const FormatException(
        'Message acknowledgement is missing message identifiers.',
      );
    }
    return FriendMessageAck(
      tempMessageId: tempMessageId.toString(),
      success: success,
      messageId: messageId?.toString(),
      message: nestedMessage is Map ? FriendMessage.fromJson(message) : null,
      errorMessage: success
          ? null
          : (json['error'] ?? json['message'])?.toString(),
    );
  }

  static FriendReadReceipt readReceipt(dynamic payload) {
    final json = _payloadMap(payload, 'read receipt');
    return FriendReadReceipt(
      messageId: _requiredString(json, 'messageId'),
      conversationId: _requiredString(json, 'conversationId'),
      readerId: _requiredInt(json, 'readerId'),
    );
  }

  static FriendshipDeletedEvent friendshipDeleted(dynamic payload) {
    final json = _payloadMap(payload, 'friendship deletion');
    return FriendshipDeletedEvent(
      friendId: _requiredInt(json, 'friendId'),
      deletedByUserId: _requiredInt(json, 'deletedByUserId'),
    );
  }

  static FriendRequest friendRequest(dynamic payload) {
    return FriendRequest.fromJson(_payloadMap(payload, 'friend request'));
  }

  static FriendRequestAcceptedEvent friendRequestAccepted(dynamic payload) {
    return FriendRequestAcceptedEvent.fromJson(
      _payloadMap(payload, 'accepted friend request'),
    );
  }

  static FriendRequestRejectedEvent friendRequestRejected(dynamic payload) {
    return FriendRequestRejectedEvent.fromJson(
      _payloadMap(payload, 'rejected friend request'),
    );
  }

  static SessionRevokedEvent sessionRevoked(dynamic payload) {
    final json = payload is Map
        ? Map<String, Object?>.from(payload)
        : const <String, Object?>{};
    return SessionRevokedEvent(reason: json['reason']?.toString());
  }
}

class FriendsSocketClient
    implements FriendsSocketGateway, FriendRelationsSocketGateway {
  FriendsSocketClient({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    FriendsSocketTransportFactory? transportFactory,
    this.commandTimeout = const Duration(seconds: 10),
  }) : _namespaceUrl = '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/friends',
       _accessTokenProvider = accessTokenProvider,
       _transportFactory = transportFactory ?? _productionTransport;

  final String _namespaceUrl;
  final AccessTokenProvider _accessTokenProvider;
  final FriendsSocketTransportFactory _transportFactory;
  final Duration commandTimeout;

  final _messageController = StreamController<FriendMessage>.broadcast(
    sync: true,
  );
  final _ackController = StreamController<FriendMessageAck>.broadcast(
    sync: true,
  );
  final _readController = StreamController<FriendReadReceipt>.broadcast(
    sync: true,
  );
  final _friendshipController =
      StreamController<FriendshipDeletedEvent>.broadcast(sync: true);
  final _newFriendRequestController = StreamController<FriendRequest>.broadcast(
    sync: true,
  );
  final _acceptedFriendRequestController =
      StreamController<FriendRequestAcceptedEvent>.broadcast(sync: true);
  final _rejectedFriendRequestController =
      StreamController<FriendRequestRejectedEvent>.broadcast(sync: true);
  final _sessionController = StreamController<SessionRevokedEvent>.broadcast(
    sync: true,
  );
  final _connectionController = StreamController<bool>.broadcast(sync: true);
  final _errorController = StreamController<Object>.broadcast(sync: true);

  final Map<String, void Function(dynamic)> _handlers =
      <String, void Function(dynamic)>{};
  final Map<String, _PendingSend> _pendingSends = <String, _PendingSend>{};

  FriendsSocketTransport? _transport;
  Future<void>? _connectionAttempt;
  Completer<void>? _connectionCompleter;
  Timer? _connectionTimer;
  bool _disposed = false;

  @override
  bool get isConnected => _transport?.connected ?? false;

  @override
  Stream<FriendMessage> get messages => _messageController.stream;

  @override
  Stream<FriendMessageAck> get acknowledgements => _ackController.stream;

  @override
  Stream<FriendReadReceipt> get readReceipts => _readController.stream;

  @override
  Stream<FriendshipDeletedEvent> get friendshipDeleted =>
      _friendshipController.stream;

  @override
  Stream<FriendRequest> get newFriendRequests =>
      _newFriendRequestController.stream;

  @override
  Stream<FriendRequestAcceptedEvent> get acceptedFriendRequests =>
      _acceptedFriendRequestController.stream;

  @override
  Stream<FriendRequestRejectedEvent> get rejectedFriendRequests =>
      _rejectedFriendRequestController.stream;

  @override
  Stream<FriendshipDeletedEvent> get deletedFriendships =>
      _friendshipController.stream;

  @override
  Stream<SessionRevokedEvent> get sessionRevoked => _sessionController.stream;

  @override
  Stream<bool> get connectionChanges => _connectionController.stream;

  @override
  Stream<Object> get errors => _errorController.stream;

  @override
  Future<void> connect() {
    if (_disposed) {
      return Future<void>.error(
        StateError('FriendsSocketClient has been disposed.'),
      );
    }
    if (isConnected) return Future<void>.value();
    return _connectionAttempt ??= _connectInternal().whenComplete(() {
      _connectionAttempt = null;
    });
  }

  Future<void> _connectInternal() async {
    final token = await _accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw StateError('An access token is required for the friends socket.');
    }

    final existing = _transport;
    if (existing != null) {
      _removeListeners(existing);
      existing.dispose();
    }

    final transport = _transportFactory(_namespaceUrl, <String, dynamic>{
      'transports': <String>['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'auth': <String, String>{'token': token},
    });
    _transport = transport;
    _registerListeners(transport);
    _connectionCompleter = Completer<void>();
    _connectionTimer = Timer(commandTimeout, () {
      final completer = _connectionCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(
          TimeoutException('Friends socket connection timed out.'),
        );
      }
    });
    transport.connect();
    return _connectionCompleter!.future;
  }

  void _registerListeners(FriendsSocketTransport transport) {
    void register(String event, void Function(dynamic) handler) {
      _handlers[event] = handler;
      transport.on(event, handler);
    }

    register(FriendsSocketEvents.connect, (_) {
      _connectionTimer?.cancel();
      final completer = _connectionCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
      transport.emit(FriendsSocketEvents.join, const <String, Object?>{});
      _connectionController.add(true);
    });
    register(FriendsSocketEvents.disconnect, (_) {
      _connectionController.add(false);
    });
    register(FriendsSocketEvents.connectError, (error) {
      final normalized = error is Object ? error : Exception('$error');
      final completer = _connectionCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(normalized);
      }
      _errorController.add(normalized);
    });
    register(FriendsSocketEvents.newMessage, (payload) {
      _mapAndAdd(
        () => FriendsSocketPayloadMapper.message(payload),
        _messageController,
      );
    });
    register(FriendsSocketEvents.revokedMessage, (payload) {
      _mapAndAdd(
        () => FriendsSocketPayloadMapper.message(payload),
        _messageController,
      );
    });
    register(FriendsSocketEvents.messageAck, (payload) {
      try {
        final ack = FriendsSocketPayloadMapper.messageAck(payload);
        _ackController.add(ack);
        _completePendingSend(ack);
      } catch (error) {
        _errorController.add(error);
      }
    });
    register(FriendsSocketEvents.readReceipt, (payload) {
      _mapAndAdd(
        () => FriendsSocketPayloadMapper.readReceipt(payload),
        _readController,
      );
    });
    register(FriendsSocketEvents.deletedFriendship, (payload) {
      _mapAndAdd(
        () => FriendsSocketPayloadMapper.friendshipDeleted(payload),
        _friendshipController,
      );
    });
    register(FriendsSocketEvents.newFriendRequest, (payload) {
      _mapAndAdd(
        () => FriendsSocketPayloadMapper.friendRequest(payload),
        _newFriendRequestController,
      );
    });
    register(FriendsSocketEvents.acceptedFriendRequest, (payload) {
      _mapAndAdd(
        () => FriendsSocketPayloadMapper.friendRequestAccepted(payload),
        _acceptedFriendRequestController,
      );
    });
    register(FriendsSocketEvents.rejectedFriendRequest, (payload) {
      _mapAndAdd(
        () => FriendsSocketPayloadMapper.friendRequestRejected(payload),
        _rejectedFriendRequestController,
      );
    });
    register(FriendsSocketEvents.revokedSession, (payload) {
      _sessionController.add(
        FriendsSocketPayloadMapper.sessionRevoked(payload),
      );
    });
  }

  void _mapAndAdd<T>(T Function() mapper, StreamController<T> controller) {
    try {
      controller.add(mapper());
    } catch (error) {
      _errorController.add(error);
    }
  }

  @override
  Future<FriendMessageAck> sendTextMessage({
    required int receiverId,
    required String content,
    required String tempMessageId,
  }) {
    return sendMessage(
      receiverId: receiverId,
      messageType: 'text',
      content: content,
      tempMessageId: tempMessageId,
    );
  }

  @override
  Future<FriendMessageAck> sendMessage({
    required int receiverId,
    required String messageType,
    required String content,
    required String tempMessageId,
  }) async {
    await connect();
    final completer = Completer<FriendMessageAck>();
    final timer = Timer(commandTimeout, () {
      _pendingSends.remove(tempMessageId);
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Message acknowledgement timed out.'),
        );
      }
    });
    _pendingSends[tempMessageId] = _PendingSend(completer, timer);

    _transport!.emitWithAck(
      FriendsSocketEvents.sendMessage,
      <String, Object?>{
        'receiverId': receiverId,
        'messageType': messageType,
        'content': content,
        'tempMessageId': tempMessageId,
      },
      ack: (payload) {
        try {
          final acknowledgement = FriendsSocketPayloadMapper.messageAck(
            payload,
            fallbackTempMessageId: tempMessageId,
          );
          _ackController.add(acknowledgement);
          _completePendingSend(acknowledgement);
        } catch (error) {
          _failPendingSend(tempMessageId, error);
        }
      },
    );
    return completer.future;
  }

  void _completePendingSend(FriendMessageAck ack) {
    final pending = _pendingSends.remove(ack.tempMessageId);
    if (pending == null) return;
    pending.timer.cancel();
    if (!pending.completer.isCompleted) pending.completer.complete(ack);
  }

  void _failPendingSend(String tempMessageId, Object error) {
    final pending = _pendingSends.remove(tempMessageId);
    if (pending == null) return;
    pending.timer.cancel();
    if (!pending.completer.isCompleted) pending.completer.completeError(error);
  }

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) {
    return _emitCommand(FriendsSocketEvents.markRead, <String, Object?>{
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  @override
  Future<void> fetchOfflineMessages() {
    return _emitCommand(
      FriendsSocketEvents.fetchOffline,
      const <String, Object?>{},
    );
  }

  @override
  Future<void> acknowledgeOfflineMessages(List<String> messageIds) {
    if (messageIds.isEmpty) return Future<void>.value();
    return _emitCommand(
      FriendsSocketEvents.acknowledgeOffline,
      <String, Object?>{'messageIds': messageIds},
    );
  }

  Future<void> _emitCommand(String event, Map<String, Object?> payload) async {
    await connect();
    final completer = Completer<void>();
    final timer = Timer(commandTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('$event timed out.'));
      }
    });
    _transport!.emitWithAck(
      event,
      payload,
      ack: (response) {
        try {
          final json = response is Map
              ? Map<String, Object?>.from(response)
              : const <String, Object?>{};
          _throwWhenRejected(json);
          if (!completer.isCompleted) completer.complete();
        } catch (error) {
          if (!completer.isCompleted) completer.completeError(error);
        } finally {
          timer.cancel();
        }
      },
    );
    return completer.future.whenComplete(timer.cancel);
  }

  @override
  Future<void> stop() async {
    _connectionTimer?.cancel();
    _connectionTimer = null;
    final connectionCompleter = _connectionCompleter;
    if (connectionCompleter != null && !connectionCompleter.isCompleted) {
      connectionCompleter.completeError(
        StateError('Friends socket stopped before connecting.'),
      );
    }
    _connectionCompleter = null;
    final transport = _transport;
    _transport = null;
    if (transport != null) {
      if (transport.connected) {
        transport.emit(FriendsSocketEvents.leave, const <String, Object?>{});
      }
      _removeListeners(transport);
      transport.disconnect();
      transport.dispose();
    }
    for (final pending in _pendingSends.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          StateError('Friends socket stopped before acknowledgement.'),
        );
      }
    }
    _pendingSends.clear();
    _connectionController.add(false);
  }

  void _removeListeners(FriendsSocketTransport transport) {
    for (final entry in _handlers.entries) {
      transport.off(entry.key, entry.value);
    }
    _handlers.clear();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    await Future.wait<void>(<Future<void>>[
      _messageController.close(),
      _ackController.close(),
      _readController.close(),
      _friendshipController.close(),
      _newFriendRequestController.close(),
      _acceptedFriendRequestController.close(),
      _rejectedFriendRequestController.close(),
      _sessionController.close(),
      _connectionController.close(),
      _errorController.close(),
    ]);
  }
}

class _PendingSend {
  const _PendingSend(this.completer, this.timer);

  final Completer<FriendMessageAck> completer;
  final Timer timer;
}

FriendsSocketTransport _productionTransport(
  String url,
  Map<String, dynamic> options,
) {
  return _IoFriendsSocketTransport(io.io(url, options));
}

class _IoFriendsSocketTransport implements FriendsSocketTransport {
  const _IoFriendsSocketTransport(this._socket);

  final io.Socket _socket;

  @override
  bool get connected => _socket.connected;

  @override
  void connect() => _socket.connect();

  @override
  void disconnect() => _socket.disconnect();

  @override
  void dispose() => _socket.dispose();

  @override
  void emit(String event, [dynamic data]) => _socket.emit(event, data);

  @override
  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic data) ack,
  }) {
    _socket.emitWithAck(event, data, ack: ack);
  }

  @override
  void off(String event, void Function(dynamic data) handler) {
    _socket.off(event, handler);
  }

  @override
  void on(String event, void Function(dynamic data) handler) {
    _socket.on(event, handler);
  }
}

Map<String, Object?> _payloadMap(dynamic payload, String name) {
  if (payload is Map) return Map<String, Object?>.from(payload);
  throw FormatException('$name payload must be a JSON object.');
}

void _throwWhenRejected(Map<String, Object?> payload) {
  if (payload['success'] == false) {
    throw StateError(
      payload['message']?.toString() ?? 'Friends socket command failed.',
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value.toString().isEmpty) {
    throw FormatException('$key is required.');
  }
  return value.toString();
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null) return parsed;
  throw FormatException('$key must be an integer.');
}
