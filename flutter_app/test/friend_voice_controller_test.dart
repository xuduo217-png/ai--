import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/network/asset_url_resolver.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_voice_content.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_voice_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_voice_gateways.dart';

void main() {
  late Directory directory;
  late _FakeRecorder recorder;
  late _FakePlayer player;
  late _FakePermission permission;
  late List<FriendVoiceSendRequest> sentRequests;
  late FriendVoiceController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('friend-voice-test-');
    recorder = _FakeRecorder(directory);
    player = _FakePlayer();
    permission = _FakePermission();
    sentRequests = [];
    controller = FriendVoiceController(
      recorder: recorder,
      player: player,
      permission: permission,
      onSend: (request) async => sentRequests.add(request),
    );
  });

  tearDown(() async {
    await controller.close();
    controller.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('首次拒绝先返回用途说明，授权后不自动补录', () async {
    permission.checkedStatus = FriendMicrophonePermissionStatus.denied;
    permission.requestedStatus = FriendMicrophonePermissionStatus.granted;

    expect(
      await controller.beginHold(),
      FriendVoiceStartOutcome.needsRationale,
    );
    expect(
      await controller.requestPermission(),
      FriendMicrophonePermissionStatus.granted,
    );

    expect(recorder.startCalls, 0);
    expect(controller.state, FriendVoiceControllerState.idle);
    expect(controller.takeNotice(), contains('再次按住'));
  });

  test('永久拒绝提供系统设置入口', () async {
    permission.checkedStatus =
        FriendMicrophonePermissionStatus.permanentlyDenied;

    expect(
      await controller.beginHold(),
      FriendVoiceStartOutcome.permanentlyDenied,
    );
    expect(await controller.openSettings(), isTrue);
    expect(permission.openSettingsCalls, 1);
  });

  test('不足 1 秒不发送并删除临时文件', () async {
    expect(await controller.beginHold(), FriendVoiceStartOutcome.started);
    final recordedPath = recorder.currentPath!;
    recorder.emitDuration(const Duration(milliseconds: 999));

    await controller.finishHold();

    expect(sentRequests, isEmpty);
    expect(await File(recordedPath).exists(), isFalse);
    expect(controller.takeNotice(), contains('不足 1 秒'));
  });

  test('达到 1 秒生成固定 M4A 请求并发送一次', () async {
    expect(await controller.beginHold(), FriendVoiceStartOutcome.started);
    recorder.emitDuration(const Duration(seconds: 1));

    await controller.finishHold();

    expect(sentRequests, hasLength(1));
    expect(sentRequests.single.duration, 1);
    expect(sentRequests.single.fileName, endsWith('.m4a'));
    expect(sentRequests.single.mimeType, friendVoiceMimeType);
    expect(sentRequests.single.size, greaterThan(0));
  });

  test('达到 60 秒自动结束且松手不会重复发送', () async {
    expect(await controller.beginHold(), FriendVoiceStartOutcome.started);

    recorder.emitDuration(const Duration(seconds: 60));
    await _waitFor(() => sentRequests.isNotEmpty);
    await controller.finishHold();

    expect(sentRequests, hasLength(1));
    expect(sentRequests.single.duration, 60);
    expect(recorder.stopCalls, 1);
  });

  test('取消录音和页面停止均清理文件并停止播放器', () async {
    expect(await controller.beginHold(), FriendVoiceStartOutcome.started);
    final recordedPath = recorder.currentPath!;
    final firstCancellation = controller.cancelHold();
    final duplicateCancellation = controller.cancelHold();
    await Future.wait([firstCancellation, duplicateCancellation]);

    expect(await File(recordedPath).exists(), isFalse);
    expect(recorder.cancelCalls, 1);

    await controller.togglePlayback(
      _voiceMessage('/uploads/a.m4a'),
      isMine: false,
    );
    await controller.stopAll();
    expect(player.stopCalls, greaterThan(0));
  });

  test('单播放器切换消息并将相对 URL 仅在加载前解析', () async {
    final first = _voiceMessage('/uploads/first.m4a', id: 'first');
    final second = _voiceMessage('https://cdn.test/second.m4a', id: 'second');
    final firstPlayback = controller.playbackFor(first.localKey);
    final secondPlayback = controller.playbackFor(second.localKey);

    await controller.togglePlayback(first, isMine: false);
    expect(player.remoteUrls, [resolveAssetUrl('/uploads/first.m4a')]);
    expect(firstPlayback.value, FriendVoicePlaybackStatus.playing);

    await controller.togglePlayback(second, isMine: false);
    expect(player.stopCalls, 1);
    expect(firstPlayback.value, FriendVoicePlaybackStatus.idle);
    expect(secondPlayback.value, FriendVoicePlaybackStatus.playing);
    expect(player.remoteUrls.last, 'https://cdn.test/second.m4a');

    player.complete();
    expect(secondPlayback.value, FriendVoicePlaybackStatus.idle);
  });

  test('自己发送优先本地文件，本地失败后回退远程地址', () async {
    final local = await File('${directory.path}/play.m4a').writeAsBytes([1]);
    final message = _voiceMessage(
      '/uploads/fallback.m4a',
      id: 'mine',
      senderId: 1,
      localFilePath: local.path,
    );
    player.failLocal = true;

    await controller.togglePlayback(message, isMine: true);

    expect(player.localPaths, [local.path]);
    expect(player.remoteUrls, [resolveAssetUrl('/uploads/fallback.m4a')]);
    expect(
      controller.playbackFor(message.localKey).value,
      FriendVoicePlaybackStatus.playing,
    );
  });

  test('录音前停止正在播放的语音', () async {
    await controller.togglePlayback(
      _voiceMessage('/uploads/playing.m4a'),
      isMine: false,
    );

    expect(await controller.beginHold(), FriendVoiceStartOutcome.started);

    expect(player.stopCalls, 1);
    expect(controller.state, FriendVoiceControllerState.recording);
  });
}

FriendMessage _voiceMessage(
  String url, {
  String id = 'voice',
  int senderId = 2,
  String? localFilePath,
}) {
  final now = DateTime.utc(2026, 7, 24, 8);
  return FriendMessage(
    messageId: id,
    conversationId: '1_2',
    senderId: senderId,
    receiverId: senderId == 1 ? 2 : 1,
    messageType: 'voice',
    content: FriendVoiceContent(url: url, duration: 8).toMessageContent(),
    sendStatus: MessageSendStatus.sent,
    isRead: false,
    readSynced: true,
    createdAt: now,
    updatedAt: now,
    localFilePath: localFilePath,
    localFileExists: localFilePath != null,
    mediaStage: MediaTransferStage.sent,
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Condition was not met before timeout.');
}

class _FakeRecorder implements FriendVoiceRecorderGateway {
  _FakeRecorder(this.directory);

  final Directory directory;
  final StreamController<Duration> durationController =
      StreamController<Duration>.broadcast(sync: true);
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  String? currentPath;

  @override
  Stream<Duration> get durations => durationController.stream;

  @override
  Future<String> start() async {
    startCalls += 1;
    currentPath = '${directory.path}/voice_$startCalls.m4a';
    await File(currentPath!).writeAsBytes([1, 2, 3]);
    return currentPath!;
  }

  @override
  Future<String?> stop() async {
    stopCalls += 1;
    final result = currentPath;
    currentPath = null;
    return result;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    final value = currentPath;
    currentPath = null;
    await deleteTemporaryFile(value);
  }

  @override
  Future<void> deleteTemporaryFile(String? filePath) async {
    if (filePath == null) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  void emitDuration(Duration duration) => durationController.add(duration);

  @override
  Future<void> dispose() => durationController.close();
}

class _FakePlayer implements FriendVoicePlayerGateway {
  final StreamController<void> completionController =
      StreamController<void>.broadcast(sync: true);
  final List<String> localPaths = [];
  final List<String> remoteUrls = [];
  int stopCalls = 0;
  bool failLocal = false;

  @override
  Stream<void> get completions => completionController.stream;

  @override
  Future<void> playLocalFile(String filePath) async {
    localPaths.add(filePath);
    if (failLocal) throw StateError('local playback failed');
  }

  @override
  Future<void> playRemoteUrl(String url) async => remoteUrls.add(url);

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  void complete() => completionController.add(null);

  @override
  Future<void> dispose() => completionController.close();
}

class _FakePermission implements FriendMicrophonePermissionGateway {
  FriendMicrophonePermissionStatus checkedStatus =
      FriendMicrophonePermissionStatus.granted;
  FriendMicrophonePermissionStatus requestedStatus =
      FriendMicrophonePermissionStatus.granted;
  int openSettingsCalls = 0;

  @override
  Future<FriendMicrophonePermissionStatus> check() async => checkedStatus;

  @override
  Future<FriendMicrophonePermissionStatus> request() async => requestedStatus;

  @override
  Future<bool> openSettings() async {
    openSettingsCalls += 1;
    return true;
  }
}
