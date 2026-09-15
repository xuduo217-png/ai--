/**
 * Add activity cover image and online voting options.
 *
 * Run with:
 *   ts-node migrations/add-activity-cover-and-vote-options.ts
 */

import { DataSource } from 'typeorm';

async function addActivityCoverAndVoteOptions() {
  console.log('Starting activity cover and vote options schema migration...');

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
      const activitiesTable = await queryRunner.getTable('activities');
      if (!activitiesTable) {
        throw new Error('activities table not found');
      }

      const coverImageColumn = activitiesTable.findColumnByName('coverImage');
      if (!coverImageColumn) {
        await queryRunner.query(`
          ALTER TABLE activities
          ADD COLUMN coverImage VARCHAR(500) NOT NULL DEFAULT '' COMMENT '活动封面图片URL' AFTER description
        `);
        console.log('Added activities.coverImage');
      } else {
        console.log('activities.coverImage already exists, skipped');
      }

      let registrationsTable = await queryRunner.getTable('activity_registrations');
      if (!registrationsTable) {
        throw new Error('activity_registrations table not found');
      }

      const voteOptionIdColumn = registrationsTable.findColumnByName('voteOptionId');
      if (!voteOptionIdColumn) {
        await queryRunner.query(`
          ALTER TABLE activity_registrations
          ADD COLUMN voteOptionId INT NULL COMMENT '投票选手ID（线上投票专用）' AFTER phone
        `);
        console.log('Added activity_registrations.voteOptionId');
      } else {
        console.log('activity_registrations.voteOptionId already exists, skipped');
      }

      const participationKeyColumn = registrationsTable.findColumnByName('participationKey');
      if (!participationKeyColumn) {
        await queryRunner.query(`
          ALTER TABLE activity_registrations
          ADD COLUMN participationKey VARCHAR(20) NOT NULL DEFAULT 'offline'
          COMMENT '参与唯一键：线下固定 offline，线上为投票日期 YYYY-MM-DD'
          AFTER voteOptionId
        `);
        console.log('Added activity_registrations.participationKey');
      } else {
        console.log('activity_registrations.participationKey already exists, skipped');
      }

      await queryRunner.query(`
        UPDATE activity_registrations
        SET participationKey = CASE
          WHEN voteOptionId IS NOT NULL
            THEN DATE_FORMAT(FROM_UNIXTIME(registeredAt / 1000), '%Y-%m-%d')
          ELSE 'offline'
        END
        WHERE participationKey = '' OR participationKey IS NULL OR participationKey = 'offline'
      `);
      console.log('Backfilled activity_registrations.participationKey');

      registrationsTable = await queryRunner.getTable('activity_registrations');
      if (!registrationsTable) {
        throw new Error('activity_registrations table not found after participationKey migration');
      }

      const legacyUniqueParticipationIndex = registrationsTable.indices.find((index) => {
        const columns = [...index.columnNames].sort();
        return index.isUnique && columns.length === 2 && columns[0] === 'activityId' && columns[1] === 'userId';
      });
      if (legacyUniqueParticipationIndex) {
        await queryRunner.dropIndex('activity_registrations', legacyUniqueParticipationIndex);
        console.log(`Dropped legacy unique index ${legacyUniqueParticipationIndex.name}`);
      } else {
        console.log('Legacy unique activity/user index not found, skipped');
      }

      const hasDailyParticipationUniqueIndex = registrationsTable.indices.some((index) => {
        const columns = [...index.columnNames].sort();
        return index.isUnique
          && columns.length === 3
          && columns[0] === 'activityId'
          && columns[1] === 'participationKey'
          && columns[2] === 'userId';
      });
      if (!hasDailyParticipationUniqueIndex) {
        await queryRunner.query(`
          CREATE UNIQUE INDEX idx_activity_registrations_participation_unique
          ON activity_registrations(activityId, userId, participationKey)
        `);
        console.log('Added idx_activity_registrations_participation_unique');
      } else {
        console.log('idx_activity_registrations_participation_unique already exists, skipped');
      }

      const voteOptionsTable = await queryRunner.getTable('activity_vote_options');
      if (!voteOptionsTable) {
        await queryRunner.query(`
          CREATE TABLE activity_vote_options (
            id INT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
            activityId INT NOT NULL COMMENT '活动ID',
            image VARCHAR(500) NOT NULL DEFAULT '' COMMENT '选手图片URL',
            video VARCHAR(500) NOT NULL DEFAULT '' COMMENT '选手视频URL',
            videoCover VARCHAR(500) NOT NULL DEFAULT '' COMMENT '选手视频缩略图URL',
            title VARCHAR(100) NOT NULL COMMENT '选手标题',
            description TEXT NULL COMMENT '选手描述',
            voteCount INT NOT NULL DEFAULT 0 COMMENT '票数',
            sortOrder INT NOT NULL DEFAULT 0 COMMENT '排序值',
            createdAt BIGINT NOT NULL COMMENT '创建时间（时间戳，毫秒）',
            updatedAt BIGINT NOT NULL COMMENT '更新时间（时间戳，毫秒）',
            PRIMARY KEY (id),
            INDEX idx_activity_vote_options_activity_id (activityId),
            INDEX idx_activity_vote_options_activity_sort (activityId, sortOrder),
            CONSTRAINT fk_activity_vote_options_activity
              FOREIGN KEY (activityId)
              REFERENCES activities(id)
              ON DELETE CASCADE
          ) COMMENT='活动投票选手表'
        `);
        console.log('Created activity_vote_options table');
      } else {
        console.log('activity_vote_options table already exists, skipped');

        const videoColumn = voteOptionsTable.findColumnByName('video');
        if (!videoColumn) {
          await queryRunner.query(`
            ALTER TABLE activity_vote_options
            ADD COLUMN video VARCHAR(500) NOT NULL DEFAULT '' COMMENT '选手视频URL' AFTER image
          `);
          console.log('Added activity_vote_options.video');
        } else {
          console.log('activity_vote_options.video already exists, skipped');
        }

        const videoCoverColumn = voteOptionsTable.findColumnByName('videoCover');
        if (!videoCoverColumn) {
          await queryRunner.query(`
            ALTER TABLE activity_vote_options
            ADD COLUMN videoCover VARCHAR(500) NOT NULL DEFAULT '' COMMENT '选手视频缩略图URL' AFTER video
          `);
          console.log('Added activity_vote_options.videoCover');
        } else {
          console.log('activity_vote_options.videoCover already exists, skipped');
        }
      }

      const hasVoteOptionIndex = registrationsTable.indices.some(
        (index) => index.name === 'idx_activity_registrations_vote_option_id',
      );
      if (!hasVoteOptionIndex) {
        await queryRunner.query(`
          CREATE INDEX idx_activity_registrations_vote_option_id
          ON activity_registrations(voteOptionId)
        `);
        console.log('Added idx_activity_registrations_vote_option_id');
      } else {
        console.log('idx_activity_registrations_vote_option_id already exists, skipped');
      }

      console.log('Activity cover and vote options schema migration finished');
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Activity cover and vote options schema migration failed:', message);
    console.error('Detailed error:', error);
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

void addActivityCoverAndVoteOptions();
