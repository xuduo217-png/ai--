/**
 * 为 messages 表的 type 枚举补充 VIDEO
 *
 * 运行方式：ts-node migrations/add-chat-message-video-type.ts
 */

import { DataSource } from 'typeorm'
import { Message } from '../src/chat/entities/message.entity'

async function addChatMessageVideoType() {
  console.log('开始为 messages.type 枚举补充 VIDEO...')

  const appDataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_DATABASE || 'pet_hospitals',
    entities: [Message],
    synchronize: false,
  })

  try {
    await appDataSource.initialize()
    console.log('数据库连接成功')

    const queryRunner = appDataSource.createQueryRunner()

    try {
      const [rows] = await queryRunner.query(
        `
          SELECT COLUMN_TYPE AS columnType
          FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME = 'messages'
            AND COLUMN_NAME = 'type'
        `,
      )

      const columnType = Array.isArray(rows) ? rows[0]?.columnType : rows?.columnType
      if (!columnType) {
        throw new Error('未找到 messages.type 字段定义')
      }

      if (String(columnType).includes("'VIDEO'")) {
        console.log('⚠️  messages.type 已包含 VIDEO，跳过')
        return
      }

      await queryRunner.query(
        `
          ALTER TABLE messages
          MODIFY COLUMN type ENUM(
            'TEXT',
            'IMAGE',
            'VIDEO',
            'VOICE',
            'AI_CONSULTATION',
            'SYSTEM',
            'PAYMENT_SUCCESS',
            'PAYMENT_PROMPT'
          ) NOT NULL DEFAULT 'TEXT' COMMENT '消息类型'
        `,
      )

      console.log('✅ messages.type 已成功补充 VIDEO')
    } finally {
      await queryRunner.release()
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : '未知错误'
    console.error('❌ 更新 messages.type 失败:', errorMessage)
    console.error('详细错误:', error)
  } finally {
    await appDataSource.destroy()
  }
}

void addChatMessageVideoType()
