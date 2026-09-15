import { DataSource } from 'typeorm';
import { chatSeedData } from './chat.seeds';
import { seedSystemArticles } from '../system-configs/seeds/system-articles.seed';
import { seedPetCategories } from '../pet-categories/seeds/pet-categories.seed';

export async function runSeeds(dataSource: DataSource) {
  console.log('🌱 Starting seed data...\n');

  try {
    // 运行聊天模块的种子数据
    await chatSeedData(dataSource);

    // 运行系统文章的种子数据
    await seedSystemArticles(dataSource);

    // 运行宠物分类的种子数据
    await seedPetCategories(dataSource);

    console.log('\n✅ All seed data completed successfully!');
  } catch (error) {
    console.error('❌ Error seeding data:', error);
    throw error;
  }
}
