/**
 * Add charity donation support columns and enum values.
 *
 * Run with:
 *   ts-node migrations/add-charity-donation-support.ts
 */

import { DataSource } from "typeorm";

type ColumnTypeRow = {
  columnType?: string;
};

async function addCharityDonationSupport() {
  console.log("Starting charity donation schema migration...");

  const AppDataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "3306", 10),
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_DATABASE || "pet_hospitals",
    synchronize: false,
  });

  try {
    await AppDataSource.initialize();
    console.log("Database connection established");

    const queryRunner = AppDataSource.createQueryRunner();

    try {
      const charityRecordsTable = await queryRunner.getTable("charity_records");
      if (!charityRecordsTable) {
        throw new Error("charity_records table not found");
      }

      const checkInDateColumn =
        charityRecordsTable.findColumnByName("checkInDate");
      if (checkInDateColumn && !checkInDateColumn.isNullable) {
        await queryRunner.query(`
          ALTER TABLE charity_records
          MODIFY COLUMN checkInDate DATE NULL COMMENT '打卡日期(YYYY-MM-DD)，捐款记录可为空'
        `);
        console.log("Updated charity_records.checkInDate to nullable");
      } else {
        console.log("charity_records.checkInDate already nullable, skipped");
      }

      const donationAmountColumn =
        charityRecordsTable.findColumnByName("donationAmount");
      if (!donationAmountColumn) {
        await queryRunner.query(`
          ALTER TABLE charity_records
          ADD COLUMN donationAmount DECIMAL(10,2) NULL DEFAULT 0 COMMENT '捐款金额（元，捐款类型公益专用）' AFTER taskEvidence
        `);
        console.log("Added charity_records.donationAmount");
      } else {
        console.log("charity_records.donationAmount already exists, skipped");
      }

      const walletTransactionsTable = await queryRunner.getTable(
        "wallet_transactions",
      );
      if (!walletTransactionsTable) {
        throw new Error("wallet_transactions table not found");
      }

      const relatedTypeColumn =
        walletTransactionsTable.findColumnByName("relatedType");
      if (!relatedTypeColumn) {
        throw new Error("wallet_transactions.relatedType column not found");
      }

      const queryResult = (await queryRunner.query(`
        SELECT COLUMN_TYPE AS columnType
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'wallet_transactions'
          AND COLUMN_NAME = 'relatedType'
      `)) as ColumnTypeRow[] | ColumnTypeRow;

      const columnType = Array.isArray(queryResult)
        ? queryResult[0]?.columnType
        : queryResult?.columnType;

      if (!String(columnType).includes("'charity'")) {
        await queryRunner.query(`
          ALTER TABLE wallet_transactions
          MODIFY COLUMN relatedType ENUM('order', 'refund', 'recharge', 'withdraw', 'charity') NOT NULL COMMENT '关联类型'
        `);
        console.log("Updated wallet_transactions.relatedType enum");
      } else {
        console.log(
          "wallet_transactions.relatedType already supports charity, skipped",
        );
      }

      console.log("✅ Charity donation schema migration finished");
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("❌ Charity donation schema migration failed:", message);
    console.error("Detailed error:", error);
  } finally {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}

void addCharityDonationSupport();
