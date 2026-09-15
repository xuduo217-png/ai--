/**
 * 平台商城与二手交易统一售后迁移（MySQL 5.7+）。
 *
 * 默认只执行只读预检：
 *   node --env-file=.env -r ts-node/register migrations/extend-unified-shop-after-sales.ts
 *
 * 显式执行：
 *   node --env-file=.env -r ts-node/register migrations/extend-unified-shop-after-sales.ts --execute
 *
 * 核心表只做增量 DDL 和原位字段重命名。脚本可重复执行；任何无法证明正确的
 * 商品金额或关联数据都会中止，不自动猜测修复。
 */
import { DataSource, QueryRunner } from "typeorm";

const MIGRATION_ID = "20260730_unified_shop_after_sales_v1";
const MIGRATION_LOCK = "pet_hospitals_unified_shop_after_sales_migration";
const EXECUTE = process.argv.includes("--execute");

interface OrderRow {
  id: number;
  orderType: string;
  status: string;
  totalAmount: string | number;
  originalAmount: string | number;
  couponDiscount: string | number;
  refundedAmount?: string | number;
  completedAt: Date | null;
  items: unknown;
}

interface SnapshotItem {
  lineKey: string;
  productId: number;
  productName: string;
  productImage?: string;
  quantity: number;
  price: number;
  skuId?: number;
  skuName?: string;
  discountAmount: number;
  paidAmount: number;
  [key: string]: unknown;
}

const toCents = (value: unknown) =>
  Math.round((Number.parseFloat(String(value ?? 0)) || 0) * 100);
const toYuan = (value: number) => value / 100;

