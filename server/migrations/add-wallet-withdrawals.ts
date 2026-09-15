/**
 * 钱包支付宝提现数据结构迁移。
 *
 * 检查：node --env-file=.env -r ts-node/register migrations/add-wallet-withdrawals.ts --dry-run
 * 执行：node --env-file=.env -r ts-node/register migrations/add-wallet-withdrawals.ts
 *
 * 生产执行前必须备份数据库并另行获得用户确认。
 */
import { DataSource, QueryRunner, TableColumn, TableIndex } from "typeorm";

const dryRun = process.argv.includes("--dry-run");
const lockName = "pet_hospitals_wallet_withdrawals_migration";

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

const withdrawalColumns: Array<{ name: string; sql: string }> = [
  { name: "id", sql: "id INT NOT NULL AUTO_INCREMENT PRIMARY KEY" },
  { name: "withdrawalNo", sql: "withdrawalNo VARCHAR(40) NOT NULL" },
  { name: "idempotencyKey", sql: "idempotencyKey VARCHAR(36) NOT NULL" },
  { name: "userId", sql: "userId INT NOT NULL" },
  { name: "walletTransactionId", sql: "walletTransactionId INT NULL" },
  { name: "amount", sql: "amount DECIMAL(10,2) NOT NULL" },
  {
    name: "status",
    sql: "status ENUM('pending_review','processing','succeeded','rejected','failed') NOT NULL DEFAULT 'pending_review'",
  },
  {
    name: "payeeIdentityType",
    sql: "payeeIdentityType ENUM('ALIPAY_LOGON_ID') NOT NULL DEFAULT 'ALIPAY_LOGON_ID'",
  },
  { name: "payeeAccountEncrypted", sql: "payeeAccountEncrypted TEXT NOT NULL" },
  { name: "payeeAccountMasked", sql: "payeeAccountMasked VARCHAR(160) NOT NULL" },
  { name: "payeeNameEncrypted", sql: "payeeNameEncrypted TEXT NOT NULL" },
  { name: "payeeNameMasked", sql: "payeeNameMasked VARCHAR(80) NOT NULL" },
  { name: "encryptionKeyVersion", sql: "encryptionKeyVersion VARCHAR(20) NOT NULL DEFAULT 'v1'" },
  { name: "outBizNo", sql: "outBizNo VARCHAR(64) NULL" },
  { name: "alipayOrderId", sql: "alipayOrderId VARCHAR(80) NULL" },
  { name: "payFundOrderId", sql: "payFundOrderId VARCHAR(80) NULL" },
  { name: "alipayStatus", sql: "alipayStatus VARCHAR(40) NULL" },
  { name: "failureCode", sql: "failureCode VARCHAR(80) NULL" },
  { name: "failureMessage", sql: "failureMessage VARCHAR(500) NULL" },
  { name: "reviewedBy", sql: "reviewedBy INT NULL" },
  { name: "reviewedAt", sql: "reviewedAt DATETIME NULL" },
  { name: "rejectReason", sql: "rejectReason TEXT NULL" },
  { name: "processingAt", sql: "processingAt DATETIME NULL" },
  { name: "completedAt", sql: "completedAt DATETIME NULL" },
  { name: "failedAt", sql: "failedAt DATETIME NULL" },
  { name: "version", sql: "version INT NOT NULL DEFAULT 1" },
  { name: "createdAt", sql: "createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)" },
  {
    name: "updatedAt",
    sql: "updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)",
  },
];

const logColumns: Array<{ name: string; sql: string }> = [
  { name: "id", sql: "id INT NOT NULL AUTO_INCREMENT PRIMARY KEY" },
  { name: "withdrawalId", sql: "withdrawalId INT NOT NULL" },
  { name: "fromStatus", sql: "fromStatus VARCHAR(30) NULL" },
  { name: "toStatus", sql: "toStatus VARCHAR(30) NOT NULL" },
  { name: "action", sql: "action VARCHAR(50) NOT NULL" },
  { name: "actorType", sql: "actorType ENUM('user','admin','system') NOT NULL" },
  { name: "actorId", sql: "actorId INT NULL" },
  { name: "externalCode", sql: "externalCode VARCHAR(80) NULL" },
  { name: "description", sql: "description VARCHAR(500) NULL" },
  { name: "createdAt", sql: "createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)" },
];

