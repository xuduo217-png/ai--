import 'package:socket_io_client/socket_io_client.dart' as io;

import '../domain/chat_models.dart';

typedef ChatMessageHandler = void Function(ChatMessage message);
typedef ChatSessionExtensionHandler =
    void Function(ChatSessionExtension extension);
typedef ChatErrorHandler = void Function(String message);
typedef DoctorStatusHandler = void Function(bool online);

class ChatSocketClient {
  ChatSocketClient({
    required this.serverUrl,
    required this.accessToken,
    required this.doctorId,
    required this.conversationId,
    required this.onMessage,
    required this.onMessageRevoked,
    required this.onConnectedChanged,
    required this.onPaymentRequired,
    required this.onSessionExpired,
    required this.onDoctorStatusChanged,
    this.onSessionExtended,
    required this.onError,
  });

  final String serverUrl;
  final String accessToken;
  final int doctorId;
  final String conversationId;
  final ChatMessageHandler onMessage;
  final ChatMessageHandler onMessageRevoked;
  final void Function(bool connected) onConnectedChanged;
  final void Function(Object? payload) onPaymentRequired;
  final void Function(Object? payload) onSessionExpired;
  final DoctorStatusHandler onDoctorStatusChanged;
  final ChatSessionExtensionHandler? onSessionExtended;
  final ChatErrorHandler onError;

  io.Socket? _socket;
  bool _joined = false;

  bool get isConnected => _socket?.connected == true;

  void connect() {
    if (_socket != null) {
      if (!isConnected) _socket!.connect();
      return;
    }

    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': accessToken})
        .enableForceNew()
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionAttempts(5)
        .setTimeout(10000)
        .build();
    final socket = io.io(serverUrl, options);
    _socket = socket;

    socket.onConnect((_) {
      _joined = false;
      onConnectedChanged(true);
      _joinRoom();
    });
    socket.onDisconnect((_) {
      _joined = false;
      onConnectedChanged(false);
    });
    socket.onConnectError((data) {
      onConnectedChanged(false);
      onError(_socketErrorMessage(data));
    });
    socket.onError((data) => onError(_socketErrorMessage(data)));
    socket.on('newMessage', (data) {
      final json = _asMap(data);
      if (json.isNotEmpty) onMessage(ChatMessage.fromJson(json));
    });
    socket.on('messageRevoked', (data) {
      final json = _asMap(data);
      if (json.isNotEmpty) onMessageRevoked(ChatMessage.fromJson(json));
    });
    socket.on('paymentRequired', onPaymentRequired);
    socket.on('sessionExpired', onSessionExpired);
    socket.on('doctorOnlineStatusChanged', (data) {
      final json = _asMap(data);
      if (_toInt(json['doctorId']) != doctorId) return;
      onDoctorStatusChanged(
        '${json['onlineStatus']}'.toUpperCase() == 'ONLINE',
      );
    });
    socket.on('chat:session:extended', (data) {
      final handler = onSessionExtended;
      if (handler == null) return;
      final json = _asMap(data);
      if (json.isEmpty) return;
      try {
        handler(ChatSessionExtension.fromJson(json));
      } on Object catch (error) {
        onError('$error');
      }
    });
    socket.connect();
  }

  void reconnect() {
    final socket = _socket;
    if (socket == null) {
      connect();
      return;
    }
    if (socket.connected) {
      _joinRoom();
    } else {
      socket.connect();
    }
  }

  void sendMessage({
    required String content,
    required ChatMessageType type,
    required void Function(ChatMessage message) onAcknowledged,
    required void Function(String message) onFailed,
  }) {
    final socket = _socket;
    if (socket == null) {
      onFailed('聊天连接尚未建立');
      return;
    }

    socket.emitWithAck(
      'sendMessage',
      {
        'conversationId': conversationId,
        'content': content,
        'type': type.wireValue,
      },
      ack: (data) {
        final response = _asMap(data);
        final error = response['error'];
        if (error != null) {
          onFailed(_friendlySendError('$error'));
          return;
        }
        final message = _asMap(response['message']);
        if (message.isNotEmpty) {
          onAcknowledged(ChatMessage.fromJson(message));
        }
      },
    );
  }

  void _joinRoom() {
    final socket = _socket;
    if (socket == null || !socket.connected || _joined) return;
    socket.emit('join', {'conversationId': conversationId});
    _joined = true;
  }

  void dispose() {
    final socket = _socket;
    if (socket == null) return;
    if (socket.connected && _joined) {
      socket.emit('leave', {'conversationId': conversationId});
    }
    socket.dispose();
    _socket = null;
    _joined = false;
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int _toInt(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  _ => int.tryParse('$value') ?? 0,
};

String _socketErrorMessage(Object? value) {
  final json = _asMap(value);
  final message = json['message'];
  return message == null ? '聊天连接失败，正在重试' : '$message';
}

String _friendlySendError(String value) {
  return switch (value) {
    'FREE_LIMIT_EXCEEDED' => '免费咨询次数已用完，请先购买套餐',
    'SESSION_EXPIRED' => '当前咨询已过期，请续费后继续',
    _ => value,
  };
}
