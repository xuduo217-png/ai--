import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';
import 'package:pet_hospital_flutter/features/pets/presentation/pet_edit_controller.dart';

void main() {
  test('新建只加载分类树，编辑并行加载详情并完整回填草稿', () async {
    final createGateway = _PetGateway();
    final createController = PetEditController(gateway: createGateway);
    final createLoad = createController.load();
    createGateway.categoryCompleter.complete([_category()]);
    await createLoad;
    expect(createGateway.detailCalls, 0);
    expect(createController.draft.gender, PetGender.male);
    expect(createController.categories.single.name, '犬');

    final editGateway = _PetGateway();
    final editController = PetEditController(gateway: editGateway, petId: 9);
    final editLoad = editController.load();
    expect(editGateway.detailCalls, 1);
    editGateway.categoryCompleter.complete([_category()]);
    editGateway.detailCompleter.complete(_pet(9));
    await editLoad;

    expect(editController.draft.name, '旺财9');
    expect(editController.draft.categoryId, 1);
    expect(editController.draft.birthDate, DateTime(2022, 1, 1));
    expect(editController.draft.weightText, '10');
    expect(editController.loadError, isNull);
  });

  test('校验名称、分类、出生日期、性别、体重和疫苗针数边界', () async {
    final controller = PetEditController(
      gateway: _PetGateway(),
      now: () => DateTime(2026, 7, 25),
    );

    await _expectValidation(controller, '请输入宠物名称');
    controller.updateName('a' * 51);
    await _expectValidation(controller, '宠物名称不能超过 50 个字符');
    controller.updateName('团团');
    await _expectValidation(controller, '请选择宠物类型');
    controller.updateCategory(1);
    await _expectValidation(controller, '请选择出生日期');
    controller.updateBirthDate(DateTime(2026, 7, 25));
    await _expectValidation(controller, '出生日期必须早于今天');
    controller.updateBirthDate(DateTime(2025, 7, 25));
    controller.updateGender(PetGender.unknown);
    await _expectValidation(controller, '请选择宠物性别');
    controller.updateGender(PetGender.female);
    controller.updateWeight('abc');
    await _expectValidation(controller, '请输入有效体重');
    controller.updateWeight('0');
    await _expectValidation(controller, '体重必须大于 0');
    controller.updateWeight('1000');
    await _expectValidation(controller, '体重不能超过 999.99 公斤');
    controller.updateWeight('4.2');
    controller.updateVaccineCount('-1');
    await _expectValidation(controller, '疫苗针数不能小于 0');
    controller.updateVaccineCount('1.5');
    await _expectValidation(controller, '疫苗针数必须是整数');
  });

  test('新建保存去重并使用当前草稿，失败后保留用户输入', () async {
    final createCompleter = Completer<Pet>();
    final gateway = _PetGateway(createCompleter: createCompleter);
    final controller = PetEditController(
      gateway: gateway,
      now: () => DateTime(2026, 7, 25),
    );
    _fillValidDraft(controller);

    final first = controller.save();
    final second = controller.save();
    expect(gateway.createCalls, 1);
    expect(controller.isSaving, isTrue);
    createCompleter.completeError(StateError('save failed'));
    await expectLater(first, throwsStateError);
    await expectLater(second, throwsStateError);
    expect(controller.draft.name, '团团');
    expect(controller.draft.weightText, '4.2');
    expect(controller.isSaving, isFalse);
  });

  test('编辑保存调用 update 并返回 updated', () async {
    final gateway = _PetGateway();
    final controller = PetEditController(
      gateway: gateway,
      petId: 9,
      now: () => DateTime(2026, 7, 25),
    );
    final load = controller.load();
    gateway.categoryCompleter.complete([_category()]);
    gateway.detailCompleter.complete(_pet(9));
    await load;
    controller.updateName('修改后');

    expect(await controller.save(), PetEditorResult.updated);
    expect(gateway.updateCalls, 1);
    expect(gateway.lastDraft?.name, '修改后');
  });

  test('图片选择取消、权限失败、文件丢失、上传成功和重复上传都有明确结果', () async {
    var controller = PetEditController(
      gateway: _PetGateway(),
      imagePicker: const _ImagePicker(null),
      fileExists: (_) => true,
    );
    expect(
      (await controller.pickAndUploadAvatar(PetImageSource.gallery)).status,
      PetAvatarUploadStatus.cancelled,
    );

    controller.dispose();
    controller = PetEditController(
      gateway: _PetGateway(),
      imagePicker: const _ThrowingImagePicker(),
      fileExists: (_) => true,
    );
    expect(
      (await controller.pickAndUploadAvatar(PetImageSource.gallery)).status,
      PetAvatarUploadStatus.failed,
    );
    final cameraFailure = await controller.pickAndUploadAvatar(
      PetImageSource.camera,
    );
    expect(cameraFailure.status, PetAvatarUploadStatus.failed);
    expect(cameraFailure.message, contains('相机'));

    controller.dispose();
    final missingGateway = _PetGateway();
    controller = PetEditController(
      gateway: missingGateway,
      imagePicker: const _ImagePicker(
        PickedPetImage(path: '/tmp/missing.jpg', filename: 'missing.jpg'),
      ),
      fileExists: (_) => false,
    );
    expect(
      (await controller.pickAndUploadAvatar(PetImageSource.gallery)).status,
      PetAvatarUploadStatus.failed,
    );
    expect(missingGateway.uploadCalls, 0);

    controller.dispose();
    final uploadCompleter = Completer<PetImageUpload>();
    final uploadGateway = _PetGateway(uploadCompleter: uploadCompleter);
    controller = PetEditController(
      gateway: uploadGateway,
      imagePicker: const _ImagePicker(
        PickedPetImage(path: '/tmp/pet.jpg', filename: 'pet.jpg'),
      ),
      fileExists: (_) => true,
    );
    final uploading = controller.pickAndUploadAvatar(PetImageSource.gallery);
    final busy = await controller.pickAndUploadAvatar(PetImageSource.gallery);
    expect(busy.status, PetAvatarUploadStatus.busy);
    uploadCompleter.complete(_upload());
    final uploaded = await uploading;
    expect(uploaded.status, PetAvatarUploadStatus.uploaded);
    expect(controller.draft.avatarUrl, '/uploads/pet.jpg');
  });

  test('编辑删除请求折叠，且新建态不能删除', () async {
    final deleteCompleter = Completer<void>();
    final gateway = _PetGateway(deleteCompleter: deleteCompleter);
    final controller = PetEditController(gateway: gateway, petId: 9);

    final first = controller.delete();
    final second = controller.delete();
    expect(gateway.deleteCalls, 1);
    expect(controller.isDeleting, isTrue);
    deleteCompleter.complete();
    expect(await first, PetEditorResult.deleted);
    expect(await second, PetEditorResult.deleted);

    await expectLater(
      PetEditController(gateway: gateway).delete(),
      throwsStateError,
    );
  });
}