async function ensureTable(
  queryRunner: QueryRunner,
  tableName: string,
  columns: Array<{ name: string; sql: string }>,
) {
  let table = await queryRunner.getTable(tableName);
  if (!table) {
    console.log(`[${dryRun ? "CHECK" : "APPLY"}] create table ${tableName}`);
    if (!dryRun) {
      await queryRunner.query(
        `CREATE TABLE ${tableName} (${columns.map((column) => column.sql).join(", ")}) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
      );
      table = await queryRunner.getTable(tableName);
    }
  }
  for (const column of columns) {
    if (!table?.findColumnByName(column.name)) {
      console.log(`[${dryRun ? "CHECK" : "APPLY"}] add ${tableName}.${column.name}`);
      if (!dryRun) {
        await queryRunner.query(`ALTER TABLE ${tableName} ADD COLUMN ${column.sql}`);
      }
    }
  }
}

async function ensureIndex(
  queryRunner: QueryRunner,
  tableName: string,
  name: string,
  columns: string[],
  isUnique = false,
) {
  const table = await queryRunner.getTable(tableName);
  if (!table?.indices.some((index) => index.name === name)) {
    console.log(`[${dryRun ? "CHECK" : "APPLY"}] add index ${name}`);
    if (!dryRun) {
      await queryRunner.createIndex(
        tableName,
        new TableIndex({ name, columnNames: columns, isUnique }),
      );
    }
  }
}

async function migrate() {
  await dataSource.initialize();
  const queryRunner = dataSource.createQueryRunner();
  await queryRunner.connect();
  let lockAcquired = false;
  try {
    const [lock] = await queryRunner.query("SELECT GET_LOCK(?, 30) AS acquired", [
      lockName,
    ]);
    if (Number(lock?.acquired) !== 1) {
      throw new Error("无法获取钱包提现迁移锁");
    }
    lockAcquired = true;

    const users = await queryRunner.getTable("users");
    if (!users) throw new Error("users 表不存在");
    if (!users.findColumnByName("withdrawalFrozenBalance")) {
      console.log(
        `[${dryRun ? "CHECK" : "APPLY"}] add users.withdrawalFrozenBalance`,
      );
      if (!dryRun) {
        await queryRunner.addColumn(
          "users",
          new TableColumn({
            name: "withdrawalFrozenBalance",
            type: "decimal",
            precision: 10,
            scale: 2,
            default: "0.00",
            isNullable: false,
          }),
        );
      }
    }

    await ensureTable(queryRunner, "wallet_withdrawals", withdrawalColumns);
    await ensureTable(queryRunner, "wallet_withdrawal_logs", logColumns);

    await ensureIndex(queryRunner, "wallet_withdrawals", "UQ_wallet_withdrawal_no", ["withdrawalNo"], true);
    await ensureIndex(queryRunner, "wallet_withdrawals", "UQ_wallet_withdrawal_idempotency", ["userId", "idempotencyKey"], true);
    await ensureIndex(queryRunner, "wallet_withdrawals", "UQ_wallet_withdrawal_transaction", ["walletTransactionId"], true);
    await ensureIndex(queryRunner, "wallet_withdrawals", "UQ_wallet_withdrawal_out_biz_no", ["outBizNo"], true);
    await ensureIndex(queryRunner, "wallet_withdrawals", "IDX_wallet_withdrawal_user_created", ["userId", "createdAt"]);
    await ensureIndex(queryRunner, "wallet_withdrawals", "IDX_wallet_withdrawal_status_updated", ["status", "updatedAt"]);
    await ensureIndex(queryRunner, "wallet_withdrawal_logs", "IDX_wallet_withdrawal_log_created", ["withdrawalId", "createdAt"]);

    const walletTransactions = await queryRunner.getTable("wallet_transactions");
    const relatedType = walletTransactions?.findColumnByName("relatedType");
    const enumValues = relatedType?.enum || [];
    if (!enumValues.includes("adjustment")) {
      const preservedValues = [...new Set([...enumValues, "adjustment"])];
      if (preservedValues.length === 1) {
        throw new Error("无法读取 wallet_transactions.relatedType 现有 ENUM 值");
      }
      console.log(
        `[${dryRun ? "CHECK" : "APPLY"}] extend wallet_transactions.relatedType with adjustment`,
      );
      if (!dryRun) {
        const enumSql = preservedValues
          .map((value) => `'${value.replace(/'/g, "''")}'`)
          .join(",");
        await queryRunner.query(
          `ALTER TABLE wallet_transactions MODIFY COLUMN relatedType ENUM(${enumSql}) NOT NULL COMMENT '关联类型'`,
        );
      }
    }

    console.log(dryRun ? "钱包提现迁移检查完成，未修改数据库" : "钱包提现迁移执行完成");
  } finally {
    if (lockAcquired) {
      await queryRunner.query("SELECT RELEASE_LOCK(?)", [lockName]);
    }
    await queryRunner.release();
    await dataSource.destroy();
  }
}

migrate().catch((error) => {
  console.error("钱包提现迁移失败:", error instanceof Error ? error.message : "未知错误");
  process.exitCode = 1;
});
