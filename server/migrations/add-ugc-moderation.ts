/**
 * Add UGC report and user block tables for App Store user-generated content moderation.
 *
 * Run with:
 *   ts-node migrations/add-ugc-moderation.ts
 */

import { DataSource } from 'typeorm';

async function addUgcModeration() {
  console.log('Starting UGC moderation migration...');

  const AppDataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_DATABASE || 'pet_hospitals',
    synchronize: false,
  });

  try {
    await AppDataSource.initialize();
    console.log('Database connection established');

    const queryRunner = AppDataSource.createQueryRunner();

    try {
      const reportsTable = await queryRunner.getTable('ugc_reports');
      if (!reportsTable) {
        await queryRunner.query(`
          CREATE TABLE ugc_reports (
            id INT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
            reporterId INT NOT NULL COMMENT '举报人ID',
            targetType ENUM(
              'COMMUNITY_POST',
              'COMMUNITY_COMMENT',
              'LOST_FOUND_RECORD',
              'LOST_FOUND_COMMENT',
              'ACTIVITY_COMMENT',
              'ACTIVITY_VOTE_OPTION',
              'SECOND_HAND_PRODUCT',
              'CHAT_MESSAGE',
              'USER'
            ) NOT NULL COMMENT '举报目标类型',
            targetId VARCHAR(64) NOT NULL COMMENT '举报目标ID',
            targetUserId INT NULL COMMENT '被举报用户ID',
            reason ENUM(
              'HARASSMENT',
              'PORNOGRAPHY',
              'VIOLENCE',
              'FRAUD',
              'SPAM',
              'ILLEGAL',
              'MISINFORMATION',
              'OTHER'
            ) NOT NULL COMMENT '举报原因',
            description VARCHAR(500) NULL COMMENT '补充说明',
            targetSnapshot JSON NULL COMMENT '目标内容快照',
            status ENUM('PENDING', 'PROCESSING', 'RESOLVED', 'REJECTED') NOT NULL DEFAULT 'PENDING' COMMENT '处理状态',
            action ENUM('NONE', 'CONTENT_REMOVED', 'USER_WARNED', 'USER_BLOCKED', 'ACCOUNT_DISABLED') NOT NULL DEFAULT 'NONE' COMMENT '处理动作',
            handledBy INT NULL COMMENT '处理人ID',
            handlingRemark VARCHAR(500) NULL COMMENT '处理备注',
            handledAt TIMESTAMP NULL COMMENT '处理时间',
            createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
            updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
            PRIMARY KEY (id),
            INDEX IDX_ugc_reports_reporter_target (reporterId, targetType, targetId),
            INDEX IDX_ugc_reports_target (targetType, targetId),
            INDEX IDX_ugc_reports_status_created (status, createdAt),
            INDEX IDX_ugc_reports_target_user (targetUserId)
          ) COMMENT='UGC 举报记录表'
        `);
        console.log('Created ugc_reports table');
      } else {
        console.log('ugc_reports table already exists, skipped');
      }

      const blocksTable = await queryRunner.getTable('user_blocks');
      if (!blocksTable) {
        await queryRunner.query(`
          CREATE TABLE user_blocks (
            id INT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
            blockerId INT NOT NULL COMMENT '屏蔽人ID',
            blockedUserId INT NOT NULL COMMENT '被屏蔽用户ID',
            reason VARCHAR(200) NULL COMMENT '屏蔽原因',
            createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
            PRIMARY KEY (id),
            UNIQUE INDEX UQ_user_blocks_pair (blockerId, blockedUserId),
            INDEX IDX_user_blocks_blocked_user (blockedUserId)
          ) COMMENT='用户屏蔽关系表'
        `);
        console.log('Created user_blocks table');
      } else {
        console.log('user_blocks table already exists, skipped');
      }

      const voteOptionsTable = await queryRunner.getTable('activity_vote_options');
      const hasDeletedAt = voteOptionsTable?.findColumnByName('deletedAt');
      if (voteOptionsTable && !hasDeletedAt) {
        await queryRunner.query(`
          ALTER TABLE activity_vote_options
          ADD COLUMN deletedAt TIMESTAMP NULL COMMENT '软删除时间'
        `);
        console.log('Added activity_vote_options.deletedAt column');
      }

      console.log('UGC moderation migration finished');
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('UGC moderation migration failed:', message);
    console.error('Detailed error:', error);
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

void addUgcModeration();