Future<void> _expectValidation(
  PetEditController controller,
  String message,
) async {
  await expectLater(
    controller.save(),
    throwsA(
      isA<PetValidationException>().having(
        (error) => error.message,
        'message',
        message,
      ),
    ),
  );
}

void _fillValidDraft(PetEditController controller) {
  controller.updateName('团团');
  controller.updateCategory(1);
  controller.updateBirthDate(DateTime(2024, 1, 1));
  controller.updateGender(PetGender.female);
  controller.updateWeight('4.2');
  controller.updateVaccineCount('2');
}

Pet _pet(int id) {
  return Pet(
    id: id,
    name: '旺财$id',
    avatarUrl: '/uploads/pet.jpg',
    categoryId: 1,
    subCategoryId: 5,
    gender: PetGender.male,
    birthDate: DateTime(2022, 1, 1),
    weight: 10,
    isNeutered: true,
    vaccineCount: 2,
    category: _category(),
    subCategory: _category(id: 5, name: '金毛', parentId: 1),
    ownerId: 8,
    createdAt: null,
    updatedAt: null,
  );
}

PetCategory _category({int id = 1, String name = '犬', int? parentId}) {
  return PetCategory(
    id: id,
    name: name,
    parentId: parentId,
    sortOrder: 0,
    children: id == 1
        ? [const PetCategory(id: 5, name: '金毛', parentId: 1, sortOrder: 0)]
        : const [],
  );
}

PetImageUpload _upload() {
  return const PetImageUpload(
    id: 21,
    url: '/uploads/pet.jpg',
    filename: 'stored-pet.jpg',
    originalName: 'pet.jpg',
    size: 123,
  );
}

class _PetGateway implements PetGateway {
  _PetGateway({
    this.createCompleter,
    this.uploadCompleter,
    this.deleteCompleter,
  });

  final Completer<List<PetCategory>> categoryCompleter =
      Completer<List<PetCategory>>();
  final Completer<Pet> detailCompleter = Completer<Pet>();
  final Completer<Pet>? createCompleter;
  final Completer<PetImageUpload>? uploadCompleter;
  final Completer<void>? deleteCompleter;
  int detailCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int uploadCalls = 0;
  int deleteCalls = 0;
  PetDraft? lastDraft;

  @override
  Future<List<PetCategory>> loadCategoryTree() => categoryCompleter.future;

  @override
  Future<Pet> loadPet(int id) {
    detailCalls += 1;
    return detailCompleter.future;
  }

  @override
  Future<Pet> createPet(PetDraft draft) {
    createCalls += 1;
    lastDraft = draft;
    return createCompleter?.future ?? Future.value(_pet(21));
  }

  @override
  Future<Pet> updatePet(int id, PetDraft draft) {
    updateCalls += 1;
    lastDraft = draft;
    return Future.value(_pet(id));
  }

  @override
  Future<PetImageUpload> uploadAvatar({
    required String filePath,
    String? filename,
  }) {
    uploadCalls += 1;
    return uploadCompleter?.future ?? Future.value(_upload());
  }

  @override
  Future<void> deletePet(int id) {
    deleteCalls += 1;
    return deleteCompleter?.future ?? Future<void>.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImagePicker implements PetImagePicker {
  const _ImagePicker(this.image);

  final PickedPetImage? image;

  @override
  Future<PickedPetImage?> pickAvatar(
    PetImageSource source, {
    BuildContext? context,
  }) async => image;
}

class _ThrowingImagePicker implements PetImagePicker {
  const _ThrowingImagePicker();

  @override
  Future<PickedPetImage?> pickAvatar(
    PetImageSource source, {
    BuildContext? context,
  }) {
    throw StateError('permission denied');
  }
}
