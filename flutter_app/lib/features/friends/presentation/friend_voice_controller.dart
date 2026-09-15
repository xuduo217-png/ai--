import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../../core/network/asset_url_resolver.dart';
import '../domain/friend_messaging_models.dart';
import '../domain/friend_voice_content.dart';
import 'friend_voice_gateways.dart';

enum FriendVoiceControllerState {
  idle,
  requestingPermission,
  recording,
  stopping,
  error,
}

enum FriendVoiceStartOutcome {
  started,
  needsRationale,
  needsPermissionRequest,
  permanentlyDenied,
  ignored,
}

enum FriendVoicePlaybackStatus { idle, loading, playing }

typedef FriendVoiceSendCallback =
    Future<void> Function(FriendVoiceSendRequest request);

class FriendVoiceController extends ChangeNotifier {
  FriendVoiceController({
    required FriendVoiceSendCallback onSend,
    FriendVoiceRecorderGateway? recorder,
    FriendVoicePlayerGateway? player,
    FriendMicrophonePermissionGateway? permission,
  }) : _onSend = onSend,
       _recorder = recorder ?? RecordFriendVoiceRecorder(),
       _player = player ?? JustAudioFriendVoicePlayer(),
       _permission = permission ?? PermissionHandlerFriendMicrophoneGateway() {
    _durationSubscription = _recorder.durations.listen(_handleDuration);
    _completionSubscription = _player.completions.listen((_) {
      _setPlayback(null, FriendVoicePlaybackStatus.idle);
    });
  }

  static const Duration minimumDuration = Duration(seconds: 1);
  static const Duration maximumDuration = Duration(seconds: 60);

  final FriendVoiceSendCallback _onSend;
  final FriendVoiceRecorderGateway _recorder;
  final FriendVoicePlayerGateway _player;
  final FriendMicrophonePermissionGateway _permission;
  final Map<String, ValueNotifier<FriendVoicePlaybackStatus>>
  _playbackNotifiers = {};

  late final StreamSubscription<Duration> _durationSubscription;
  late final StreamSubscription<void> _completionSubscription;

  FriendVoiceControllerState _state = FriendVoiceControllerState.idle;
  Duration _elapsed = Duration.zero;
  String? _recordingPath;
  String? _activePlaybackKey;
  String? _notice;
  Future<void>? _stoppingOperation;
  Future<void>? _closeOperation;
  bool _gestureHeld = false;
  bool _rationaleShown = false;
  bool _sendInFlight = false;
  bool _disposed = false;

  FriendVoiceControllerState get state => _state;
  Duration get elapsed => _elapsed;
  int get elapsedSeconds => _elapsed.inSeconds.clamp(0, 60);
  bool get isRecording => _state == FriendVoiceControllerState.recording;
  bool get sendInFlight => _sendInFlight;

  String? takeNotice() {
    final value = _notice;
    _notice = null;
    return value;
  }

  ValueListenable<FriendVoicePlaybackStatus> playbackFor(String messageKey) {
    return _playbackNotifiers.putIfAbsent(
      messageKey,
      () => ValueNotifier<FriendVoicePlaybackStatus>(
        FriendVoicePlaybackStatus.idle,
      ),
    );
  }

  Future<FriendVoiceStartOutcome> beginHold() async {
    if (_disposed ||
        _sendInFlight ||
        (_state != FriendVoiceControllerState.idle &&
            _state != FriendVoiceControllerState.error)) {
      return FriendVoiceStartOutcome.ignored;
    }
    _gestureHeld = true;
    if (_state == FriendVoiceControllerState.error) {
      _setState(FriendVoiceControllerState.idle);
    }

    await stopPlayback();
    _setState(FriendVoiceControllerState.requestingPermission);
    try {
      final permission = await _permission.check();
      if (!_gestureHeld || _disposed) {
        _setState(FriendVoiceControllerState.idle);
        return FriendVoiceStartOutcome.ignored;
      }
      if (permission == FriendMicrophonePermissionStatus.granted) {
        _recordingPath = await _recorder.start();
        if (!_gestureHeld || _disposed) {
          await _recorder.cancel();
          _recordingPath = null;
          _setState(FriendVoiceControllerState.idle);
          return FriendVoiceStartOutcome.ignored;
        }
        _elapsed = Duration.zero;
        _setState(FriendVoiceControllerState.recording);
        return FriendVoiceStartOutcome.started;
      }

      _gestureHeld = false;
      _setState(FriendVoiceControllerState.idle);
      if (permission == FriendMicrophonePermissionStatus.permanentlyDenied) {
        return FriendVoiceStartOutcome.permanentlyDenied;
      }
      if (!_rationaleShown) {
        _rationaleShown = true;
        return FriendVoiceStartOutcome.needsRationale;
      }
      return FriendVoiceStartOutcome.needsPermissionRequest;
    } on Object catch (error) {
      _fail(error, '无法开始录音');
      return FriendVoiceStartOutcome.ignored;
    }
  }

