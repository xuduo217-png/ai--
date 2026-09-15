import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../domain/chat_models.dart';

abstract interface class ConsultationRealtimeGateway {
  bool get isConnected;
  Stream<ChatMessage> get messages;
  Stream<bool> get connectionChanges;
  Stream<Object> get errors;
  Stream<Object?> get sessionRevoked;

  Future<void> connect();
  Future<void> pause();
  Future<void> close();
}

abstract interface class ConsultationSessionExtensionRealtimeGateway {
  Stream<ChatSessionExtension> get sessionExtensions;
}

class ConsultationRealtimeSocketClient
    implements
        ConsultationRealtimeGateway,
        ConsultationSessionExtensionRealtimeGateway {
  ConsultationRealtimeSocketClient({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
  }) : _serverUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _accessTokenProvider = accessTokenProvider;

  static const newMessageEvent = 'chat:message:new';
  static const revokedSessionEvent = 'auth:session:revoked';

  final String _serverUrl;
  final Future<String?> Function() _accessTokenProvider;
  final _messages = StreamController<ChatMessage>.broadcast(sync: true);
  final _connections = StreamController<bool>.broadcast(sync: true);
  final _errors = StreamController<Object>.broadcast(sync: true);
  final _revokedSessions = StreamController<Object?>.broadcast(sync: true);
  final _sessionExtensions = StreamController<ChatSessionExtension>.broadcast(
    sync: true,
  );

  io.Socket? _socket;
  bool _closed = false;

  @override
  bool get isConnected => _socket?.connected == true;

  @override
  Stream<ChatMessage> get messages => _messages.stream;

  @override
  Stream<bool> get connectionChanges => _connections.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Stream<Object?> get sessionRevoked => _revokedSessions.stream;

  @override
  Stream<ChatSessionExtension> get sessionExtensions =>
      _sessionExtensions.stream;

  @override
  Future<void> connect() async {
    if (_closed) throw StateError('Consultation realtime client is closed.');
    final existing = _socket;
    if (existing != null) {
      if (!existing.connected) existing.connect();
      return;
    }

    final token = await _accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw StateError('登录后才能接收咨询消息');
    }

    final socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token.trim()})
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(5)
          .setTimeout(10000)
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) => _connections.add(true));
    socket.onDisconnect((_) => _connections.add(false));
    socket.onConnectError(_addSocketError);
    socket.onError(_addSocketError);
    socket.on(newMessageEvent, (payload) {
      try {
        final json = payload is Map
            ? Map<String, dynamic>.from(payload)
            : const <String, dynamic>{};
        if (json.isNotEmpty) _messages.add(ChatMessage.fromJson(json));
      } on Object catch (error) {
        _errors.add(error);
      }
    });
    socket.on(revokedSessionEvent, _revokedSessions.add);
    socket.on('chat:session:extended', (payload) {
      try {
        final json = payload is Map
            ? Map<String, dynamic>.from(payload)
            : const <String, dynamic>{};
        if (json.isNotEmpty) {
          _sessionExtensions.add(ChatSessionExtension.fromJson(json));
        }
      } on Object catch (error) {
        _errors.add(error);
      }
    });
    socket.connect();
  }

  void _addSocketError(Object? value) {
    _connections.add(false);
    _errors.add(value is Object ? value : Exception('$value'));
  }

  @override
  Future<void> pause() async {
    _socket?.disconnect();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _socket?.dispose();
    _socket = null;
    await Future.wait<void>([
      _messages.close(),
      _connections.close(),
      _errors.close(),
      _revokedSessions.close(),
      _sessionExtensions.close(),
    ]);
  }
}
