import { DataSource } from 'typeorm';
import { PetCategory } from '../entities/pet-category.entity';

/**
 * 初始化宠物分类种子数据
 */
export const seedPetCategories = async (dataSource: DataSource) => {
  const petCategoryRepository = dataSource.getRepository(PetCategory);

  // 检查是否已存在宠物分类
  const existingCount = await petCategoryRepository.count();

  if (existingCount > 0) {
    console.log('✅ 宠物分类已存在，跳过');
    return;
  }

  // 创建一级分类
  const firstLevelCategories = [
    { name: '狗', parentId: null, sortOrder: 1 },
    { name: '猫', parentId: null, sortOrder: 2 },
    { name: '鸟', parentId: null, sortOrder: 3 },
    { name: '兔子', parentId: null, sortOrder: 4 },
    { name: '仓鼠', parentId: null, sortOrder: 5 },
    { name: '其他', parentId: null, sortOrder: 6 },
  ];

  const savedFirstLevel = await petCategoryRepository.save(firstLevelCategories);
  console.log(`✅ 宠物一级分类初始化完成（${savedFirstLevel.length}条记录）`);

  // 创建二级分类（狗）
  const dogCategory = savedFirstLevel.find(c => c.name === '狗')!;
  const dogBreeds = [
    { name: '金毛', parentId: dogCategory.id, sortOrder: 1 },
    { name: '拉布拉多', parentId: dogCategory.id, sortOrder: 2 },
    { name: '泰迪', parentId: dogCategory.id, sortOrder: 3 },
    { name: '哈士奇', parentId: dogCategory.id, sortOrder: 4 },
    { name: '柯基', parentId: dogCategory.id, sortOrder: 5 },
    { name: '博美', parentId: dogCategory.id, sortOrder: 6 },
    { name: '比熊', parentId: dogCategory.id, sortOrder: 7 },
    { name: '吉娃娃', parentId: dogCategory.id, sortOrder: 8 },
    { name: '萨摩耶', parentId: dogCategory.id, sortOrder: 9 },
    { name: '柴犬', parentId: dogCategory.id, sortOrder: 10 },
    { name: '德国牧羊犬', parentId: dogCategory.id, sortOrder: 11 },
    { name: '边境牧羊犬', parentId: dogCategory.id, sortOrder: 12 },
    { name: '法国斗牛犬', parentId: dogCategory.id, sortOrder: 13 },
    { name: '斗牛犬', parentId: dogCategory.id, sortOrder: 14 },
    { name: '松狮', parentId: dogCategory.id, sortOrder: 15 },
    { name: '阿拉斯加', parentId: dogCategory.id, sortOrder: 16 },
    { name: '雪纳瑞', parentId: dogCategory.id, sortOrder: 17 },
    { name: '约克夏', parentId: dogCategory.id, sortOrder: 18 },
    { name: '马尔济斯', parentId: dogCategory.id, sortOrder: 19 },
    { name: '其他犬种', parentId: dogCategory.id, sortOrder: 20 },
  ];
  const savedDogBreeds = await petCategoryRepository.save(dogBreeds);
  console.log(`✅ 狗品种二级分类初始化完成（${savedDogBreeds.length}条记录）`);

  // 创建二级分类（猫）
  const catCategory = savedFirstLevel.find(c => c.name === '猫')!;
  const catBreeds = [
    { name: '英短', parentId: catCategory.id, sortOrder: 1 },
    { name: '美短', parentId: catCategory.id, sortOrder: 2 },
    { name: '布偶猫', parentId: catCategory.id, sortOrder: 3 },
    { name: '暹罗猫', parentId: catCategory.id, sortOrder: 4 },
    { name: '波斯猫', parentId: catCategory.id, sortOrder: 5 },
    { name: '缅因猫', parentId: catCategory.id, sortOrder: 6 },
    { name: '加菲猫', parentId: catCategory.id, sortOrder: 7 },
    { name: '折耳猫', parentId: catCategory.id, sortOrder: 8 },
    { name: '缅甸猫', parentId: catCategory.id, sortOrder: 9 },
    { name: '孟加拉猫', parentId: catCategory.id, sortOrder: 10 },
    { name: '挪威森林猫', parentId: catCategory.id, sortOrder: 11 },
    { name: '埃及猫', parentId: catCategory.id, sortOrder: 12 },
    { name: '新加坡猫', parentId: catCategory.id, sortOrder: 13 },
    { name: '斯芬克斯猫', parentId: catCategory.id, sortOrder: 14 },
    { name: '其他猫种', parentId: catCategory.id, sortOrder: 15 },
  ];
  const savedCatBreeds = await petCategoryRepository.save(catBreeds);
  console.log(`✅ 猫品种二级分类初始化完成（${savedCatBreeds.length}条记录）`);

  // 创建二级分类（鸟）
  const birdCategory = savedFirstLevel.find(c => c.name === '鸟')!;
  const birdBreeds = [
    { name: '鹦鹉', parentId: birdCategory.id, sortOrder: 1 },
    { name: '金丝雀', parentId: birdCategory.id, sortOrder: 2 },
    { name: '八哥', parentId: birdCategory.id, sortOrder: 3 },
    { name: '画眉', parentId: birdCategory.id, sortOrder: 4 },
    { name: '百灵', parentId: birdCategory.id, sortOrder: 5 },
    { name: '其他鸟类', parentId: birdCategory.id, sortOrder: 6 },
  ];
  const savedBirdBreeds = await petCategoryRepository.save(birdBreeds);
  console.log(`✅ 鸟品种二级分类初始化完成（${savedBirdBreeds.length}条记录）`);

  // 创建二级分类（兔子）
  const rabbitCategory = savedFirstLevel.find(c => c.name === '兔子')!;
  const rabbitBreeds = [
    { name: '荷兰兔', parentId: rabbitCategory.id, sortOrder: 1 },
    { name: '垂耳兔', parentId: rabbitCategory.id, sortOrder: 2 },
    { name: '狮子兔', parentId: rabbitCategory.id, sortOrder: 3 },
    { name: '安哥拉兔', parentId: rabbitCategory.id, sortOrder: 4 },
    { name: '其他兔种', parentId: rabbitCategory.id, sortOrder: 5 },
  ];
  const savedRabbitBreeds = await petCategoryRepository.save(rabbitBreeds);
  console.log(`✅ 兔子品种二级分类初始化完成（${savedRabbitBreeds.length}条记录）`);

  // 创建二级分类（仓鼠）
  const hamsterCategory = savedFirstLevel.find(c => c.name === '仓鼠')!;
  const hamsterBreeds = [
    { name: '金丝熊', parentId: hamsterCategory.id, sortOrder: 1 },
    { name: '三线仓鼠', parentId: hamsterCategory.id, sortOrder: 2 },
    { name: '一线仓鼠', parentId: hamsterCategory.id, sortOrder: 3 },
    { name: '其他仓鼠种', parentId: hamsterCategory.id, sortOrder: 4 },
  ];
  const savedHamsterBreeds = await petCategoryRepository.save(hamsterBreeds);
  console.log(`✅ 仓鼠品种二级分类初始化完成（${savedHamsterBreeds.length}条记录）`);

  console.log('✅ 宠物分类种子数据初始化完成');
};
