/**
 * 初始化医疗咨询基础配置
 *
 * 运行方式：ts-node migrations/add-medical-consultation-config.ts
 */

import { DataSource } from "typeorm";

const MEDICAL_CONSULTATION_CONFIG_KEY = "medical_consultation_config";
const DEFAULT_PAYMENT_PROMPT_DISCLAIMER =
  "在线咨询仅供宠物健康管理参考，不能替代线下诊疗。若宠物出现急症或症状加重，请及时前往正规宠物医院就诊。";

async function addMedicalConsultationConfig() {
  console.log("开始初始化医疗咨询基础配置...");

  const appDataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "3306", 10),
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_DATABASE || "pet_hospitals",
    synchronize: false,
  });

  try {
    await appDataSource.initialize();
    console.log("数据库连接成功");

    const queryRunner = appDataSource.createQueryRunner();

    try {
      const existingRows: unknown = await queryRunner.query(
        "SELECT id FROM system_configs WHERE configKey = ? LIMIT 1",
        [MEDICAL_CONSULTATION_CONFIG_KEY],
      );

      if (Array.isArray(existingRows) && existingRows.length > 0) {
        console.log("医疗咨询基础配置已存在，跳过");
        return;
      }

      await queryRunner.query(
        `
          INSERT INTO system_configs
            (configKey, configValue, description, createdAt, updatedAt)
          VALUES
            (?, ?, ?, NOW(), NOW())
        `,
        [
          MEDICAL_CONSULTATION_CONFIG_KEY,
          JSON.stringify({
            paymentPromptDisclaimer: DEFAULT_PAYMENT_PROMPT_DISCLAIMER,
          }),
          "医疗咨询基础配置",
        ],
      );

      console.log("✅ 医疗咨询基础配置初始化完成");
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : "未知错误";
    console.error("❌ 初始化医疗咨询基础配置失败:", errorMessage);
    console.error("详细错误:", error);
    process.exitCode = 1;
  } finally {
    if (appDataSource.isInitialized) {
      await appDataSource.destroy();
    }
  }
}

void addMedicalConsultationConfig();
