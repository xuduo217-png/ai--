import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_voice_content.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_voice_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_voice_gateways.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/widgets/friend_message_bubble.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/widgets/friend_recording_overlay.dart';

void main() {
  testWidgets('语音气泡显示固定波形和时长并只响应自己的播放状态', (tester) async {
    final playback = ValueNotifier<FriendVoicePlaybackStatus>(
      FriendVoicePlaybackStatus.idle,
    );
    addTearDown(playback.dispose);
    var taps = 0;
    final message = _voiceMessage();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendMessageBubble(
            message: message,
            isMine: true,
            onRetry: () {},
            onVoiceTap: () => taps += 1,
            voicePlayback: playback,
          ),
        ),
      ),
    );

    expect(find.text('8"'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('friend-voice-${message.localKey}')));
    expect(taps, 1);

    playback.value = FriendVoicePlaybackStatus.playing;
    await tester.pump();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('录音浮层显示秒数并可取消', (tester) async {
    final recorder = _WidgetRecorder();
    final controller = FriendVoiceController(
      recorder: recorder,
      player: _WidgetPlayer(),
      permission: _WidgetPermission(),
      onSend: (_) async {},
    );
    addTearDown(() async {
      await controller.close();
      controller.dispose();
    });
    await controller.beginHold();
    recorder.emit(const Duration(seconds: 12));
    Future<void>? cancellation;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => FriendRecordingOverlay(
              controller: controller,
              onCancel: () => cancellation = controller.cancelHold(),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('friend-recording-overlay')),
      findsOneWidget,
    );
    expect(find.text('正在录音  12"'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-recording-cancel')));
    expect(cancellation, isNotNull);
    await cancellation;
    await tester.pump();
    expect(
      find.byKey(const ValueKey('friend-recording-overlay')),
      findsNothing,
    );
  });
}

FriendMessage _voiceMessage() {
  final now = DateTime.utc(2026, 7, 24, 8);
  return FriendMessage(
    messageId: 'voice-1',
    conversationId: '1_2',
    senderId: 1,
    receiverId: 2,
    messageType: 'voice',
    content: const FriendVoiceContent(
      url: '/uploads/voice.m4a',
      duration: 8,
    ).toMessageContent(),
    sendStatus: MessageSendStatus.sent,
    isRead: false,
    readSynced: true,
    createdAt: now,
    updatedAt: now,
    mediaStage: MediaTransferStage.sent,
  );
}

class _WidgetRecorder implements FriendVoiceRecorderGateway {
  final StreamController<Duration> controller =
      StreamController<Duration>.broadcast(sync: true);
  String? filePath;

  @override
  Stream<Duration> get durations => controller.stream;

  @override
  Future<String> start() async {
    filePath = '/tmp/friend_voice_widget.m4a';
    return filePath!;
  }

  @override
  Future<String?> stop() async => filePath;

  @override
  Future<void> cancel() async {
    filePath = null;
  }

  @override
  Future<void> deleteTemporaryFile(String? filePath) async {}

  void emit(Duration value) => controller.add(value);

  @override
  Future<void> dispose() => controller.close();
}

class _WidgetPlayer implements FriendVoicePlayerGateway {
  final StreamController<void> controller = StreamController<void>.broadcast();

  @override
  Stream<void> get completions => controller.stream;

  @override
  Future<void> playLocalFile(String filePath) async {}

  @override
  Future<void> playRemoteUrl(String url) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => controller.close();
}

class _WidgetPermission implements FriendMicrophonePermissionGateway {
  @override
  Future<FriendMicrophonePermissionStatus> check() async =>
      FriendMicrophonePermissionStatus.granted;

  @override
  Future<FriendMicrophonePermissionStatus> request() async =>
      FriendMicrophonePermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;
}
