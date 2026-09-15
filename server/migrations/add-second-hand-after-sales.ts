/**
 * 二手交易闭环数据库迁移。
 *
 * 运行方式：node --env-file=.env -r ts-node/register migrations/add-second-hand-after-sales.ts
 * 迁移可重复执行；执行前应备份生产数据库并检查异常清单表。
 */
import { DataSource, QueryRunner, TableColumn } from "typeorm";

interface HistoricalOrderRow {
  id: number;
  orderType: string;
  sellerId: number | null;
  items: unknown;
}

interface ProductOwnerRow {
  id: number;
  publishSource: string;
  publishedBy: number | null;
}

function parseOrderItems(value: unknown): Array<Record<string, unknown>> {
  if (Array.isArray(value)) return value;
  if (typeof value !== "string") return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

async function recordHistoricalAnomalies(queryRunner: QueryRunner) {
  const orders = (await queryRunner.query(
    "SELECT id, orderType, sellerId, items FROM orders",
  )) as HistoricalOrderRow[];
  const productIds = [
    ...new Set(
      orders.flatMap((order) =>
        parseOrderItems(order.items)
          .map((item) => Number(item.productId))
          .filter((id) => Number.isInteger(id) && id > 0),
      ),
    ),
  ];
  const products = productIds.length
    ? ((await queryRunner.query(
        `SELECT id, publishSource, publishedBy FROM products
         WHERE id IN (${productIds.map(() => "?").join(", ")})`,
        productIds,
      )) as ProductOwnerRow[])
    : [];
  const productMap = new Map(
    products.map((product) => [Number(product.id), product]),
  );

  for (const order of orders) {
    const items = parseOrderItems(order.items);
    const linkedProducts = items
      .map((item) => productMap.get(Number(item.productId)))
      .filter((product): product is ProductOwnerRow => Boolean(product));
    const userProducts = linkedProducts.filter(
      (product) => product.publishSource === "USER",
    );
    const nonUserProducts = linkedProducts.filter(
      (product) => product.publishSource !== "USER",
    );
    const sellerIds = new Set(
      userProducts
        .map((product) => Number(product.publishedBy))
        .filter((id) => Number.isInteger(id) && id > 0),
    );
    const anomalies: Array<{ type: string; detail: string }> = [];

    if (userProducts.length > 0 && nonUserProducts.length > 0) {
      anomalies.push({
        type: "MIXED_PUBLISH_SOURCE",
        detail: "同一订单同时包含平台商品和二手商品，需要人工拆分或核对",
      });
    }
    if (sellerIds.size > 1) {
      anomalies.push({
        type: "MULTIPLE_SECOND_HAND_SELLERS",
        detail: "同一订单包含多个二手卖家，需要人工核对",
      });
    }
    const invalidUserOrder =
      userProducts.length > 0 &&
      (items.length !== 1 ||
        Number(items[0]?.quantity) !== 1 ||
        sellerIds.size !== 1);
    const invalidKnownSecondHandOrder =
      order.orderType === "second_hand" &&
      (items.length !== 1 || !order.sellerId);
    if (invalidUserOrder || invalidKnownSecondHandOrder) {
      anomalies.push({
        type: "INVALID_SECOND_HAND_SHAPE",
        detail: "二手订单不是单商品、数量不为1或卖家无法确定，需要人工核对",
      });
    }

    for (const anomaly of anomalies) {
      await queryRunner.query(
        `INSERT IGNORE INTO order_migration_anomalies
          (orderId, anomalyType, detail) VALUES (?, ?, ?)`,
        [order.id, anomaly.type, anomaly.detail],
      );
    }
  }
}

async function addColumnIfMissing(
  queryRunner: QueryRunner,
  tableName: string,
  column: TableColumn,
) {
  const table = await queryRunner.getTable(tableName);
  if (!table?.findColumnByName(column.name)) {
    await queryRunner.addColumn(tableName, column);
  }
}

async function migrate() {
  const dataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT || 3306),
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_DATABASE || "pet_hospitals",
    synchronize: false,
    connectTimeout: 30000,
  });

  await dataSource.initialize();
  const queryRunner = dataSource.createQueryRunner();
  await queryRunner.connect();
  let lockAcquired = false;

  try {
    const [migrationLock] = await queryRunner.query(
      "SELECT GET_LOCK(?, 30) AS acquired",
      ["pet_hospitals_second_hand_after_sales_migration"],
    );
    if (Number(migrationLock?.acquired) !== 1) {
      throw new Error("无法获取数据库迁移锁，请确认没有其他迁移实例正在运行");
    }
    lockAcquired = true;
    await queryRunner.startTransaction();

    await addColumnIfMissing(
      queryRunner,
      "orders",
      new TableColumn({
        name: "platformFeeRate",
        type: "decimal",
        precision: 5,
        scale: 2,
        isNullable: true,
        comment: "支付时平台费率快照（百分比）",
      }),
    );
    await addColumnIfMissing(
      queryRunner,
      "orders",
      new TableColumn({
        name: "autoConfirmAt",
        type: "datetime",
        isNullable: true,
        comment: "自动确认收货时间",
      }),
    );
    await addColumnIfMissing(
      queryRunner,
      "orders",
      new TableColumn({
        name: "inventoryRestoredAt",
        type: "datetime",
        isNullable: true,
        comment: "库存恢复时间（幂等标记）",
      }),
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS order_after_sales (
        id INT NOT NULL AUTO_INCREMENT,
        afterSaleNo VARCHAR(40) NOT NULL,
        orderId INT NOT NULL,
        buyerId INT NOT NULL,
        sellerId INT NOT NULL,
        status ENUM(
          'pending_seller', 'seller_rejected', 'seller_timeout',
          'waiting_buyer_return', 'waiting_seller_receipt',
          'arbitration_pending', 'refunding', 'refunded', 'closed'
        ) NOT NULL,
        reasonCode VARCHAR(50) NOT NULL,
        description TEXT NULL,
        evidenceUrls JSON NULL,
        sellerDecision ENUM('approved', 'rejected') NULL,
        sellerReason TEXT NULL,
        returnRequired TINYINT(1) NULL,
        returnAddress TEXT NULL,
        returnTrackingNumber VARCHAR(100) NULL,
        returnEvidenceUrls JSON NULL,
        arbitrationReason TEXT NULL,
        arbitrationEvidenceUrls JSON NULL,
        arbitrationDecision ENUM('support_buyer', 'support_seller') NULL,
        arbitrationRemark TEXT NULL,
        arbitratorId INT NULL,
        refundId INT NULL,
        refundAmount DECIMAL(10, 2) NOT NULL,
        refundFailureReason TEXT NULL,
        sellerDeadlineAt DATETIME NULL,
        arbitrationDeadlineAt DATETIME NULL,
        buyerReturnDeadlineAt DATETIME NULL,
        sellerReceiptDeadlineAt DATETIME NULL,
        arbitrationAt DATETIME NULL,
        refundedAt DATETIME NULL,
        closedAt DATETIME NULL,
        version INT NOT NULL DEFAULT 1,
        createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
          ON UPDATE CURRENT_TIMESTAMP(6),
        PRIMARY KEY (id),
        UNIQUE KEY UQ_order_after_sales_no (afterSaleNo),
        KEY IDX_order_after_sales_order_status (orderId, status),
        KEY IDX_order_after_sales_buyer_status (buyerId, status),
        KEY IDX_order_after_sales_seller_status (sellerId, status)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='二手订单售后单'
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS order_after_sale_logs (
        id INT NOT NULL AUTO_INCREMENT,
        afterSaleId INT NOT NULL,
        operatorType ENUM('buyer', 'seller', 'admin', 'system') NOT NULL,
        operatorId INT NULL,
        action VARCHAR(50) NOT NULL,
        fromStatus ENUM(
          'pending_seller', 'seller_rejected', 'seller_timeout',
          'waiting_buyer_return', 'waiting_seller_receipt',
          'arbitration_pending', 'refunding', 'refunded', 'closed'
        ) NULL,
        toStatus ENUM(
          'pending_seller', 'seller_rejected', 'seller_timeout',
          'waiting_buyer_return', 'waiting_seller_receipt',
          'arbitration_pending', 'refunding', 'refunded', 'closed'
        ) NULL,
        description TEXT NULL,
        snapshot JSON NULL,
        createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        PRIMARY KEY (id),
        KEY IDX_order_after_sale_logs_sale_time (afterSaleId, createdAt)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='二手订单售后操作日志'
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS order_migration_anomalies (
        id INT NOT NULL AUTO_INCREMENT,
        orderId INT NOT NULL,
        anomalyType VARCHAR(50) NOT NULL,
        detail TEXT NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY UQ_order_migration_anomaly (orderId, anomalyType)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单历史数据迁移异常清单'
    `);

    // MySQL 5.7 不支持 JSON_TABLE，因此在应用层解析 JSON 并参数化记录异常。
    await recordHistoricalAnomalies(queryRunner);

    await queryRunner.query(`
      UPDATE orders o
      JOIN products p
        ON p.id = CAST(JSON_UNQUOTE(JSON_EXTRACT(o.items, '$[0].productId')) AS UNSIGNED)
      SET o.orderType = 'second_hand', o.sellerId = p.publishedBy
      WHERE JSON_LENGTH(o.items) = 1
        AND CAST(JSON_UNQUOTE(JSON_EXTRACT(o.items, '$[0].quantity')) AS UNSIGNED) = 1
        AND p.publishSource = 'USER'
        AND p.publishedBy IS NOT NULL
    `);

    await queryRunner.query(`
      UPDATE orders SET status = 'pending' WHERE status = 'pending_payment'
    `);
    await queryRunner.query(`
      UPDATE orders SET status = 'shipped' WHERE status = 'pending_confirm'
    `);
    await queryRunner.query(`
      UPDATE orders SET status = 'cancelled' WHERE status = 'refunding'
    `);
    await queryRunner.query(`
      ALTER TABLE orders
      MODIFY COLUMN status ENUM('pending', 'paid', 'shipped', 'completed', 'cancelled')
      NOT NULL DEFAULT 'pending' COMMENT '订单状态'
    `);
    await queryRunner.query(`
      UPDATE orders
      SET autoConfirmAt = DATE_ADD(shippedAt, INTERVAL 10 DAY)
      WHERE status = 'shipped' AND shippedAt IS NOT NULL AND autoConfirmAt IS NULL
    `);

    await queryRunner.query(`
      INSERT IGNORE INTO system_configs
        (configKey, configValue, description, createdAt, updatedAt)
      VALUES
        (
          'second_hand_after_sale_policy',
          JSON_OBJECT(
            'sellerHandleHours', 48,
            'arbitrationDays', 7,
            'buyerReturnDays', 7,
            'sellerReceiptHours', 48
          ),
          '二手订单售后各阶段超时策略',
          NOW(),
          NOW()
        )
    `);

    await queryRunner.commitTransaction();
    console.log("二手交易闭环数据库迁移完成");
  } catch (error) {
    if (queryRunner.isTransactionActive) {
      await queryRunner.rollbackTransaction();
    }
    throw error;
  } finally {
    if (lockAcquired) {
      await queryRunner.query("SELECT RELEASE_LOCK(?)", [
        "pet_hospitals_second_hand_after_sales_migration",
      ]);
    }
    await queryRunner.release();
    await dataSource.destroy();
  }
}

migrate().catch((error) => {
  console.error("二手交易闭环数据库迁移失败:", error);
  process.exitCode = 1;
});
