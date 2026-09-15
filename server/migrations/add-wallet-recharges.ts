/**
 * 钱包支付宝主动充值数据结构迁移。
 *
 * 检查：node --env-file=.env -r ts-node/register migrations/add-wallet-recharges.ts --dry-run
 * 执行：node --env-file=.env -r ts-node/register migrations/add-wallet-recharges.ts
 *
 * 生产执行前必须备份数据库并另行获得用户确认。
 */
import { DataSource, QueryRunner, TableIndex } from "typeorm";

const dryRun = process.argv.includes("--dry-run");
const lockName = "pet_hospitals_wallet_recharges_migration";

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

const rechargeColumns: Array<{ name: string; sql: string }> = [
  { name: "id", sql: "id INT NOT NULL AUTO_INCREMENT PRIMARY KEY" },
  { name: "rechargeNo", sql: "rechargeNo VARCHAR(40) NOT NULL" },
  { name: "idempotencyKey", sql: "idempotencyKey VARCHAR(36) NOT NULL" },
  { name: "userId", sql: "userId INT NOT NULL" },
  { name: "paymentNo", sql: "paymentNo VARCHAR(80) NULL" },
  { name: "walletTransactionId", sql: "walletTransactionId INT NULL" },
  { name: "amount", sql: "amount DECIMAL(10,2) NOT NULL" },
  {
    name: "status",
    sql: "status ENUM('pending','succeeded','failed','closed') NOT NULL DEFAULT 'pending'",
  },
  { name: "expiredAt", sql: "expiredAt DATETIME NULL" },
  { name: "paidAt", sql: "paidAt DATETIME NULL" },
  { name: "failedAt", sql: "failedAt DATETIME NULL" },
  { name: "failureMessage", sql: "failureMessage VARCHAR(500) NULL" },
  { name: "version", sql: "version INT NOT NULL DEFAULT 1" },
  {
    name: "createdAt",
    sql: "createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)",
  },
  {
    name: "updatedAt",
    sql: "updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)",
  },
];

async function ensureRechargeTable(queryRunner: QueryRunner) {
  let table = await queryRunner.getTable("wallet_recharges");
  if (!table) {
    console.log(
      `[${dryRun ? "CHECK" : "APPLY"}] create table wallet_recharges`,
    );
    if (!dryRun) {
      await queryRunner.query(
        `CREATE TABLE wallet_recharges (${rechargeColumns.map((column) => column.sql).join(", ")}) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
      );
      table = await queryRunner.getTable("wallet_recharges");
    }
  }

  for (const column of rechargeColumns) {
    if (!table?.findColumnByName(column.name)) {
      console.log(
        `[${dryRun ? "CHECK" : "APPLY"}] add wallet_recharges.${column.name}`,
      );
      if (!dryRun) {
        await queryRunner.query(
          `ALTER TABLE wallet_recharges ADD COLUMN ${column.sql}`,
        );
      }
    }
  }
}

async function ensureIndex(
  queryRunner: QueryRunner,
  name: string,
  columns: string[],
  isUnique = false,
) {
  const table = await queryRunner.getTable("wallet_recharges");
  if (!table?.indices.some((index) => index.name === name)) {
    console.log(`[${dryRun ? "CHECK" : "APPLY"}] add index ${name}`);
    if (!dryRun) {
      await queryRunner.createIndex(
        "wallet_recharges",
        new TableIndex({ name, columnNames: columns, isUnique }),
      );
    }
  }
}

async function ensureEnumValue(
  queryRunner: QueryRunner,
  tableName: string,
  columnName: string,
  value: string,
  comment: string,
) {
  const table = await queryRunner.getTable(tableName);
  if (!table) throw new Error(`${tableName} 表不存在`);
  const column = table.findColumnByName(columnName);
  if (!column) throw new Error(`${tableName}.${columnName} 字段不存在`);
  const enumValues = column.enum || [];
  if (enumValues.includes(value)) return;
  if (enumValues.length === 0) {
    throw new Error(`无法读取 ${tableName}.${columnName} 现有 ENUM 值`);
  }

  console.log(
    `[${dryRun ? "CHECK" : "APPLY"}] extend ${tableName}.${columnName} with ${value}`,
  );
  if (!dryRun) {
    const enumSql = [...enumValues, value]
      .map((item) => `'${item.replace(/'/g, "''")}'`)
      .join(",");
    await queryRunner.query(
      `ALTER TABLE ${tableName} MODIFY COLUMN ${columnName} ENUM(${enumSql}) NOT NULL COMMENT '${comment.replace(/'/g, "''")}'`,
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
      throw new Error("无法获取钱包充值迁移锁");
    }
    lockAcquired = true;

    await ensureRechargeTable(queryRunner);
    await ensureIndex(
      queryRunner,
      "UQ_wallet_recharge_no",
      ["rechargeNo"],
      true,
    );
    await ensureIndex(
      queryRunner,
      "UQ_wallet_recharge_idempotency",
      ["userId", "idempotencyKey"],
      true,
    );
    await ensureIndex(
      queryRunner,
      "UQ_wallet_recharge_payment",
      ["paymentNo"],
      true,
    );
    await ensureIndex(
      queryRunner,
      "UQ_wallet_recharge_transaction",
      ["walletTransactionId"],
      true,
    );
    await ensureIndex(queryRunner, "IDX_wallet_recharge_user_created", [
      "userId",
      "createdAt",
    ]);
    await ensureIndex(queryRunner, "IDX_wallet_recharge_status_updated", [
      "status",
      "updatedAt",
    ]);

    await ensureEnumValue(
      queryRunner,
      "payments",
      "businessType",
      "wallet_recharge",
      "业务类型（关联不同模块）",
    );
    await ensureEnumValue(
      queryRunner,
      "wallet_transactions",
      "relatedType",
      "recharge",
      "关联类型",
    );

    console.log(
      dryRun ? "钱包充值迁移检查完成，未修改数据库" : "钱包充值迁移执行完成",
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
    "钱包充值迁移失败:",
    error instanceof Error ? error.message : "未知错误",
  );
  process.exitCode = 1;
});
