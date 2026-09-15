import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';
import 'package:pet_hospital_flutter/features/pets/presentation/pet_list_controller.dart';

void main() {
  test('首次加载并行获取分类和宠物，重复刷新折叠为一次请求', () async {
    final gateway = _PetGateway();
    final controller = PetListController(gateway: gateway);

    final load = controller.load();
    expect(gateway.categoryCalls, 1);
    expect(gateway.listCalls, 1);
    expect(controller.isInitialLoading, isTrue);
    gateway.categoryCompleter.complete([_category()]);
    gateway.listCompleters.single.complete([_pet(1)]);
    await load;

    expect(controller.categories.single.name, '犬');
    expect(controller.pets.single.id, 1);
    expect(controller.errorMessage, isNull);

    final firstRefresh = controller.refresh();
    final secondRefresh = controller.refresh();
    expect(gateway.listCalls, 2);
    gateway.listCompleters.last.complete([_pet(2)]);
    await Future.wait([firstRefresh, secondRefresh]);
    expect(controller.pets.single.id, 2);
  });

  test('分类切换携带 categoryId，迟到的旧分类结果不会覆盖新分类', () async {
    final gateway = _PetGateway();
    final controller = PetListController(gateway: gateway);
    final initial = controller.load();
    gateway.categoryCompleter.complete([_category()]);
    gateway.listCompleters.single.complete([_pet(1)]);
    await initial;

    final dogs = controller.selectCategory(1);
    final cats = controller.selectCategory(2);
    expect(gateway.categoryIds, [null, 1, 2]);
    gateway.listCompleters[2].complete([_pet(22)]);
    await cats;
    gateway.listCompleters[1].complete([_pet(11)]);
    await dogs;

    expect(controller.selectedCategoryId, 2);
    expect(controller.pets.single.id, 22);
  });

  test('删除请求去重，成功后宠物立即从当前列表消失', () async {
    final deleteCompleter = Completer<void>();
    final gateway = _PetGateway(deleteCompleter: deleteCompleter);
    final controller = PetListController(gateway: gateway);
    final load = controller.load();
    gateway.categoryCompleter.complete([]);
    gateway.listCompleters.single.complete([_pet(1), _pet(2)]);
    await load;

    final first = controller.deletePet(1);
    final second = controller.deletePet(1);
    expect(gateway.deleteCalls, 1);
    expect(controller.isDeleting(1), isTrue);
    deleteCompleter.complete();
    expect(await first, PetDeleteResult.deleted);
    expect(await second, PetDeleteResult.deleted);

    expect(controller.pets.map((pet) => pet.id), [2]);
    expect(controller.isDeleting(1), isFalse);
  });

  test('只有成功的新建、编辑和删除返回才各触发一次刷新', () async {
    final gateway = _PetGateway();
    final controller = PetListController(gateway: gateway);
    final load = controller.load();
    gateway.categoryCompleter.complete([]);
    gateway.listCompleters.single.complete([_pet(1)]);
    await load;

    await controller.handleEditorResult(null);
    expect(gateway.listCalls, 1);

    for (final result in PetEditorResult.values) {
      final refresh = controller.handleEditorResult(result);
      expect(gateway.listCalls, result.index + 2);
      gateway.listCompleters.last.complete([_pet(result.index + 10)]);
      await refresh;
    }

    expect(gateway.listCalls, 4);
    expect(controller.pets.single.id, 12);
  });

  test('刷新失败保留最后一次有效列表，错误可通过重试恢复', () async {
    final gateway = _PetGateway();
    final controller = PetListController(gateway: gateway);
    final load = controller.load();
    gateway.categoryCompleter.complete([]);
    gateway.listCompleters.single.complete([_pet(1)]);
    await load;

    final failed = controller.refresh();
    gateway.listCompleters.last.completeError(StateError('offline'));
    await failed;
    expect(controller.pets.single.id, 1);
    expect(controller.errorMessage, isNotNull);

    final retry = controller.retry();
    gateway.listCompleters.last.complete([_pet(2)]);
    await retry;
    expect(controller.pets.single.id, 2);
    expect(controller.errorMessage, isNull);
  });
}

Pet _pet(int id) {
  return Pet(
    id: id,
    name: '旺财$id',
    avatarUrl: '',
    categoryId: 1,
    subCategoryId: null,
    gender: PetGender.male,
    birthDate: DateTime(2022, 1, 1),
    weight: 10,
    isNeutered: false,
    vaccineCount: 2,
    category: _category(),
    subCategory: null,
    ownerId: 8,
    createdAt: null,
    updatedAt: null,
  );
}

PetCategory _category() {
  return const PetCategory(id: 1, name: '犬', parentId: null, sortOrder: 0);
}

class _PetGateway implements PetGateway {
  _PetGateway({this.deleteCompleter});

  final Completer<List<PetCategory>> categoryCompleter =
      Completer<List<PetCategory>>();
  final List<Completer<List<Pet>>> listCompleters = [];
  final List<int?> categoryIds = [];
  final Completer<void>? deleteCompleter;
  int categoryCalls = 0;
  int listCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<PetCategory>> loadCategoryTree() {
    categoryCalls += 1;
    return categoryCompleter.future;
  }

  @override
  Future<List<Pet>> loadMyPets({int? categoryId}) {
    listCalls += 1;
    categoryIds.add(categoryId);
    final completer = Completer<List<Pet>>();
    listCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<void> deletePet(int id) {
    deleteCalls += 1;
    return deleteCompleter?.future ?? Future<void>.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
