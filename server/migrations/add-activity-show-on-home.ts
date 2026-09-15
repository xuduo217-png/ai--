/**
 * Add homepage display flag to activities.
 *
 * Run with:
 *   ts-node migrations/add-activity-show-on-home.ts
 */

import { DataSource } from 'typeorm';

async function addActivityShowOnHome() {
  console.log('Starting activity showOnHome migration...');

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

      const showOnHomeColumn = activitiesTable.findColumnByName('showOnHome');
      if (!showOnHomeColumn) {
        await queryRunner.query(`
          ALTER TABLE activities
          ADD COLUMN showOnHome TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否展示到首页' AFTER coverImage
        `);
        console.log('Added activities.showOnHome');
      } else {
        console.log('activities.showOnHome already exists, skipped');
      }

      const hasShowOnHomeIndex = activitiesTable.indices.some(
        (index) =>
          index.name === 'idx_activities_show_on_home' ||
          index.columnNames.includes('showOnHome'),
      );
      if (!hasShowOnHomeIndex) {
        await queryRunner.query(`
          CREATE INDEX idx_activities_show_on_home
          ON activities(showOnHome)
        `);
        console.log('Added idx_activities_show_on_home');
      } else {
        console.log('activities.showOnHome index already exists, skipped');
      }

      console.log('Activity showOnHome migration finished');
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Activity showOnHome migration failed:', message);
    console.error('Detailed error:', error);
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

void addActivityShowOnHome();
