import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/core/media/gallery_media_picker.dart';
import 'package:pet_hospital_flutter/features/community/domain/community_models.dart';
import 'package:pet_hospital_flutter/features/community/presentation/community_design.dart';
import 'package:pet_hospital_flutter/features/community/presentation/pages/community_home_page.dart';
import 'package:pet_hospital_flutter/features/community/presentation/pages/community_profile_page.dart';
import 'package:pet_hospital_flutter/features/community/presentation/pages/post_detail_page.dart';
import 'package:pet_hospital_flutter/features/community/presentation/pages/publish_post_page.dart';
import 'package:pet_hospital_flutter/features/friends/data/friend_relations_repository.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_database.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_local_store.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_repository.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_socket_client.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_relation_models.dart';
import 'package:pet_hospital_flutter/features/friends/friends_feature_session.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_directory_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_messaging_controller.dart';
import 'package:pet_hospital_flutter/features/home/domain/home_models.dart';
import 'package:pet_hospital_flutter/features/home/presentation/home_page.dart';
import 'package:pet_hospital_flutter/features/mall/domain/mall_models.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/image_picker_gallery_media_gateway.dart';

void main() {
  testWidgets('Flutter 首页宠物社区入口进入推荐流并打开帖子详情', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _CommunityHomeGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage.guest(
          gateway: gateway,
          mallGateway: _FakeMallGateway(),
          initialTab: HomeTab.medical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const ValueKey('medical-home-feature-community'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('community-home')), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('今天带布丁去公园晒太阳'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('community-publish-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('community-post-7')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-post-detail-page')),
      findsOneWidget,
    );
    final detailHeader = tester.widget<Container>(
      find.byKey(const ValueKey('community-post-detail-header')),
    );
    expect(detailHeader.color, Colors.transparent);
    expect(detailHeader.constraints?.maxHeight, 58);
    expect(find.text('帖子详情'), findsOneWidget);
    expect(find.text('全部评论'), findsOneWidget);
    expect(find.text('好可爱，今天阳光也很好'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已登录社区从悬浮发布按钮进入完整发布页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _CommunityHomeGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHomePage(
          gateway: gateway,
          authenticated: true,
          currentUserId: 8,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-publish-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-publish-page')),
      findsOneWidget,
    );
    expect(find.text('分享你的养宠经验或生活片段'), findsOneWidget);
    expect(find.text('图片与视频'), findsOneWidget);
    expect(find.text('添加标签'), findsOneWidget);
    final hotTagChips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(hotTagChips, isNotEmpty);
    expect(hotTagChips.every((chip) => chip.showCheckmark == false), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('社区首页进入我的主页并可编辑、删除本人帖子', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _CommunityHomeGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHomePage(
          gateway: gateway,
          authenticated: true,
          currentUserId: 8,
          currentUserAvatarUrl: '/uploads/avatar.png',
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final profileEntry = find.byKey(
      const ValueKey('community-my-profile-button'),
    );
    expect(profileEntry, findsOneWidget);
    await tester.tap(profileEntry);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-profile-page')),
      findsOneWidget,
    );
    expect(find.text('我的主页'), findsOneWidget);
    expect(find.text('我的帖子'), findsOneWidget);
    final profileHero = find.byKey(const ValueKey('community-profile-hero'));
    final profileSummary = find.byKey(
      const ValueKey('community-profile-summary'),
    );
    final profileAvatar = find.byKey(
      const ValueKey('community-profile-avatar'),
    );
    final profileNickname = find.byKey(
      const ValueKey('community-profile-nickname'),
    );
    expect(
      find.descendant(of: profileHero, matching: profileAvatar),
      findsNothing,
    );
    expect(
      find.descendant(of: profileSummary, matching: profileAvatar),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(profileAvatar).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(profileHero).dy),
    );
    expect(
      tester.getBottomLeft(profileAvatar).dy,
      lessThan(tester.getTopLeft(profileNickname).dy),
    );
    final editProfileButton = find.byKey(
      const ValueKey('community-edit-profile'),
    );
    final publishButton = find.byKey(
      const ValueKey('community-profile-publish'),
    );
    expect(tester.getSize(editProfileButton), tester.getSize(publishButton));
    final editShape = tester
        .widget<OutlinedButton>(editProfileButton)
        .style
        ?.shape
        ?.resolve(<WidgetState>{});
    final publishShape = tester
        .widget<FilledButton>(publishButton)
        .style
        ?.shape
        ?.resolve(<WidgetState>{});
    expect(editShape, _profileActionShape);
    expect(publishShape, _profileActionShape);
    final coverFallback = find.byKey(
      const ValueKey('community-profile-cover-fallback'),
    );
    expect(coverFallback, findsOneWidget);
    expect(
      find.descendant(
        of: coverFallback,
        matching: find.byIcon(Icons.pets_rounded),
      ),
      findsNothing,
    );

    final manageButton = find.byKey(const ValueKey('community-manage-7'));
    await tester.ensureVisible(manageButton);
    await tester.pumpAndSettle();
    await tester.tap(manageButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-edit-post-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-edit-post-page')),
      findsOneWidget,
    );
    final contentField = find.byKey(
      const ValueKey('community-post-content-field'),
    );
    expect(
      tester.widget<TextField>(contentField).controller?.text,
      _post.content,
    );
    await tester.enterText(contentField, '更新后的布丁日常');
    await tester.tap(find.byKey(const ValueKey('community-submit-post')));
    await tester.pumpAndSettle();

    expect(gateway.updatedPostId, 7);
    expect(gateway.updatedDraft?.content, '更新后的布丁日常');

    final refreshedManageButton = find.byKey(
      const ValueKey('community-manage-7'),
    );
    await tester.ensureVisible(refreshedManageButton);
    await tester.pumpAndSettle();
    await tester.tap(refreshedManageButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('community-delete-post-action')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-delete-post-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('community-delete-post-confirm')),
    );
    await tester.pumpAndSettle();

    expect(gateway.deletedPostId, 7);
    expect(find.text('还没有发布帖子'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('社区个人主页黑名单可进入用户主页并解除拉黑', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _CommunityHomeGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          gateway: gateway,
          userId: 8,
          authenticated: true,
          currentUserId: 8,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('community-blacklist-entry')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-blacklist-page')),
      findsOneWidget,
    );
    expect(find.text('布丁妈妈'), findsOneWidget);
    expect(find.text('不想再看他的内容'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('community-block-9')));
    await tester.pumpAndSettle();
    expect(find.text('他的主页'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('community-remove-from-blacklist')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('community-follow-button')), findsNothing);
    expect(find.byKey(const ValueKey('community-friend-action')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('community-remove-from-blacklist')),
    );
    await tester.pumpAndSettle();
    expect(find.text('确定要将 布丁妈妈 移出黑名单吗？'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('community-remove-from-blacklist-confirm')),
    );
    await tester.pumpAndSettle();

    expect(gateway.unblockedUserId, 9);
    expect(
      find.byKey(const ValueKey('community-remove-from-blacklist')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('community-follow-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('community-friend-action')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('返回').first);
    await tester.pumpAndSettle();
    expect(find.text('黑名单为空'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('本人帖子详情菜单只显示编辑和删除操作', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailPage(
          gateway: _CommunityHomeGateway(),
          postId: 7,
          authenticated: true,
          currentUserId: 8,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-post-menu')));
    await tester.pumpAndSettle();

    expect(find.text('编辑帖子'), findsOneWidget);
    expect(find.text('删除帖子'), findsOneWidget);
    expect(find.text('举报帖子'), findsNothing);
    expect(find.text('拉黑作者'), findsNothing);
  });

  testWidgets('社区主页封面延伸到状态栏且头部操作位于安全区内', (tester) async {
    const statusBarHeight = 28.0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: statusBarHeight),
          ),
          child: CommunityProfilePage(
            gateway: _CommunityHomeGateway(),
            userId: 8,
            authenticated: true,
            currentUserId: 8,
            requestLogin: (_) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('community-profile-hero'));
    final cover = find.byKey(
      const ValueKey('community-profile-cover-fallback'),
    );
    expect(tester.getTopLeft(hero).dy, 0);
    expect(tester.getSize(hero).height, 242 + statusBarHeight);
    expect(tester.getTopLeft(cover).dy, 0);
    expect(
      find.byKey(const ValueKey('community-profile-cover-overlay')),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.byTooltip('返回').first).dy,
      greaterThanOrEqualTo(statusBarHeight),
    );

    final systemUi = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('community-profile-system-ui')),
    );
    expect(systemUi.value.statusBarColor, Colors.transparent);
    expect(systemUi.value.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('社区主页用户封面图片同样延伸到状态栏', (tester) async {
    const statusBarHeight = 28.0;
    const userWithCover = CommunityUser(
      id: 8,
      username: 'xiaogu',
      nickname: '小顾和布丁',
      avatarUrl: '',
      bio: '分享布丁的快乐生活',
      coverImageUrl: 'https://example.test/community-cover.jpg',
      verified: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: statusBarHeight),
          ),
          child: CommunityProfilePage(
            gateway: _CommunityHomeGateway(profileUser: userWithCover),
            userId: 8,
            authenticated: true,
            currentUserId: 8,
            requestLogin: (_) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final coverImage = find.byKey(
      const ValueKey('community-profile-cover-image'),
    );
    expect(tester.getTopLeft(coverImage).dy, 0);
    expect(
      find.byKey(const ValueKey('community-profile-cover-overlay')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byTooltip('返回').first).dy,
      greaterThanOrEqualTo(statusBarHeight),
    );
  });

  testWidgets('社区主页好友申请弹窗发送后安全退出', (tester) async {
    final repository = _CommunityFriendRelationsRepository();
    final socket = FriendsSocketClient(
      baseUrl: 'https://example.test',
      accessTokenProvider: () async => 'token',
    );
    final messagingController = _UnusedMessagingController(socket);
    final directoryController = FriendsDirectoryController(
      repository: repository,
      socket: socket,
    );
    final session = FriendsFeatureSession(
      ownerUserId: 1,
      messagingController: messagingController,
      directoryController: directoryController,
      socket: socket,
      repository: repository,
    );
    addTearDown(() {
      directoryController.dispose();
      messagingController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          gateway: _CommunityHomeGateway(
            profileRelationship: const CommunityRelationship.empty(),
          ),
          userId: 8,
          authenticated: true,
          currentUserId: 1,
          requestLogin: (_) async => false,
          friendsSession: session,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('community-friend-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(const ValueKey('community-friend-request-message-field')),
      '我们交个朋友吧',
    );
    await tester.tap(find.text('发送'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.lastReceiverId, 8);
    expect(repository.lastMessage, '我们交个朋友吧');
    expect(tester.takeException(), isNull);
  });

  testWidgets('社区头部无标题并将无下划线圆角 Tab 提至首行', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHomePage(
          gateway: _CommunityHomeGateway(),
          authenticated: true,
          currentUserId: 8,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('community-header'));
    expect(tester.widget<Container>(header).decoration, isNull);
    expect(tester.getSize(header).height, 56);
    final feedViewport = find.byKey(const ValueKey('community-feed-viewport'));
    expect(tester.getTopLeft(feedViewport).dy, tester.getBottomLeft(header).dy);
    expect(
      tester
          .widget<RefreshIndicator>(
            find.byKey(const ValueKey('community-feed-refresh')),
          )
          .edgeOffset,
      0,
    );
    expect(
      find.descendant(of: header, matching: find.text('宠物社区')),
      findsNothing,
    );
    expect(
      find.descendant(of: header, matching: find.byIcon(Icons.pets_rounded)),
      findsNothing,
    );

    final tabs = tester.widget<Container>(
      find.byKey(const ValueKey('community-feed-tabs')),
    );
    final tabsDecoration = tabs.decoration! as BoxDecoration;
    expect(tabsDecoration.borderRadius, BorderRadius.circular(22));

    final selectedTab = find.byKey(const ValueKey('community-tab-recommend'));
    final selectedDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: selectedTab,
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(selectedDecoration.color, const Color(0xFFE7EEFF));
    expect(selectedDecoration.borderRadius, BorderRadius.circular(20));
    expect(selectedDecoration.border, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('发布页自定义标签弹窗在窄屏下完成输入与添加', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.2)),
          child: child!,
        ),
        home: CommunityPublishPostPage(gateway: _CommunityHomeGateway()),
      ),
    );
    await tester.pumpAndSettle();

    final customTag = find.text('自定义');
    await tester.scrollUntilVisible(
      customTag,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(customTag);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-custom-tag-dialog')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.tag_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    final addButton = find.byKey(const ValueKey('community-custom-tag-add'));
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('community-custom-tag-field')),
      '周末遛狗',
    );
    await tester.pump();

    expect(find.text('4/20'), findsOneWidget);
    expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-custom-tag-dialog')),
      findsNothing,
    );
    expect(find.text('#周末遛狗'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final imagesFirst in const [true, false]) {
    testWidgets('发布页${imagesFirst ? '先选图片再选视频' : '先选视频再选图片'}时保留两类媒体', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = _CommunityHomeGateway();

      await tester.pumpWidget(
        MaterialApp(
          home: CommunityPublishPostPage(
            gateway: gateway,
            galleryMediaPicker: GalleryMediaPicker(
              gateway: ImagePickerGalleryMediaGateway(_CommunityMediaPicker()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('community-post-content-field')),
        '图片和视频一起记录宠物日常',
      );

      final addImages = find.byKey(const ValueKey('community-add-images'));
      final addVideo = find.byKey(const ValueKey('community-add-video'));
      final scrollable = find.byType(Scrollable).first;

      Future<void> selectMedia(Finder action) async {
        await tester.scrollUntilVisible(action, 260, scrollable: scrollable);
        await tester.tap(action);
        await tester.pumpAndSettle();
      }

      expect(addImages, findsOneWidget);
      expect(addVideo, findsOneWidget);
      await selectMedia(imagesFirst ? addImages : addVideo);

      expect(imagesFirst ? addVideo : addImages, findsOneWidget);
      await selectMedia(imagesFirst ? addVideo : addImages);

      expect(find.byTooltip('移除图片'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('community-preview-video')),
        findsOneWidget,
      );
      expect(find.text('1/9 张图片 · 1 个视频'), findsOneWidget);
      expect(addImages, findsOneWidget);
      expect(addVideo, findsNothing);

      await tester.tap(find.byKey(const ValueKey('community-submit-post')));
      await tester.pumpAndSettle();

      expect(gateway.createdDraft?.images, ['/uploads/community/image.jpg']);
      expect(gateway.createdDraft?.videoUrl, '/uploads/community/video.mp4');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('游客确认去登录后不会继续发起原点赞请求', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _CommunityHomeGateway();
    var loginRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailPage(
          gateway: gateway,
          postId: 7,
          authenticated: false,
          currentUserId: null,
          requestLogin: (_) async {
            loginRequests += 1;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-detail-like')));
    await tester.pump();

    expect(loginRequests, 1);
    expect(gateway.likeCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('帖子详情空评论区底部仅预留评论框所需空间', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(bottom: 34),
            viewPadding: const EdgeInsets.only(bottom: 34),
          ),
          child: child!,
        ),
        home: CommunityPostDetailPage(
          gateway: _EmptyCommentsGateway(),
          postId: 7,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = find.byKey(const ValueKey('community-post-detail-scroll'));
    final list = tester.widget<ListView>(scroll);
    expect(list.padding, const EdgeInsets.fromLTRB(16, 14, 16, 118));

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: scroll, matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    final emptyState = find.byKey(
      const ValueKey('community-comments-empty-state'),
    );
    final composer = find.byKey(const ValueKey('community-comment-composer'));
    final page = find.byKey(const ValueKey('community-post-detail-page'));
    final bottomClearance =
        tester.getBottomLeft(page).dy - tester.getBottomLeft(composer).dy;
    expect(bottomClearance, 42);
    final gap =
        tester.getTopLeft(composer).dy - tester.getBottomLeft(emptyState).dy;
    expect(gap, inInclusiveRange(0, 24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('帖子详情单图不限制固定高度并完整适配宽度', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final post = CommunityPost(
      id: _post.id,
      userId: _post.userId,
      author: _post.author,
      content: _post.content,
      images: const ['https://example.test/portrait.png'],
      videoUrl: _post.videoUrl,
      videoCoverUrl: _post.videoCoverUrl,
      tags: _post.tags,
      likeCount: _post.likeCount,
      commentCount: 0,
      viewCount: _post.viewCount,
      isPinned: _post.isPinned,
      isFeatured: _post.isFeatured,
      isLiked: _post.isLiked,
      status: _post.status,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailPage(
          gateway: _EmptyCommentsGateway(post: post),
          postId: post.id,
          authenticated: true,
          currentUserId: post.userId,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final imageTile = find.byKey(const ValueKey('community-post-image-0'));
    final image = find.descendant(
      of: imageTile,
      matching: find.byType(CommunityNetworkImage),
    );
    final imageBox = tester.widget<SizedBox>(
      find.ancestor(of: image, matching: find.byType(SizedBox)).first,
    );
    expect(tester.widget<CommunityNetworkImage>(image).fit, BoxFit.fitWidth);
    expect(imageBox.width, double.infinity);
    expect(imageBox.height, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('社区共享帖子卡片封面不使用预设比例裁切', (tester) async {
    final post = CommunityPost(
      id: 6,
      userId: _post.userId,
      author: _post.author,
      content: _post.content,
      images: const ['https://example.test/portrait.png'],
      videoUrl: '',
      videoCoverUrl: '',
      tags: _post.tags,
      likeCount: _post.likeCount,
      commentCount: _post.commentCount,
      viewCount: _post.viewCount,
      isPinned: false,
      isFeatured: false,
      isLiked: false,
      status: _post.status,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: CommunityPostCard(
              post: post,
              onPressed: () {},
              onOpenUser: () {},
              onLike: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cover = find.byKey(const ValueKey('community-post-card-cover-6'));
    final image = find.descendant(
      of: cover,
      matching: find.byType(CommunityNetworkImage),
    );
    expect(tester.widget<CommunityNetworkImage>(image).fit, BoxFit.contain);
    expect(tester.widget<AspectRatio>(cover).aspectRatio, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('帖子详情视频保留页面内播放器并可进入全屏', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailPage(
          gateway: _EmptyCommentsGateway(post: _videoPost),
          postId: 8,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('community-post-video')), findsOneWidget);
    final fullscreen = find.byKey(
      const ValueKey('community-post-video-fullscreen'),
    );
    expect(fullscreen, findsOneWidget);

    await tester.ensureVisible(fullscreen);
    await tester.tap(fullscreen);
    await tester.pumpAndSettle();

    expect(find.text('视频播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('帖子详情视频首屏自动播放、离屏暂停并在切换视频时停止上一个', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalPlatform = VideoPlayerPlatform.instance;
    final videoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await videoPlatform.close();
    });

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: CommunityPostDetailPage(
          gateway: _VideoCommentsGateway(post: _videoPost),
          postId: _videoPost.id,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final firstPlayIndex = videoPlatform.operations.indexOf('play:0');
    expect(firstPlayIndex, greaterThanOrEqualTo(0));

    final scroll = find.byKey(const ValueKey('community-post-detail-scroll'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: scroll, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(350));
    scrollable.position.jumpTo(350);
    await tester.pump();
    await tester.pump();

    final firstOffscreenPauseIndex = videoPlatform.operations.indexWhere(
      (operation) => operation == 'pause:0',
      firstPlayIndex + 1,
    );
    expect(firstOffscreenPauseIndex, greaterThan(firstPlayIndex));

    scrollable.position.jumpTo(0);
    await tester.pump();
    await tester.pump();
    final firstReplayIndex = videoPlatform.operations.indexWhere(
      (operation) => operation == 'play:0',
      firstOffscreenPauseIndex + 1,
    );
    expect(firstReplayIndex, greaterThan(firstOffscreenPauseIndex));

    unawaited(
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CommunityPostDetailPage(
            gateway: _EmptyCommentsGateway(post: _secondVideoPost),
            postId: _secondVideoPost.id,
            authenticated: true,
            currentUserId: 7,
            requestLogin: (_) async => false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    final switchPauseIndex = videoPlatform.operations.indexWhere(
      (operation) => operation == 'pause:0',
      firstReplayIndex + 1,
    );
    final secondPlayIndex = videoPlatform.operations.indexWhere(
      (operation) => operation == 'play:1',
      switchPauseIndex + 1,
    );
    expect(switchPauseIndex, greaterThan(firstReplayIndex));
    expect(secondPlayIndex, greaterThan(switchPauseIndex));
    expect(tester.takeException(), isNull);
  });

  testWidgets('帖子详情系统返回动画前先移除视频播放器', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalPlatform = VideoPlayerPlatform.instance;
    final videoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await videoPlatform.close();
    });

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    unawaited(
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CommunityPostDetailPage(
            gateway: _VideoCommentsGateway(post: _videoPost),
            postId: _videoPost.id,
            authenticated: true,
            currentUserId: 7,
            requestLogin: (_) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('community-post-video-detached')),
      findsOneWidget,
    );
    final playIndex = videoPlatform.operations.lastIndexOf('play:0');
    final pauseIndex = videoPlatform.operations.lastIndexOf('pause:0');
    expect(pauseIndex, greaterThan(playIndex));

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-post-detail-page')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('帖子详情使用统一样式拉黑确认框', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _CommunityHomeGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailPage(
          gateway: gateway,
          postId: 7,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拉黑作者'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-block-user-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('community-block-user-dialog-panel')),
      findsOneWidget,
    );
    expect(find.text('拉黑用户'), findsOneWidget);
    expect(find.text('拉黑 小顾和布丁 后，将减少看到对方内容。确定继续吗？'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确认拉黑'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final cancelSize = tester.getSize(
      find.byKey(const ValueKey('community-block-user-cancel')),
    );
    final confirmSize = tester.getSize(
      find.byKey(const ValueKey('community-block-user-confirm')),
    );
    expect(cancelSize.width, confirmSize.width);

    await tester.tap(find.text('确认拉黑'));
    await tester.pumpAndSettle();

    expect(gateway.blockedUserId, 8);
    expect(find.text('已拉黑 小顾和布丁'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页搜索进入社区话题搜索且不依赖好友搜索会话', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _CommunityHomeGateway();
    var loginRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHomePage(
          gateway: gateway,
          authenticated: true,
          currentUserId: 8,
          requestLogin: (_) async {
            loginRequests += 1;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchButton = find.byKey(const ValueKey('community-search-button'));
    expect(searchButton, findsOneWidget);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('community-search-page')), findsOneWidget);
    expect(find.text('搜索社区'), findsOneWidget);
    expect(find.text('热议话题'), findsOneWidget);
    expect(loginRequests, 0);

    await tester.enterText(
      find.byKey(const ValueKey('community-search-field')),
      '萌宠',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(gateway.searchedKeyword, '萌宠');
    await tester.tap(find.byKey(const ValueKey('community-search-tag-1')));
    await tester.pumpAndSettle();

    expect(gateway.loadedTag, '#萌宠');
    expect(find.text('#萌宠 内容'), findsOneWidget);
    expect(find.text('今天带布丁去公园晒太阳'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('游客点击社区搜索时先触发现有登录提示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var loginRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHomePage(
          gateway: _CommunityHomeGateway(),
          authenticated: false,
          currentUserId: null,
          requestLogin: (_) async {
            loginRequests += 1;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-search-button')));
    await tester.pump();

    expect(loginRequests, 1);
    expect(find.byKey(const ValueKey('community-search-page')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    (label: '320 窄屏', size: Size(320, 700), textScale: 1.0),
    (label: '390 大字体', size: Size(390, 844), textScale: 1.35),
    (label: '768 平板', size: Size(768, 1024), textScale: 1.0),
  ]) {
    testWidgets('社区瀑布流在 ${viewport.label} 下无溢出', (tester) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(viewport.textScale)),
            child: child!,
          ),
          home: CommunityHomePage(
            gateway: _CommunityHomeGateway(),
            authenticated: false,
            requestLogin: (_) async => false,
            currentUserId: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('关注'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);
      expect(find.text('今天带布丁去公园晒太阳'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _CommunityMediaPicker extends ImagePicker {
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => [XFile('/tmp/community-image.jpg')];

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async => XFile('/tmp/community-video.mp4');
}

class _CommunityHomeGateway implements HomeGateway, CommunityGateway {
  _CommunityHomeGateway({
    CommunityPost post = _post,
    CommunityUser profileUser = _user,
    CommunityRelationship profileRelationship = const CommunityRelationship(
      isSelf: true,
      isFollowing: false,
      isFollowedBy: false,
      isMutualFollow: false,
    ),
  }) : _fixturePost = post,
       _profileUser = profileUser,
       _profileRelationship = profileRelationship;

  final CommunityPost _fixturePost;
  final CommunityUser _profileUser;
  final CommunityRelationship _profileRelationship;
  int likeCalls = 0;
  int? blockedUserId;
  CommunityPostDraft? createdDraft;
  int? updatedPostId;
  CommunityPostDraft? updatedDraft;
  int? deletedPostId;
  int? unblockedUserId;
  bool communityBlockRemoved = false;
  String searchedKeyword = '';
  String loadedTag = '';

  @override
  Future<HomeSnapshot> loadHome({required bool authenticated}) async {
    return const HomeSnapshot();
  }

  @override
  Future<CommunityPage<CommunityPost>> loadCommunityPosts({
    required bool authenticated,
    required CommunityFeedType type,
    int page = 1,
    int pageSize = 10,
    String tag = '',
  }) async {
    loadedTag = tag;
    return CommunityPage(
      items: [_fixturePost],
      total: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    );
  }

  @override
  Future<CommunityPost> loadCommunityPost(
    int postId, {
    required bool authenticated,
  }) async => _fixturePost;

  @override
  Future<CommunityPost> createCommunityPost(CommunityPostDraft draft) async {
    createdDraft = draft;
    return _fixturePost;
  }

  @override
  Future<CommunityMediaUpload> uploadCommunityImage({
    required String filePath,
    String? filename,
    String category = 'community-post',
  }) async => const CommunityMediaUpload(url: '/uploads/community/image.jpg');

  @override
  Future<CommunityMediaUpload> uploadCommunityVideo({
    required String filePath,
    String? filename,
  }) async => const CommunityMediaUpload(
    url: '/uploads/community/video.mp4',
    thumbnailUrl: '/uploads/community/video-cover.jpg',
  );

  @override
  Future<CommunityProfile> loadCommunityProfile(
    int userId, {
    required bool authenticated,
  }) async {
    final isProfileOwner = userId == _profileUser.id;
    return CommunityProfile(
      user: isProfileOwner ? _profileUser : _comment.author,
      stats: CommunityProfileStats(
        postCount: deletedPostId == null ? 1 : 0,
        followerCount: 12,
        followingCount: 6,
      ),
      relationship: isProfileOwner
          ? _profileRelationship
          : const CommunityRelationship.empty(),
    );
  }

  @override
  Future<List<CommunityPost>> loadCommunityUserPosts(
    int userId, {
    required bool authenticated,
  }) async => deletedPostId == null ? [_fixturePost] : const [];

  @override
  Future<CommunityPost> updateCommunityPost(
    int postId,
    CommunityPostDraft draft,
  ) async {
    updatedPostId = postId;
    updatedDraft = draft;
    return _fixturePost;
  }

  @override
  Future<void> deleteCommunityPost(int postId) async {
    deletedPostId = postId;
  }

  @override
  Future<CommunityPage<CommunityComment>> loadCommunityComments(
    int postId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
  }) async {
    return CommunityPage(
      items: const [_comment],
      total: 1,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    );
  }

  @override
  Future<List<CommunityTag>> loadCommunityHotTags() async {
    return const [CommunityTag(id: 1, name: '#萌宠', usageCount: 16)];
  }

  @override
  Future<List<CommunityTag>> searchCommunityTags(String keyword) async {
    searchedKeyword = keyword;
    return const [CommunityTag(id: 1, name: '#萌宠', usageCount: 16)];
  }

  @override
  Future<void> likeCommunityPost(int postId) async {
    likeCalls += 1;
  }

  @override
  Future<void> blockCommunityUser(int userId, {String reason = ''}) async {
    blockedUserId = userId;
  }

  @override
  Future<List<CommunityBlockItem>> loadCommunityBlockedUsers() async {
    if (communityBlockRemoved) return const [];
    return [
      CommunityBlockItem(
        id: 20,
        blockedUserId: _comment.author.id,
        reason: '不想再看他的内容',
        blockedAt: DateTime(2026, 7, 28, 16),
        blockedUser: _comment.author,
      ),
    ];
  }

  @override
  Future<void> unblockCommunityUser(int userId) async {
    unblockedUserId = userId;
    communityBlockRemoved = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CommunityFriendRelationsRepository
    implements FriendRelationsRepositoryGateway {
  int? lastReceiverId;
  String? lastMessage;

  @override
  Future<FriendRelationshipSummary> loadRelationshipSummary({
    required int targetUserId,
  }) async {
    return const FriendRelationshipSummary(
      isFriend: false,
      outgoingPending: false,
      incomingPending: false,
    );
  }

  @override
  Future<SendFriendRequestResult> sendFriendRequest({
    required int receiverId,
    required String message,
  }) async {
    lastReceiverId = receiverId;
    lastMessage = message;
    return const SendFriendRequestResult(
      success: true,
      status: SendFriendRequestStatus.sent,
      message: '好友申请已发送',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedFriendsRepository implements FriendsRepositoryGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedMessagingController extends FriendsMessagingController {
  _UnusedMessagingController(FriendsSocketClient socket)
    : super(
        ownerUserId: 1,
        repository: _UnusedFriendsRepository(),
        localStore: FriendsLocalStore(
          FriendsDatabase.production(fileName: 'unused_community_test.db'),
        ),
        socket: socket,
        onSessionRevoked: () async {},
      );

  @override
  Future<void> stop({bool clearLocalData = false}) async {}

  @override
  Future<void> close({bool clearLocalData = false}) async {}
}

class _EmptyCommentsGateway extends _CommunityHomeGateway {
  _EmptyCommentsGateway({super.post});

  @override
  Future<CommunityPage<CommunityComment>> loadCommunityComments(
    int postId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const CommunityPage(
      items: [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    );
  }
}

class _VideoCommentsGateway extends _CommunityHomeGateway {
  _VideoCommentsGateway({required super.post});

  @override
  Future<CommunityPage<CommunityComment>> loadCommunityComments(
    int postId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 20,
  }) async {
    final comments = List<CommunityComment>.generate(
      8,
      (index) => CommunityComment(
        id: 100 + index,
        userId: _comment.userId,
        postId: postId,
        content: '测试视频滚动评论 $index',
        parentId: null,
        likeCount: 0,
        isLiked: false,
        author: _comment.author,
        replies: const [],
      ),
    );
    return CommunityPage(
      items: comments,
      total: comments.length,
      page: 1,
      pageSize: pageSize,
      totalPages: 1,
    );
  }
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> operations = [];
  final Map<int, StreamController<VideoEvent>> _streams = {};
  int _nextPlayerId = 0;

  @override
  Future<void> init() async {
    operations.add('init');
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    operations.add('create:$playerId');
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(160, 90),
        duration: const Duration(seconds: 30),
      ),
    );
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _streams[playerId]!.stream;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> play(int playerId) async {
    operations.add('play:$playerId');
  }

  @override
  Future<void> pause(int playerId) async {
    operations.add('pause:$playerId');
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    operations.add('looping:$playerId:$looping');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> dispose(int playerId) async {
    operations.add('dispose:$playerId');
    await _streams.remove(playerId)?.close();
  }

  Future<void> close() async {
    final streams = _streams.values.toList(growable: false);
    _streams.clear();
    for (final stream in streams) {
      await stream.close();
    }
  }
}

class _FakeMallGateway implements MallGateway {
  @override
  Future<MallSnapshot> loadMall({required bool authenticated}) async {
    return const MallSnapshot();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _user = CommunityUser(
  id: 8,
  username: 'xiaogu',
  nickname: '小顾和布丁',
  avatarUrl: '',
  bio: '分享布丁的快乐生活',
  coverImageUrl: '',
  verified: true,
);

const _profileActionShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

const _post = CommunityPost(
  id: 7,
  userId: 8,
  author: _user,
  content: '今天带布丁去公园晒太阳',
  images: [],
  videoUrl: '',
  videoCoverUrl: '',
  tags: ['#宠物日常'],
  likeCount: 18,
  commentCount: 1,
  viewCount: 120,
  isPinned: false,
  isFeatured: true,
  isLiked: false,
  status: 'PUBLISHED',
);

const _videoPost = CommunityPost(
  id: 8,
  userId: 8,
  author: _user,
  content: '布丁第一次参加宠物技能展示',
  images: [],
  videoUrl: 'https://example.test/pudding.mp4',
  videoCoverUrl: 'https://example.test/pudding-cover.jpg',
  tags: ['#宠物日常'],
  likeCount: 4,
  commentCount: 0,
  viewCount: 8,
  isPinned: false,
  isFeatured: false,
  isLiked: false,
  status: 'PUBLISHED',
);

const _secondVideoPost = CommunityPost(
  id: 9,
  userId: 8,
  author: _user,
  content: '布丁的第二段宠物技能展示',
  images: [],
  videoUrl: 'https://example.test/pudding-second.mp4',
  videoCoverUrl: 'https://example.test/pudding-second-cover.jpg',
  tags: ['#宠物日常'],
  likeCount: 2,
  commentCount: 0,
  viewCount: 5,
  isPinned: false,
  isFeatured: false,
  isLiked: false,
  status: 'PUBLISHED',
);

const _comment = CommunityComment(
  id: 3,
  userId: 9,
  postId: 7,
  content: '好可爱，今天阳光也很好',
  parentId: null,
  likeCount: 2,
  isLiked: false,
  author: CommunityUser(
    id: 9,
    username: 'pudding',
    nickname: '布丁妈妈',
    avatarUrl: '',
    bio: '',
    coverImageUrl: '',
    verified: false,
  ),
  replies: [],
);
