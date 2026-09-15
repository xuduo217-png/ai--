/**
 * 新增二手商城买卖聊天表，并扩展 UGC 举报目标类型。
 *
 * 运行方式：ts-node migrations/add-marketplace-chat.ts
 */

import { DataSource } from "typeorm";

async function addMarketplaceChat() {
  console.log("开始执行二手商城聊天迁移...");

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
      if (!(await queryRunner.hasTable("marketplace_conversations"))) {
        await queryRunner.query(`
          CREATE TABLE marketplace_conversations (
            id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
            conversationId VARCHAR(36) NOT NULL COMMENT '会话UUID',
            productId INT NOT NULL COMMENT '商品ID',
            buyerId INT NOT NULL COMMENT '买家ID',
            sellerId INT NOT NULL COMMENT '卖家ID',
            lastMessageId VARCHAR(36) NULL COMMENT '最后一条消息UUID',
            lastMessageType ENUM('text', 'image', 'voice', 'video') NULL COMMENT '最后一条消息类型',
            lastMessageContent TEXT NULL COMMENT '最后一条消息内容',
            lastMessageSenderId INT NULL COMMENT '最后一条消息发送人ID',
            lastMessageAt TIMESTAMP NULL COMMENT '最后消息时间',
            createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
            updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
            PRIMARY KEY (id),
            UNIQUE INDEX UQ_marketplace_conversation_id (conversationId),
            UNIQUE INDEX UQ_marketplace_conversation_participants (productId, buyerId, sellerId),
            INDEX IDX_marketplace_conversation_buyer (buyerId, lastMessageAt),
            INDEX IDX_marketplace_conversation_seller (sellerId, lastMessageAt)
          ) COMMENT='二手商城买卖双方会话表'
        `);
        console.log("已创建 marketplace_conversations");
      }

      if (!(await queryRunner.hasTable("marketplace_messages"))) {
        await queryRunner.query(`
          CREATE TABLE marketplace_messages (
            id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
            messageId VARCHAR(36) NOT NULL COMMENT '消息UUID',
            conversationId VARCHAR(36) NOT NULL COMMENT '会话UUID',
            senderId INT NOT NULL COMMENT '发送人ID',
            receiverId INT NOT NULL COMMENT '接收人ID',
            messageType ENUM('text', 'image', 'voice', 'video') NOT NULL COMMENT '消息类型',
            content TEXT NOT NULL COMMENT '消息内容',
            cloudFileUrl VARCHAR(500) NULL COMMENT '媒体文件URL',
            isRead TINYINT NOT NULL DEFAULT 0 COMMENT '是否已读',
            createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
            updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
            PRIMARY KEY (id),
            UNIQUE INDEX UQ_marketplace_message_id (messageId),
            INDEX IDX_marketplace_message_conversation (conversationId, createdAt),
            INDEX IDX_marketplace_message_sender (senderId, createdAt),
            INDEX IDX_marketplace_message_unread (receiverId, isRead, createdAt)
          ) COMMENT='二手商城聊天消息表'
        `);
        console.log("已创建 marketplace_messages");
      }

      if (await queryRunner.hasTable("ugc_reports")) {
        const targetTypeRows = await queryRunner.query(
          "SHOW COLUMNS FROM ugc_reports LIKE 'targetType'",
        );
        const currentType = String(targetTypeRows?.[0]?.Type || "");
        if (!currentType.includes("MARKETPLACE_MESSAGE")) {
          await queryRunner.query(`
            ALTER TABLE ugc_reports MODIFY COLUMN targetType ENUM(
              'COMMUNITY_POST',
              'COMMUNITY_COMMENT',
              'LOST_FOUND_RECORD',
              'LOST_FOUND_COMMENT',
              'ACTIVITY_COMMENT',
              'ACTIVITY_VOTE_OPTION',
              'SECOND_HAND_PRODUCT',
              'CHAT_MESSAGE',
              'MARKETPLACE_MESSAGE',
              'USER'
            ) NOT NULL COMMENT '举报目标类型'
          `);
          console.log("已扩展 ugc_reports.targetType");
        }
      }

      console.log("二手商城聊天迁移完成");
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    console.error("二手商城聊天迁移失败:", error);
    process.exitCode = 1;
  } finally {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  }
}

void addMarketplaceChat();
