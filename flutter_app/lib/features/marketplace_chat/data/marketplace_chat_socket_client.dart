import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../friends/data/friends_socket_client.dart';
import '../../friends/domain/friend_messaging_models.dart';

typedef MarketplaceSocketTransportFactory =
    FriendsSocketTransport Function(String url, Map<String, dynamic> options);

abstract interface class MarketplaceChatSocketGateway {
  bool get isConnected;
  Stream<FriendMessage> get messages;
  Stream<FriendMessageAck> get acknowledgements;
  Stream<FriendReadReceipt> get readReceipts;
  Stream<SessionRevokedEvent> get sessionRevoked;
  Stream<bool> get connectionChanges;
  Stream<Object> get errors;

  Future<void> connect();
  Future<FriendMessageAck> sendMessage({
    required String conversationId,
    required String messageType,
    required String content,
    required String tempMessageId,
  });
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  });
  Future<void> fetchOfflineMessages();
  Future<void> acknowledgeOfflineMessages(List<String> messageIds);
  Future<void> sendTyping({
    required String conversationId,
    required bool isTyping,
  });
  Future<void> stop();
  Future<void> dispose();
}

class MarketplaceChatSocketEvents {
  const MarketplaceChatSocketEvents._();

  static const connect = 'connect';
  static const disconnect = 'disconnect';
  static const connectError = 'connect_error';
  static const join = 'marketplace:join';
  static const sendMessage = 'marketplace:message:send';
  static const newMessage = 'marketplace:message:new';
  static const revokedMessage = 'marketplace:message:revoked';
  static const markRead = 'marketplace:message:read';
  static const readReceipt = 'marketplace:read:receipt';
  static const fetchOffline = 'marketplace:offline:fetch';
  static const acknowledgeOffline = 'marketplace:offline:ack';
  static const typingStart = 'marketplace:typing:start';
  static const typingStop = 'marketplace:typing:stop';
  static const revokedSession = 'auth:session:revoked';
}

class MarketplaceChatSocketClient implements MarketplaceChatSocketGateway {
  MarketplaceChatSocketClient({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    MarketplaceSocketTransportFactory? transportFactory,
    this.commandTimeout = const Duration(seconds: 10),
  }) : _namespaceUrl =
           '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/marketplace-chat',
       _accessTokenProvider = accessTokenProvider,
       _transportFactory = transportFactory ?? _productionTransport;

  final String _namespaceUrl;
  final AccessTokenProvider _accessTokenProvider;
  final MarketplaceSocketTransportFactory _transportFactory;
  final Duration commandTimeout;

  final _messages = StreamController<FriendMessage>.broadcast(sync: true);
  final _acks = StreamController<FriendMessageAck>.broadcast(sync: true);
  final _reads = StreamController<FriendReadReceipt>.broadcast(sync: true);
  final _sessions = StreamController<SessionRevokedEvent>.broadcast(sync: true);
  final _connections = StreamController<bool>.broadcast(sync: true);
  final _errors = StreamController<Object>.broadcast(sync: true);
  final Map<String, void Function(dynamic)> _handlers = {};

  FriendsSocketTransport? _transport;
  Future<void>? _connectionAttempt;
  Completer<void>? _connectionCompleter;
  Timer? _connectionTimer;
  bool _disposed = false;

  @override
  bool get isConnected => _transport?.connected ?? false;
  @override
  Stream<FriendMessage> get messages => _messages.stream;
  @override
  Stream<FriendMessageAck> get acknowledgements => _acks.stream;
  @override
  Stream<FriendReadReceipt> get readReceipts => _reads.stream;
  @override
  Stream<SessionRevokedEvent> get sessionRevoked => _sessions.stream;
  @override
  Stream<bool> get connectionChanges => _connections.stream;
  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> connect() {
    if (_disposed) {
      return Future<void>.error(
        StateError('Marketplace chat socket is disposed.'),
      );
    }
    if (isConnected) return Future<void>.value();
    return _connectionAttempt ??= _connectInternal().whenComplete(() {
      _connectionAttempt = null;
    });
  }

