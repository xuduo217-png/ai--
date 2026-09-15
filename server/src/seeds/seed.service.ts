import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { chatSeedData } from './chat.seeds';
import { userSeedData } from './user.seeds';
import { categorySeeds } from './category.seeds';
import { fixSingleSkuProducts } from './product-fix.seeds';

@Injectable()
export class SeedService {
  private readonly logger = new Logger(SeedService.name);

  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  async runSeeds() {
    this.logger.log('🌱 Starting seed data...\n');

    try {
      // 运行用户种子数据（创建超级管理员）
      await userSeedData(this.dataSource);

      // 运行分类模块的种子数据
      await categorySeeds(this.dataSource);

      // 运行聊天模块的种子数据
      await chatSeedData(this.dataSource);

      // 修复单规格商品数据（为没有 SKU 的商品创建默认 SKU）
      await fixSingleSkuProducts(this.dataSource);

      this.logger.log('\n✅ All seed data completed successfully!');
    } catch (error) {
      this.logger.error('❌ Error seeding data:', error);
      throw error;
    }
  }
}
