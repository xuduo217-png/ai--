/**
 * 为 wallet_transactions 表添加审核相关字段
 *
 * 运行方式：ts-node migrations/add-wallet-transaction-audit-fields.ts
 */

import { DataSource } from 'typeorm';
import { WalletTransaction } from '../src/shop/entities/wallet-transaction.entity';

async function addWalletTransactionAuditFields() {
  console.log('开始为 wallet_transactions 表添加审核字段...');

  // 创建数据库连接
  const AppDataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_DATABASE || 'pet_hospitals',
    entities: [WalletTransaction],
    synchronize: false,
  });

  try {
    await AppDataSource.initialize();
    console.log('数据库连接成功');

    const queryRunner = AppDataSource.createQueryRunner();

    try {
      // 检查字段是否已存在
      const table = await queryRunner.getTable('wallet_transactions');

      const fieldsToAdd = [
        {
          name: 'frozenAmount',
          sql: `ALTER TABLE wallet_transactions ADD COLUMN frozenAmount DECIMAL(10,2) DEFAULT 0 COMMENT '冻结金额（审核拒绝时）'`,
        },
        {
          name: 'rejectReason',
          sql: `ALTER TABLE wallet_transactions ADD COLUMN rejectReason TEXT COMMENT '拒绝原因'`,
        },
        {
          name: 'reviewedAt',
          sql: `ALTER TABLE wallet_transactions ADD COLUMN reviewedAt DATETIME COMMENT '审核时间'`,
        },
        {
          name: 'reviewedBy',
          sql: `ALTER TABLE wallet_transactions ADD COLUMN reviewedBy INT COMMENT '审核人ID（管理员ID）'`,
        },
        {
          name: 'autoProcessed',
          sql: `ALTER TABLE wallet_transactions ADD COLUMN autoProcessed TINYINT(1) DEFAULT 0 COMMENT '是否自动处理（0=手动，1=自动）'`,
        },
      ];

      for (const field of fieldsToAdd) {
        const existingField = table.findColumnByName(field.name);
        if (!existingField) {
          console.log(`添加字段: ${field.name}`);
          await queryRunner.query(field.sql);
          console.log(`✅ 字段 ${field.name} 添加成功`);
        } else {
          console.log(`⚠️  字段 ${field.name} 已存在，跳过`);
        }
      }

      console.log('✅ 所有审核字段添加完成！');

    } finally {
      await queryRunner.release();
    }

  } catch (error) {
    console.error('❌ 添加字段失败:', error.message);
    console.error('详细错误:', error);
  } finally {
    await AppDataSource.destroy();
  }
}

addWalletTransactionAuditFields();
