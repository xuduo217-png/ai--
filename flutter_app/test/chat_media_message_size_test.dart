import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/chat/presentation/chat_widgets.dart';

void main() {
  testWidgets('医患消息分别使用当前账号和对方头像', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatMessageBubble(
                message: _textMessage(id: 1, senderId: 1),
                currentUserId: 1,
                currentUserAvatar: '/uploads/user-avatar.png',
                targetAvatar: '/uploads/doctor-avatar.png',
                paidSession: true,
                onPurchase: (_) {},
                onImageTap: (_) {},
                onVideoTap: (_) {},
              ),
              ChatMessageBubble(
                message: _textMessage(id: 2, senderId: 2),
                currentUserId: 1,
                currentUserAvatar: '/uploads/user-avatar.png',
                targetAvatar: '/uploads/doctor-avatar.png',
                paidSession: true,
                onPurchase: (_) {},
                onImageTap: (_) {},
                onVideoTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final imageUrls = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as NetworkImage).url)
        .toList();
    expect(
      imageUrls,
      containsAll([
        endsWith('/uploads/user-avatar.png'),
        endsWith('/uploads/doctor-avatar.png'),
      ]),
    );
  });

  testWidgets('医生咨询图片与视频按媒体原始比例使用相同最大边', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_message(ChatMessageType.image, 1080, 1920)));
    expect(find.text('2026-07-31 08:05'), findsOneWidget);
    final imageSize = tester.getSize(
      find.byKey(const ValueKey('chat-image-1')),
    );
    expect(imageSize.width, closeTo(109.6875, 0.001));
    expect(imageSize.height, 195);

    await tester.pumpWidget(_app(_message(ChatMessageType.video, 1920, 1080)));
    final videoSize = tester.getSize(
      find.byKey(const ValueKey('chat-video-1')),
    );
    expect(videoSize.width, 195);
    expect(videoSize.height, closeTo(109.6875, 0.001));
    expect(tester.takeException(), isNull);
  });
}

ChatMessage _textMessage({required int id, required int senderId}) {
  return ChatMessage(
    id: id,
    conversationId: 'consultation-1',
    senderId: senderId,
    receiverId: senderId == 1 ? 2 : 1,
    content: '消息$id',
    type: ChatMessageType.text,
    isAutoReply: false,
    isRead: true,
    createdAt: DateTime(2026, 8, 13, 10, id),
  );
}

Widget _app(ChatMessage message) {
  return MaterialApp(
    home: Scaffold(
      body: ChatMessageBubble(
        message: message,
        currentUserId: 1,
        targetAvatar: '',
        paidSession: true,
        onPurchase: (_) {},
        onImageTap: (_) {},
        onVideoTap: (_) {},
      ),
    ),
  );
}

ChatMessage _message(ChatMessageType type, int width, int height) {
  return ChatMessage(
    id: 1,
    conversationId: 'consultation-1',
    senderId: 1,
    receiverId: 2,
    content: ChatMediaContent(
      url: '/uploads/media',
      width: width,
      height: height,
    ).toMessageContent(),
    type: type,
    isAutoReply: false,
    isRead: false,
    createdAt: DateTime(2026, 7, 31, 8, 5),
  );
}
