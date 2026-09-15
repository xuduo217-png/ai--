import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/rich_text_video_player.dart';
import 'package:pet_hospital_flutter/features/activity/domain/activity_models.dart';
import 'package:pet_hospital_flutter/features/activity/presentation/activity_controller.dart';
import 'package:pet_hospital_flutter/features/activity/presentation/pages/activity_detail_page.dart';
import 'package:pet_hospital_flutter/features/activity/presentation/pages/activity_list_page.dart';
import 'package:pet_hospital_flutter/features/activity/presentation/pages/activity_vote_option_detail_page.dart';
import 'package:pet_hospital_flutter/features/activity/presentation/pages/activity_vote_option_editor_page.dart';

void main() {
  testWidgets('活动列表支持筛选已结束活动', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeActivityGateway(activity: _onlineActivity());

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: ActivityListPage(
          gateway: gateway,
          authenticated: true,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('activity-status-UPCOMING')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-status-ONGOING')),
      findsOneWidget,
    );
    final expiredTab = find.byKey(const ValueKey('activity-status-EXPIRED'));
    expect(expiredTab, findsOneWidget);

    await tester.tap(expiredTab);
    await tester.pumpAndSettle();

    expect(gateway.lastListStatus, ActivityStatus.expired);
    expect(find.text('暂无活动'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('活动列表按 RN 结构进入线上投票详情并完成投票', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeActivityGateway(activity: _onlineActivity());

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityListPage(
          gateway: gateway,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('activity-list-header'));
    expect(header, findsOneWidget);
    expect(tester.getSize(header).height, 56);
    expect(
      find.descendant(of: header, matching: find.text('活动中心')),
      findsNothing,
    );
    for (final key in const ['activity-back', 'activity-search-toggle']) {
      final action = find.byKey(ValueKey(key));
      final material = tester.widget<Material>(
        find.descendant(of: action, matching: find.byType(Material)).first,
      );
      expect(material.shape, isA<CircleBorder>());
    }
    final tabs = tester.widget<Container>(
      find.byKey(const ValueKey('activity-status-tabs')),
    );
    final tabsDecoration = tabs.decoration! as BoxDecoration;
    expect(tabsDecoration.borderRadius, BorderRadius.circular(22));
    final selectedTab = find.byKey(const ValueKey('activity-status-ONGOING'));
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
    expect(
      find.descendant(of: header, matching: find.byType(Divider)),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('activity-search-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-search-bar')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-search-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-search-bar')), findsNothing);
    expect(find.text('线上萌宠选美'), findsOneWidget);
    expect(find.text('投票活动'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('activity-card-1')));
    await tester.pumpAndSettle();

    expect(find.text('活动详情'), findsWidgets);
    expect(find.text('选手列表'), findsOneWidget);
    final mainCard = find.byKey(const ValueKey('activity-main-card'));
    expect(mainCard, findsOneWidget);
    expect(
      find.descendant(
        of: mainCard,
        matching: find.byKey(const ValueKey('activity-share')),
      ),
      findsOneWidget,
    );
    expect(find.text('评论 0'), findsOneWidget);
    expect(find.text('友善交流'), findsOneWidget);
    final voteButton = find.byKey(const ValueKey('activity-vote-11'));
    final detailScroll = find.byKey(const ValueKey('activity-detail-scroll'));
    final scrollable = find
        .descendant(of: detailScroll, matching: find.byType(Scrollable))
        .first;
    final commentInput = find.byKey(
      const ValueKey('activity-comment-input-activity'),
    );
    final commentSend = find.byKey(
      const ValueKey('activity-comment-send-activity'),
    );
    await tester.scrollUntilVisible(commentInput, 180, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(commentSend).dy,
      tester.getTopLeft(commentInput).dy,
    );
    expect(
      tester.getBottomLeft(commentSend).dy,
      tester.getBottomLeft(commentInput).dy,
    );
    await tester.scrollUntilVisible(voteButton, 180, scrollable: scrollable);
    await tester.drag(detailScroll, const Offset(0, -90));
    await tester.pumpAndSettle();
    await tester.tap(voteButton);
    await tester.pumpAndSettle();

    expect(gateway.votedOptionId, 11);
    expect(find.text('1 票'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('线下活动报名校验手机号并刷新为已报名', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeActivityGateway(activity: _offlineActivity());

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailPage(
          gateway: gateway,
          activityId: 2,
          authenticated: true,
          initialPhone: '13800138000',
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detailList = tester.widget<ListView>(
      find.byKey(const ValueKey('activity-detail-scroll')),
    );
    expect((detailList.padding! as EdgeInsets).bottom, lessThan(20));

    await tester.tap(find.byKey(const ValueKey('activity-primary-action')));
    await tester.pumpAndSettle();
    expect(find.text('确认报名'), findsOneWidget);
    expect(find.text('请输入您的联系电话'), findsOneWidget);
    expect(find.text('13800138000'), findsOneWidget);

    final cancelCenter = tester.getCenter(
      find.byKey(const ValueKey('activity-register-cancel')),
    );
    final confirmCenter = tester.getCenter(
      find.byKey(const ValueKey('activity-register-confirm')),
    );
    expect(cancelCenter.dx, lessThan(confirmCenter.dx));
    expect((cancelCenter.dy - confirmCenter.dy).abs(), lessThan(1));

    await tester.tap(find.byKey(const ValueKey('activity-register-confirm')));
    await tester.pumpAndSettle();

    expect(gateway.registeredPhone, '13800138000');
    expect(find.text('已报名'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选手详情按 RN 结构展示并可从指标卡投票', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeActivityGateway(activity: _onlineActivity());

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: gateway,
          activityId: 1,
          optionId: 11,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('activity-option-detail-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-option-header-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-option-detail-comments')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-option-comments-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-option-comment-sticky')),
      findsOneWidget,
    );
    final commentSurface = tester.widget<Material>(
      find.byKey(const ValueKey('activity-option-comment-surface')),
    );
    expect(commentSurface.color, Colors.white);
    expect(find.text('布丁的夏天'), findsOneWidget);
    expect(find.text('宠爱医院'), findsOneWidget);
    expect(find.text('评论 0'), findsOneWidget);
    expect(find.text('友善交流'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('activity-option-detail-vote')));
    await tester.pumpAndSettle();

    expect(gateway.votedOptionId, 11);
    expect(find.text('今日已投'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('本人选手菜单支持二次确认删除', (tester) async {
    final gateway = _FakeActivityGateway(activity: _onlineActivity());

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: gateway,
          activityId: 1,
          optionId: 11,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除选手'), findsOneWidget);
    expect(find.textContaining('相关票数和评论也会一并删除'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(gateway.deletedOptionId, isNull);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(gateway.deletedOptionId, 11);
    expect(tester.takeException(), isNull);
  });

  testWidgets('非本人选手菜单不显示编辑和删除', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: _FakeActivityGateway(activity: _onlineActivity()),
          activityId: 1,
          optionId: 11,
          authenticated: true,
          currentUserId: 8,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsNothing);
    expect(find.text('删除'), findsNothing);
    expect(find.text('举报'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('游客和用户 ID 为空时菜单仅显示举报', (tester) async {
    var loginRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: _FakeActivityGateway(activity: _onlineActivity()),
          activityId: 1,
          optionId: 11,
          authenticated: false,
          requestLogin: (_) async {
            loginRequests += 1;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsNothing);
    expect(find.text('删除'), findsNothing);
    expect(find.text('举报'), findsOneWidget);

    await tester.tap(find.text('举报'));
    await tester.pumpAndSettle();
    expect(loginRequests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已登录但用户 ID 为空时菜单仅显示举报', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: _FakeActivityGateway(activity: _onlineActivity()),
          activityId: 1,
          optionId: 11,
          authenticated: true,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsNothing);
    expect(find.text('删除'), findsNothing);
    expect(find.text('举报'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('历史无归属作品不会因空用户 ID 显示编辑入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailPage(
          gateway: _FakeActivityGateway(
            activity: _onlineActivity(ownerUserId: null),
          ),
          activityId: 1,
          authenticated: true,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity-edit-option-11')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已结束活动菜单不展示编辑和删除', (tester) async {
    final activity = _onlineActivity(status: ActivityStatus.expired);
    final gateway = _FakeActivityGateway(activity: activity);

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: gateway,
          activityId: 1,
          optionId: 11,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsNothing);
    expect(find.text('删除'), findsNothing);
    expect(find.text('举报'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已结束活动编辑器拒绝提交', (tester) async {
    final activity = _onlineActivity(status: ActivityStatus.expired);
    final gateway = _FakeActivityGateway(activity: activity);
    final controller = ActivityDetailController(
      gateway: gateway,
      activityId: 1,
      authenticated: true,
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionEditorPage(
          controller: controller,
          initialOption: activity.voteOptions.single,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final submitButton = find.byKey(const ValueKey('activity-option-submit'));
    await tester.scrollUntilVisible(
      submitButton,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ActivityVoteOptionEditorPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('活动已结束，无法编辑'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选手详情视频使用可视区域自动播放组件', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: _FakeActivityGateway(
            activity: _onlineActivity(
              optionVideoUrl: 'https://example.test/contestant.mp4',
            ),
          ),
          activityId: 1,
          optionId: 11,
          authenticated: false,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('activity-option-detail-video')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<RichTextVideoPlayer>(
            find.byKey(const ValueKey('activity-option-detail-video-state')),
          )
          .autoPlayWhenVisible,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('选手详情评论框随软键盘自动上移', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: _FakeActivityGateway(activity: _onlineActivity()),
          activityId: 1,
          optionId: 11,
          authenticated: true,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byKey(
      const ValueKey('activity-option-comment-sticky'),
    );
    final initialBottom = tester.getBottomRight(composer).dy;

    await tester.tap(
      find.byKey(const ValueKey('activity-option-comment-input')),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final keyboardPadding = tester.widget<AnimatedPadding>(
      find.byKey(const ValueKey('activity-option-comment-keyboard-inset')),
    );
    expect(keyboardPadding.padding, const EdgeInsets.only(bottom: 300));
    expect(tester.getBottomRight(composer).dy, initialBottom - 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选手详情举报弹窗在短屏下可滚动且不溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeActivityGateway(activity: _onlineActivity());

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityVoteOptionDetailPage(
          gateway: gateway,
          activityId: 1,
          optionId: 11,
          authenticated: true,
          currentUserId: 7,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('举报'));
    await tester.pumpAndSettle();

    expect(find.text('选择举报原因'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-report-reason-list')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    (label: '320 窄屏', size: Size(320, 700), textScale: 1.0),
    (label: '390 大字体', size: Size(390, 844), textScale: 1.5),
    (label: '横屏', size: Size(844, 390), textScale: 1.0),
  ]) {
    testWidgets('选手详情在 ${viewport.label} 下无溢出', (tester) async {
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
          home: ActivityVoteOptionDetailPage(
            gateway: _FakeActivityGateway(activity: _onlineActivity()),
            activityId: 1,
            optionId: 11,
            authenticated: false,
            requestLogin: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('布丁的夏天'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-option-comment-sticky')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('未配置分享海报时按 RN 回退为大二维码', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailPage(
          gateway: _FakeActivityGateway(activity: _offlineActivity()),
          activityId: 2,
          authenticated: false,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity-share')));
    await tester.pumpAndSettle();

    expect(find.text('让朋友扫一扫二维码，直接进入这个活动详情页'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-share-poster-save-area')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('活动详情富文本图片忽略固定宽高并占满内容区域', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailPage(
          gateway: _FakeActivityGateway(
            activity: _onlineActivity(
              description: '''
                <p>活动图文详情</p>
                <img
                  src="https://example.test/detail.jpg"
                  width="120"
                  height="80"
                  style="width: 120px; height: 80px"
                />
                <div data-w-e-type="video" data-w-e-is-void>
                  <video poster="" controls="true">
                    <source
                      src="https://example.test/activity.mp4"
                      type="video/mp4"
                    />
                  </video>
                </div>
              ''',
            ),
          ),
          activityId: 1,
          authenticated: false,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final richContent = find.byKey(const ValueKey('activity-rich-content'));
    final richImage = find.byKey(const ValueKey('activity-rich-image-0'));
    final richVideo = find.byKey(const ValueKey('activity-rich-video-0'));
    await tester.scrollUntilVisible(
      richImage,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('activity-detail-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(tester.getSize(richImage).width, tester.getSize(richContent).width);
    expect(tester.getSize(richImage).width, greaterThan(340));
    expect(richVideo, findsOneWidget);
    expect(
      tester.widget<Semantics>(richVideo).properties.value,
      'https://example.test/activity.mp4',
    );
    expect(
      tester
          .widget<RichTextVideoPlayer>(
            find.byKey(const ValueKey('activity-rich-video-state-0')),
          )
          .autoPlayWhenVisible,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    (label: '320 窄屏', size: Size(320, 700), textScale: 1.0),
    (label: '390 大字体', size: Size(390, 844), textScale: 1.5),
    (label: '横屏', size: Size(844, 390), textScale: 1.0),
  ]) {
    testWidgets('活动详情和分享海报在 ${viewport.label} 下无溢出', (tester) async {
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
          home: ActivityDetailPage(
            gateway: _FakeActivityGateway(activity: _onlineActivity()),
            activityId: 1,
            authenticated: false,
            requestLogin: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('活动详情'), findsWidgets);
      expect(find.text('线上萌宠选美'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('activity-share')));
      await tester.pumpAndSettle();

      expect(find.text('分享活动'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-share-poster-save-area')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Android 分享海报支持点击预览和长按保存确认',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const posterChannel = MethodChannel(
        'com.good.pet.hospital/activity_share_poster',
      );
      String? invokedMethod;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(posterChannel, (call) async {
            invokedMethod = call.method;
            expect(call.arguments['bytes'], isA<Uint8List>());
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(posterChannel, null),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityDetailPage(
            gateway: _FakeActivityGateway(activity: _onlineActivity()),
            activityId: 1,
            authenticated: false,
            requestLogin: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('activity-share')));
      await tester.pumpAndSettle();

      final poster = find.byKey(
        const ValueKey('activity-share-poster-save-area'),
      );
      await tester.ensureVisible(poster);
      await tester.pumpAndSettle();
      tester.widget<GestureDetector>(poster).onTap!();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('activity-share-preview-close')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('activity-share-preview-close')),
      );
      await tester.pumpAndSettle();
      tester.widget<GestureDetector>(poster).onLongPress!();
      await tester.pumpAndSettle();
      expect(find.text('保存海报到相册'), findsOneWidget);
      expect(find.text('允许保存海报'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));

      final cancelCenter = tester.getCenter(
        find.byKey(const ValueKey('activity-share-save-cancel')),
      );
      final confirmCenter = tester.getCenter(
        find.byKey(const ValueKey('activity-share-save-confirm')),
      );
      expect(cancelCenter.dx, lessThan(confirmCenter.dx));
      expect((cancelCenter.dy - confirmCenter.dy).abs(), lessThan(1));

      await tester.tap(
        find.byKey(const ValueKey('activity-share-save-confirm')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(invokedMethod, 'savePng');
      expect(find.text('海报已保存到相册'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS 长按分享海报时跳过自绘权限弹窗并直接保存',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const posterChannel = MethodChannel(
        'com.good.pet.hospital/activity_share_poster',
      );
      String? invokedMethod;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(posterChannel, (call) async {
            invokedMethod = call.method;
            expect(call.arguments['bytes'], isA<Uint8List>());
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(posterChannel, null),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityDetailPage(
            gateway: _FakeActivityGateway(activity: _onlineActivity()),
            activityId: 1,
            authenticated: false,
            requestLogin: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('activity-share')));
      await tester.pumpAndSettle();

      final poster = find.byKey(
        const ValueKey('activity-share-poster-save-area'),
      );
      await tester.ensureVisible(poster);
      await tester.pumpAndSettle();
      tester.widget<GestureDetector>(poster).onLongPress!();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.text('保存海报到相册'), findsNothing);
      expect(invokedMethod, 'savePng');
      expect(find.text('海报已保存到相册'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _FakeActivityGateway implements ActivityGateway {
  _FakeActivityGateway({required ActivityItem activity}) : _activity = activity;

  ActivityItem _activity;
  int? votedOptionId;
  int? deletedOptionId;
  String? registeredPhone;
  ActivityStatus? lastListStatus;

  @override
  Future<ActivityPage> loadActivities({
    required bool authenticated,
    required ActivityStatus status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    lastListStatus = status;
    return ActivityPage(
      items: status == _activity.status ? [_activity] : const [],
      total: status == _activity.status ? 1 : 0,
      page: page,
      pageSize: pageSize,
      totalPages: status == _activity.status ? 1 : 0,
    );
  }

  @override
  Future<ActivityItem> loadActivityDetail(
    int activityId, {
    required bool authenticated,
  }) async => _activity;

  @override
  Future<ActivityCommentPage> loadActivityComments(
    int activityId, {
    required bool authenticated,
    int? voteOptionId,
    int page = 1,
    int pageSize = 20,
  }) async => ActivityCommentPage(
    items: const [],
    total: 0,
    page: page,
    pageSize: pageSize,
    totalPages: 0,
  );

  @override
  Future<ActivityActionResult<void>> voteActivity(
    int activityId, {
    required int optionId,
  }) async {
    votedOptionId = optionId;
    final updatedOptions = _activity.voteOptions
        .map(
          (option) => option.id == optionId
              ? ActivityVoteOption(
                  id: option.id,
                  activityId: option.activityId,
                  imageUrl: option.imageUrl,
                  videoUrl: option.videoUrl,
                  videoCoverUrl: option.videoCoverUrl,
                  title: option.title,
                  description: option.description,
                  voteCount: option.voteCount + 1,
                  sortOrder: option.sortOrder,
                  ownerUserId: option.ownerUserId,
                )
              : option,
        )
        .toList(growable: false);
    _activity = _copyActivity(
      _activity,
      voteOptions: updatedOptions,
      isRegistered: true,
    );
    return const ActivityActionResult(success: true, message: '投票成功');
  }

  @override
  Future<ActivityActionResult<void>> registerActivity(
    int activityId, {
    required String phone,
  }) async {
    registeredPhone = phone;
    _activity = _copyActivity(
      _activity,
      isRegistered: true,
      canRegister: false,
      registrationCount: _activity.registrationCount + 1,
    );
    return const ActivityActionResult(success: true, message: '报名成功');
  }

  @override
  Future<ActivityActionResult<void>> deleteActivityVoteOption(
    int activityId,
    int optionId,
  ) async {
    deletedOptionId = optionId;
    return const ActivityActionResult(success: true, message: '删除成功');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

ActivityItem _onlineActivity({
  String? description,
  String optionVideoUrl = '',
  int? ownerUserId = 7,
  ActivityStatus status = ActivityStatus.ongoing,
}) => ActivityItem(
  id: 1,
  title: '线上萌宠选美',
  startTime: DateTime(2026, 7, 20),
  endTime: DateTime(2026, 8, 20),
  location: '',
  summary: '上传萌宠照片，邀请朋友为它投票。',
  description: description ?? '<p>展示你的萌宠故事。</p>',
  coverImageUrl: '',
  sharePosterImageUrl: 'https://example.test/activity-poster.jpg',
  sharePosterTitle: '扫码参与',
  sharePosterDescription: '长按识别二维码查看活动详情',
  hospitalId: 1,
  hospitalName: '宠爱医院',
  registrationCount: 0,
  status: status,
  activityType: ActivityType.online,
  voteOptions: [
    ActivityVoteOption(
      id: 11,
      activityId: 1,
      imageUrl: '',
      videoUrl: optionVideoUrl,
      videoCoverUrl: '',
      title: '布丁的夏天',
      description: '爱晒太阳的小猫',
      voteCount: 0,
      sortOrder: 1,
      ownerUserId: ownerUserId,
    ),
  ],
  isRegistered: false,
  canRegister: true,
  createdAt: DateTime(2026, 7, 10),
  updatedAt: DateTime(2026, 7, 20),
);

ActivityItem _offlineActivity() => ActivityItem(
  id: 2,
  title: '周末宠物义诊',
  startTime: DateTime(2026, 7, 28),
  endTime: DateTime(2026, 7, 28),
  location: '城市公园东门',
  summary: '现场提供基础健康检查。',
  description: '<p>请为宠物佩戴牵引绳。</p>',
  coverImageUrl: '',
  sharePosterImageUrl: '',
  sharePosterTitle: '',
  sharePosterDescription: '',
  hospitalId: 1,
  hospitalName: '宠爱医院',
  registrationCount: 12,
  status: ActivityStatus.upcoming,
  activityType: ActivityType.offline,
  voteOptions: const [],
  isRegistered: false,
  canRegister: true,
  createdAt: DateTime(2026, 7, 10),
  updatedAt: DateTime(2026, 7, 20),
);

ActivityItem _copyActivity(
  ActivityItem source, {
  List<ActivityVoteOption>? voteOptions,
  bool? isRegistered,
  bool? canRegister,
  int? registrationCount,
}) => ActivityItem(
  id: source.id,
  title: source.title,
  startTime: source.startTime,
  endTime: source.endTime,
  location: source.location,
  summary: source.summary,
  description: source.description,
  coverImageUrl: source.coverImageUrl,
  sharePosterImageUrl: source.sharePosterImageUrl,
  sharePosterTitle: source.sharePosterTitle,
  sharePosterDescription: source.sharePosterDescription,
  hospitalId: source.hospitalId,
  hospitalName: source.hospitalName,
  registrationCount: registrationCount ?? source.registrationCount,
  status: source.status,
  activityType: source.activityType,
  voteOptions: voteOptions ?? source.voteOptions,
  isRegistered: isRegistered ?? source.isRegistered,
  canRegister: canRegister ?? source.canRegister,
  createdAt: source.createdAt,
  updatedAt: source.updatedAt,
  hospital: source.hospital,
);
