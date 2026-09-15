/**
 * 为 lost_found_records 表补充媒体字段和记录类型字段
 *
 * 运行方式：ts-node migrations/add-lost-found-media-fields.ts
 */

import { DataSource } from 'typeorm'
import { LostFound } from '../src/lost-found/entities/lost-found.entity'

async function addLostFoundMediaFields() {
  console.log('开始为 lost_found_records 表添加媒体字段和记录类型字段...')

  const AppDataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_DATABASE || 'pet_hospitals',
    entities: [LostFound],
    synchronize: false,
  })

  try {
    await AppDataSource.initialize()
    console.log('数据库连接成功')

    const queryRunner = AppDataSource.createQueryRunner()

    try {
      const table = await queryRunner.getTable('lost_found_records')
      const recordTypeColumn = table?.findColumnByName('recordType')
      const imagesColumn = table?.findColumnByName('images')
      const videoColumn = table?.findColumnByName('video')
      const videoCoverColumn = table?.findColumnByName('videoCover')
      const hasRecordTypeIndex = table?.indices.some(
        (index) => index.name === 'idx_lost_found_record_type_created_at',
      )

      if (!recordTypeColumn) {
        await queryRunner.query(
          "ALTER TABLE lost_found_records ADD COLUMN recordType ENUM('LOST', 'ADOPTION') NOT NULL DEFAULT 'LOST' COMMENT '记录类型：LOST=走失，ADOPTION=领养' AFTER publisherType",
        )
        console.log('✅ 字段 recordType 添加成功')
      } else {
        console.log('⚠️  字段 recordType 已存在，跳过')
      }

      if (!imagesColumn) {
        await queryRunner.query(
          "ALTER TABLE lost_found_records ADD COLUMN images JSON NULL COMMENT '图片列表（最多 9 张）' AFTER description",
        )
        console.log('✅ 字段 images 添加成功')
      } else {
        console.log('⚠️  字段 images 已存在，跳过')
      }

      if (!videoColumn) {
        await queryRunner.query(
          "ALTER TABLE lost_found_records ADD COLUMN video VARCHAR(500) NULL COMMENT '视频 URL' AFTER images",
        )
        console.log('✅ 字段 video 添加成功')
      } else {
        console.log('⚠️  字段 video 已存在，跳过')
      }

      if (!videoCoverColumn) {
        await queryRunner.query(
          "ALTER TABLE lost_found_records ADD COLUMN videoCover VARCHAR(500) NULL COMMENT '视频封面图 URL' AFTER video",
        )
        console.log('✅ 字段 videoCover 添加成功')
      } else {
        console.log('⚠️  字段 videoCover 已存在，跳过')
      }

      if (!hasRecordTypeIndex) {
        await queryRunner.query(
          'CREATE INDEX idx_lost_found_record_type_created_at ON lost_found_records(recordType, isPinned, createdAt)',
        )
        console.log('✅ 索引 idx_lost_found_record_type_created_at 添加成功')
      } else {
        console.log('⚠️  索引 idx_lost_found_record_type_created_at 已存在，跳过')
      }
    } finally {
      await queryRunner.release()
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : '未知错误'
    console.error('❌ 添加 lost-found 媒体字段失败:', errorMessage)
    console.error('详细错误:', error)
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy()
    }
  }
}

void addLostFoundMediaFields()
