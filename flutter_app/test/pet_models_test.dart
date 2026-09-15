import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';

void main() {
  group('Pet models', () {
    test('兼容数字字符串、decimal 字符串和可空分类字段', () {
      final pet = Pet.fromJson(const {
        'id': '12',
        'name': ' 团团 ',
        'avatar': null,
        'categoryId': '1',
        'subCategoryId': null,
        'gender': '2',
        'birthDate': '2023-07-08',
        'weight': '4.25',
        'isNeutered': true,
        'vaccineCount': '3',
        'category': {'id': '1', 'name': ' 猫 ', 'parentId': null},
        'subCategory': null,
        'ownerId': '8',
        'createdAt': '2025-01-01T08:00:00.000Z',
        'updatedAt': '2025-01-02T08:00:00.000Z',
      });

      expect(pet.id, 12);
      expect(pet.name, '团团');
      expect(pet.avatarUrl, isEmpty);
      expect(pet.categoryId, 1);
      expect(pet.subCategoryId, isNull);
      expect(pet.gender, PetGender.female);
      expect(pet.birthDate, DateTime(2023, 7, 8));
      expect(pet.weight, 4.25);
      expect(pet.vaccineCount, 3);
      expect(pet.category?.name, '猫');
      expect(pet.subCategory, isNull);
      expect(pet.ownerId, 8);
      expect(pet.breedLabel, '猫');
      expect(pet.vaccineLabel, '已接种 3 针疫苗');
    });

    test('未知性别和缺失可选字段使用稳定边界值', () {
      final pet = Pet.fromJson(const {
        'id': 3,
        'name': '小白',
        'gender': 9,
        'weight': null,
        'ownerId': 8,
        'createdAt': null,
        'updatedAt': null,
      });

      expect(pet.gender, PetGender.unknown);
      expect(pet.genderLabel, '未知');
      expect(pet.weight, 0);
      expect(pet.isNeutered, isFalse);
      expect(pet.vaccineCount, 0);
      expect(pet.birthDate, isNull);
      expect(pet.breedLabel, '未知品种');
      expect(pet.vaccineLabel, '待接种疫苗');
    });

    test('分类树递归解析并兼容字符串 ID', () {
      final category = PetCategory.fromJson(const {
        'id': '1',
        'name': '犬',
        'parentId': null,
        'sortOrder': '2',
        'children': [
          {'id': 5, 'name': '金毛', 'parentId': '1', 'sortOrder': 0},
        ],
      });

      expect(category.id, 1);
      expect(category.sortOrder, 2);
      expect(category.children.single.id, 5);
      expect(category.children.single.parentId, 1);
    });

    test('年龄按完整生日计算，未来日期返回未知', () {
      expect(
        formatPetAge(DateTime(2024, 7, 26), now: DateTime(2026, 7, 25)),
        '1 岁 11 个月',
      );
      expect(
        formatPetAge(DateTime(2026, 1, 25), now: DateTime(2026, 7, 25)),
        '6 个月',
      );
      expect(
        formatPetAge(DateTime(2026, 7, 1), now: DateTime(2026, 7, 25)),
        '0 个月',
      );
      expect(
        formatPetAge(DateTime(2026, 7, 26), now: DateTime(2026, 7, 25)),
        '未知年龄',
      );
      expect(formatPetAge(null, now: DateTime(2026, 7, 25)), '未知');
    });

    test('创建和更新分别生成显式且一致的后端字段映射', () {
      const draft = PetDraft(
        name: ' 旺财 ',
        avatarUrl: ' /uploads/pet.png ',
        categoryId: 1,
        subCategoryId: 5,
        gender: PetGender.male,
        birthDate: null,
        weightText: '12.50',
        isNeutered: false,
        vaccineCountText: '2',
      );

      final expected = {
        'name': '旺财',
        'avatar': '/uploads/pet.png',
        'categoryId': 1,
        'subCategoryId': 5,
        'gender': 1,
        'weight': 12.5,
        'isNeutered': false,
        'vaccineCount': 2,
      };
      expect(draft.toCreateJson(), expected);
      expect(draft.toUpdateJson(), expected);
    });

    test('固定响应缺少必需字段时抛出 FormatException', () {
      expect(
        () => Pet.fromJson(const {'id': 1, 'gender': 1, 'ownerId': 8}),
        throwsFormatException,
      );
      expect(
        () => PetCategory.fromJson(const {'id': 1, 'name': ''}),
        throwsFormatException,
      );
    });
  });
}
