/**
 * Add vote option scope to activity comments.
 *
 * Run with:
 *   ts-node migrations/add-activity-comment-vote-option.ts
 */

import { DataSource } from 'typeorm';

async function addActivityCommentVoteOption() {
  console.log('Starting activity comment vote option migration...');

  const AppDataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_DATABASE || 'pet_hospitals',
    synchronize: false,
    connectTimeout: parseInt(process.env.DB_CONNECT_TIMEOUT || '30000', 10),
    extra: {
      enableKeepAlive: true,
      keepAliveInitialDelay: 0,
    },
  });

  try {
    await AppDataSource.initialize();
    console.log('Database connection established');

    const queryRunner = AppDataSource.createQueryRunner();

    try {
      const commentsTable = await queryRunner.getTable('activity_comments');
      if (!commentsTable) {
        throw new Error('activity_comments table not found');
      }

      const voteOptionColumn = commentsTable.findColumnByName('voteOptionId');
      if (!voteOptionColumn) {
        await queryRunner.query(`
          ALTER TABLE activity_comments
          ADD COLUMN voteOptionId INT NULL COMMENT '选手ID（为空表示活动级评论）' AFTER activityId
        `);
        console.log('Added activity_comments.voteOptionId');
      } else {
        console.log('activity_comments.voteOptionId already exists, skipped');
      }

      const latestCommentsTable = await queryRunner.getTable('activity_comments');
      if (!latestCommentsTable) {
        throw new Error('activity_comments table not found after column update');
      }

      const hasVoteOptionIndex = latestCommentsTable.indices.some(
        (index) => index.name === 'idx_activity_comments_vote_option_id',
      );
      if (!hasVoteOptionIndex) {
        await queryRunner.query(`
          CREATE INDEX idx_activity_comments_vote_option_id
          ON activity_comments(voteOptionId)
        `);
        console.log('Added idx_activity_comments_vote_option_id');
      } else {
        console.log('idx_activity_comments_vote_option_id already exists, skipped');
      }

      const hasVoteOptionForeignKey = latestCommentsTable.foreignKeys.some(
        (foreignKey) => foreignKey.columnNames.includes('voteOptionId'),
      );
      if (!hasVoteOptionForeignKey) {
        await queryRunner.query(`
          ALTER TABLE activity_comments
          ADD CONSTRAINT fk_activity_comments_vote_option
          FOREIGN KEY (voteOptionId)
          REFERENCES activity_vote_options(id)
          ON DELETE CASCADE
        `);
        console.log('Added fk_activity_comments_vote_option');
      } else {
        console.log('fk_activity_comments_vote_option already exists, skipped');
      }

      console.log('Activity comment vote option migration finished');
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Activity comment vote option migration failed:', message);
    console.error('Detailed error:', error);
    process.exitCode = 1;
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

void addActivityCommentVoteOption();
