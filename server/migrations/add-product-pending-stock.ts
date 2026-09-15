/**
 * 为 products_pending 表补充库存字段
 *
 * 运行方式：ts-node migrations/add-product-pending-stock.ts
 */

import { DataSource } from 'typeorm';
import { ProductPending } from '../src/shop/entities/product-pending.entity';

async function addProductPendingStock() {
  console.log('开始为 products_pending 表添加 stock 字段...');

  const AppDataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_DATABASE || 'pet_hospitals',
    entities: [ProductPending],
    synchronize: false,
  });

  try {
    await AppDataSource.initialize();
    console.log('数据库连接成功');

    const queryRunner = AppDataSource.createQueryRunner();

    try {
      const table = await queryRunner.getTable('products_pending');
      const stockColumn = table?.findColumnByName('stock');

      if (!stockColumn) {
        await queryRunner.query(
          "ALTER TABLE products_pending ADD COLUMN stock INT NOT NULL DEFAULT 1 COMMENT '库存数量' AFTER price",
        );
        console.log('✅ 字段 stock 添加成功');
      } else {
        console.log('⚠️  字段 stock 已存在，跳过');
      }
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    console.error('❌ 添加 stock 字段失败:', error.message);
    console.error('详细错误:', error);
  } finally {
    await AppDataSource.destroy();
  }
}

addProductPendingStock();
