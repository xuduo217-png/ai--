/**
 * Add soft delete columns for good deeds charity and activities.
 *
 * Run with:
 *   ts-node migrations/add-good-deeds-soft-delete.ts
 */

import { DataSource } from 'typeorm';

async function addGoodDeedsSoftDelete() {
  console.log('Starting good deeds soft delete schema migration...');

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
      for (const tableName of ['charities', 'activities']) {
        const table = await queryRunner.getTable(tableName);
        if (!table) {
          throw new Error(`${tableName} table not found`);
        }

        const deletedAtColumn = table.findColumnByName('deletedAt');
        if (!deletedAtColumn) {
          await queryRunner.query(`
            ALTER TABLE ${tableName}
            ADD COLUMN deletedAt TIMESTAMP NULL COMMENT '删除时间（软删除）' AFTER updatedAt
          `);
          console.log(`Added ${tableName}.deletedAt`);
        } else {
          console.log(`${tableName}.deletedAt already exists, skipped`);
        }

        const indexName = `idx_${tableName}_deleted_at`;
        const hasDeletedAtIndex = table.indices.some(
          (index) => index.name === indexName || index.columnNames.includes('deletedAt'),
        );
        if (!hasDeletedAtIndex) {
          await queryRunner.query(`
            CREATE INDEX ${indexName}
            ON ${tableName}(deletedAt)
          `);
          console.log(`Added ${indexName}`);
        } else {
          console.log(`${tableName}.deletedAt index already exists, skipped`);
        }
      }

      console.log('Good deeds soft delete schema migration finished');
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Good deeds soft delete schema migration failed:', message);
    console.error('Detailed error:', error);
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

void addGoodDeedsSoftDelete();
