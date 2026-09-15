/**
 * Add owner user id to activity vote options.
 *
 * Run with:
 *   ts-node migrations/add-activity-vote-option-owner.ts
 */

import { DataSource } from 'typeorm';

async function addActivityVoteOptionOwner() {
  console.log('Starting activity vote option owner migration...');

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
      const voteOptionsTable = await queryRunner.getTable('activity_vote_options');
      if (!voteOptionsTable) {
        throw new Error('activity_vote_options table not found');
      }

      const ownerUserIdColumn = voteOptionsTable.findColumnByName('ownerUserId');
      if (!ownerUserIdColumn) {
        await queryRunner.query(`
          ALTER TABLE activity_vote_options
          ADD COLUMN ownerUserId INT NULL COMMENT '所属用户ID（用户端报名添加时记录）' AFTER sortOrder
        `);
        console.log('Added activity_vote_options.ownerUserId');
      } else {
        console.log('activity_vote_options.ownerUserId already exists, skipped');
      }

      const hasOwnerUserIdIndex = voteOptionsTable.indices.some(
        (index) => index.name === 'idx_activity_vote_options_owner_user_id',
      );
      if (!hasOwnerUserIdIndex) {
        await queryRunner.query(`
          CREATE INDEX idx_activity_vote_options_owner_user_id
          ON activity_vote_options(ownerUserId)
        `);
        console.log('Added idx_activity_vote_options_owner_user_id');
      } else {
        console.log('idx_activity_vote_options_owner_user_id already exists, skipped');
      }

      const hasOwnerUserForeignKey = voteOptionsTable.foreignKeys.some(
        (foreignKey) => foreignKey.columnNames.includes('ownerUserId'),
      );
      if (!hasOwnerUserForeignKey) {
        await queryRunner.query(`
          ALTER TABLE activity_vote_options
          ADD CONSTRAINT fk_activity_vote_options_owner_user
          FOREIGN KEY (ownerUserId)
          REFERENCES users(id)
          ON DELETE SET NULL
        `);
        console.log('Added fk_activity_vote_options_owner_user');
      } else {
        console.log('fk_activity_vote_options_owner_user already exists, skipped');
      }

      console.log('Activity vote option owner migration finished');
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Activity vote option owner migration failed:', message);
    console.error('Detailed error:', error);
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

void addActivityVoteOptionOwner();
