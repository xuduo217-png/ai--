import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/camera_media_picker.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_database.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_local_store.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_repository.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_socket_client.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_media_content.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/conversation_list_view.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_chat_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_chat_page.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_media_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_voice_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_voice_gateways.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_messaging_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/pages/friend_chat_media_viewer_page.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/widgets/conversation_tile.dart';

void main() {
  late _WidgetMessagingController controller;

  setUp(() {
    controller = _WidgetMessagingController();
  });

  tearDown(() async {
    await controller.close();
    controller.dispose();
  });

  testWidgets('会话列表左滑展示按钮并在点击后本地隐藏', (tester) async {
    controller.seedConversation(
      FriendConversation(
        conversationId: '1_2',
        friendId: 2,
        friendName: '小明',
        lastMessage: '你好',
        lastMessageAt: _testTime,
        unreadCount: 1,
        hidden: false,
      ),
    );
    FriendshipSummary? openedFriend;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationListView(
            controller: controller,
            onOpenConversation: (friend) => openedFriend = friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('conversation-background')),
    );
    final gradient = (background.decoration as BoxDecoration).gradient!;
    expect((gradient as LinearGradient).colors, const [
      Color(0xFFDEE9FF),
      Color(0xFFFAFBFF),
    ]);
    expect(find.text('小明'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conversation-1_2')));
    expect(openedFriend?.friendId, 2);

    await tester.enterText(
      find.byKey(const ValueKey('conversation-search-field')),
      '不存在',
    );
    await _pumpUntil(tester, find.text('没有匹配的会话'));
    expect(find.text('没有匹配的会话'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('conversation-search-field')),
      '',
    );
    await _pumpUntil(tester, find.byKey(const ValueKey('conversation-1_2')));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.fling(
      find.byKey(const ValueKey('dismiss-1_2')),
      const Offset(-700, 0),
      1200,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('hide-conversation-1_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-1_2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hide-conversation-1_2')));
    await _pumpUntilGone(
      tester,
      find.byKey(const ValueKey('conversation-1_2')),
    );

    expect(find.byKey(const ValueKey('conversation-1_2')), findsNothing);
    expect(controller.messagesForConversation('1_2'), hasLength(1));
  });

  testWidgets('会话未读数超过 99 时显示 99+', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationTile(
            conversation: FriendConversation(
              conversationId: '1_2',
              friendId: 2,
              friendName: '小明',
              lastMessage: '你好',
              lastMessageAt: DateTime.utc(2026, 7, 24, 8),
              unreadCount: 100,
              hidden: false,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('私聊页本地优先、限制 500 字并完成乐观发送 ACK', (tester) async {
    controller.seedMessage(_incoming(messageId: 'local-message'));
    controller.pendingSend = Completer<FriendMessageAck>();

    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(
      find.descendant(of: find.byType(AppBar), matching: find.text('小明')),
    );
    expect(appBar.backgroundColor, const Color(0xFFDEE9FF));
    expect(appBar.surfaceTintColor, const Color(0xFFDEE9FF));
    expect(appBar.foregroundColor, AppColors.ink);
    expect(title.style?.color, AppColors.ink);
    expect(find.text('你好'), findsOneWidget);

    final input = find.byKey(const ValueKey('friend-chat-input'));
    await tester.enterText(input, List.filled(520, '字').join());
    expect(tester.widget<TextField>(input).controller!.text.length, 500);

    await tester.enterText(input, '新的消息');
    await tester.tap(find.byKey(const ValueKey('friend-chat-send')));
    await _pumpUntil(tester, find.text('新的消息'));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final tempId = controller.sentTempIds.single;
    controller.pendingSend!.complete(
      FriendMessageAck(
        tempMessageId: tempId,
        success: true,
        messageId: 'server-new',
      ),
    );
    await _pumpUntilGone(tester, find.byType(CircularProgressIndicator));

    final messages = controller.messagesForConversation('1_2');
    expect(messages.last.messageId, 'server-new');
    expect(messages.last.sendStatus, MessageSendStatus.sent);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('好友聊天图片和视频可以按消息顺序左右滑动预览', (tester) async {
    controller
      ..seedMessage(
        _mediaMessage(
          messageId: 'image-1',
          type: 'image',
          url: 'unsupported://image-1',
          at: _testTime,
        ),
      )
      ..seedMessage(
        _mediaMessage(
          messageId: 'video-1',
          type: 'video',
          url: 'unsupported://video-1',
          at: _testTime.add(const Duration(minutes: 1)),
        ),
      )
      ..seedMessage(
        _mediaMessage(
          messageId: 'image-2',
          type: 'image',
          url: 'unsupported://image-2',
          at: _testTime.add(const Duration(minutes: 2)),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('friend-image-image-1')));
    await tester.pumpAndSettle();

    expect(find.byType(FriendChatMediaViewerPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('friend-chat-media-position')),
      findsNothing,
    );
    final pageController = tester
        .widget<PageView>(
          find.byKey(const ValueKey('friend-chat-media-page-view')),
        )
        .controller!;
    expect(pageController.page, 0);

    await tester.fling(
      find.byKey(const ValueKey('friend-chat-media-page-view')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(pageController.page, 1);
    expect(find.text('视频无法播放'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('friend-chat-media-page-view')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(pageController.page, 2);

    await tester.fling(
      find.byKey(const ValueKey('friend-chat-media-page-view')),
      const Offset(400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(pageController.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新好友的短会话从消息区域顶部开始展示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    controller.seedMessage(_incoming(messageId: 'first-message'));

    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listTop = tester
        .getTopLeft(find.byKey(const ValueKey('friend-chat-message-list')))
        .dy;
    final messageTop = tester.getTopLeft(find.text('你好')).dy;
    expect(messageTop, lessThan(listTop + 80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('好友消息按 RN 布局显示左右头像和消息时间', (tester) async {
    final incomingTime = DateTime(2026, 7, 24, 8, 5);
    final outgoingTime = DateTime(2026, 7, 24, 8, 6);
    controller.seedMessage(
      _incoming(
        messageId: 'incoming-avatar',
        content: '好友消息',
        at: incomingTime,
      ),
    );
    controller.seedMessage(
      _outgoing(
        messageId: 'outgoing-avatar',
        content: '我的消息',
        at: outgoingTime,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final incomingAvatar = find.byKey(
      const ValueKey('friend-message-avatar-incoming-avatar'),
    );
    final outgoingAvatar = find.byKey(
      const ValueKey('friend-message-avatar-outgoing-avatar'),
    );
    expect(incomingAvatar, findsOneWidget);
    expect(outgoingAvatar, findsOneWidget);
    expect(
      tester.getCenter(incomingAvatar).dx,
      lessThan(tester.getCenter(find.text('好友消息')).dx),
    );
    expect(
      tester.getCenter(outgoingAvatar).dx,
      greaterThan(tester.getCenter(find.text('我的消息')).dx),
    );
    expect(find.text('2026-07-24 08:05'), findsOneWidget);
    expect(find.text('2026-07-24 08:06'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('2026-07-24 08:05')).dy,
      greaterThan(tester.getTopLeft(find.text('好友消息')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('长会话首次打开仍定位到最新消息', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var index = 0; index < 40; index += 1) {
      controller.seedMessage(
        _incoming(
          messageId: 'message-$index',
          content: '第 $index 条消息',
          at: _testTime.add(Duration(minutes: index)),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第 39 条消息'), findsOneWidget);
    expect(find.text('第 0 条消息'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('好友聊天在键盘出现和收发新消息后保持在最新位置', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    for (var index = 0; index < 32; index += 1) {
      controller.seedMessage(
        _incoming(
          messageId: 'scroll-message-$index',
          content: '好友历史消息 $index',
          at: _testTime.add(Duration(minutes: index)),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final messageList = tester.widget<ListView>(
      find.byKey(const ValueKey('friend-chat-message-list')),
    );
    final scrollController = messageList.controller!;
    expect(messageList.reverse, isTrue);
    expect(scrollController.offset, scrollController.position.minScrollExtent);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(scrollController.offset, scrollController.position.minScrollExtent);

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    controller.emitMessage(
      _incoming(
        messageId: 'new-friend-message',
        content: '刚收到的好友消息',
        at: _testTime.add(const Duration(hours: 1)),
      ),
    );
    await _pumpUntil(tester, find.text('刚收到的好友消息'));
    await tester.pumpAndSettle();
    expect(scrollController.offset, scrollController.position.minScrollExtent);

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.enterText(
      find.byKey(const ValueKey('friend-chat-input')),
      '刚发送的好友消息',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('friend-chat-send')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('friend-chat-input')))
          .controller!
          .text,
      isEmpty,
    );
    await _pumpUntil(tester, find.text('刚发送的好友消息'));
    await tester.pumpAndSettle();
    expect(scrollController.offset, scrollController.position.minScrollExtent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('发送失败显示重试按钮，点击后恢复为已发送', (tester) async {
    controller.failNextSend = true;
    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('friend-chat-input')),
      '需要重试',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('friend-chat-send')));
    await _pumpUntilCondition(tester, () {
      final messages = controller.messagesForConversation('1_2');
      return messages.isNotEmpty &&
          messages.single.sendStatus == MessageSendStatus.failed;
    });
    await _pumpUntil(tester, find.byTooltip('重试'));

    await tester.tap(find.byTooltip('重试'));
    await _pumpUntilGone(tester, find.byTooltip('重试'));

    final message = controller.messagesForConversation('1_2').single;
    expect(message.messageId, startsWith('server-'));
    expect(message.sendStatus, MessageSendStatus.sent);
    expect(find.byTooltip('重试'), findsNothing);
  });

  testWidgets('媒体面板与输入焦点互斥且不会遮挡输入区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('friend-chat-voice-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('friend-chat-media-toggle')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('friend-chat-media-panel')),
      findsOneWidget,
    );
    expect(find.text('图片/视频'), findsOneWidget);
    expect(find.text('相机'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-chat-input')));
    await tester.pump();
    expect(find.byKey(const ValueKey('friend-chat-media-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('好友聊天选择图片视频后直接按顺序发送', (tester) async {
    const drafts = [
      FriendMediaSendRequest(
        type: FriendMediaType.image,
        localFilePath: '/tmp/friend-0.jpg',
        fileName: 'friend-0.jpg',
        mimeType: 'image/jpeg',
        size: 1,
      ),
      FriendMediaSendRequest(
        type: FriendMediaType.video,
        localFilePath: '/tmp/friend-1.mp4',
        fileName: 'friend-1.mp4',
        mimeType: 'video/mp4',
        size: 1,
        duration: 12,
      ),
      FriendMediaSendRequest(
        type: FriendMediaType.image,
        localFilePath: '/tmp/friend-2.jpg',
        fileName: 'friend-2.jpg',
        mimeType: 'image/jpeg',
        size: 1,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatPage(
          controller: FriendChatController(
            messagingController: controller,
            friend: _friend,
            mediaController: _SelectedFriendMediaController(drafts),
          ),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      find.byKey(const ValueKey('friend-chat-media-toggle')),
    );

    await tester.tap(find.byKey(const ValueKey('friend-chat-media-toggle')));
    await tester.pump();
    await tester.tap(find.text('图片/视频'));
    await _pumpUntilCondition(
      tester,
      () => controller.sentMediaTypes.length == 3,
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.sentMediaTypes, [
      FriendMediaType.image,
      FriendMediaType.video,
      FriendMediaType.image,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android 好友聊天拍照和录音先显示权限说明', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      var cameraLaunchCalls = 0;
      CameraMediaPickerOptions? cameraOptions;
      final microphone = _FriendMicrophonePermission();
      await tester.pumpWidget(
        MaterialApp(
          home: FriendChatPage(
            controller: FriendChatController(
              messagingController: controller,
              friend: _friend,
              mediaController: FriendMediaController(
                picker: ImagePickerFriendMediaGateway(
                  cameraMediaPicker: CameraMediaPicker(
                    targetPlatform: TargetPlatform.android,
                    permissionStatusReader: (_) async =>
                        const CameraMediaPermissionState(
                          cameraGranted: false,
                          microphoneGranted: false,
                        ),
                    captureLauncher: (_, options) async {
                      cameraLaunchCalls += 1;
                      cameraOptions = options;
                      return null;
                    },
                  ),
                ),
              ),
              voiceController: FriendVoiceController(
                onSend: (_) async {},
                recorder: _FriendVoiceRecorder(),
                player: _FriendVoicePlayer(),
                permission: microphone,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('friend-chat-media-toggle')));
      await tester.pump();
      await tester.tap(find.text('相机'));
      await tester.pumpAndSettle();

      expect(find.text('需要相机和麦克风权限'), findsOneWidget);
      expect(cameraLaunchCalls, 0);
      await tester.tap(
        find.byKey(const ValueKey('camera-media-permission-confirm')),
      );
      await tester.pumpAndSettle();
      expect(cameraLaunchCalls, 1);
      expect(cameraOptions?.allowPhoto, isTrue);
      expect(cameraOptions?.allowVideo, isTrue);
      expect(cameraOptions?.needsMicrophonePermission, isTrue);

      tester
          .widget<Listener>(
            find.byKey(const ValueKey('friend-chat-voice-button')),
          )
          .onPointerDown!(const PointerDownEvent());
      await tester.pumpAndSettle();

      expect(find.text('需要麦克风权限'), findsOneWidget);
      expect(microphone.requestCalls, 0);
      await tester.tap(
        find.byKey(const ValueKey('friend-microphone-permission-confirm')),
      );
      await tester.pumpAndSettle();
      expect(microphone.requestCalls, 1);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS 好友聊天拍照和录音跳过自绘权限弹窗', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      var cameraLaunchCalls = 0;
      CameraMediaPickerOptions? cameraOptions;
      final microphone = _FriendMicrophonePermission();
      await tester.pumpWidget(
        MaterialApp(
          home: FriendChatPage(
            controller: FriendChatController(
              messagingController: controller,
              friend: _friend,
              mediaController: FriendMediaController(
                picker: ImagePickerFriendMediaGateway(
                  cameraMediaPicker: CameraMediaPicker(
                    targetPlatform: TargetPlatform.iOS,
                    permissionStatusReader: (_) async =>
                        throw StateError('iOS 不应预读相机权限'),
                    captureLauncher: (_, options) async {
                      cameraLaunchCalls += 1;
                      cameraOptions = options;
                      return null;
                    },
                  ),
                ),
              ),
              voiceController: FriendVoiceController(
                onSend: (_) async {},
                recorder: _FriendVoiceRecorder(),
                player: _FriendVoicePlayer(),
                permission: microphone,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('friend-chat-media-toggle')));
      await tester.pump();
      await tester.tap(find.text('相机'));
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsNothing);
      expect(find.text('需要相机和麦克风权限'), findsNothing);
      expect(cameraLaunchCalls, 1);
      expect(cameraOptions?.allowVideo, isTrue);
      expect(cameraOptions?.needsMicrophonePermission, isTrue);

      tester
          .widget<Listener>(
            find.byKey(const ValueKey('friend-chat-voice-button')),
          )
          .onPointerDown!(const PointerDownEvent());
      await tester.pumpAndSettle();

      expect(find.text('需要麦克风权限'), findsNothing);
      expect(microphone.requestCalls, 1);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('私聊控制器按每页 50 条加载更早历史', () async {
    controller.remoteTotalPages = 2;
    controller.remoteHistoryPages[1] = List.generate(
      50,
      (index) => _incoming(
        messageId: 'page-1-$index',
        at: _testTime.add(Duration(minutes: index)),
      ),
    );
    controller.remoteHistoryPages[2] = List.generate(
      2,
      (index) => _incoming(
        messageId: 'page-2-$index',
        at: _testTime.subtract(Duration(minutes: index + 1)),
      ),
    );
    final chatController = FriendChatController(
      messagingController: controller,
      friend: _friend,
    );
    addTearDown(chatController.dispose);

    await chatController.initialize();

    expect(controller.syncedPages, [1]);
    expect(chatController.messages, hasLength(50));
    expect(chatController.hasMore, isTrue);

    await chatController.loadOlder();

    expect(controller.syncedPages, [1, 2]);
    expect(chatController.messages, hasLength(52));
    expect(chatController.hasMore, isFalse);
  });
}

const _friend = FriendshipSummary(
  friendId: 2,
  friendName: '小明',
  lastChatAt: null,
);

final _testTime = DateTime.utc(2026, 7, 24, 8);

FriendMessage _incoming({
  required String messageId,
  DateTime? at,
  String content = '你好',
}) {
  final timestamp = at ?? DateTime.utc(2026, 7, 24, 8);
  return FriendMessage(
    messageId: messageId,
    conversationId: '1_2',
    senderId: 2,
    receiverId: 1,
    messageType: 'text',
    content: content,
    sendStatus: MessageSendStatus.sent,
    isRead: false,
    readSynced: true,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

FriendMessage _outgoing({
  required String messageId,
  required DateTime at,
  required String content,
}) {
  return FriendMessage(
    messageId: messageId,
    conversationId: '1_2',
    senderId: 1,
    receiverId: 2,
    messageType: 'text',
    content: content,
    sendStatus: MessageSendStatus.sent,
    isRead: true,
    readSynced: true,
    createdAt: at,
    updatedAt: at,
  );
}

FriendMessage _mediaMessage({
  required String messageId,
  required String type,
  required String url,
  required DateTime at,
}) {
  final mediaType = type == 'video'
      ? FriendMediaType.video
      : FriendMediaType.image;
  return FriendMessage(
    messageId: messageId,
    conversationId: '1_2',
    senderId: 2,
    receiverId: 1,
    messageType: type,
    content: FriendMediaContent(
      url: url,
      width: 1200,
      height: mediaType == FriendMediaType.video ? 675 : 900,
      duration: mediaType == FriendMediaType.video ? 12 : null,
    ).toMessageContent(),
    sendStatus: MessageSendStatus.sent,
    isRead: true,
    readSynced: true,
    createdAt: at,
    updatedAt: at,
    mediaStage: MediaTransferStage.sent,
  );
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 10));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Widget was not found before timeout.');
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 10));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Widget was still present after timeout.');
}

Future<void> _pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 10));
    if (condition()) return;
  }
  fail('Condition was not met before timeout.');
}

class _WidgetMessagingController extends FriendsMessagingController {
  _WidgetMessagingController()
    : super(
        ownerUserId: 1,
        repository: _WidgetRepository(),
        localStore: FriendsLocalStore(
          FriendsDatabase.production(fileName: 'unused_widget_test.db'),
        ),
        socket: _WidgetSocket(),
        onSessionRevoked: () async {},
      );

  final List<FriendConversation> _allConversations = [];
  final List<FriendMessage> _messages = [];
  String _query = '';
  int _sequence = 0;
  bool failNextSend = false;
  Completer<FriendMessageAck>? pendingSend;
  final List<String> sentTempIds = [];
  final List<FriendMediaType> sentMediaTypes = [];
  final Map<int, List<FriendMessage>> remoteHistoryPages = {};
  final List<int> syncedPages = [];
  int remoteTotalPages = 0;

  @override
  List<FriendConversation> get conversations {
    return _allConversations
        .where((conversation) => conversation.friendName.contains(_query))
        .toList(growable: false);
  }

  @override
  bool get loading => false;

  @override
  String? get errorMessage => null;

  @override
  String get search => _query;

  @override
  Future<void> start() async {}

  @override
  Future<void> refresh() async {}

  void seedConversation(FriendConversation conversation) {
    _allConversations.add(conversation);
    _messages.add(_incoming(messageId: 'seed-message'));
  }

  void seedMessage(FriendMessage message) {
    _messages.add(message);
  }

  void emitMessage(FriendMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  List<FriendMessage> messagesForConversation(String conversationId) {
    return _messages
        .where((message) => message.conversationId == conversationId)
        .toList(growable: false);
  }

  @override
  Future<void> updateSearch(String value) async {
    _query = value.trim();
    notifyListeners();
  }

  @override
  FriendshipSummary friendForConversation(FriendConversation conversation) {
    return FriendshipSummary(
      friendId: conversation.friendId,
      friendName: conversation.friendName,
      serverConversationId: conversation.conversationId,
    );
  }

  @override
  Future<void> hideConversation(FriendConversation conversation) async {
    _allConversations.removeWhere(
      (item) => item.conversationId == conversation.conversationId,
    );
    notifyListeners();
  }

  @override
  Future<List<FriendMessage>> loadMessages(
    String conversationId, {
    int limit = FriendsMessagingController.historyPageSize,
  }) async {
    final matching = messagesForConversation(conversationId);
    if (matching.length <= limit) return matching;
    return matching.sublist(matching.length - limit);
  }

  @override
  Future<int> messageCount(String conversationId) async {
    return messagesForConversation(conversationId).length;
  }

  @override
  Future<void> setActiveConversation(FriendshipSummary friend) async {}

  @override
  void clearActiveConversation(String conversationId) {}

  @override
  Future<FriendPage<FriendMessage>> syncConversation(
    FriendshipSummary friend, {
    required int page,
  }) async {
    syncedPages.add(page);
    final remoteMessages = remoteHistoryPages[page] ?? const [];
    for (final message in remoteMessages) {
      if (_messages.every((item) => item.messageId != message.messageId)) {
        _messages.add(message);
      }
    }
    _messages.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    notifyListeners();
    return FriendPage<FriendMessage>(
      items: remoteMessages,
      page: page,
      pageSize: FriendsMessagingController.historyPageSize,
      total: _messages.length,
      totalPages: remoteTotalPages,
    );
  }

  @override
  Future<String?> sendText(
    FriendshipSummary friend,
    String rawContent, {
    String? tempMessageId,
  }) async {
    final temporaryId = tempMessageId ?? 'temp-${++_sequence}';
    final now = DateTime.now().toUtc();
    final message = FriendMessage(
      tempMessageId: temporaryId,
      conversationId: friend.conversationIdFor(ownerUserId),
      senderId: ownerUserId,
      receiverId: friend.friendId,
      messageType: 'text',
      content: rawContent.trim(),
      sendStatus: MessageSendStatus.sending,
      isRead: false,
      readSynced: true,
      createdAt: now,
      updatedAt: now,
    );
    _messages.add(message);
    notifyListeners();
    await _finishSend(message);
    return temporaryId;
  }

  @override
  Future<String> sendMedia(
    FriendshipSummary friend,
    FriendMediaSendRequest request,
  ) async {
    sentMediaTypes.add(request.type);
    return 'media-${sentMediaTypes.length}';
  }

  @override
  Future<void> retryMessage(
    FriendshipSummary friend,
    FriendMessage message,
  ) async {
    _replaceMessage(
      message,
      message.copyWith(sendStatus: MessageSendStatus.sending),
    );
    notifyListeners();
    await _finishSend(message);
  }

  Future<void> _finishSend(FriendMessage message) async {
    final tempMessageId = message.tempMessageId!;
    sentTempIds.add(tempMessageId);
    try {
      if (failNextSend) {
        failNextSend = false;
        throw TimeoutException('发送超时');
      }
      final pending = pendingSend;
      final ack = pending != null && !pending.isCompleted
          ? await pending.future
          : FriendMessageAck(
              tempMessageId: tempMessageId,
              success: true,
              messageId: 'server-$tempMessageId',
            );
      _replaceMessage(
        message,
        message.copyWith(
          messageId: ack.messageId,
          sendStatus: MessageSendStatus.sent,
        ),
      );
    } on Object {
      _replaceMessage(
        message,
        message.copyWith(sendStatus: MessageSendStatus.failed),
      );
    }
    notifyListeners();
  }

  void _replaceMessage(FriendMessage original, FriendMessage replacement) {
    final index = _messages.indexWhere(
      (item) => item.tempMessageId == original.tempMessageId,
    );
    if (index >= 0) _messages[index] = replacement;
  }
}

class _SelectedFriendMediaController extends FriendMediaController {
  _SelectedFriendMediaController(this.drafts);

  final List<FriendMediaSendRequest> drafts;

  @override
  Future<List<FriendMediaSendRequest>> pickMedia({
    BuildContext? context,
  }) async => drafts;
}

class _FriendMicrophonePermission implements FriendMicrophonePermissionGateway {
  int requestCalls = 0;

  @override
  Future<FriendMicrophonePermissionStatus> check() async =>
      FriendMicrophonePermissionStatus.denied;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<FriendMicrophonePermissionStatus> request() async {
    requestCalls += 1;
    return FriendMicrophonePermissionStatus.granted;
  }
}

class _FriendVoiceRecorder implements FriendVoiceRecorderGateway {
  @override
  Stream<Duration> get durations => const Stream<Duration>.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> deleteTemporaryFile(String? filePath) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<String> start() async => '/tmp/friend-permission-test.m4a';

  @override
  Future<String?> stop() async => null;
}

class _FriendVoicePlayer implements FriendVoicePlayerGateway {
  @override
  Stream<void> get completions => const Stream<void>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playLocalFile(String filePath) async {}

  @override
  Future<void> playRemoteUrl(String url) async {}

  @override
  Future<void> stop() async {}
}

class _WidgetRepository implements FriendsRepositoryGateway {
  @override
  Future<FriendPage<FriendshipSummary>> loadFriends({
    required int page,
    required int pageSize,
  }) async {
    return const FriendPage<FriendshipSummary>(
      items: [],
      page: 1,
      pageSize: 50,
      total: 0,
      totalPages: 0,
    );
  }

  @override
  Future<FriendPage<FriendMessage>> loadMessageHistory({
    required int friendId,
    required int page,
    required int pageSize,
  }) async {
    return FriendPage<FriendMessage>(
      items: const [],
      page: page,
      pageSize: pageSize,
      total: 0,
      totalPages: 0,
    );
  }

  @override
  Future<int> loadUnreadCount() async => 0;

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {}
}

class _WidgetSocket implements FriendsSocketGateway {
  final messageController = StreamController<FriendMessage>.broadcast(
    sync: true,
  );
  final ackController = StreamController<FriendMessageAck>.broadcast(
    sync: true,
  );
  final readController = StreamController<FriendReadReceipt>.broadcast(
    sync: true,
  );
  final friendshipController =
      StreamController<FriendshipDeletedEvent>.broadcast(sync: true);
  final revokedController = StreamController<SessionRevokedEvent>.broadcast(
    sync: true,
  );
  final connectionController = StreamController<bool>.broadcast(sync: true);
  final errorController = StreamController<Object>.broadcast(sync: true);

  bool _connected = false;
  bool failNextSend = false;
  Completer<FriendMessageAck>? pendingSend;
  final List<String> sentTempIds = [];

  @override
  bool get isConnected => _connected;
  @override
  Stream<FriendMessage> get messages => messageController.stream;
  @override
  Stream<FriendMessageAck> get acknowledgements => ackController.stream;
  @override
  Stream<FriendReadReceipt> get readReceipts => readController.stream;
  @override
  Stream<FriendshipDeletedEvent> get friendshipDeleted =>
      friendshipController.stream;
  @override
  Stream<SessionRevokedEvent> get sessionRevoked => revokedController.stream;
  @override
  Stream<bool> get connectionChanges => connectionController.stream;
  @override
  Stream<Object> get errors => errorController.stream;

  @override
  Future<void> connect() async {
    _connected = true;
    connectionController.add(true);
  }

  @override
  Future<void> fetchOfflineMessages() async {}

  @override
  Future<void> acknowledgeOfflineMessages(List<String> messageIds) async {}

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {}

  @override
  Future<FriendMessageAck> sendTextMessage({
    required int receiverId,
    required String content,
    required String tempMessageId,
  }) => sendMessage(
    receiverId: receiverId,
    messageType: 'text',
    content: content,
    tempMessageId: tempMessageId,
  );

  @override
  Future<FriendMessageAck> sendMessage({
    required int receiverId,
    required String messageType,
    required String content,
    required String tempMessageId,
  }) async {
    sentTempIds.add(tempMessageId);
    if (failNextSend) {
      failNextSend = false;
      throw TimeoutException('发送超时');
    }
    final pending = pendingSend;
    if (pending != null && !pending.isCompleted) return pending.future;
    return FriendMessageAck(
      tempMessageId: tempMessageId,
      success: true,
      messageId: 'server-$tempMessageId',
    );
  }

  @override
  Future<void> stop() async => _connected = false;

  @override
  Future<void> dispose() async {
    await messageController.close();
    await ackController.close();
    await readController.close();
    await friendshipController.close();
    await revokedController.close();
    await connectionController.close();
    await errorController.close();
  }
}