  Future<void> _connectInternal() async {
    final token = await _accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw StateError('登录后才能连接商城聊天');
    }
    final oldTransport = _transport;
    if (oldTransport != null) {
      _removeListeners(oldTransport);
      oldTransport.dispose();
    }
    final transport = _transportFactory(_namespaceUrl, {
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'auth': {'token': token.trim()},
    });
    _transport = transport;
    _registerListeners(transport);
    _connectionCompleter = Completer<void>();
    _connectionTimer = Timer(commandTimeout, () {
      final completer = _connectionCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(TimeoutException('商城聊天连接超时'));
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

    register(MarketplaceChatSocketEvents.connect, (_) {
      _connectionTimer?.cancel();
      final completer = _connectionCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
      transport.emit(MarketplaceChatSocketEvents.join, const {});
      _connections.add(true);
    });
    register(
      MarketplaceChatSocketEvents.disconnect,
      (_) => _connections.add(false),
    );
    register(MarketplaceChatSocketEvents.connectError, (error) {
      final normalized = error is Object ? error : Exception('$error');
      final completer = _connectionCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(normalized);
      }
      _errors.add(normalized);
    });
    register(MarketplaceChatSocketEvents.newMessage, (payload) {
      try {
        _messages.add(FriendMessage.fromJson(_map(payload)));
      } catch (error) {
        _errors.add(error);
      }
    });
    register(MarketplaceChatSocketEvents.revokedMessage, (payload) {
      try {
        _messages.add(FriendMessage.fromJson(_map(payload)));
      } catch (error) {
        _errors.add(error);
      }
    });
    register(MarketplaceChatSocketEvents.readReceipt, (payload) {
      try {
        final json = _map(payload);
        _reads.add(
          FriendReadReceipt(
            messageId: '${json['messageId'] ?? ''}',
            conversationId: '${json['conversationId'] ?? ''}',
            readerId: _int(json['readerId']),
          ),
        );
      } catch (error) {
        _errors.add(error);
      }
    });
    register(MarketplaceChatSocketEvents.revokedSession, (payload) {
      _sessions.add(
        SessionRevokedEvent(reason: _map(payload)['reason']?.toString()),
      );
    });
  }

  @override
  Future<FriendMessageAck> sendMessage({
    required String conversationId,
    required String messageType,
    required String content,
    required String tempMessageId,
  }) async {
    await connect();
    final completer = Completer<FriendMessageAck>();
    final timer = Timer(commandTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('消息确认超时'));
      }
    });
    _transport!.emitWithAck(
      MarketplaceChatSocketEvents.sendMessage,
      {
        'conversationId': conversationId,
        'messageType': messageType,
        'content': content,
        'tempMessageId': tempMessageId,
      },
      ack: (payload) {
        try {
          final ack = FriendsSocketPayloadMapper.messageAck(
            payload,
            fallbackTempMessageId: tempMessageId,
          );
          _acks.add(ack);
          if (!completer.isCompleted) {
            if (ack.success) {
              completer.complete(ack);
            } else {
              completer.completeError(StateError(ack.errorMessage ?? '消息发送失败'));
            }
          }
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
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) {
    return _command(MarketplaceChatSocketEvents.markRead, {
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  @override
  Future<void> fetchOfflineMessages() =>
      _command(MarketplaceChatSocketEvents.fetchOffline, const {});

  @override
  Future<void> acknowledgeOfflineMessages(List<String> messageIds) {
    if (messageIds.isEmpty) return Future.value();
    return _command(MarketplaceChatSocketEvents.acknowledgeOffline, {
      'messageIds': messageIds,
    });
  }

  @override
  Future<void> sendTyping({
    required String conversationId,
    required bool isTyping,
  }) {
    return _command(
      isTyping
          ? MarketplaceChatSocketEvents.typingStart
          : MarketplaceChatSocketEvents.typingStop,
      {'conversationId': conversationId},
    );
  }

  Future<void> _command(String event, Map<String, Object?> payload) async {
    await connect();
    final completer = Completer<void>();
    final timer = Timer(commandTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('$event 超时'));
      }
    });
    _transport!.emitWithAck(
      event,
      payload,
      ack: (response) {
        final json = _map(response);
        if (json['success'] == false) {
          if (!completer.isCompleted) {
            completer.completeError(StateError('${json['message'] ?? '操作失败'}'));
          }
        } else if (!completer.isCompleted) {
          completer.complete();
        }
        timer.cancel();
      },
    );
    return completer.future.whenComplete(timer.cancel);
  }

  @override
  Future<void> stop() async {
    _connectionTimer?.cancel();
    final completer = _connectionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError('商城聊天连接已停止'));
    }
    _connectionCompleter = null;
    final transport = _transport;
    _transport = null;
    if (transport != null) {
      _removeListeners(transport);
      transport.disconnect();
      transport.dispose();
    }
    _connections.add(false);
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
    await Future.wait([
      _messages.close(),
      _acks.close(),
      _reads.close(),
      _sessions.close(),
      _connections.close(),
      _errors.close(),
    ]);
  }
}

FriendsSocketTransport _productionTransport(
  String url,
  Map<String, dynamic> options,
) => _IoMarketplaceSocketTransport(io.io(url, options));

class _IoMarketplaceSocketTransport implements FriendsSocketTransport {
  const _IoMarketplaceSocketTransport(this._socket);

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
    required void Function(dynamic) ack,
  }) {
    _socket.emitWithAck(event, data, ack: ack);
  }

  @override
  void off(String event, void Function(dynamic) handler) =>
      _socket.off(event, handler);
  @override
  void on(String event, void Function(dynamic) handler) =>
      _socket.on(event, handler);
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
