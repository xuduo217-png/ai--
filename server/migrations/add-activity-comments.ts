/**
 * Create independent comments table for online vote activities.
 *
 * Run with:
 *   ts-node migrations/add-activity-comments.ts
 */

import { DataSource } from 'typeorm';

async function addActivityComments() {
  console.log('Starting activity comments migration...');

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
      const activityCommentsTable = await queryRunner.getTable('activity_comments');

      if (!activityCommentsTable) {
        await queryRunner.query(`
          CREATE TABLE activity_comments (
            id INT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
            activityId INT NOT NULL COMMENT '活动ID',
            userId INT NOT NULL COMMENT '评论用户ID',
            parentId INT NULL COMMENT '父评论ID（用于回复）',
            content TEXT NOT NULL COMMENT '评论内容',
            likeCount INT NOT NULL DEFAULT 0 COMMENT '点赞数（预留）',
            createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
            updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
            deletedAt TIMESTAMP NULL COMMENT '删除时间（软删除）',
            PRIMARY KEY (id),
            INDEX IDX_activity_comments_activity_id (activityId),
            INDEX IDX_activity_comments_user_id (userId),
            INDEX IDX_activity_comments_parent_id (parentId),
            CONSTRAINT fk_activity_comments_activity
              FOREIGN KEY (activityId)
              REFERENCES activities(id)
              ON DELETE CASCADE,
            CONSTRAINT fk_activity_comments_user
              FOREIGN KEY (userId)
              REFERENCES users(id),
            CONSTRAINT fk_activity_comments_parent
              FOREIGN KEY (parentId)
              REFERENCES activity_comments(id)
              ON DELETE CASCADE
          ) COMMENT='活动评论表'
        `);
        console.log('Created activity_comments table');
      } else {
        console.log('activity_comments table already exists, skipped');
      }

      console.log('Activity comments migration finished');
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Activity comments migration failed:', message);
    console.error('Detailed error:', error);
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

void addActivityComments();
