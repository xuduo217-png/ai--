/**
 * 公益支付宝捐款支付类型迁移。
 *
 * 检查：node --env-file=.env -r ts-node/register migrations/add-charity-donation-payment.ts --dry-run
 * 执行：node --env-file=.env -r ts-node/register migrations/add-charity-donation-payment.ts
 */
import { DataSource, QueryRunner } from "typeorm";

const dryRun = process.argv.includes("--dry-run");
const lockName = "pet_hospitals_charity_donation_payment_migration";
const enumValue = "charity_donation";

const dataSource = new DataSource({
  type: "mysql",
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 3306),
  username: process.env.DB_USERNAME || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_DATABASE || "pet_hospitals",
  synchronize: false,
  connectTimeout: 30_000,
});

async function ensureBusinessType(queryRunner: QueryRunner) {
  const table = await queryRunner.getTable("payments");
  if (!table) throw new Error("payments 表不存在");
  const column = table.findColumnByName("businessType");
  if (!column) throw new Error("payments.businessType 字段不存在");

  const enumValues = column.enum || [];
  if (enumValues.includes(enumValue)) {
    console.log("[OK] payments.businessType 已包含 charity_donation");
    return;
  }
  if (enumValues.length === 0) {
    throw new Error("无法读取 payments.businessType 现有 ENUM 值");
  }

  console.log(
    `[${dryRun ? "CHECK" : "APPLY"}] extend payments.businessType with ${enumValue}`,
  );
  if (!dryRun) {
    const enumSql = [...enumValues, enumValue]
      .map((item) => `'${item.replace(/'/g, "''")}'`)
      .join(",");
    await queryRunner.query(
      `ALTER TABLE payments MODIFY COLUMN businessType ENUM(${enumSql}) NOT NULL COMMENT '业务类型（关联不同模块）'`,
    );
  }
}

async function migrate() {
  await dataSource.initialize();
  const queryRunner = dataSource.createQueryRunner();
  await queryRunner.connect();
  let lockAcquired = false;
  try {
    const [lock] = await queryRunner.query(
      "SELECT GET_LOCK(?, 30) AS acquired",
      [lockName],
    );
    if (Number(lock?.acquired) !== 1) {
      throw new Error("无法获取公益支付迁移锁");
    }
    lockAcquired = true;

    await ensureBusinessType(queryRunner);
    console.log(
      dryRun ? "公益支付迁移检查完成，未修改数据库" : "公益支付迁移执行完成",
    );
  } finally {
    if (lockAcquired) {
      await queryRunner.query("SELECT RELEASE_LOCK(?)", [lockName]);
    }
    await queryRunner.release();
    await dataSource.destroy();
  }
}

migrate().catch((error) => {
  console.error(
    "公益支付迁移失败:",
    error instanceof Error ? error.message : "未知错误",
  );
  process.exitCode = 1;
});