  Future<FriendMicrophonePermissionStatus> requestPermission() async {
    if (_disposed) return FriendMicrophonePermissionStatus.denied;
    _gestureHeld = false;
    _setState(FriendVoiceControllerState.requestingPermission);
    try {
      final status = await _permission.request();
      _setState(FriendVoiceControllerState.idle);
      _notice = switch (status) {
        FriendMicrophonePermissionStatus.granted => '麦克风权限已开启，请再次按住录音',
        FriendMicrophonePermissionStatus.permanentlyDenied =>
          '麦克风权限已被永久拒绝，请前往系统设置开启',
        FriendMicrophonePermissionStatus.restricted => '当前设备限制了麦克风权限',
        FriendMicrophonePermissionStatus.denied => '未获得麦克风权限',
      };
      _safeNotify();
      return status;
    } on Object catch (error) {
      _fail(error, '麦克风权限申请失败');
      return FriendMicrophonePermissionStatus.denied;
    }
  }

  Future<bool> openSettings() => _permission.openSettings();

  Future<void> finishHold() async {
    _gestureHeld = false;
    if (_state == FriendVoiceControllerState.recording) {
      await _stopRecording(send: true);
    }
  }

  Future<void> cancelHold() async {
    _gestureHeld = false;
    final existing = _stoppingOperation;
    if (existing != null) {
      await existing;
      return;
    }
    if (_state != FriendVoiceControllerState.recording) return;
    final operation = _cancelRecording();
    _stoppingOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_stoppingOperation, operation)) {
        _stoppingOperation = null;
      }
    }
  }

  Future<void> togglePlayback(
    FriendMessage message, {
    required bool isMine,
  }) async {
    if (_disposed ||
        _state == FriendVoiceControllerState.recording ||
        _state == FriendVoiceControllerState.stopping) {
      return;
    }
    final key = message.localKey;
    final currentStatus = playbackFor(key).value;
    if (_activePlaybackKey == key &&
        currentStatus != FriendVoicePlaybackStatus.idle) {
      await stopPlayback();
      return;
    }

    await stopPlayback();
    final content = FriendVoiceContent.parse(message.content);
    if (content == null || !content.canPlay) {
      _notice = '语音地址无效';
      _safeNotify();
      return;
    }

    _setPlayback(key, FriendVoicePlaybackStatus.loading);
    Object? localError;
    if (isMine) {
      final localFile = resolveLocalFile(message.localFilePath);
      if (localFile != null && await localFile.exists()) {
        try {
          await _player.playLocalFile(localFile.path);
          _setPlayback(key, FriendVoicePlaybackStatus.playing);
          return;
        } on Object catch (error) {
          localError = error;
        }
      }
    }

    final remoteUrl = resolveAssetUrl(content.url);
    if (remoteUrl.isEmpty || isLocalMediaPath(remoteUrl)) {
      _setPlayback(null, FriendVoicePlaybackStatus.idle);
      _notice = localError == null ? '语音地址无效' : '语音文件播放失败';
      _safeNotify();
      return;
    }
    try {
      await _player.playRemoteUrl(remoteUrl);
      _setPlayback(key, FriendVoicePlaybackStatus.playing);
    } on Object catch (error) {
      _setPlayback(null, FriendVoicePlaybackStatus.idle);
      _notice = _readableError(error, '语音播放失败');
      _safeNotify();
    }
  }

  Future<void> stopPlayback() async {
    if (_activePlaybackKey == null) return;
    try {
      await _player.stop();
    } on Object {
      // UI state still needs resetting if the native player already stopped.
    }
    _setPlayback(null, FriendVoicePlaybackStatus.idle);
  }

  Future<void> stopAll() async {
    _gestureHeld = false;
    if (_state == FriendVoiceControllerState.recording ||
        _state == FriendVoiceControllerState.stopping) {
      await cancelHold();
    }
    await stopPlayback();
  }

  Future<void> _stopRecording({required bool send}) {
    final existing = _stoppingOperation;
    if (existing != null) return existing;
    final operation = _stopRecordingInternal(send: send);
    _stoppingOperation = operation;
    return operation.whenComplete(() {
      if (identical(_stoppingOperation, operation)) {
        _stoppingOperation = null;
      }
    });
  }

  Future<void> _stopRecordingInternal({required bool send}) async {
    if (_state != FriendVoiceControllerState.recording) return;
    _setState(FriendVoiceControllerState.stopping);
    final fallbackPath = _recordingPath;
    try {
      final stoppedPath = await _recorder.stop();
      final filePath = stoppedPath?.trim().isNotEmpty == true
          ? stoppedPath!
          : fallbackPath;
      _recordingPath = null;
      if (!send || _elapsed < minimumDuration) {
        await _recorder.deleteTemporaryFile(filePath);
        _elapsed = Duration.zero;
        _setState(FriendVoiceControllerState.idle);
        if (send) {
          _notice = '录音时间不足 1 秒';
          _safeNotify();
        }
        return;
      }
      if (filePath == null || !await File(filePath).exists()) {
        throw StateError('录音文件不存在，请重新录制');
      }

      final duration = _elapsed.inSeconds.clamp(1, 60);
      final file = File(filePath);
      final request = FriendVoiceSendRequest(
        localFilePath: filePath,
        duration: duration,
        fileName: path.basename(filePath).toLowerCase().endsWith('.m4a')
            ? path.basename(filePath)
            : 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        size: await file.length(),
      );
      _elapsed = Duration.zero;
      _sendInFlight = true;
      _setState(FriendVoiceControllerState.idle);
      try {
        await _onSend(request);
      } finally {
        _sendInFlight = false;
        _safeNotify();
      }
    } on Object catch (error) {
      _recordingPath = null;
      _fail(error, '录音发送失败，请重试');
    }
  }

  Future<void> _cancelRecording() async {
    _setState(FriendVoiceControllerState.stopping);
    final filePath = _recordingPath;
    _recordingPath = null;
    _elapsed = Duration.zero;
    try {
      await _recorder.cancel();
      await _recorder.deleteTemporaryFile(filePath);
      _setState(FriendVoiceControllerState.idle);
    } on Object catch (error) {
      _fail(error, '取消录音失败');
    }
  }

  void _handleDuration(Duration value) {
    if (_disposed ||
        (_state != FriendVoiceControllerState.recording &&
            _state != FriendVoiceControllerState.stopping)) {
      return;
    }
    _elapsed = value > maximumDuration ? maximumDuration : value;
    _safeNotify();
    if (_state == FriendVoiceControllerState.recording &&
        value >= maximumDuration &&
        _stoppingOperation == null) {
      _gestureHeld = false;
      unawaited(_stopRecording(send: true));
    }
  }

  void _setPlayback(String? key, FriendVoicePlaybackStatus status) {
    final previousKey = _activePlaybackKey;
    if (previousKey != null && previousKey != key) {
      _playbackNotifiers[previousKey]?.value = FriendVoicePlaybackStatus.idle;
    }
    if (key == null || status == FriendVoicePlaybackStatus.idle) {
      if (previousKey != null) {
        _playbackNotifiers[previousKey]?.value = FriendVoicePlaybackStatus.idle;
      }
      _activePlaybackKey = null;
      return;
    }
    _activePlaybackKey = key;
    _playbackNotifiers
            .putIfAbsent(
              key,
              () => ValueNotifier<FriendVoicePlaybackStatus>(
                FriendVoicePlaybackStatus.idle,
              ),
            )
            .value =
        status;
  }

  void _setState(FriendVoiceControllerState value) {
    if (_disposed || _state == value) return;
    _state = value;
    _safeNotify();
  }

  void _fail(Object error, String fallback) {
    _notice = _readableError(error, fallback);
    _state = FriendVoiceControllerState.error;
    _safeNotify();
  }

  Future<void> close() {
    return _closeOperation ??= _close();
  }

  Future<void> _close() async {
    if (_disposed) return;
    _disposed = true;
    _gestureHeld = false;
    await _durationSubscription.cancel();
    await _completionSubscription.cancel();
    try {
      await _recorder.cancel();
    } on Object {
      // Continue releasing the remaining native resources.
    }
    try {
      await _player.stop();
    } on Object {
      // Continue releasing the remaining native resources.
    }
    await _recorder.dispose();
    await _player.dispose();
    for (final notifier in _playbackNotifiers.values) {
      notifier.dispose();
    }
    _playbackNotifiers.clear();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}

String _readableError(Object error, String fallback) {
  final value = error.toString().trim();
  if (value.isEmpty || value == 'Exception') return fallback;
  return value
      .replaceFirst('Exception: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Bad state: ', '');
}
