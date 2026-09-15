import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 宠物管理功能重构 - 分类字段迁移
 *
 * 变更内容：
 * 1. 删除 type 和 breed 字段
 * 2. 修改 gender 字段类型（从字符串枚举改为数字：1=弟弟，2=妹妹）
 * 3. 添加 categoryId 和 subCategoryId 字段
 * 4. 添加外键约束和索引
 * 5. 删除 notes, medicalHistory, allergies 字段
 */
export class RefactorPetCategoryFields1705984000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. 删除旧索引
    await queryRunner.query(`DROP INDEX IF EXISTS type ON pets`);

    // 2. 删除旧字段
    await queryRunner.query(`ALTER TABLE pets DROP COLUMN IF EXISTS type`);
    await queryRunner.query(`ALTER TABLE pets DROP COLUMN IF EXISTS breed`);
    await queryRunner.query(`ALTER TABLE pets DROP COLUMN IF EXISTS notes`);
    await queryRunner.query(
      `ALTER TABLE pets DROP COLUMN IF EXISTS medicalHistory`,
    );
    await queryRunner.query(`ALTER TABLE pets DROP COLUMN IF EXISTS allergies`);

    // 3. 修改 gender 字段类型（从 ENUM 字符串改为 TINYINT）
    await queryRunner.query(`
      ALTER TABLE pets
      MODIFY COLUMN gender TINYINT NOT NULL COMMENT '性别：1=弟弟，2=妹妹'
    `);

    // 4. 添加新字段（categoryId 和 subCategoryId）
    await queryRunner.query(`
      ALTER TABLE pets
      ADD COLUMN categoryId INT NULL COMMENT '一级分类ID（类型）' AFTER avatar
    `);

    await queryRunner.query(`
      ALTER TABLE pets
      ADD COLUMN subCategoryId INT NULL COMMENT '二级分类ID（种类）' AFTER categoryId
    `);

    // 5. 添加外键约束
    await queryRunner.query(`
      ALTER TABLE pets
      ADD CONSTRAINT fk_pet_category
      FOREIGN KEY (categoryId) REFERENCES pet_categories(id) ON DELETE SET NULL
    `);

    await queryRunner.query(`
      ALTER TABLE pets
      ADD CONSTRAINT fk_pet_subcategory
      FOREIGN KEY (subCategoryId) REFERENCES pet_categories(id) ON DELETE SET NULL
    `);

    // 6. 添加索引
    await queryRunner.query(
      `CREATE INDEX idx_pet_categoryId ON pets(categoryId)`,
    );
    await queryRunner.query(
      `CREATE INDEX idx_pet_subCategoryId ON pets(subCategoryId)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // 回滚：删除新字段和约束
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_pet_subCategoryId ON pets`,
    );
    await queryRunner.query(`DROP INDEX IF EXISTS idx_pet_categoryId ON pets`);

    await queryRunner.query(
      `ALTER TABLE pets DROP FOREIGN KEY fk_pet_subcategory`,
    );
    await queryRunner.query(
      `ALTER TABLE pets DROP FOREIGN KEY fk_pet_category`,
    );

    await queryRunner.query(
      `ALTER TABLE pets DROP COLUMN IF EXISTS subCategoryId`,
    );
    await queryRunner.query(
      `ALTER TABLE pets DROP COLUMN IF EXISTS categoryId`,
    );

    // 回滚：恢复旧字段和类型
    await queryRunner.query(`
      ALTER TABLE pets
      MODIFY COLUMN gender ENUM('male', 'female') NOT NULL COMMENT '性别'
    `);

    await queryRunner.query(`
      ALTER TABLE pets
      ADD COLUMN type ENUM('dog', 'cat', 'bird', 'other') NOT NULL COMMENT '宠物类型' AFTER avatar
    `);

    await queryRunner.query(`
      ALTER TABLE pets
      ADD COLUMN breed VARCHAR(100) NULL COMMENT '品种' AFTER type
    `);

    await queryRunner.query(`
      ALTER TABLE pets
      ADD COLUMN notes TEXT NULL COMMENT '备注' AFTER weight
    `);

    await queryRunner.query(`
      ALTER TABLE pets
      ADD COLUMN medicalHistory TEXT NULL COMMENT '既往病史' AFTER deletedAt
    `);

    await queryRunner.query(`
      ALTER TABLE pets
      ADD COLUMN allergies TEXT NULL COMMENT '过敏史' AFTER medicalHistory
    `);

    await queryRunner.query(`CREATE INDEX type ON pets(type)`);
  }
}
