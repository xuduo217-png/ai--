import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 添加健康相关字段到 pets 表
 * 创建 health_appointments 表
 */
export class AddHealthFields1698888888888 implements MigrationInterface {
  name = 'AddHealthFields1698888888888';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 为 pets 表添加健康相关字段
    await queryRunner.query(`
      ALTER TABLE \`pets\`
      ADD COLUMN \`lastDewormingAt\` date NULL COMMENT '上次驱虫时间' AFTER \`consultationCount\`,
      ADD COLUMN \`nextDewormingAt\` date NULL COMMENT '下次驱虫时间' AFTER \`lastDewormingAt\`,
      ADD COLUMN \`lastVaccineAt\` date NULL COMMENT '上次疫苗时间' AFTER \`nextDewormingAt\`,
      ADD COLUMN \`nextVaccineAt\` date NULL COMMENT '下次疫苗时间' AFTER \`lastVaccineAt\`,
      ADD COLUMN \`lastCheckupAt\` date NULL COMMENT '上次体检时间' AFTER \`nextVaccineAt\`,
      ADD COLUMN \`nextCheckupAt\` date NULL COMMENT '下次体检时间' AFTER \`lastCheckupAt\`,
      ADD COLUMN \`vaccineCount\` int DEFAULT 0 COMMENT '疫苗接种针数' AFTER \`nextCheckupAt\`,
      ADD COLUMN \`dewormingCount\` int DEFAULT 0 COMMENT '驱虫次数' AFTER \`vaccineCount\`,
      ADD COLUMN \`checkupCount\` int DEFAULT 0 COMMENT '体检次数' AFTER \`dewormingCount\`
    `);

    // 创建 health_appointments 表
    await queryRunner.query(`
      CREATE TABLE \`health_appointments\` (
        \`id\` int NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
        \`type\` enum('vaccine','deworming','checkup') NOT NULL COMMENT '预约类型',
        \`status\` enum('pending','confirmed','completed','cancelled') NOT NULL DEFAULT 'pending' COMMENT '预约状态',
        \`appointmentDate\` date NOT NULL COMMENT '预约日期',
        \`timeSlot\` varchar(20) NOT NULL COMMENT '预约时间段',
        \`petId\` int NOT NULL COMMENT '宠物ID',
        \`hospitalId\` int NOT NULL COMMENT '医院ID',
        \`userId\` int NOT NULL COMMENT '用户ID',
        \`notes\` text NULL COMMENT '备注',
        \`createdAt\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
        \`updatedAt\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
        \`deletedAt\` timestamp NULL COMMENT '删除时间',
        INDEX \`idx_status\` (\`status\`),
        INDEX \`idx_userId\` (\`userId\`),
        INDEX \`idx_petId\` (\`petId\`),
        INDEX \`idx_hospitalId\` (\`hospitalId\`),
        INDEX \`idx_appointmentDate\` (\`appointmentDate\`),
        INDEX \`idx_userId_deletedAt\` (\`userId\`, \`deletedAt\`),
        INDEX \`idx_type\` (\`type\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='健康预约表'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // 删除 health_appointments 表
    await queryRunner.query(`DROP TABLE \`health_appointments\``);

    // 移除 pets 表的健康相关字段
    await queryRunner.query(`
      ALTER TABLE \`pets\`
      DROP COLUMN \`lastDewormingAt\`,
      DROP COLUMN \`nextDewormingAt\`,
      DROP COLUMN \`lastVaccineAt\`,
      DROP COLUMN \`nextVaccineAt\`,
      DROP COLUMN \`lastCheckupAt\`,
      DROP COLUMN \`nextCheckupAt\`,
      DROP COLUMN \`vaccineCount\`,
      DROP COLUMN \`dewormingCount\`,
      DROP COLUMN \`checkupCount\`
    `);
  }
}
