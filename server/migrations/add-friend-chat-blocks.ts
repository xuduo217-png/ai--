/**
 * Add the friend-only chat block table.
 *
 * Run with:
 *   ts-node migrations/add-friend-chat-blocks.ts
 */

import { DataSource } from "typeorm";

async function addFriendChatBlocks() {
  console.log("Starting friend chat blocks migration...");

  const appDataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "3306", 10),
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_DATABASE || "pet_hospitals",
    synchronize: false,
  });

  try {
    await appDataSource.initialize();
    const queryRunner = appDataSource.createQueryRunner();

    try {
      const table = await queryRunner.getTable("friend_chat_blocks");
      if (table) {
        console.log("friend_chat_blocks table already exists, skipped");
        return;
      }

      await queryRunner.query(`
        CREATE TABLE friend_chat_blocks (
          id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
          blockerUserId INT NOT NULL COMMENT '拉黑人ID',
          blockedUserId INT NOT NULL COMMENT '被拉黑用户ID',
          createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '拉黑时间',
          PRIMARY KEY (id),
          UNIQUE INDEX UQ_friend_chat_blocks_pair (blockerUserId, blockedUserId),
          INDEX IDX_friend_chat_blocks_blocked_user (blockedUserId)
        ) COMMENT='好友聊天拉黑关系表'
      `);
      console.log("Created friend_chat_blocks table");
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("Friend chat blocks migration failed:", message);
    console.error("Detailed error:", error);
    process.exitCode = 1;
  } finally {
    if (appDataSource.isInitialized) {
      await appDataSource.destroy();
    }
  }
}

void addFriendChatBlocks();
