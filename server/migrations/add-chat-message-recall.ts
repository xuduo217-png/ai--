/**
 * 为好友聊天、医患聊天和商城聊天补充消息撤回字段。
 *
 * 运行方式：ts-node migrations/add-chat-message-recall.ts
 */

import { DataSource, QueryRunner } from "typeorm";

async function addColumnIfMissing(
  queryRunner: QueryRunner,
  tableName: string,
  columnName: string,
  definition: string,
) {
  if (!(await queryRunner.hasTable(tableName))) {
    console.log(`表 ${tableName} 不存在，跳过`);
    return;
  }
  if (await queryRunner.hasColumn(tableName, columnName)) {
    console.log(`${tableName}.${columnName} 已存在，跳过`);
    return;
  }
  await queryRunner.query(
    `ALTER TABLE \`${tableName}\` ADD COLUMN \`${columnName}\` ${definition}`,
  );
  console.log(`已新增 ${tableName}.${columnName}`);
}

async function addChatMessageRecall() {
  const dataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "3306", 10),
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_DATABASE || "pet_hospitals",
    synchronize: false,
  });

  try {
    await dataSource.initialize();
    const queryRunner = dataSource.createQueryRunner();
    try {
      await addColumnIfMissing(
        queryRunner,
        "friend_messages",
        "isRevoked",
        "TINYINT NOT NULL DEFAULT 0 COMMENT '是否已撤回' AFTER `isRead`",
      );
      await addColumnIfMissing(
        queryRunner,
        "friend_messages",
        "revokedAt",
        "DATETIME NULL COMMENT '撤回时间' AFTER `isRevoked`",
      );
      await addColumnIfMissing(
        queryRunner,
        "marketplace_messages",
        "isRevoked",
        "TINYINT NOT NULL DEFAULT 0 COMMENT '是否已撤回' AFTER `isRead`",
      );
      await addColumnIfMissing(
        queryRunner,
        "marketplace_messages",
        "revokedAt",
        "DATETIME NULL COMMENT '撤回时间' AFTER `isRevoked`",
      );
      await addColumnIfMissing(
        queryRunner,
        "messages",
        "isRevoked",
        "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否已撤回' AFTER `isDeleted`",
      );
      await addColumnIfMissing(
        queryRunner,
        "messages",
        "revokedAt",
        "DATETIME NULL COMMENT '撤回时间' AFTER `isRevoked`",
      );
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    console.error("消息撤回字段迁移失败:", error);
    process.exitCode = 1;
  } finally {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  }
}

void addChatMessageRecall();
