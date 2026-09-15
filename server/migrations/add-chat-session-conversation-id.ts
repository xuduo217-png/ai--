/**
 * 为 `chat_sessions` 表新增持久化 `conversationId` 字段并回填历史数据
 *
 * 运行方式：
 * - 预检：`DRY_RUN=1 ts-node migrations/add-chat-session-conversation-id.ts`
 * - 正式：`ts-node migrations/add-chat-session-conversation-id.ts`
 *
 * 说明：
 * - 脚本会优先读取当前进程环境变量；
 * - 若未显式传入数据库配置，则回退读取 `server/.env`。
 */

import { randomUUID } from "crypto";
import { existsSync, readFileSync } from "fs";
import { resolve } from "path";
import { DataSource, QueryRunner } from "typeorm";

const TABLE_NAME = "chat_sessions";
const COLUMN_NAME = "conversationId";
const INDEX_NAME = "uk_chat_sessions_conversation_id";
const DEFAULT_ENV_PATH = resolve(__dirname, "..", ".env");

type CountRow = { count: number | string };
type ColumnRow = { columnName: string; isNullable: "YES" | "NO" };
type IndexRow = { indexName: string; nonUnique: number | string };

/**
 * 迁移脚本独立于 Nest 启动链路运行，不能依赖 ConfigModule。
 * 这里按最小需求读取 `.env`，并且不覆盖调用方显式传入的环境变量。
 */
