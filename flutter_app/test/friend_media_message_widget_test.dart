import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_media_content.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/widgets/friend_message_bubble.dart';

void main() {
  late Directory directory;
  late File localImage;
  late File remoteThumbnail;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('friend-media-widget-');
    localImage = await File(
      '${directory.path}/local.png',
    ).writeAsBytes(base64Decode(_transparentPng));
    remoteThumbnail = await File(
      '${directory.path}/thumbnail.png',
    ).writeAsBytes(base64Decode(_transparentPng));
  });

  tearDown(() => directory.delete(recursive: true));

  testWidgets('图片消息优先展示本地文件并在窄屏保持约束', (tester) async {
    tester.view.physicalSize = const Size(240, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final message = _message(
      type: 'image',
      content: const FriendMediaContent(
        url: '/uploads/remote.png',
        width: 1200,
        height: 900,
      ).toMessageContent(),
      localFilePath: localImage.path,
      localFileExists: true,
    );

    await tester.pumpWidget(_app(message));
    await tester.pump();

    expect(
      find.byKey(ValueKey('friend-image-local-${message.localKey}')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(ValueKey('friend-image-${message.localKey}'))),
      const Size(120, 90),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('本地图片不存在时回退远程内容且非法内容稳定占位', (tester) async {
    final remoteMessage = _message(
      type: 'image',
      content: FriendMediaContent(
        url: 'data:image/png;base64,$_transparentPng',
        thumbnail: 'unsupported://thumbnail',
      ).toMessageContent(),
      localFilePath: '${directory.path}/missing.png',
      localFileExists: true,
    );

    await tester.pumpWidget(_app(remoteMessage));
    await tester.pump();

    expect(
      find.byKey(ValueKey('friend-image-remote-${remoteMessage.localKey}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_app(_message(type: 'image', content: '')));
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程图片优先展示原图并将缩略图作为失败兜底', (tester) async {
    final message = _message(
      type: 'image',
      content: FriendMediaContent(
        url: localImage.path,
        thumbnail: remoteThumbnail.path,
      ).toMessageContent(),
    );

    await tester.pumpWidget(_app(message));
    await tester.pump();

    final image = tester.widget<Image>(
      find.byKey(ValueKey('friend-image-remote-${message.localKey}')),
    );
    final resizedImage = image.image as ResizeImage;
    expect(
      (resizedImage.imageProvider as FileImage).file.path,
      localImage.path,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('视频消息展示本地缩略图、播放入口和格式化时长', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final message = _message(
      type: 'video',
      content: const FriendMediaContent(
        url: '/uploads/clip.mp4',
        thumbnail: '/uploads/clip-cover.jpg',
        width: 1080,
        height: 1920,
        duration: 65,
      ).toMessageContent(),
      localThumbnailPath: localImage.path,
    );

    await tester.pumpWidget(_app(message));
    await tester.pump();

    expect(find.text('01:05'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expect(
      find.byKey(ValueKey('friend-video-local-thumbnail-${message.localKey}')),
      findsOneWidget,
    );
    final size = tester.getSize(
      find.byKey(ValueKey('friend-video-${message.localKey}')),
    );
    expect(size.width, closeTo(109.6875, 0.001));
    expect(size.height, 195);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(FriendMessage message) {
  return MaterialApp(
    home: Scaffold(
      body: FriendMessageBubble(message: message, isMine: true, onRetry: () {}),
    ),
  );
}

FriendMessage _message({
  required String type,
  required String content,
  String? localFilePath,
  String? localThumbnailPath,
  bool localFileExists = false,
}) {
  final now = DateTime.utc(2026, 7, 24, 10);
  return FriendMessage(
    tempMessageId: 'temp-$type',
    conversationId: '1_2',
    senderId: 1,
    receiverId: 2,
    messageType: type,
    content: content,
    sendStatus: MessageSendStatus.sent,
    isRead: false,
    readSynced: true,
    createdAt: now,
    updatedAt: now,
    localFilePath: localFilePath,
    localThumbnailPath: localThumbnailPath,
    localFileExists: localFileExists,
    mediaStage: MediaTransferStage.sent,
  );
}

const _transparentPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
