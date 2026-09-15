import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/core/media/gallery_media_picker.dart';
import 'package:pet_hospital_flutter/core/platform/external_uri_launcher.dart';
import 'package:pet_hospital_flutter/features/lost_found/domain/lost_found_models.dart';
import 'package:pet_hospital_flutter/features/lost_found/presentation/lost_found_controller.dart';
import 'package:pet_hospital_flutter/features/lost_found/presentation/pages/lost_found_editor_page.dart';

import 'support/image_picker_gallery_media_gateway.dart';
import 'package:pet_hospital_flutter/features/lost_found/presentation/pages/lost_found_detail_page.dart';
import 'package:pet_hospital_flutter/features/lost_found/presentation/pages/lost_found_list_page.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';

void main() {
  test('列表控制器切换类型并分页去重', () async {
    final gateway = _LostFoundGateway();
    final controller = LostFoundListController(
      gateway: gateway,
      authenticated: false,
    );

    await controller.load();
    expect(controller.records.map((item) => item.id), [1, 2]);
    expect(controller.hasMore, isTrue);

    await controller.loadMore();
    expect(controller.records.map((item) => item.id), [1, 2, 3]);
    expect(controller.hasMore, isFalse);

    await controller.selectType(LostFoundRecordType.adoption);
    expect(controller.recordType, LostFoundRecordType.adoption);
    expect(controller.records.single.recordType, LostFoundRecordType.adoption);
  });

  testWidgets('走失领养发布页使用项目 picker 选择宠物', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: LostFoundEditorPage(gateway: _LostFoundGateway())),
    );
    await tester.pumpAndSettle();

    final submitButton = find.byKey(const ValueKey('lost-found-submit'));
    expect(submitButton, findsOneWidget);
    expect(tester.getSize(submitButton).height, 52);
    expect(tester.getSize(submitButton).width, greaterThan(340));
    expect(find.widgetWithText(OutlinedButton, '取消'), findsNothing);

    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lost-found-pet-field')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsOneWidget);
    expect(find.text('选择宠物'), findsNWidgets(2));
    expect(find.text('确定'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('团子  ·  猫 - 英国短毛猫'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('lost-found-editor-scroll')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    final tips = find.byKey(const ValueKey('lost-found-editor-tips'));
    final contentToButtonGap =
        tester.getTopLeft(submitButton).dy - tester.getBottomLeft(tips).dy;
    expect(contentToButtonGap, inInclusiveRange(24, 32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('发布页图片多选遵守剩余额度并防止平台超量返回', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _LostFoundGateway();
    final picker = _LostFoundMediaPicker(
      imageSelections: [
        List.generate(7, (index) => XFile('/tmp/image-$index.jpg')),
        List.generate(3, (index) => XFile('/tmp/extra-image-$index.jpg')),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LostFoundEditorPage(
          gateway: gateway,
          galleryMediaPicker: GalleryMediaPicker(
            gateway: ImagePickerGalleryMediaGateway(picker),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addImages = find.byKey(const ValueKey('lost-found-add-images'));
    final editorScroll = find
        .descendant(
          of: find.byKey(const ValueKey('lost-found-editor-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(addImages, 300, scrollable: editorScroll);
    await tester.pumpAndSettle();
    await tester.tap(addImages);
    await tester.pumpAndSettle();

    expect(picker.imageLimits, [9]);
    expect(gateway.uploadedImagePaths, hasLength(7));
    expect(find.text('7/9'), findsOneWidget);

    await tester.ensureVisible(addImages);
    await tester.pumpAndSettle();
    await tester.tap(addImages);
    await tester.pumpAndSettle();

    expect(picker.imageLimits, [9, 2]);
    expect(gateway.uploadedImagePaths, hasLength(9));
    expect(find.text('9/9'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(addImages).onPressed, isNull);
    expect(find.text('最多只能上传9张图片，本次已添加前2张'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('发布页视频保持单选并支持替换', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _LostFoundGateway();
    final picker = _LostFoundMediaPicker(
      videoSelections: [
        XFile('/tmp/first-video.mp4'),
        XFile('/tmp/second-video.mp4'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LostFoundEditorPage(
          gateway: gateway,
          galleryMediaPicker: GalleryMediaPicker(
            gateway: ImagePickerGalleryMediaGateway(picker),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addVideo = find.byKey(const ValueKey('lost-found-add-video'));
    final editorScroll = find
        .descendant(
          of: find.byKey(const ValueKey('lost-found-editor-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(addVideo, 300, scrollable: editorScroll);
    await tester.pumpAndSettle();
    await tester.tap(addVideo);
    await tester.pumpAndSettle();

    expect(picker.videoSources, [ImageSource.gallery]);
    expect(picker.videoMaxDurations, [const Duration(minutes: 3)]);
    expect(gateway.uploadedVideoPaths, ['/tmp/first-video.mp4']);
    expect(find.text('更换视频'), findsOneWidget);
    expect(find.byTooltip('预览视频'), findsOneWidget);

    await tester.ensureVisible(addVideo);
    await tester.pumpAndSettle();
    await tester.tap(addVideo);
    await tester.pumpAndSettle();

    expect(gateway.uploadedVideoPaths, [
      '/tmp/first-video.mp4',
      '/tmp/second-video.mp4',
    ]);
    expect(find.byTooltip('预览视频'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('发布页支持手动填写非系统宠物并提交快照', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _LostFoundGateway();

    await tester.pumpWidget(
      MaterialApp(home: LostFoundEditorPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('lost-found-pet-source-manual')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lost-found-manual-pet-name')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('lost-found-pet-field')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('lost-found-manual-pet-name')),
      '小黑',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lost-found-manual-pet-category')),
      '狗',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lost-found-manual-pet-breed')),
      '中华田园犬',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lost-found-contact-name-field')),
      '小顾',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lost-found-contact-phone-field')),
      '13800138000',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('lost-found-description-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('lost-found-description-field')),
      '性格亲人，希望为它寻找认真负责的领养家庭。',
    );
    await tester.tap(find.byKey(const ValueKey('lost-found-submit')));
    await tester.pumpAndSettle();

    expect(gateway.createdDrafts, hasLength(1));
    expect(gateway.createdDrafts.single.petId, isNull);
    expect(gateway.createdDrafts.single.petName, '小黑');
    expect(gateway.createdDrafts.single.petCategory, '狗');
    expect(gateway.createdDrafts.single.petBreed, '中华田园犬');
    expect(tester.takeException(), isNull);
  });

  testWidgets('非系统宠物记录再次编辑时回填手动宠物信息', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _LostFoundGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: LostFoundEditorPage(
          gateway: gateway,
          initialRecord: _externalRecord(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑信息'), findsOneWidget);
    expect(find.byKey(const ValueKey('lost-found-pet-field')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('lost-found-manual-pet-name')),
          )
          .controller!
          .text,
      '小黑',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('lost-found-manual-pet-breed')),
          )
          .controller!
          .text,
      '中华田园犬',
    );

    await tester.tap(find.byKey(const ValueKey('lost-found-submit')));
    await tester.pumpAndSettle();

    expect(gateway.updatedDrafts, hasLength(1));
    expect(gateway.updatedDrafts.single.petId, isNull);
    expect(gateway.updatedDrafts.single.petName, '小黑');
    expect(gateway.updatedDrafts.single.petBreed, '中华田园犬');
    expect(tester.takeException(), isNull);
  });

  testWidgets('走失详情举报原因不显示对号且底部按钮样式一致', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LostFoundDetailPage(
          gateway: _LostFoundGateway(),
          initialRecord: _record(1, '团子', LostFoundRecordType.lost),
          authenticated: true,
          currentUserId: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('举报信息'));
    await tester.pumpAndSettle();

    final reasonChips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(reasonChips, isNotEmpty);
    expect(reasonChips.every((chip) => chip.showCheckmark == false), isTrue);

    final cancelButton = find.byKey(const ValueKey('lost-found-report-cancel'));
    final submitButton = find.byKey(const ValueKey('lost-found-report-submit'));
    expect(tester.getSize(cancelButton), tester.getSize(submitButton));
    expect(tester.getSize(cancelButton).height, 52);
    expect(tester.takeException(), isNull);
  });

  testWidgets('走失详情拨号不受 capability 假阴性影响', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final launcher = _LostFoundUriLauncher();

    await tester.pumpWidget(
      MaterialApp(
        home: LostFoundDetailPage(
          gateway: _LostFoundGateway(),
          initialRecord: _record(1, '团子', LostFoundRecordType.lost),
          authenticated: true,
          currentUserId: 10,
          uriLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final callButton = find.byKey(const ValueKey('lost-found-call'));
    await tester.drag(
      find.byKey(const ValueKey('lost-found-detail-scroll')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(callButton);
    await tester.pumpAndSettle();
    await tester.tap(callButton);
    await tester.pumpAndSettle();
    expect(find.text('拨打电话'), findsOneWidget);
    expect(launcher.launchUris, isEmpty);

    await tester.tap(find.text('拨打'));
    await tester.pumpAndSettle();
    expect(launcher.canLaunchUris, isEmpty);
    expect(launcher.launchUris.single.toString(), 'tel:13800138000');
  });

  testWidgets('走失详情回复时悬浮输入框自动聚焦并提交回复对象', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _LostFoundGateway(comments: [_comment(101)]);

    await tester.pumpWidget(
      MaterialApp(
        home: LostFoundDetailPage(
          gateway: gateway,
          initialRecord: _record(1, '团子', LostFoundRecordType.lost),
          authenticated: true,
          currentUserId: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lost-found-comment-composer')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('lost-found-detail-scroll')),
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();
    final replyButton = find.text('回复');
    await tester.ensureVisible(replyButton);
    await tester.tap(replyButton);
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('lost-found-comment-field')),
    );
    expect(field.focusNode!.hasFocus, isTrue);
    expect(find.text('回复 评论用户'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey('lost-found-comment-field')),
      '我也看到过它',
    );
    await tester.tap(find.byKey(const ValueKey('lost-found-comment-send')));
    await tester.pumpAndSettle();

    expect(gateway.createdCommentParentIds, [101]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('我的发布按用户和类型查询并支持直接编辑删除', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _LostFoundGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: LostFoundListPage(
          gateway: gateway,
          authenticated: true,
          currentUserId: 9,
          publisherId: 9,
          title: '我的发布',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.publisherIds, [9]);
    expect(gateway.recordTypes, [LostFoundRecordType.lost]);
    expect(find.byKey(const ValueKey('lost-found-edit-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lost-found-delete-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lost-found-tab-ADOPTION')));
    await tester.pumpAndSettle();
    expect(gateway.publisherIds.last, 9);
    expect(gateway.recordTypes.last, LostFoundRecordType.adoption);
    expect(find.byKey(const ValueKey('lost-found-edit-8')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lost-found-edit-8')));
    await tester.pumpAndSettle();
    expect(find.text('编辑信息'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lost-found-delete-8')));
    await tester.pumpAndSettle();
    expect(find.text('删除信息'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(gateway.deletedIds, [8]);
    expect(find.text('删除成功'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    (label: '320 窄屏', size: Size(320, 844), textScale: 1.0),
    (label: '390 常规屏', size: Size(390, 844), textScale: 1.0),
    (label: '390 大字体', size: Size(390, 844), textScale: 1.5),
    (label: '横屏', size: Size(844, 390), textScale: 1.0),
  ]) {
    testWidgets('走失领养列表在 ${viewport.label} 下保持 RN 双列布局', (tester) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var loginMessage = '';

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(viewport.textScale)),
            child: child!,
          ),
          home: LostFoundListPage(
            gateway: _LostFoundGateway(),
            authenticated: false,
            requestLogin: (message) async {
              loginMessage = message;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('lost-found-list')), findsOneWidget);
      expect(find.text('走失'), findsOneWidget);
      expect(find.text('领养'), findsOneWidget);
      expect(find.text('团子'), findsOneWidget);
      expect(find.text('豆包'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lost-found-publish-button')),
        findsOneWidget,
      );
      expect(find.text('发布'), findsOneWidget);

      final header = find.byKey(const ValueKey('lost-found-header'));
      final list = find.byKey(const ValueKey('lost-found-list'));
      expect(tester.getSize(header).height, 56);
      expect(tester.getTopLeft(list).dy, tester.getTopLeft(header).dy);
      expect(
        tester
            .widget<RefreshIndicator>(
              find.byKey(const ValueKey('lost-found-refresh')),
            )
            .edgeOffset,
        56,
      );
      expect(
        tester
            .widget<SizedBox>(
              find.byKey(const ValueKey('lost-found-scroll-header-spacer')),
            )
            .height,
        56,
      );
      expect(
        tester
            .widget<SizedBox>(
              find.byKey(
                const ValueKey('lost-found-scroll-bottom-spacer'),
                skipOffstage: false,
              ),
            )
            .height,
        28,
      );

      final tabs = tester.widget<Container>(
        find.byKey(const ValueKey('lost-found-tabs')),
      );
      final tabsDecoration = tabs.decoration! as BoxDecoration;
      expect(tabsDecoration.borderRadius, BorderRadius.circular(22));

      final selectedTab = find.byKey(const ValueKey('lost-found-tab-LOST'));
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

      await tester.tap(find.byTooltip('发布信息'));
      await tester.pump();
      expect(loginMessage, '登录后即可发布走失或领养信息');

      await tester.ensureVisible(find.text('团子'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('团子'));
      await tester.pumpAndSettle();
      expect(find.text('走失详情'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('联系方式'),
        180,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('lost-found-detail-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('联系方式'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lost-found-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _LostFoundMediaPicker extends ImagePicker {
  _LostFoundMediaPicker({
    this.imageSelections = const [],
    this.videoSelections = const [],
  });

  final List<List<XFile>> imageSelections;
  final List<XFile?> videoSelections;
  final List<int?> imageLimits = [];
  final List<ImageSource> videoSources = [];
  final List<Duration?> videoMaxDurations = [];
  int _imageSelectionIndex = 0;
  int _videoSelectionIndex = 0;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    imageLimits.add(limit);
    if (_imageSelectionIndex >= imageSelections.length) return [];
    return imageSelections[_imageSelectionIndex++];
  }

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    videoSources.add(source);
    videoMaxDurations.add(maxDuration);
    if (_videoSelectionIndex >= videoSelections.length) return null;
    return videoSelections[_videoSelectionIndex++];
  }
}

class _LostFoundUriLauncher implements ExternalUriLauncher {
  final List<Uri> canLaunchUris = [];
  final List<Uri> launchUris = [];

  @override
  Future<bool> canLaunch(Uri uri) async {
    canLaunchUris.add(uri);
    return false;
  }

  @override
  Future<bool> launch(Uri uri) async {
    launchUris.add(uri);
    return true;
  }
}

class _LostFoundGateway implements LostFoundGateway {
  _LostFoundGateway({List<LostFoundComment>? comments})
    : comments = List<LostFoundComment>.of(comments ?? const []);

  final List<int?> publisherIds = [];
  final List<LostFoundRecordType> recordTypes = [];
  final List<int> deletedIds = [];
  final List<LostFoundDraft> createdDrafts = [];
  final List<LostFoundDraft> updatedDrafts = [];
  final List<String> uploadedImagePaths = [];
  final List<String> uploadedVideoPaths = [];
  final List<LostFoundComment> comments;
  final List<int?> createdCommentParentIds = [];

  @override
  Future<LostFoundPage> loadLostFoundRecords({
    required bool authenticated,
    LostFoundRecordType? recordType,
    bool? isFound,
    int? publisherId,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    final type = recordType ?? LostFoundRecordType.lost;
    publisherIds.add(publisherId);
    recordTypes.add(type);
    if (type == LostFoundRecordType.adoption) {
      return LostFoundPage(
        items: [_record(8, '奶糖', type)],
        total: 1,
        page: 1,
        pageSize: pageSize,
        totalPages: 1,
      );
    }
    return LostFoundPage(
      items: page == 1
          ? [_record(1, '团子', type), _record(2, '豆包', type)]
          : [_record(2, '豆包', type), _record(3, '雪球', type)],
      total: 3,
      page: page,
      pageSize: 2,
      totalPages: 2,
    );
  }

  @override
  Future<LostFoundRecord> loadLostFoundRecord(
    int id, {
    required bool authenticated,
  }) async => _record(id, id == 1 ? '团子' : '豆包', LostFoundRecordType.lost);

  @override
  Future<void> deleteLostFoundRecord(int id) async {
    deletedIds.add(id);
  }

  @override
  Future<LostFoundRecord> createLostFoundRecord(LostFoundDraft draft) async {
    createdDrafts.add(draft);
    return _record(20, draft.petName, draft.recordType);
  }

  @override
  Future<LostFoundRecord> updateLostFoundRecord(
    int id,
    LostFoundDraft draft,
  ) async {
    updatedDrafts.add(draft);
    return _externalRecord();
  }

  @override
  Future<List<Pet>> loadLostFoundPets() async => [
    Pet.fromJson({
      'id': 1,
      'name': '团子',
      'avatar': '',
      'categoryId': 1,
      'subCategoryId': 11,
      'gender': 2,
      'birthDate': '2024-01-01',
      'weight': 4.8,
      'isNeutered': true,
      'vaccineCount': 2,
      'category': {'id': 1, 'name': '猫', 'parentId': null, 'sortOrder': 1},
      'subCategory': {'id': 11, 'name': '英国短毛猫', 'parentId': 1, 'sortOrder': 1},
      'ownerId': 9,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    }),
  ];

  @override
  Future<LostFoundMediaUpload> uploadLostFoundImage({
    required String filePath,
    String? filename,
  }) async {
    uploadedImagePaths.add(filePath);
    return LostFoundMediaUpload(
      url: '/uploads/lost-found/${filename ?? 'image.jpg'}',
    );
  }

  @override
  Future<LostFoundMediaUpload> uploadLostFoundVideo({
    required String filePath,
    String? filename,
  }) async {
    uploadedVideoPaths.add(filePath);
    return LostFoundMediaUpload(
      url: '/uploads/lost-found/${filename ?? 'video.mp4'}',
      thumbnailUrl: '/uploads/lost-found/video-cover.jpg',
    );
  }

  @override
  Future<LostFoundCommentPage> loadLostFoundComments(
    int lostFoundId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) async => LostFoundCommentPage(
    items: comments,
    total: comments.length,
    page: 1,
    pageSize: pageSize,
    totalPages: 1,
  );

  @override
  Future<LostFoundComment> createLostFoundComment(
    int lostFoundId, {
    required String content,
    int? parentId,
  }) async {
    createdCommentParentIds.add(parentId);
    return _comment(
      200 + createdCommentParentIds.length,
      content: content,
      parentId: parentId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName}');
  }
}

LostFoundRecord _record(int id, String name, LostFoundRecordType recordType) {
  return LostFoundRecord(
    id: id,
    petId: id,
    publisherId: 9,
    pet: LostFoundPet(
      id: id,
      name: name,
      avatarUrl: '',
      categoryName: '猫',
      subCategoryName: '英国短毛猫',
    ),
    publisher: const LostFoundUser(
      id: 9,
      username: 'publisher',
      nickname: '爱宠之家',
      avatarUrl: '',
    ),
    recordType: recordType,
    contactName: '小顾',
    contactPhone: '13800138000',
    description: recordType == LostFoundRecordType.lost
        ? '昨晚在公园东门附近走失，戴着蓝色项圈，请大家帮忙留意。'
        : '性格亲人，疫苗齐全，希望寻找认真负责的领养家庭。',
    images: const [],
    videoUrl: '',
    videoCoverUrl: '',
    isPinned: id == 1,
    isFound: false,
    foundAt: null,
    createdAt: DateTime(2026, 7, 25, 8),
    updatedAt: DateTime(2026, 7, 25, 9),
  );
}

LostFoundComment _comment(
  int id, {
  String content = '请问是在附近看到的吗？',
  int? parentId,
}) {
  return LostFoundComment(
    id: id,
    lostFoundId: 1,
    userId: 20,
    content: content,
    parentId: parentId,
    likeCount: 0,
    createdAt: DateTime(2026, 8, 14),
    user: const LostFoundUser(
      id: 20,
      username: 'commenter',
      nickname: '评论用户',
      avatarUrl: '',
    ),
    replies: const [],
  );
}

LostFoundRecord _externalRecord() {
  return LostFoundRecord(
    id: 20,
    petId: null,
    petName: '小黑',
    petCategory: '狗',
    petBreed: '中华田园犬',
    publisherId: 9,
    pet: null,
    publisher: const LostFoundUser(
      id: 9,
      username: 'publisher',
      nickname: '爱宠之家',
      avatarUrl: '',
    ),
    recordType: LostFoundRecordType.adoption,
    contactName: '小顾',
    contactPhone: '13800138000',
    description: '性格亲人，希望为它寻找认真负责的领养家庭。',
    images: const [],
    videoUrl: '',
    videoCoverUrl: '',
    isPinned: false,
    isFound: false,
    foundAt: null,
    createdAt: DateTime(2026, 7, 25, 8),
    updatedAt: DateTime(2026, 7, 25, 9),
  );
}