function loadLocalEnv(filePath: string = DEFAULT_ENV_PATH) {
  if (!existsSync(filePath)) {
    return;
  }

  const content = readFileSync(filePath, "utf8");
  const lines = content.split(/\r?\n/);

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = line.indexOf("=");
    if (separatorIndex <= 0) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    const value = line.slice(separatorIndex + 1).trim();

    if (!key || process.env[key] !== undefined) {
      continue;
    }

    // 兼容简单的双引号/单引号包裹形式，避免把引号本身写入环境变量。
    process.env[key] = value.replace(/^['"]|['"]$/g, "");
  }
}

function getCountValue(rows: CountRow[]): number {
  return Number(rows[0]?.count ?? 0);
}

async function queryColumnState(queryRunner: QueryRunner) {
  const rows = await queryRunner.query(
    `
      SELECT
        COLUMN_NAME AS columnName,
        IS_NULLABLE AS isNullable
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ?
        AND COLUMN_NAME = ?
    `,
    [TABLE_NAME, COLUMN_NAME],
  );

  return Array.isArray(rows) ? (rows[0] as ColumnRow | undefined) : undefined;
}

async function queryIndexState(queryRunner: QueryRunner) {
  const rows = await queryRunner.query(
    `
      SELECT
        INDEX_NAME AS indexName,
        NON_UNIQUE AS nonUnique
      FROM INFORMATION_SCHEMA.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ?
        AND INDEX_NAME = ?
    `,
    [TABLE_NAME, INDEX_NAME],
  );

  return Array.isArray(rows) ? (rows as IndexRow[]) : [];
}

async function countRowsToBackfill(
  queryRunner: QueryRunner,
  columnExists: boolean,
) {
  if (!columnExists) {
    const rows = await queryRunner.query(
      `SELECT COUNT(*) AS count FROM ${TABLE_NAME}`,
    );
    return getCountValue(rows as CountRow[]);
  }

  const rows = await queryRunner.query(
    `
      SELECT COUNT(*) AS count
      FROM ${TABLE_NAME}
      WHERE ${COLUMN_NAME} IS NULL OR ${COLUMN_NAME} = ''
    `,
  );
  return getCountValue(rows as CountRow[]);
}

async function queryDuplicateConversationIds(queryRunner: QueryRunner) {
  return queryRunner.query(
    `
      SELECT ${COLUMN_NAME} AS conversationId, COUNT(*) AS count
      FROM ${TABLE_NAME}
      WHERE ${COLUMN_NAME} IS NOT NULL AND ${COLUMN_NAME} <> ''
      GROUP BY ${COLUMN_NAME}
      HAVING COUNT(*) > 1
      LIMIT 5
    `,
  );
}

async function addChatSessionConversationId() {
  loadLocalEnv();
  const isDryRun = process.env.DRY_RUN === "1";
  console.log(
    isDryRun
      ? "开始预检 chat_sessions.conversationId 迁移..."
      : "开始执行 chat_sessions.conversationId 迁移...",
  );

  const appDataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "3306", 10),
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_DATABASE || "pet_hospitals",
    // 脚本只执行原生 SQL，不需要加载实体，避免关联元数据缺失导致初始化失败。
    entities: [],
    synchronize: false,
  });

  try {
    await appDataSource.initialize();
    console.log("数据库连接成功");

    const queryRunner = appDataSource.createQueryRunner();

    try {
      const columnState = await queryColumnState(queryRunner);
      const indexRows = await queryIndexState(queryRunner);
      const columnExists = Boolean(columnState);
      const uniqueIndexExists = indexRows.some(
        (row) => Number(row.nonUnique) === 0,
      );
      const backfillCount = await countRowsToBackfill(
        queryRunner,
        columnExists,
      );

      console.log(`字段存在: ${columnExists ? "是" : "否"}`);
      console.log(`字段可空: ${columnState?.isNullable ?? "N/A"}`);
      console.log(`唯一索引存在: ${uniqueIndexExists ? "是" : "否"}`);
      console.log(`待回填行数: ${backfillCount}`);

      if (isDryRun) {
        console.log("DRY_RUN=1，仅输出预检结果，不执行任何 DDL / UPDATE");
        return;
      }

      if (!columnExists) {
        console.log(`新增列: ${TABLE_NAME}.${COLUMN_NAME}`);
        await queryRunner.query(
          `
            ALTER TABLE ${TABLE_NAME}
            ADD COLUMN ${COLUMN_NAME} VARCHAR(36) NULL COMMENT '会话级唯一标识'
            AFTER doctorId
          `,
        );
      }

      const rowsToBackfill = await queryRunner.query(
        `
          SELECT id
          FROM ${TABLE_NAME}
          WHERE ${COLUMN_NAME} IS NULL OR ${COLUMN_NAME} = ''
          ORDER BY id ASC
        `,
      );

      for (const row of rowsToBackfill as Array<{ id: number }>) {
        await queryRunner.query(
          `
            UPDATE ${TABLE_NAME}
            SET ${COLUMN_NAME} = ?
            WHERE id = ?
          `,
          [randomUUID(), row.id],
        );
      }

      const emptyRows = await queryRunner.query(
        `
          SELECT COUNT(*) AS count
          FROM ${TABLE_NAME}
          WHERE ${COLUMN_NAME} IS NULL OR ${COLUMN_NAME} = ''
        `,
      );
      const emptyCount = getCountValue(emptyRows as CountRow[]);
      if (emptyCount > 0) {
        throw new Error(`仍有 ${emptyCount} 条会话缺少 conversationId`);
      }

      const duplicateRows = await queryDuplicateConversationIds(queryRunner);
      if (Array.isArray(duplicateRows) && duplicateRows.length > 0) {
        throw new Error(
          `检测到重复 conversationId，示例: ${JSON.stringify(duplicateRows)}`,
        );
      }

      if (indexRows.length > 0 && !uniqueIndexExists) {
        console.log(`发现同名非唯一索引，先删除再重建: ${INDEX_NAME}`);
        await queryRunner.query(
          `ALTER TABLE ${TABLE_NAME} DROP INDEX ${INDEX_NAME}`,
        );
      }

      if (!uniqueIndexExists) {
        console.log(`创建唯一索引: ${INDEX_NAME}`);
        await queryRunner.query(
          `
            ALTER TABLE ${TABLE_NAME}
            ADD UNIQUE INDEX ${INDEX_NAME} (${COLUMN_NAME})
          `,
        );
      }

      const latestColumnState = await queryColumnState(queryRunner);
      if (latestColumnState?.isNullable === "YES") {
        console.log(`收紧字段为 NOT NULL: ${TABLE_NAME}.${COLUMN_NAME}`);
        await queryRunner.query(
          `
            ALTER TABLE ${TABLE_NAME}
            MODIFY COLUMN ${COLUMN_NAME} VARCHAR(36) NOT NULL COMMENT '会话级唯一标识'
          `,
        );
      }

      console.log("✅ chat_sessions.conversationId 迁移完成");
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : "未知错误";
    console.error("❌ 迁移 chat_sessions.conversationId 失败:", errorMessage);
    console.error("详细错误:", error);
  } finally {
    if (appDataSource.isInitialized) {
      await appDataSource.destroy();
    }
  }
}

void addChatSessionConversationId();
