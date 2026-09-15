import { DataSource } from 'typeorm';
import { Category } from '../shop/entities/category.entity';

export const categorySeeds = async (dataSource: DataSource): Promise<void> => {
  const categoryRepository = dataSource.getRepository(Category);

  // 检查是否已有分类数据
  const count = await categoryRepository.count();
  if (count > 0) {
    console.log('✅ 分类数据已存在，跳过种子数据创建');
    return;
  }

  // 创建一级分类
  const categories = [
    {
      name: '宠物食品',
      icon: '🍖',
      description: '狗粮、猫粮、宠物零食等',
      sortOrder: 1,
      parentId: null,
    },
    {
      name: '狗粮',
      icon: '🦮',
      description: '全价狗粮、天然狗粮、处方狗粮等',
      sortOrder: 1,
      parentId: null,
    },
    {
      name: '猫粮',
      icon: '🐱',
      description: '全价猫粮、天然猫粮、无谷猫粮等',
      sortOrder: 2,
      parentId: null,
    },
    {
      name: '宠物玩具',
      icon: '🎾',
      description: '咬胶玩具、互动玩具、益智玩具等',
      sortOrder: 2,
      parentId: null,
    },
    {
      name: '宠物用品',
      icon: '🧼',
      description: '窝垫、食盆、牵引绳、美容工具等',
      sortOrder: 3,
      parentId: null,
    },
    {
      name: '医疗保健',
      icon: '💊',
      description: '处方药、保健品、护理用品等',
      sortOrder: 4,
      parentId: null,
    },
    {
      name: '宠物服务',
      icon: '🏥',
      description: '寄养、美容、训练等服务',
      sortOrder: 5,
      parentId: null,
    },
  ];

  // 先保存所有一级分类
  const savedCategories = await categoryRepository.save(
    categories.map((cat) => categoryRepository.create(cat)),
  );

  // 创建二级分类
  const subCategories = [
    // 狗粮的子分类
    {
      name: '全价狗粮',
      icon: '🍖',
      description: '营养均衡的完整狗粮',
      sortOrder: 1,
      parentId: savedCategories[1].id,
    },
    {
      name: '天然狗粮',
      icon: '🌿',
      description: '无添加天然狗粮',
      sortOrder: 2,
      parentId: savedCategories[1].id,
    },
    {
      name: '处方狗粮',
      icon: '💊',
      description: '特殊医疗用途狗粮',
      sortOrder: 3,
      parentId: savedCategories[1].id,
    },

    // 猫粮的子分类
    {
      name: '全价猫粮',
      icon: '🍖',
      description: '营养均衡的完整猫粮',
      sortOrder: 1,
      parentId: savedCategories[2].id,
    },
    {
      name: '无谷猫粮',
      icon: '🌾',
      description: '无谷物猫粮',
      sortOrder: 2,
      parentId: savedCategories[2].id,
    },
    {
      name: '冻干猫粮',
      icon: '❄️',
      description: '冻干生肉猫粮',
      sortOrder: 3,
      parentId: savedCategories[2].id,
    },

    // 宠物玩具的子分类
    {
      name: '咬胶玩具',
      icon: '🦴',
      description: '耐咬磨牙玩具',
      sortOrder: 1,
      parentId: savedCategories[3].id,
    },
    {
      name: '互动玩具',
      icon: '🎯',
      description: '互动娱乐玩具',
      sortOrder: 2,
      parentId: savedCategories[3].id,
    },
    {
      name: '益智玩具',
      icon: '🧩',
      description: '开发智力玩具',
      sortOrder: 3,
      parentId: savedCategories[3].id,
    },

    // 宠物用品的子分类
    {
      name: '窝垫',
      icon: '🛏️',
      description: '宠物床、垫子',
      sortOrder: 1,
      parentId: savedCategories[4].id,
    },
    {
      name: '食盆水盆',
      icon: '🥣',
      description: '喂食碗、饮水器',
      sortOrder: 2,
      parentId: savedCategories[4].id,
    },
    {
      name: '牵引绳',
      icon: '🦮',
      description: '牵引绳、胸背带',
      sortOrder: 3,
      parentId: savedCategories[4].id,
    },

    // 医疗保健的子分类
    {
      name: '处方药',
      icon: '💊',
      description: '宠物处方药品',
      sortOrder: 1,
      parentId: savedCategories[5].id,
    },
    {
      name: '保健品',
      icon: '💚',
      description: '营养保健品',
      sortOrder: 2,
      parentId: savedCategories[5].id,
    },
    {
      name: '护理用品',
      icon: '🧴',
      description: '日常护理用品',
      sortOrder: 3,
      parentId: savedCategories[5].id,
    },

    // 宠物服务的子分类
    {
      name: '宠物寄养',
      icon: '🏠',
      description: '短期寄养服务',
      sortOrder: 1,
      parentId: savedCategories[6].id,
    },
    {
      name: '宠物美容',
      icon: '✂️',
      description: '洗澡美容服务',
      sortOrder: 2,
      parentId: savedCategories[6].id,
    },
    {
      name: '宠物训练',
      icon: '🎓',
      description: '行为训练服务',
      sortOrder: 3,
      parentId: savedCategories[6].id,
    },
  ];

  await categoryRepository.save(
    subCategories.map((cat) => categoryRepository.create(cat)),
  );

  console.log(
    `✅ 成功创建 ${savedCategories.length + subCategories.length} 个商品分类`,
  );
};