function parseItems(value: unknown): Array<Record<string, unknown>> {
  if (Array.isArray(value)) return value as Array<Record<string, unknown>>;
  if (typeof value !== "string") return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function buildItemSnapshots(order: OrderRow): SnapshotItem[] {
  const source = parseItems(order.items);
  if (!source.length) throw new Error(`订单 ${order.id} 没有可迁移的商品行`);

  const lineCents = source.map((item, index) => {
    const productId = Number(item.productId);
    const quantity = Number(item.quantity);
    const priceCents = toCents(item.price);
    if (
      !Number.isInteger(productId) ||
      productId <= 0 ||
      !Number.isInteger(quantity) ||
      quantity <= 0 ||
      priceCents < 0
    ) {
      throw new Error(
        `订单 ${order.id} 第 ${index + 1} 行商品、数量或价格无效`,
      );
    }
    return priceCents * quantity;
  });
  const originalCents = lineCents.reduce((sum, value) => sum + value, 0);
  if (originalCents !== toCents(order.originalAmount)) {
    throw new Error(
      `订单 ${order.id} 商品行原价 ${toYuan(originalCents)} 与订单原价 ${order.originalAmount} 不一致`,
    );
  }
  const discountCents = toCents(order.couponDiscount);
  if (originalCents - discountCents !== toCents(order.totalAmount)) {
    throw new Error(`订单 ${order.id} 原价、优惠与实付金额不一致`);
  }

  let allocated = 0;
  const seenLineKeys = new Set<string>();
  return source.map((item, index) => {
    const lineDiscount =
      index === source.length - 1
        ? discountCents - allocated
        : originalCents > 0
          ? Math.floor((discountCents * lineCents[index]) / originalCents)
          : 0;
    allocated += lineDiscount;
    const lineKey = String(item.lineKey || `legacy-${order.id}-${index + 1}`);
    if (seenLineKeys.has(lineKey)) {
      throw new Error(`订单 ${order.id} 存在重复 lineKey`);
    }
    seenLineKeys.add(lineKey);
    return {
      ...item,
      lineKey,
      productId: Number(item.productId),
      productName: String(item.productName || "历史商品"),
      productImage: item.productImage ? String(item.productImage) : undefined,
      quantity: Number(item.quantity),
      price: toYuan(toCents(item.price)),
      skuId: item.skuId ? Number(item.skuId) : undefined,
      skuName: item.skuName ? String(item.skuName) : undefined,
      discountAmount: toYuan(lineDiscount),
      paidAmount: toYuan(lineCents[index] - lineDiscount),
    };
  });
}

async function tableExists(queryRunner: QueryRunner, tableName: string) {
  const rows = await queryRunner.query(
    `SELECT 1 FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? LIMIT 1`,
    [tableName],
  );
  return rows.length > 0;
}

async function columnExists(
  queryRunner: QueryRunner,
  tableName: string,
  columnName: string,
) {
  const rows = await queryRunner.query(
    `SELECT 1 FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? LIMIT 1`,
    [tableName, columnName],
  );
  return rows.length > 0;
}

async function addColumnIfMissing(
  queryRunner: QueryRunner,
  tableName: string,
  columnName: string,
  definition: string,
) {
  if (!(await columnExists(queryRunner, tableName, columnName))) {
    await queryRunner.query(
      `ALTER TABLE \`${tableName}\` ADD COLUMN \`${columnName}\` ${definition}`,
    );
  }
}

async function renameColumnIfNeeded(
  queryRunner: QueryRunner,
  tableName: string,
  oldName: string,
  newDefinition: string,
  newName: string,
) {
  const hasOld = await columnExists(queryRunner, tableName, oldName);
  const hasNew = await columnExists(queryRunner, tableName, newName);
  if (hasOld && !hasNew) {
    await queryRunner.query(
      `ALTER TABLE \`${tableName}\` CHANGE COLUMN \`${oldName}\` ${newDefinition}`,
    );
  }
}

async function indexExists(
  queryRunner: QueryRunner,
  tableName: string,
  indexName: string,
) {
  const rows = await queryRunner.query(
    `SELECT 1 FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ? LIMIT 1`,
    [tableName, indexName],
  );
  return rows.length > 0;
}

async function collectSnapshot(queryRunner: QueryRunner) {
  const [orders] = await queryRunner.query(`
    SELECT COUNT(*) count,
      COALESCE(SUM(totalAmount), 0) totalAmount,
      COALESCE(SUM(originalAmount), 0) originalAmount,
      COALESCE(SUM(couponDiscount), 0) couponDiscount
    FROM orders
  `);
  const [afterSales] = await queryRunner.query(`
    SELECT COUNT(*) count,
      COALESCE(SUM(${(await columnExists(queryRunner, "order_after_sales", "requestedAmount")) ? "requestedAmount" : "refundAmount"}), 0) amount
    FROM order_after_sales
  `);
  const [logs] = await queryRunner.query(
    "SELECT COUNT(*) count FROM order_after_sale_logs",
  );
  const [refunds] = await queryRunner.query(`
    SELECT COUNT(*) count, COALESCE(SUM(refundAmount), 0) amount FROM refunds
  `);
  return { orders, afterSales, logs, refunds };
}

async function preflight(queryRunner: QueryRunner) {
  const [versions, activeDuplicates, orphanSales, paymentMismatch] =
    await Promise.all([
      queryRunner.query("SELECT VERSION() version, DATABASE() databaseName"),
      queryRunner.query(`
        SELECT orderId, COUNT(*) count FROM order_after_sales
        WHERE status NOT IN ('refunded', 'closed')
        GROUP BY orderId HAVING COUNT(*) > 1
      `),
      queryRunner.query(`
        SELECT a.id FROM order_after_sales a
        LEFT JOIN orders o ON o.id = a.orderId
        WHERE o.id IS NULL
      `),
      queryRunner.query(`
        SELECT o.id FROM orders o
        LEFT JOIN payments p
          ON p.businessType = 'shop_order' AND p.businessId = o.id
             AND p.status IN ('success', 'refunded')
        WHERE o.status IN ('paid', 'shipped', 'completed')
        GROUP BY o.id HAVING COUNT(p.id) = 0
      `),
    ]);
  const version = versions[0];
  if (activeDuplicates.length)
    throw new Error("存在同订单多条进行中售后，迁移中止");
  if (orphanSales.length) throw new Error("存在无订单的售后单，迁移中止");

  const orders = (await queryRunner.query(
    `SELECT id, orderType, status, totalAmount, originalAmount, couponDiscount,
            ${(await columnExists(queryRunner, "orders", "refundedAmount")) ? "refundedAmount" : "0 AS refundedAmount"},
            completedAt, items
     FROM orders ORDER BY id`,
  )) as OrderRow[];
  let itemCount = 0;
  for (const order of orders) itemCount += buildItemSnapshots(order).length;
  return {
    serverVersion: version.version,
    databaseName: version.databaseName,
    orderCount: orders.length,
    orderItemCount: itemCount,
    activeAfterSaleDuplicateCount: activeDuplicates.length,
    orphanAfterSaleCount: orphanSales.length,
    paymentStatusMismatchOrderCount: paymentMismatch.length,
    snapshot: await collectSnapshot(queryRunner),
  };
}

async function ensureMigrationTables(queryRunner: QueryRunner) {
  await queryRunner.query(`
    CREATE TABLE IF NOT EXISTS app_schema_migrations (
      id VARCHAR(100) NOT NULL,
      appliedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      details JSON NULL,
      PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='应用正式数据库迁移记录'
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
}

async function migrateOrders(queryRunner: QueryRunner) {
  await addColumnIfMissing(
    queryRunner,
    "orders",
    "refundedAmount",
    "DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '订单累计成功退款金额'",
  );
  await addColumnIfMissing(
    queryRunner,
    "orders",
    "afterSaleDeadlineAt",
    "DATETIME NULL COMMENT '普通订单售后截止时间'",
  );

  const orders = (await queryRunner.query(`
    SELECT id, orderType, status, totalAmount, originalAmount, couponDiscount,
           refundedAmount, completedAt, items FROM orders ORDER BY id
  `)) as OrderRow[];
  for (const order of orders) {
    const items = buildItemSnapshots(order);
    await queryRunner.query("UPDATE orders SET items = ? WHERE id = ?", [
      JSON.stringify(items),
      order.id,
    ]);
  }

  await queryRunner.query(`
    UPDATE orders o
    LEFT JOIN (
      SELECT p.businessId orderId, COALESCE(SUM(r.refundAmount), 0) refundedAmount
      FROM payments p
      JOIN refunds r ON r.paymentId = p.id AND r.status = 'success'
      WHERE p.businessType = 'shop_order'
      GROUP BY p.businessId
    ) x ON x.orderId = o.id
    SET o.refundedAmount = LEAST(o.totalAmount, COALESCE(x.refundedAmount, 0))
  `);
  await queryRunner.query(`
    UPDATE orders
    SET afterSaleDeadlineAt = DATE_ADD(completedAt, INTERVAL 7 DAY)
    WHERE orderType = 'normal' AND status = 'completed'
      AND completedAt IS NOT NULL AND afterSaleDeadlineAt IS NULL
  `);
  if (
    !(await indexExists(
      queryRunner,
      "orders",
      "IDX_orders_after_sale_deadline",
    ))
  ) {
    await queryRunner.query(
      "ALTER TABLE orders ADD INDEX IDX_orders_after_sale_deadline (afterSaleDeadlineAt)",
    );
  }
}

async function migrateAfterSaleSchema(queryRunner: QueryRunner) {
  await addColumnIfMissing(
    queryRunner,
    "order_after_sales",
    "orderType",
    "ENUM('normal','second_hand') NULL",
  );
  await addColumnIfMissing(
    queryRunner,
    "order_after_sales",
    "handlerType",
    "ENUM('seller','platform') NULL",
  );
  await addColumnIfMissing(
    queryRunner,
    "order_after_sales",
    "afterSaleType",
    "ENUM('refund_only','return_refund') NULL",
  );
  await addColumnIfMissing(
    queryRunner,
    "order_after_sales",
    "approvedAmount",
    "DECIMAL(10,2) NULL",
  );
  await addColumnIfMissing(
    queryRunner,
    "order_after_sales",
    "reviewerId",
    "INT NULL",
  );
  await addColumnIfMissing(
    queryRunner,
    "order_after_sales",
    "reviewedAt",
    "DATETIME NULL",
  );

  await queryRunner.query(`
    ALTER TABLE order_after_sales MODIFY COLUMN status ENUM(
      'pending_seller','seller_rejected','seller_timeout','waiting_buyer_return',
      'waiting_seller_receipt','pending_handler','handler_rejected','handler_timeout',
      'waiting_handler_receipt','arbitration_pending','refunding','refunded','closed'
    ) NOT NULL
  `);
  await queryRunner.query(`
    UPDATE order_after_sales SET status = CASE status
      WHEN 'pending_seller' THEN 'pending_handler'
      WHEN 'seller_rejected' THEN 'handler_rejected'
      WHEN 'seller_timeout' THEN 'handler_timeout'
      WHEN 'waiting_seller_receipt' THEN 'waiting_handler_receipt'
      ELSE status END
  `);
  await queryRunner.query(`
    ALTER TABLE order_after_sales MODIFY COLUMN status ENUM(
      'pending_handler','handler_rejected','handler_timeout','waiting_buyer_return',
      'waiting_handler_receipt','arbitration_pending','refunding','refunded','closed'
    ) NOT NULL COMMENT '售后状态'
  `);

  await renameColumnIfNeeded(
    queryRunner,
    "order_after_sales",
    "sellerDecision",
    "`handlerDecision` ENUM('approved','rejected') NULL COMMENT '处理方决定'",
    "handlerDecision",
  );
  await renameColumnIfNeeded(
    queryRunner,
    "order_after_sales",
    "sellerReason",
    "`handlerReason` TEXT NULL COMMENT '处理方说明'",
    "handlerReason",
  );
  await renameColumnIfNeeded(
    queryRunner,
    "order_after_sales",
    "sellerDeadlineAt",
    "`handlerDeadlineAt` DATETIME NULL COMMENT '处理方处理截止时间'",
    "handlerDeadlineAt",
  );
  await renameColumnIfNeeded(
    queryRunner,
    "order_after_sales",
    "sellerReceiptDeadlineAt",
    "`handlerReceiptDeadlineAt` DATETIME NULL COMMENT '处理方确认退货截止时间'",
    "handlerReceiptDeadlineAt",
  );
  await renameColumnIfNeeded(
    queryRunner,
    "order_after_sales",
    "refundAmount",
    "`requestedAmount` DECIMAL(10,2) NOT NULL COMMENT '买家申请金额'",
    "requestedAmount",
  );

  await queryRunner.query(`
    UPDATE order_after_sales a JOIN orders o ON o.id = a.orderId
    SET a.orderType = o.orderType,
        a.handlerType = IF(o.orderType = 'normal', 'platform', 'seller'),
        a.afterSaleType = COALESCE(
          a.afterSaleType,
          IF(a.returnRequired = 1, 'return_refund', 'refund_only')
        ),
        a.approvedAmount = CASE
          WHEN a.handlerDecision = 'approved'
            OR a.status IN ('waiting_buyer_return','waiting_handler_receipt','refunding','refunded')
          THEN COALESCE(a.approvedAmount, a.requestedAmount)
          ELSE a.approvedAmount END,
        a.sellerId = IF(o.orderType = 'normal', NULL, a.sellerId)
  `);
  await queryRunner.query(`
    ALTER TABLE order_after_sales
      MODIFY COLUMN orderType ENUM('normal','second_hand') NOT NULL COMMENT '订单类型快照',
      MODIFY COLUMN handlerType ENUM('seller','platform') NOT NULL COMMENT '售后处理方',
      MODIFY COLUMN afterSaleType ENUM('refund_only','return_refund') NOT NULL COMMENT '售后类型',
      MODIFY COLUMN sellerId INT NULL COMMENT '卖家ID，平台售后为空'
  `);

  await queryRunner.query(`
    ALTER TABLE order_after_sale_logs
      MODIFY COLUMN fromStatus ENUM(
        'pending_seller','seller_rejected','seller_timeout','waiting_buyer_return',
        'waiting_seller_receipt','pending_handler','handler_rejected','handler_timeout',
        'waiting_handler_receipt','arbitration_pending','refunding','refunded','closed'
      ) NULL,
      MODIFY COLUMN toStatus ENUM(
        'pending_seller','seller_rejected','seller_timeout','waiting_buyer_return',
        'waiting_seller_receipt','pending_handler','handler_rejected','handler_timeout',
        'waiting_handler_receipt','arbitration_pending','refunding','refunded','closed'
      ) NULL
  `);
  await queryRunner.query(`
    UPDATE order_after_sale_logs
    SET fromStatus = CASE fromStatus
      WHEN 'pending_seller' THEN 'pending_handler'
      WHEN 'seller_rejected' THEN 'handler_rejected'
      WHEN 'seller_timeout' THEN 'handler_timeout'
      WHEN 'waiting_seller_receipt' THEN 'waiting_handler_receipt'
      ELSE fromStatus END,
        toStatus = CASE toStatus
      WHEN 'pending_seller' THEN 'pending_handler'
      WHEN 'seller_rejected' THEN 'handler_rejected'
      WHEN 'seller_timeout' THEN 'handler_timeout'
      WHEN 'waiting_seller_receipt' THEN 'waiting_handler_receipt'
      ELSE toStatus END
  `);
  await queryRunner.query(`
    ALTER TABLE order_after_sale_logs
      MODIFY COLUMN fromStatus ENUM(
        'pending_handler','handler_rejected','handler_timeout','waiting_buyer_return',
        'waiting_handler_receipt','arbitration_pending','refunding','refunded','closed'
      ) NULL,
      MODIFY COLUMN toStatus ENUM(
        'pending_handler','handler_rejected','handler_timeout','waiting_buyer_return',
        'waiting_handler_receipt','arbitration_pending','refunding','refunded','closed'
      ) NULL
  `);
}

async function migrateAfterSaleItems(queryRunner: QueryRunner) {
  await queryRunner.query(`
    CREATE TABLE IF NOT EXISTS order_after_sale_items (
      id INT NOT NULL AUTO_INCREMENT,
      afterSaleId INT NOT NULL,
      lineKey VARCHAR(80) NOT NULL,
      productId INT NOT NULL,
      skuId INT NULL,
      productName VARCHAR(255) NOT NULL,
      skuName VARCHAR(255) NULL,
      productImage VARCHAR(500) NULL,
      requestedQuantity INT NOT NULL,
      approvedQuantity INT NOT NULL DEFAULT 0,
      refundedQuantity INT NOT NULL DEFAULT 0,
      unitPrice DECIMAL(10,2) NOT NULL,
      discountAmount DECIMAL(10,2) NOT NULL,
      paidAmount DECIMAL(10,2) NOT NULL,
      approvedAmount DECIMAL(10,2) NOT NULL DEFAULT 0,
      refundedAmount DECIMAL(10,2) NOT NULL DEFAULT 0,
      restockQuantity INT NOT NULL DEFAULT 0,
      inventoryRestoredQuantity INT NOT NULL DEFAULT 0,
      version INT NOT NULL DEFAULT 1,
      createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
      PRIMARY KEY (id),
      UNIQUE KEY UQ_after_sale_item_line (afterSaleId, lineKey),
      KEY IDX_after_sale_item_product (productId)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单售后商品行快照'
  `);

  const rows = await queryRunner.query(`
    SELECT a.id afterSaleId, a.status, a.requestedAmount, a.approvedAmount,
           o.id orderId, o.items, o.inventoryRestoredAt
    FROM order_after_sales a JOIN orders o ON o.id = a.orderId
    LEFT JOIN order_after_sale_items i ON i.afterSaleId = a.id
    WHERE i.id IS NULL
  `);
  for (const row of rows) {
    const order = (
      await queryRunner.query(
        `SELECT id, orderType, status, totalAmount, originalAmount, couponDiscount,
              refundedAmount, completedAt, items FROM orders WHERE id = ?`,
        [row.orderId],
      )
    )[0] as OrderRow;
    const items = buildItemSnapshots(order);
    const itemPaidCents = items.reduce(
      (sum, item) => sum + toCents(item.paidAmount),
      0,
    );
    if (itemPaidCents !== toCents(row.requestedAmount)) {
      throw new Error(
        `售后单 ${row.afterSaleId} 申请金额与整单商品实付不一致，无法安全推断历史售后商品行`,
      );
    }
    const approved = row.approvedAmount !== null;
    const refunded = row.status === "refunded";
    for (const item of items) {
      await queryRunner.query(
        `INSERT INTO order_after_sale_items (
          afterSaleId, lineKey, productId, skuId, productName, skuName, productImage,
          requestedQuantity, approvedQuantity, refundedQuantity, unitPrice,
          discountAmount, paidAmount, approvedAmount, refundedAmount,
          restockQuantity, inventoryRestoredQuantity, version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
        [
          row.afterSaleId,
          item.lineKey,
          item.productId,
          item.skuId || null,
          item.productName,
          item.skuName || null,
          item.productImage || null,
          item.quantity,
          approved ? item.quantity : 0,
          refunded ? item.quantity : 0,
          item.price,
          item.discountAmount,
          item.paidAmount,
          approved ? item.paidAmount : 0,
          refunded ? item.paidAmount : 0,
          refunded && row.inventoryRestoredAt ? item.quantity : 0,
          refunded && row.inventoryRestoredAt ? item.quantity : 0,
        ],
      );
    }
  }

  if (
    !(await columnExists(queryRunner, "order_after_sales", "activeOrderId"))
  ) {
    await queryRunner.query(`
      ALTER TABLE order_after_sales ADD COLUMN activeOrderId INT
      GENERATED ALWAYS AS (
        CASE WHEN status IN (
          'pending_handler','handler_rejected','handler_timeout','waiting_buyer_return',
          'waiting_handler_receipt','arbitration_pending','refunding'
        ) THEN orderId ELSE NULL END
      ) STORED
    `);
  }
  if (
    !(await indexExists(
      queryRunner,
      "order_after_sales",
      "UQ_after_sale_active_order",
    ))
  ) {
    await queryRunner.query(
      "ALTER TABLE order_after_sales ADD UNIQUE INDEX UQ_after_sale_active_order (activeOrderId)",
    );
  }
  if (
    !(await indexExists(
      queryRunner,
      "order_after_sales",
      "IDX_after_sales_handler_status",
    ))
  ) {
    await queryRunner.query(
      "ALTER TABLE order_after_sales ADD INDEX IDX_after_sales_handler_status (handlerType, status)",
    );
  }
}

async function recordKnownAnomalies(queryRunner: QueryRunner) {
  await queryRunner.query(`
    INSERT IGNORE INTO order_migration_anomalies (orderId, anomalyType, detail)
    SELECT o.id, 'PAYMENT_STATUS_MISMATCH',
      '订单为已付款或后续状态，但没有 success/refunded 支付记录；未自动修复'
    FROM orders o
    LEFT JOIN payments p
      ON p.businessType = 'shop_order' AND p.businessId = o.id
         AND p.status IN ('success', 'refunded')
    WHERE o.status IN ('paid', 'shipped', 'completed')
    GROUP BY o.id HAVING COUNT(p.id) = 0
  `);
  await queryRunner.query(`
    INSERT IGNORE INTO order_migration_anomalies (orderId, anomalyType, detail)
    SELECT businessId, 'DUPLICATE_PAYMENT_RECORDS',
      '同一商城订单存在多条支付记录；未自动合并或删除'
    FROM payments WHERE businessType = 'shop_order'
    GROUP BY businessId HAVING COUNT(*) > 1
  `);
}

async function verifyMigration(queryRunner: QueryRunner, before: any) {
  const after = await collectSnapshot(queryRunner);
  for (const section of ["orders", "afterSales", "logs", "refunds"]) {
    if (Number(before[section].count) !== Number(after[section].count)) {
      throw new Error(`${section} 迁移前后行数不一致`);
    }
  }
  if (
    toCents(before.orders.totalAmount) !== toCents(after.orders.totalAmount) ||
    toCents(before.orders.originalAmount) !==
      toCents(after.orders.originalAmount) ||
    toCents(before.orders.couponDiscount) !==
      toCents(after.orders.couponDiscount) ||
    toCents(before.refunds.amount) !== toCents(after.refunds.amount)
  ) {
    throw new Error("迁移前后订单或退款金额汇总不一致");
  }
  const [lineAudit] = await queryRunner.query(`
    SELECT COUNT(*) saleCount,
      (SELECT COUNT(*) FROM order_after_sale_items) itemCount,
      COALESCE(SUM(requestedAmount), 0) requestedAmount,
      (SELECT COALESCE(SUM(paidAmount), 0) FROM order_after_sale_items) itemPaidAmount
    FROM order_after_sales
  `);
  if (
    toCents(lineAudit.requestedAmount) !== toCents(lineAudit.itemPaidAmount)
  ) {
    throw new Error("售后单申请金额与售后商品行实付金额汇总不一致");
  }
  return { after, lineAudit };
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
  let locked = false;
  try {
    const report = await preflight(queryRunner);
    console.log(
      JSON.stringify(
        { mode: EXECUTE ? "execute" : "dry-run", ...report },
        null,
        2,
      ),
    );
    if (!EXECUTE) return;

    const [lock] = await queryRunner.query("SELECT GET_LOCK(?, 30) acquired", [
      MIGRATION_LOCK,
    ]);
    if (Number(lock?.acquired) !== 1) throw new Error("无法获取数据库迁移锁");
    locked = true;
    await ensureMigrationTables(queryRunner);
    const existing = await queryRunner.query(
      "SELECT id, details FROM app_schema_migrations WHERE id = ?",
      [MIGRATION_ID],
    );
    if (existing.length) {
      console.log(
        JSON.stringify(
          { alreadyApplied: true, migrationId: MIGRATION_ID },
          null,
          2,
        ),
      );
      return;
    }

    const before = report.snapshot;
    await migrateOrders(queryRunner);
    await migrateAfterSaleSchema(queryRunner);
    await migrateAfterSaleItems(queryRunner);
    await recordKnownAnomalies(queryRunner);
    await queryRunner.query(`
      INSERT IGNORE INTO system_configs
        (configKey, configValue, description, createdAt, updatedAt)
      VALUES (
        'shop_after_sale_policy',
        JSON_OBJECT(
          'handlerHours', 48,
          'arbitrationDays', 7,
          'buyerReturnDays', 7,
          'handlerReceiptHours', 48,
          'normalCompletedDays', 7
        ),
        '商城统一售后各阶段期限策略', NOW(), NOW()
      )
    `);
    const verification = await verifyMigration(queryRunner, before);
    await queryRunner.query(
      "INSERT INTO app_schema_migrations (id, details) VALUES (?, ?)",
      [MIGRATION_ID, JSON.stringify(verification)],
    );
    console.log(
      JSON.stringify(
        { migrationId: MIGRATION_ID, completed: true, verification },
        null,
        2,
      ),
    );
  } finally {
    if (locked)
      await queryRunner.query("SELECT RELEASE_LOCK(?)", [MIGRATION_LOCK]);
    await queryRunner.release();
    await dataSource.destroy();
  }
}

migrate().catch((error) => {
  console.error(`统一售后迁移失败: ${error.message}`);
  process.exitCode = 1;
});
