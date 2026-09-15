import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

enum FriendMicrophonePermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

abstract interface class FriendMicrophonePermissionGateway {
  Future<FriendMicrophonePermissionStatus> check();

  Future<FriendMicrophonePermissionStatus> request();

  Future<bool> openSettings();
}

class PermissionHandlerFriendMicrophoneGateway
    implements FriendMicrophonePermissionGateway {
  @override
  Future<FriendMicrophonePermissionStatus> check() async {
    return _mapPermissionStatus(await Permission.microphone.status);
  }

  @override
  Future<FriendMicrophonePermissionStatus> request() async {
    return _mapPermissionStatus(await Permission.microphone.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}

abstract interface class FriendVoiceRecorderGateway {
  Stream<Duration> get durations;

  Future<String> start();

  Future<String?> stop();

  Future<void> cancel();

  Future<void> deleteTemporaryFile(String? filePath);

  Future<void> dispose();
}

class RecordFriendVoiceRecorder implements FriendVoiceRecorderGateway {
  RecordFriendVoiceRecorder({AudioRecorder? recorder}) : _recorder = recorder;

  AudioRecorder? _recorder;
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast(sync: true);
  final Stopwatch _stopwatch = Stopwatch();

  Timer? _durationTimer;
  String? _currentPath;
  bool _recording = false;

  @override
  Stream<Duration> get durations => _durationController.stream;

  @override
  Future<String> start() async {
    final recorder = _recorder ??= AudioRecorder();
    final directory = await getTemporaryDirectory();
    final voiceDirectory = Directory(path.join(directory.path, 'friend_voice'));
    await voiceDirectory.create(recursive: true);
    final filePath = path.join(
      voiceDirectory.path,
      'voice_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    try {
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );
    } on Object {
      await deleteTemporaryFile(filePath);
      rethrow;
    }

    _currentPath = filePath;
    _recording = true;
    _stopwatch
      ..reset()
      ..start();
    _durationController.add(Duration.zero);
    _durationTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_recording && !_durationController.isClosed) {
        _durationController.add(_stopwatch.elapsed);
      }
    });
    return filePath;
  }

  @override
  Future<String?> stop() async {
    if (!_recording) return _currentPath;
    _finishTiming();
    final result = await _recorder?.stop();
    _recording = false;
    final resolved = result?.trim().isNotEmpty == true ? result : _currentPath;
    _currentPath = null;
    return resolved;
  }

  @override
  Future<void> cancel() async {
    final filePath = _currentPath;
    _finishTiming();
    if (_recording) {
      await _recorder?.cancel();
    }
    _recording = false;
    _currentPath = null;
    await deleteTemporaryFile(filePath);
  }

  @override
  Future<void> deleteTemporaryFile(String? filePath) async {
    final value = filePath?.trim() ?? '';
    if (value.isEmpty) return;
    final file = File(value);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> dispose() async {
    try {
      await cancel();
    } on Object {
      // Native resources still need disposing if cancellation already failed.
    }
    await _recorder?.dispose();
    _recorder = null;
    await _durationController.close();
  }

  void _finishTiming() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _stopwatch.stop();
    if (!_durationController.isClosed) {
      _durationController.add(_stopwatch.elapsed);
    }
  }
}

abstract interface class FriendVoicePlayerGateway {
  Stream<void> get completions;

  Future<void> playLocalFile(String filePath);

  Future<void> playRemoteUrl(String url);

  Future<void> stop();

  Future<void> dispose();
}

class JustAudioFriendVoicePlayer implements FriendVoicePlayerGateway {
  JustAudioFriendVoicePlayer({AudioPlayer? player}) : _player = player;

  final StreamController<void> _completionController =
      StreamController<void>.broadcast(sync: true);
  AudioPlayer? _player;
  StreamSubscription<ProcessingState>? _completionSubscription;

  @override
  Stream<void> get completions => _completionController.stream;

  @override
  Future<void> playLocalFile(String filePath) async {
    final player = _ensurePlayer();
    await player.setFilePath(filePath);
    unawaited(player.play());
  }

  @override
  Future<void> playRemoteUrl(String url) async {
    final player = _ensurePlayer();
    await player.setUrl(url);
    unawaited(player.play());
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _completionSubscription?.cancel();
    await _player?.dispose();
    _player = null;
    await _completionController.close();
  }

  AudioPlayer _ensurePlayer() {
    final player = _player ??= AudioPlayer();
    _completionSubscription ??= player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed &&
          !_completionController.isClosed) {
        _completionController.add(null);
      }
    });
    return player;
  }
}

FriendMicrophonePermissionStatus _mapPermissionStatus(PermissionStatus status) {
  if (status.isGranted || status.isLimited) {
    return FriendMicrophonePermissionStatus.granted;
  }
  if (status.isPermanentlyDenied) {
    return FriendMicrophonePermissionStatus.permanentlyDenied;
  }
  if (status.isRestricted) {
    return FriendMicrophonePermissionStatus.restricted;
  }
  return FriendMicrophonePermissionStatus.denied;
}
