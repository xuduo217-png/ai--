/**
 * 商城普通商品自动公益：活动配置和公益流水字段。
 *
 * 检查：node --env-file=.env -r ts-node/register migrations/add-mall-auto-charity-donation.ts --dry-run
 * 执行：node --env-file=.env -r ts-node/register migrations/add-mall-auto-charity-donation.ts
 */
import { DataSource, QueryRunner } from 'typeorm';

const dryRun = process.argv.includes('--dry-run');
const lockName = 'pet_hospitals_mall_auto_charity_donation_migration';

const dataSource = new DataSource({
  type: 'mysql',
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  username: process.env.DB_USERNAME || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_DATABASE || 'pet_hospitals',
  synchronize: false,
  connectTimeout: 30_000,
});

async function addColumn(
  queryRunner: QueryRunner,
  tableName: string,
  columnName: string,
  sql: string,
) {
  const table = await queryRunner.getTable(tableName);
  if (!table) throw new Error(`${tableName} 表不存在`);
  if (table.findColumnByName(columnName)) {
    console.log(`[OK] ${tableName}.${columnName} 已存在`);
    return;
  }
  console.log(`[${dryRun ? 'CHECK' : 'APPLY'}] 添加 ${tableName}.${columnName}`);
  if (!dryRun) await queryRunner.query(sql);
}

async function migrate() {
  await dataSource.initialize();
  const queryRunner = dataSource.createQueryRunner();
  await queryRunner.connect();
  let lockAcquired = false;
  try {
    const [lock] = await queryRunner.query('SELECT GET_LOCK(?, 30) AS acquired', [lockName]);
    if (Number(lock?.acquired) !== 1) throw new Error('无法获取商城自动公益迁移锁');
    lockAcquired = true;

    await addColumn(
      queryRunner,
      'charities',
      'isMallAutoDonation',
      "ALTER TABLE charities ADD COLUMN isMallAutoDonation TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否为商城订单自动公益活动' AFTER participantType",
    );
    await addColumn(
      queryRunner,
      'charities',
      'donationRate',
      "ALTER TABLE charities ADD COLUMN donationRate DECIMAL(5,2) NOT NULL DEFAULT 0 COMMENT '商城自动公益比例（百分比）' AFTER isMallAutoDonation",
    );
    await addColumn(
      queryRunner,
      'charities',
      'isPinned',
      "ALTER TABLE charities ADD COLUMN isPinned TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否置顶展示' AFTER donationRate",
    );

    await addColumn(
      queryRunner,
      'charity_records',
      'donationSource',
      "ALTER TABLE charity_records ADD COLUMN donationSource ENUM('manual','mall_order') NOT NULL DEFAULT 'manual' COMMENT '公益来源' AFTER donationAmount",
    );
    await addColumn(
      queryRunner,
      'charity_records',
      'donationEntryType',
      "ALTER TABLE charity_records ADD COLUMN donationEntryType ENUM('credit','reversal') NOT NULL DEFAULT 'credit' COMMENT '公益流水类型' AFTER donationSource",
    );
    await addColumn(
      queryRunner,
      'charity_records',
      'orderId',
      "ALTER TABLE charity_records ADD COLUMN orderId INT NULL COMMENT '关联商城订单ID' AFTER donationEntryType",
    );
    await addColumn(
      queryRunner,
      'charity_records',
      'orderNo',
      "ALTER TABLE charity_records ADD COLUMN orderNo VARCHAR(64) NULL COMMENT '关联商城订单号' AFTER orderId",
    );
    await addColumn(
      queryRunner,
      'charity_records',
      'donationBaseAmount',
      "ALTER TABLE charity_records ADD COLUMN donationBaseAmount DECIMAL(10,2) NULL COMMENT '公益计算基数' AFTER orderNo",
    );
    await addColumn(
      queryRunner,
      'charity_records',
      'donationRate',
      "ALTER TABLE charity_records ADD COLUMN donationRate DECIMAL(5,2) NULL COMMENT '公益比例快照（百分比）' AFTER donationBaseAmount",
    );
    await addColumn(
      queryRunner,
      'charity_records',
      'sourceReference',
      "ALTER TABLE charity_records ADD COLUMN sourceReference VARCHAR(128) NULL COMMENT '幂等来源标识' AFTER donationRate",
    );

    const table = await queryRunner.getTable('charity_records');
    if (!table) throw new Error('charity_records 表不存在');
    if (!table.indices.some((index) => index.name === 'IDX_charity_records_source_reference')) {
      console.log(`[${dryRun ? 'CHECK' : 'APPLY'}] 添加公益流水幂等索引`);
      if (!dryRun) {
        await queryRunner.query(
          'CREATE UNIQUE INDEX IDX_charity_records_source_reference ON charity_records (sourceReference)',
        );
      }
    }

    console.log(dryRun ? '商城自动公益迁移检查完成，未修改数据库' : '商城自动公益迁移执行完成');
  } finally {
    if (lockAcquired) await queryRunner.query('SELECT RELEASE_LOCK(?)', [lockName]);
    await queryRunner.release();
    await dataSource.destroy();
  }
}

migrate().catch((error) => {
  console.error('商城自动公益迁移失败:', error instanceof Error ? error.message : '未知错误');
  process.exitCode = 1;
});
