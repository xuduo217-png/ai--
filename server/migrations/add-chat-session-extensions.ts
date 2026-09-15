/**
 * 为医生主动延长咨询时间创建审计表。
 * 检查：node --env-file=.env -r ts-node/register migrations/add-chat-session-extensions.ts --dry-run
 * 执行：node --env-file=.env -r ts-node/register migrations/add-chat-session-extensions.ts
 */
import { DataSource } from "typeorm";

const dryRun = process.argv.includes("--dry-run");
const lockName = "pet_hospitals_chat_session_extensions_migration";
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

async function migrate() {
  await dataSource.initialize();
  const runner = dataSource.createQueryRunner();
  await runner.connect();
  let lockAcquired = false;
  try {
    const [lock] = await runner.query("SELECT GET_LOCK(?, 30) AS acquired", [
      lockName,
    ]);
    if (Number(lock?.acquired) !== 1)
      throw new Error("无法获取聊天会话延长迁移锁");
    lockAcquired = true;
    const table = await runner.getTable("chat_session_extensions");
    if (table) {
      console.log("chat_session_extensions 已存在，无需修改");
    } else {
      console.log(
        `[${dryRun ? "CHECK" : "APPLY"}] 创建 chat_session_extensions`,
      );
      if (!dryRun) {
        await runner.query(`
          CREATE TABLE chat_session_extensions (
            id INT NOT NULL AUTO_INCREMENT,
            sessionId INT NOT NULL COMMENT '会话ID',
            conversationId VARCHAR(36) NOT NULL COMMENT '会话级唯一标识',
            orderId INT NOT NULL COMMENT '关联订单ID',
            doctorId INT NOT NULL COMMENT '医生ID',
            userId INT NOT NULL COMMENT '用户ID',
            extensionMinutes INT NOT NULL COMMENT '延长时长（分钟）',
            beforeServiceEndAt TIMESTAMP NOT NULL COMMENT '延长前服务结束时间',
            afterServiceEndAt TIMESTAMP NOT NULL COMMENT '延长后服务结束时间',
            reason VARCHAR(500) NULL COMMENT '延长原因',
            idempotencyKey VARCHAR(128) NOT NULL COMMENT '客户端幂等键',
            createdAt TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '延长时间',
            PRIMARY KEY (id),
            UNIQUE KEY IDX_chat_session_extensions_idempotency (idempotencyKey),
            KEY IDX_chat_session_extensions_conversation (conversationId, createdAt),
            KEY IDX_chat_session_extensions_doctor (doctorId, createdAt)
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='聊天会话延长记录'
        `);
      }
    }
    console.log(
      dryRun
        ? "聊天会话延长迁移检查完成，未修改数据库"
        : "聊天会话延长迁移执行完成",
    );
  } finally {
    if (lockAcquired) await runner.query("SELECT RELEASE_LOCK(?)", [lockName]);
    await runner.release();
    await dataSource.destroy();
  }
}

migrate().catch((error) => {
  console.error(
    "聊天会话延长迁移失败:",
    error instanceof Error ? error.message : "未知错误",
  );
  process.exitCode = 1;
});
