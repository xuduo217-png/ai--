import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_media_content.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/pages/friend_image_viewer_page.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/pages/friend_video_player_page.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/widgets/friend_image_message.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/widgets/friend_video_message.dart';

void main() {
  testWidgets('图片消息可以打开并关闭全屏缩放页', (tester) async {
    final content = FriendMediaContent(
      url: 'data:image/png;base64,$_transparentPng',
      width: 1,
      height: 1,
    );
    final message = _message('image', content.toMessageContent());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FriendImageMessage(message: message)),
      ),
    );
    await tester.tap(find.byKey(ValueKey('friend-image-${message.localKey}')));
    await tester.pumpAndSettle();

    expect(find.byType(FriendImageViewerPage), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(FriendImageViewerPage), findsNothing);
  });

  testWidgets('无效图片资源在全屏页显示错误状态', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FriendImageViewerPage(
          content: FriendMediaContent(url: 'unsupported://image'),
        ),
      ),
    );

    expect(find.text('图片无法加载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('视频消息可以打开播放器并在无效地址时安全关闭', (tester) async {
    final message = _message(
      'video',
      const FriendMediaContent(
        url: 'unsupported://video',
        duration: 12,
      ).toMessageContent(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FriendVideoMessage(message: message)),
      ),
    );

    await tester.tap(find.byKey(ValueKey('friend-video-${message.localKey}')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FriendVideoPlayerPage), findsOneWidget);
    expect(find.text('视频无法播放'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(FriendVideoPlayerPage), findsNothing);
  });
}

FriendMessage _message(String type, String content) {
  final now = DateTime.utc(2026, 7, 24, 10);
  return FriendMessage(
    messageId: 'message-$type',
    conversationId: '1_2',
    senderId: 2,
    receiverId: 1,
    messageType: type,
    content: content,
    sendStatus: MessageSendStatus.sent,
    isRead: true,
    readSynced: true,
    createdAt: now,
    updatedAt: now,
    mediaStage: MediaTransferStage.sent,
  );
}

const _transparentPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
