import { DataSource } from 'typeorm';
import { Category } from '../entities/category.entity';

/**
 * 初始化二手商品分类种子数据
 */
export const seedSecondHandCategories = async (dataSource: DataSource) => {
  const categoryRepository = dataSource.getRepository(Category);

  // 检查是否已存在二手商品分类
  const existingCount = await categoryRepository
    .createQueryBuilder('category')
    .where('category.name LIKE :keyword', { keyword: '%二手%' })
    .getCount();

  if (existingCount > 0) {
    console.log('✅ 二手商品分类已存在，跳过');
    return;
  }

  // 创建二手商品分类
  const categories = [
    // 一级分类：猫用品
    {
      name: '二手猫用品',
      description: '二手猫相关用品',
      icon: '',
      parentId: null,
      sort: 1,
    },
    // 一级分类：狗用品
    {
      name: '二手狗用品',
      description: '二手狗相关用品',
      icon: '',
      parentId: null,
      sort: 2,
    },
    // 一级分类：宠物食品
    {
      name: '二手宠物食品',
      description: '二手宠物食品（未开封）',
      icon: '',
      parentId: null,
      sort: 3,
    },
    // 一级分类：其他宠物用品
    {
      name: '二手其他宠物用品',
      description: '其他宠物二手用品',
      icon: '',
      parentId: null,
      sort: 4,
    },
  ];

  const savedCategories = await categoryRepository.save(categories);
  console.log(`✅ 二手商品分类初始化完成（${savedCategories.length}条记录）`);

  // 创建二级分类（猫用品子分类）
  const catCategory = savedCategories[0];
  const catSubCategories = [
    { name: '玩具', description: '猫玩具', icon: '', parentId: catCategory.id, sort: 1 },
    { name: '笼具', description: '猫笼、猫窝等', icon: '', parentId: catCategory.id, sort: 2 },
    { name: '窝垫', description: '猫窝、垫子等', icon: '', parentId: catCategory.id, sort: 3 },
    { name: '服饰', description: '猫衣服、配饰等', icon: '', parentId: catCategory.id, sort: 4 },
    { name: '其他', description: '其他猫用品', icon: '', parentId: catCategory.id, sort: 5 },
  ];
  await categoryRepository.save(catSubCategories);
  console.log(`✅ 猫用品子分类初始化完成（${catSubCategories.length}条记录）`);

  // 创建二级分类（狗用品子分类）
  const dogCategory = savedCategories[1];
  const dogSubCategories = [
    { name: '玩具', description: '狗玩具', icon: '', parentId: dogCategory.id, sort: 1 },
    { name: '笼具', description: '狗笼、狗窝等', icon: '', parentId: dogCategory.id, sort: 2 },
    { name: '窝垫', description: '狗窝、垫子等', icon: '', parentId: dogCategory.id, sort: 3 },
    { name: '服饰', description: '狗衣服、配饰等', icon: '', parentId: dogCategory.id, sort: 4 },
    { name: '其他', description: '其他狗用品', icon: '', parentId: dogCategory.id, sort: 5 },
  ];
  await categoryRepository.save(dogSubCategories);
  console.log(`✅ 狗用品子分类初始化完成（${dogSubCategories.length}条记录）`);
};
