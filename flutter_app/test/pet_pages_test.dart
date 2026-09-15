import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/camera_media_picker.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';
import 'package:pet_hospital_flutter/features/pets/presentation/pages/pet_edit_page.dart';
import 'package:pet_hospital_flutter/features/pets/presentation/pages/pet_list_page.dart';
import 'package:pet_hospital_flutter/features/pets/presentation/pet_edit_controller.dart';

import 'support/wp11_viewports.dart';

void main() {
  for (final viewport in wp11Viewports) {
    testWidgets('宠物列表在 ${viewport.label} 稳定展示 RN 核心字段', (tester) async {
      configureWp11Viewport(tester, viewport);
      final gateway = _PetGateway(
        pets: [_pet(1, name: '一只名字特别长但仍然不能挤压操作按钮的小动物')],
      );

      await tester.pumpWidget(_listApp(gateway, textScale: viewport.textScale));
      await tester.pumpAndSettle();

      expect(find.text('我的宠物'), findsOneWidget);
      expect(find.textContaining('一只名字特别长'), findsOneWidget);
      expect(find.textContaining('犬 - 金毛'), findsOneWidget);
      expect(find.textContaining('弟弟'), findsOneWidget);
      expect(find.text('已接种 2 针疫苗'), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-add')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('宠物编辑在 ${viewport.label} 不发生溢出或底栏遮挡', (tester) async {
      configureWp11Viewport(tester, viewport);
      final gateway = _PetGateway(pets: [_pet(1)]);

      await tester.pumpWidget(
        MaterialApp(
          builder: wp11TextScaleBuilder(viewport.textScale),
          home: PetEditPage(gateway: gateway, petId: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('编辑宠物'), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-edit-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-edit-save')), findsOneWidget);
      final vaccineField = find.byKey(const ValueKey('pet-edit-vaccine-count'));
      await tester.ensureVisible(vaccineField);
      await tester.pumpAndSettle();
      expect(vaccineField, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('空态、失败重试和走失跨域入口均有明确反馈', (tester) async {
    final gateway = _PetGateway()..listError = StateError('offline');
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('宠物列表加载失败'), findsOneWidget);
    gateway.listError = null;
    await tester.tap(find.byKey(const ValueKey('pet-list-retry')));
    await tester.pumpAndSettle();
    expect(find.text('暂无宠物'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pet-lost-found')));
    await tester.pump();
    expect(find.text('走失寻宠功能尚未迁移，请在原应用中使用'), findsOneWidget);
  });

  testWidgets('新增和编辑返回后刷新可见', (tester) async {
    final gateway = _PetGateway(pets: [_pet(1)]);
    await tester.pumpWidget(
      _listApp(
        gateway,
        editPageBuilder: (context, petId) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('fake-editor-complete'),
              onPressed: () {
                if (petId == null) {
                  gateway.pets.add(_pet(2, name: '新建可见'));
                  Navigator.of(context).pop(PetEditorResult.created);
                } else {
                  gateway.pets[0] = _pet(1, name: '编辑已更新');
                  Navigator.of(context).pop(PetEditorResult.updated);
                }
              },
              child: const Text('完成'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pet-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake-editor-complete')));
    await tester.pumpAndSettle();
    expect(find.text('新建可见'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pet-card-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake-editor-complete')));
    await tester.pumpAndSettle();
    expect(find.text('编辑已更新'), findsOneWidget);
  });

  testWidgets('编辑页固定底栏保留 RN 删除链路', (tester) async {
    final gateway = _PetGateway(pets: [_pet(1)]);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('open-pet-editor'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PetEditPage(gateway: gateway, petId: 1),
                  ),
                ),
                child: const Text('打开编辑页'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-pet-editor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pet-edit-delete')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pet-edit-delete')));
    await tester.pumpAndSettle();
    expect(find.text('删除宠物档案'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(gateway.deleteCalls, 1);
    expect(find.byKey(const ValueKey('open-pet-editor')), findsOneWidget);
  });

  testWidgets('文本输入框自身填满白色控件且不再使用内外双层结构', (tester) async {
    final gateway = _PetGateway();
    await tester.pumpWidget(MaterialApp(home: PetEditPage(gateway: gateway)));
    await tester.pumpAndSettle();

    final nameControl = find.byKey(const ValueKey('pet-edit-name'));
    final nameField = find.descendant(
      of: nameControl,
      matching: find.byType(TextField),
    );
    final textField = tester.widget<TextField>(nameField);

    expect(textField.expands, isTrue);
    expect(textField.decoration?.filled, isTrue);
    expect(textField.decoration?.fillColor, Colors.white);
    expect(textField.decoration?.border, isA<OutlineInputBorder>());
    expect(
      tester.getSize(nameField).height,
      tester.getSize(nameControl).height,
    );

    final weightField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('pet-edit-weight')),
        matching: find.byType(TextField),
      ),
    );
    expect(weightField.decoration?.suffixIcon, isNotNull);
  });

  testWidgets('品种、出生日期和头像来源使用底部弹层', (tester) async {
    final gateway = _PetGateway();
    var cameraLaunchCalls = 0;
    CameraMediaPickerOptions? cameraOptions;
    await tester.pumpWidget(
      MaterialApp(
        home: PetEditPage(
          gateway: gateway,
          imagePicker: MediaPetImagePicker(
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
          fileExists: (_) => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final categoryControl = find.byKey(const ValueKey('pet-edit-category'));
    await tester.ensureVisible(categoryControl);
    await tester.pumpAndSettle();
    await tester.tap(categoryControl);
    await tester.pumpAndSettle();
    expect(find.text('选择品种'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    expect(find.text('犬'), findsOneWidget);
    expect(find.text('金毛'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('犬 > 金毛'), findsOneWidget);

    final birthDateControl = find.byKey(const ValueKey('pet-edit-birth-date'));
    await tester.ensureVisible(birthDateControl);
    await tester.pumpAndSettle();
    await tester.tap(birthDateControl);
    await tester.pumpAndSettle();
    expect(find.text('选择出生日期'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final expectedBirthDate = DateTime(
      yesterday.year - 1,
      yesterday.month,
      yesterday.day,
    );
    await tester.tap(birthDateControl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text(formatPetDate(expectedBirthDate)), findsOneWidget);

    final avatarControl = find.byKey(const ValueKey('pet-edit-avatar'));
    await tester.ensureVisible(avatarControl);
    await tester.pumpAndSettle();
    await tester.tap(avatarControl);
    await tester.pumpAndSettle();
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.tap(find.byKey(const ValueKey('pet-image-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('需要相机权限'), findsOneWidget);
      expect(cameraLaunchCalls, 0);
      await tester.tap(
        find.byKey(const ValueKey('camera-media-permission-confirm')),
      );
      await tester.pumpAndSettle();
      expect(cameraLaunchCalls, 1);
      expect(cameraOptions?.allowPhoto, isTrue);
      expect(cameraOptions?.allowVideo, isFalse);
      expect(cameraOptions?.needsMicrophonePermission, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS 宠物头像拍照不显示自绘权限弹窗', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      var cameraLaunchCalls = 0;
      CameraMediaPickerOptions? cameraOptions;
      await tester.pumpWidget(
        MaterialApp(
          home: PetEditPage(
            gateway: _PetGateway(),
            imagePicker: MediaPetImagePicker(
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
            fileExists: (_) => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final avatarControl = find.byKey(const ValueKey('pet-edit-avatar'));
      await tester.ensureVisible(avatarControl);
      await tester.tap(avatarControl);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pet-image-camera')));
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsNothing);
      expect(cameraLaunchCalls, 1);
      expect(cameraOptions?.allowVideo, isFalse);
      expect(cameraOptions?.needsMicrophonePermission, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('编辑页在窄屏和键盘弹出时仍可滚动到保存按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _PetGateway(pets: [_pet(1)]);

    await tester.pumpWidget(
      MaterialApp(home: PetEditPage(gateway: gateway, petId: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑宠物'), findsOneWidget);
    expect(find.byKey(const ValueKey('pet-edit-name')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pet-edit-name')));
    await tester.showKeyboard(find.byKey(const ValueKey('pet-edit-name')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('pet-edit-scroll')),
      const Offset(0, -1100),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pet-edit-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('编辑页保存失败保留已输入名称并展示错误', (tester) async {
    final gateway = _PetGateway(pets: [_pet(1)])
      ..updateError = StateError('rejected');
    await tester.pumpWidget(
      MaterialApp(home: PetEditPage(gateway: gateway, petId: 1)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pet-edit-name')),
      '失败后仍保留',
    );
    await tester.drag(
      find.byKey(const ValueKey('pet-edit-scroll')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('pet-edit-scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pet-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('宠物资料保存失败，请稍后重试'), findsOneWidget);
    expect(find.text('失败后仍保留'), findsOneWidget);
  });
}

Widget _listApp(
  _PetGateway gateway, {
  PetEditPageBuilder? editPageBuilder,
  double textScale = 1,
}) {
  return MaterialApp(
    builder: wp11TextScaleBuilder(textScale),
    home: PetListPage(gateway: gateway, editPageBuilder: editPageBuilder),
  );
}

Pet _pet(int id, {String? name}) {
  const breed = PetCategory(id: 5, name: '金毛', parentId: 1, sortOrder: 0);
  const category = PetCategory(
    id: 1,
    name: '犬',
    parentId: null,
    sortOrder: 0,
    children: [breed],
  );
  return Pet(
    id: id,
    name: name ?? '旺财$id',
    avatarUrl: '',
    categoryId: 1,
    subCategoryId: 5,
    gender: PetGender.male,
    birthDate: DateTime(2022, 1, 1),
    weight: 10,
    isNeutered: false,
    vaccineCount: 2,
    category: category,
    subCategory: breed,
    ownerId: 8,
    createdAt: null,
    updatedAt: null,
  );
}

class _PetGateway implements PetGateway {
  _PetGateway({List<Pet>? pets}) : pets = pets ?? [];

  final List<Pet> pets;
  Object? listError;
  Object? updateError;
  int deleteCalls = 0;

  @override
  Future<List<Pet>> loadMyPets({int? categoryId}) async {
    if (listError case final error?) throw error;
    return pets
        .where((pet) => categoryId == null || pet.categoryId == categoryId)
        .toList(growable: false);
  }

  @override
  Future<List<PetCategory>> loadCategoryTree() async => const [
    PetCategory(
      id: 1,
      name: '犬',
      parentId: null,
      sortOrder: 0,
      children: [PetCategory(id: 5, name: '金毛', parentId: 1, sortOrder: 0)],
    ),
  ];

  @override
  Future<Pet> loadPet(int id) async => pets.singleWhere((pet) => pet.id == id);

  @override
  Future<Pet> createPet(PetDraft draft) async => _pet(2, name: draft.name);

  @override
  Future<Pet> updatePet(int id, PetDraft draft) async {
    if (updateError case final error?) throw error;
    return _pet(id, name: draft.name);
  }

  @override
  Future<void> deletePet(int id) async {
    deleteCalls += 1;
    pets.removeWhere((pet) => pet.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
