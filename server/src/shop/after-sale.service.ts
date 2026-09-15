import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "crypto";
import { InjectRepository } from "@nestjs/typeorm";
import { DataSource, In, LessThanOrEqual, Repository } from "typeorm";
import {
  NotificationScene,
  NotificationSenderService,
} from "../notifications/notification-sender.service";
import { PaymentService } from "../payment/payment.service";
import { SystemConfig } from "../system-configs/entities/system-config.entity";
import { User, UserRole } from "../users/entities/user.entity";
import { toCents, toNumber, toYuan } from "../common/utils/currency.util";
import {
  AdminAfterSaleDecision,
  AdminArbitrateAfterSaleDto,
  AdminConfirmReturnDto,
  AdminReviewAfterSaleDto,
  ApplyArbitrationDto,
  CreateAfterSaleDto,
  QueryAfterSaleDto,
  SellerApproveAfterSaleDto,
  SellerRejectAfterSaleDto,
  SubmitReturnDto,
} from "./dto/after-sale.dto";
import {
  ACTIVE_AFTER_SALE_STATUSES,
  AfterSaleHandlerType,
  AfterSaleStatus,
  AfterSaleType,
  ArbitrationDecision,
  HandlerDecision,
  OrderAfterSale,
} from "./entities/order-after-sale.entity";
import { OrderAfterSaleItem } from "./entities/order-after-sale-item.entity";
import {
  AfterSaleOperatorType,
  OrderAfterSaleLog,
} from "./entities/order-after-sale-log.entity";
import {
  Order,
  OrderItem,
  OrderStatus,
  OrderType,
} from "./entities/order.entity";
import { ShopService } from "./shop.service";

const POLICY_CONFIG_KEY = "shop_after_sale_policy";
const LEGACY_POLICY_CONFIG_KEY = "second_hand_after_sale_policy";
const DAY_MS = 24 * 60 * 60 * 1000;
const ACTIVE_STATUSES = [...ACTIVE_AFTER_SALE_STATUSES];
const FINISHED_STATUSES = [AfterSaleStatus.REFUNDED, AfterSaleStatus.CLOSED];

interface AfterSalePolicy {
  handlerHours: number;
  arbitrationDays: number;
  buyerReturnDays: number;
  handlerReceiptHours: number;
  normalCompletedDays: number;
}

interface RequestedLine {
  orderItem: OrderItem;
  requestedQuantity: number;
  alreadyRefundedQuantity: number;
  paidAmount: number;
  discountAmount: number;
}

@Injectable()
export class AfterSaleService {
  constructor(
    @InjectRepository(OrderAfterSale)
    private readonly afterSaleRepository: Repository<OrderAfterSale>,
    @InjectRepository(OrderAfterSaleItem)
    private readonly itemRepository: Repository<OrderAfterSaleItem>,
    @InjectRepository(OrderAfterSaleLog)
    private readonly logRepository: Repository<OrderAfterSaleLog>,
    @InjectRepository(SystemConfig)
    private readonly configRepository: Repository<SystemConfig>,
    private readonly dataSource: DataSource,
    private readonly paymentService: PaymentService,
    private readonly shopService: ShopService,
    private readonly notificationSender: NotificationSenderService,
  ) {}

  async create(orderId: number, buyerId: number, dto: CreateAfterSaleDto) {
    this.assertNonBlank(dto.reasonCode, "请选择售后原因");
    const policy = await this.getPolicy();
    const result = await this.dataSource.transaction(async (manager) => {
      const order = await this.lockOrder(manager, orderId);
      this.assertCanCreate(order, buyerId, policy);

      const active = await manager.findOne(OrderAfterSale, {
        where: { orderId, status: In(ACTIVE_STATUSES) },
      });
      if (active) {
        throw new BadRequestException("该订单已有进行中的售后");
      }

      const requestedLines = await this.buildRequestedLines(
        manager,
        order,
        dto,
      );
      const requestedAmount = requestedLines.reduce(
        (sum, line) => sum + toCents(line.paidAmount),
        0,
      );
      if (requestedAmount <= 0) {
        throw new BadRequestException("所选商品已无可售后金额");
      }

      const handlerType =
        order.orderType === OrderType.NORMAL
          ? AfterSaleHandlerType.PLATFORM
          : AfterSaleHandlerType.SELLER;
      const afterSaleType = this.resolveRequestedType(order, dto.afterSaleType);
      const afterSale = await manager.save(
        OrderAfterSale,
        manager.create(OrderAfterSale, {
          afterSaleNo: this.generateAfterSaleNo(),
          orderId,
          orderType: order.orderType,
          handlerType,
          afterSaleType,
          buyerId,
          sellerId:
            handlerType === AfterSaleHandlerType.SELLER ? order.sellerId : null,
          status: AfterSaleStatus.PENDING_HANDLER,
          reasonCode: dto.reasonCode.trim(),
          description: dto.description?.trim() || null,
          evidenceUrls: dto.evidenceUrls || [],
          requestedAmount: toYuan(requestedAmount),
          approvedAmount: null,
          handlerDeadlineAt: new Date(
            Date.now() + policy.handlerHours * 60 * 60 * 1000,
          ),
        }),
      );

      const items = requestedLines.map((line) =>
        manager.create(OrderAfterSaleItem, {
          afterSaleId: afterSale.id,
          lineKey: line.orderItem.lineKey,
          productId: line.orderItem.productId,
          skuId: line.orderItem.skuId || null,
          productName: line.orderItem.productName,
          skuName: line.orderItem.skuName || null,
          productImage: line.orderItem.productImage || null,
          requestedQuantity: line.requestedQuantity,
          approvedQuantity: 0,
          refundedQuantity: 0,
          unitPrice: toNumber(line.orderItem.price),
          discountAmount: line.discountAmount,
          paidAmount: line.paidAmount,
          approvedAmount: 0,
          refundedAmount: 0,
          restockQuantity: 0,
          inventoryRestoredQuantity: 0,
        }),
      );
      await manager.save(OrderAfterSaleItem, items);
      afterSale.items = items;
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.BUYER,
        operatorId: buyerId,
        action: "create",
        toStatus: AfterSaleStatus.PENDING_HANDLER,
        description: dto.description,
        snapshot: {
          orderType: afterSale.orderType,
          handlerType: afterSale.handlerType,
          afterSaleType: afterSale.afterSaleType,
          requestedAmount: afterSale.requestedAmount,
          items: items.map((item) => ({
            lineKey: item.lineKey,
            quantity: item.requestedQuantity,
            paidAmount: item.paidAmount,
          })),
        },
      });
      return afterSale;
    });

    if (result.handlerType === AfterSaleHandlerType.PLATFORM) {
      await Promise.all([
        this.notify(
          result.buyerId,
          NotificationScene.AFTER_SALE_CREATED,
          result,
          "buyer",
        ),
        this.notifyPlatformHandlers(
          NotificationScene.AFTER_SALE_CREATED,
          result,
        ),
      ]);
    } else {
      await this.notify(
        result.sellerId,
        NotificationScene.AFTER_SALE_CREATED,
        result,
        "seller",
      );
    }
    return this.findOne(result.id, buyerId, "USER");
  }

  async findPurchases(userId: number, query: QueryAfterSaleDto) {
    return this.findPage("buyer", userId, query);
  }

  async findSales(userId: number, query: QueryAfterSaleDto) {
    return this.findPage("seller", userId, query);
  }

  async findAdmin(query: QueryAfterSaleDto) {
    return this.findPage("admin", null, query);
  }

  async findOne(id: number, userId: number, role: string) {
    const afterSale = await this.afterSaleRepository.findOne({
      where: { id },
      relations: [
        "order",
        "buyer",
        "seller",
        "arbitrator",
        "reviewer",
        "refund",
        "items",
      ],
    });
    if (!afterSale) throw new NotFoundException("售后单不存在");

    const isAdmin = role === "SUPER_ADMIN" || role === "STAFF";
    if (
      !isAdmin &&
      afterSale.buyerId !== userId &&
      afterSale.sellerId !== userId
    ) {
      throw new ForbiddenException("无权查看该售后单");
    }
    const logs = await this.logRepository.find({
      where: { afterSaleId: id },
      order: { createdAt: "ASC" },
    });
    return this.toView(
      afterSale,
      logs,
      isAdmin ? "admin" : afterSale.buyerId === userId ? "buyer" : "seller",
    );
  }

  async cancel(id: number, buyerId: number) {
    const result = await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      if (afterSale.buyerId !== buyerId) {
        throw new ForbiddenException("只有买家可以取消售后");
      }
      if (
        ![
          AfterSaleStatus.PENDING_HANDLER,
          AfterSaleStatus.HANDLER_REJECTED,
          AfterSaleStatus.HANDLER_TIMEOUT,
          AfterSaleStatus.WAITING_BUYER_RETURN,
        ].includes(afterSale.status)
      ) {
        throw new BadRequestException("当前售后状态不能取消");
      }
      if (this.isTimedOutAfterReturn(afterSale)) {
        throw new BadRequestException("买家已提交退货，不能取消售后");
      }
      const fromStatus = afterSale.status;
      await this.closeWithoutRefund(manager, afterSale);
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.BUYER,
        operatorId: buyerId,
        action: "buyer_cancel",
        fromStatus,
        toStatus: afterSale.status,
      });
      return afterSale;
    });
    await this.notify(
      result.sellerId || result.buyerId,
      NotificationScene.AFTER_SALE_CLOSED,
      result,
    );
    return this.findOne(id, buyerId, "USER");
  }

  async sellerApprove(
    id: number,
    sellerId: number,
    dto: SellerApproveAfterSaleDto,
  ) {
    const policy = await this.getPolicy();
    const shouldRefund = await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      const order = await this.lockOrder(manager, afterSale.orderId);
      this.assertSellerPending(afterSale, sellerId);
      const items = await this.lockItems(manager, id);
      const returnRequired =
        order.status !== OrderStatus.PAID && dto.returnRequired === true;
      if (returnRequired && !dto.returnAddress?.trim()) {
        throw new BadRequestException("要求退货时必须填写退货地址");
      }
      this.approveAllItems(items, order.status === OrderStatus.PAID);
      const fromStatus = afterSale.status;
      afterSale.handlerDecision = HandlerDecision.APPROVED;
      afterSale.handlerReason = dto.reason?.trim() || null;
      afterSale.afterSaleType = returnRequired
        ? AfterSaleType.RETURN_REFUND
        : AfterSaleType.REFUND_ONLY;
      afterSale.returnRequired = returnRequired;
      afterSale.returnAddress = returnRequired
        ? dto.returnAddress.trim()
        : null;
      afterSale.approvedAmount = this.sumApprovedAmount(items);
      afterSale.status = returnRequired
        ? AfterSaleStatus.WAITING_BUYER_RETURN
        : AfterSaleStatus.REFUNDING;
      afterSale.buyerReturnDeadlineAt = returnRequired
        ? new Date(Date.now() + policy.buyerReturnDays * DAY_MS)
        : null;
      await manager.save(OrderAfterSaleItem, items);
      await manager.save(afterSale);
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.SELLER,
        operatorId: sellerId,
        action: returnRequired
          ? "handler_approve_return"
          : "handler_approve_refund",
        fromStatus,
        toStatus: afterSale.status,
        description: dto.reason,
      });
      return !returnRequired;
    });

    const updated = await this.afterSaleRepository.findOneByOrFail({ id });
    await this.notify(
      updated.buyerId,
      NotificationScene.AFTER_SALE_APPROVED,
      updated,
    );
    if (shouldRefund)
      await this.executeRefund(id, sellerId, "卖家同意售后退款");
    return this.findOne(id, sellerId, "USER");
  }

  async sellerReject(
    id: number,
    sellerId: number,
    dto: SellerRejectAfterSaleDto,
  ) {
    this.assertNonBlank(dto.reason, "卖家拒绝理由不能为空");
    const policy = await this.getPolicy();
    const result = await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      await this.lockOrder(manager, afterSale.orderId);
      this.assertSellerPending(afterSale, sellerId);
      const fromStatus = afterSale.status;
      afterSale.status = AfterSaleStatus.HANDLER_REJECTED;
      afterSale.handlerDecision = HandlerDecision.REJECTED;
      afterSale.handlerReason = dto.reason.trim();
      afterSale.arbitrationDeadlineAt = new Date(
        Date.now() + policy.arbitrationDays * DAY_MS,
      );
      await manager.save(afterSale);
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.SELLER,
        operatorId: sellerId,
        action: "handler_reject",
        fromStatus,
        toStatus: afterSale.status,
        description: dto.reason,
      });
      return afterSale;
    });
    await this.notify(
      result.buyerId,
      NotificationScene.AFTER_SALE_REJECTED,
      result,
    );
    return this.findOne(id, sellerId, "USER");
  }

  async adminReview(id: number, adminId: number, dto: AdminReviewAfterSaleDto) {
    const reason = dto.reason?.trim() || undefined;
    const policy = await this.getPolicy();
    let shouldRefund = false;
    const result = await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      const order = await this.lockOrder(manager, afterSale.orderId);
      if (afterSale.handlerType !== AfterSaleHandlerType.PLATFORM) {
        throw new BadRequestException("二手售后请使用平台仲裁流程");
      }
      if (
        ![
          AfterSaleStatus.PENDING_HANDLER,
          AfterSaleStatus.HANDLER_TIMEOUT,
        ].includes(afterSale.status) ||
        this.isTimedOutAfterReturn(afterSale)
      ) {
        throw new BadRequestException("当前售后状态不能进行平台审批");
      }
      const fromStatus = afterSale.status;
      afterSale.reviewerId = adminId;
      afterSale.reviewedAt = new Date();
      afterSale.handlerReason = reason || null;

      if (dto.decision === AdminAfterSaleDecision.REJECT) {
        afterSale.handlerDecision = HandlerDecision.REJECTED;
        await this.closeWithoutRefund(manager, afterSale);
        await this.writeLog(manager, afterSale, {
          operatorType: AfterSaleOperatorType.ADMIN,
          operatorId: adminId,
          action: "platform_reject",
          fromStatus,
          toStatus: afterSale.status,
          description: reason,
        });
        return afterSale;
      }

      const items = await this.lockItems(manager, id);
      this.applyAdminApproval(items, dto);
      const finalType = dto.afterSaleType || afterSale.afterSaleType;
      if (
        order.status === OrderStatus.PAID &&
        finalType === AfterSaleType.RETURN_REFUND
      ) {
        throw new BadRequestException("未发货订单只能同意仅退款");
      }
      const returnRequired = finalType === AfterSaleType.RETURN_REFUND;
      if (returnRequired && !dto.returnAddress?.trim()) {
        throw new BadRequestException("同意退货退款时必须填写退货地址");
      }
      if (order.status === OrderStatus.PAID) {
        for (const item of items) item.restockQuantity = item.approvedQuantity;
      }
      afterSale.handlerDecision = HandlerDecision.APPROVED;
      afterSale.afterSaleType = finalType;
      afterSale.returnRequired = returnRequired;
      afterSale.returnAddress = returnRequired
        ? dto.returnAddress.trim()
        : null;
      afterSale.approvedAmount = this.sumApprovedAmount(items);
      afterSale.status = returnRequired
        ? AfterSaleStatus.WAITING_BUYER_RETURN
        : AfterSaleStatus.REFUNDING;
      afterSale.buyerReturnDeadlineAt = returnRequired
        ? new Date(Date.now() + policy.buyerReturnDays * DAY_MS)
        : null;
      await manager.save(OrderAfterSaleItem, items);
      await manager.save(afterSale);
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.ADMIN,
        operatorId: adminId,
        action: returnRequired
          ? "platform_approve_return"
          : "platform_approve_refund",
        fromStatus,
        toStatus: afterSale.status,
        description: reason,
        snapshot: {
          approvedAmount: afterSale.approvedAmount,
          items: items.map((item) => ({
            lineKey: item.lineKey,
            quantity: item.approvedQuantity,
            approvedAmount: item.approvedAmount,
          })),
        },
      });
      shouldRefund = !returnRequired;
      return afterSale;
    });

    await this.notify(
      result.buyerId,
      result.status === AfterSaleStatus.CLOSED
        ? NotificationScene.AFTER_SALE_REJECTED
        : NotificationScene.AFTER_SALE_APPROVED,
      result,
    );
    if (shouldRefund)
      await this.executeRefund(id, adminId, "平台同意商城售后退款");
    return this.findOne(id, adminId, "SUPER_ADMIN");
  }

  async submitReturn(id: number, buyerId: number, dto: SubmitReturnDto) {
    const policy = await this.getPolicy();
    const result = await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      await this.lockOrder(manager, afterSale.orderId);
      if (afterSale.buyerId !== buyerId) {
        throw new ForbiddenException("只有买家可以提交退货信息");
      }
      if (afterSale.status !== AfterSaleStatus.WAITING_BUYER_RETURN) {
        throw new BadRequestException("当前售后状态不允许提交退货");
      }
      if (
        afterSale.buyerReturnDeadlineAt &&
        afterSale.buyerReturnDeadlineAt < new Date()
      ) {
        throw new BadRequestException("已超过买家退货期限");
      }
      const fromStatus = afterSale.status;
      afterSale.status = AfterSaleStatus.WAITING_HANDLER_RECEIPT;
      afterSale.returnTrackingNumber = dto.trackingNumber?.trim() || null;
      afterSale.returnEvidenceUrls = dto.evidenceUrls || [];
      afterSale.handlerReceiptDeadlineAt = new Date(
        Date.now() + policy.handlerReceiptHours * 60 * 60 * 1000,
      );
      await manager.save(afterSale);
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.BUYER,
        operatorId: buyerId,
        action: "submit_return",
        fromStatus,
        toStatus: afterSale.status,
        snapshot: { trackingNumber: afterSale.returnTrackingNumber },
      });
      return afterSale;
    });
    if (result.handlerType === AfterSaleHandlerType.PLATFORM) {
      await this.notifyPlatformHandlers(
        NotificationScene.AFTER_SALE_RETURNED,
        result,
      );
    } else {
      await this.notify(
        result.sellerId,
        NotificationScene.AFTER_SALE_RETURNED,
        result,
        "seller",
      );
    }
    return this.findOne(id, buyerId, "USER");
  }

  async confirmReturn(id: number, sellerId: number) {
    await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      await this.lockOrder(manager, afterSale.orderId);
      if (
        afterSale.handlerType !== AfterSaleHandlerType.SELLER ||
        afterSale.sellerId !== sellerId
      ) {
        throw new ForbiddenException("只有订单卖家可以确认收到退货");
      }
      if (afterSale.status !== AfterSaleStatus.WAITING_HANDLER_RECEIPT) {
        throw new BadRequestException("当前售后状态不允许确认退货");
      }
      if (
        afterSale.handlerReceiptDeadlineAt &&
        afterSale.handlerReceiptDeadlineAt < new Date()
      ) {
        throw new BadRequestException("确认期限已过，请等待买家申请仲裁");
      }
      const items = await this.lockItems(manager, id);
      for (const item of items) item.restockQuantity = item.approvedQuantity;
      const fromStatus = afterSale.status;
      afterSale.status = AfterSaleStatus.REFUNDING;
      await manager.save(OrderAfterSaleItem, items);
      await manager.save(afterSale);
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.SELLER,
        operatorId: sellerId,
        action: "confirm_return",
        fromStatus,
        toStatus: afterSale.status,
      });
    });
    await this.executeRefund(id, sellerId, "卖家确认收到退货");
    return this.findOne(id, sellerId, "USER");
  }

  async adminConfirmReturn(
    id: number,
    adminId: number,
    dto: AdminConfirmReturnDto,
  ) {
    await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      await this.lockOrder(manager, afterSale.orderId);
      if (afterSale.handlerType !== AfterSaleHandlerType.PLATFORM) {
        throw new BadRequestException("该售后单不由平台确认退货");
      }
      const timedOutAfterReturn = this.isTimedOutAfterReturn(afterSale);
      if (
        afterSale.status !== AfterSaleStatus.WAITING_HANDLER_RECEIPT &&
        !timedOutAfterReturn
      ) {
        throw new BadRequestException("当前售后状态不允许确认退货");
      }
      const items = await this.lockItems(manager, id);
      this.applyRestockQuantities(items, dto);
      const fromStatus = afterSale.status;
      afterSale.status = AfterSaleStatus.REFUNDING;
      afterSale.reviewerId = adminId;
      afterSale.reviewedAt = new Date();
      await manager.save(OrderAfterSaleItem, items);
      await manager.save(afterSale);
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.ADMIN,
        operatorId: adminId,
        action: "platform_confirm_return",
        fromStatus,
        toStatus: afterSale.status,
        description: dto.remark,
        snapshot: {
          items: items.map((item) => ({
            lineKey: item.lineKey,
            restockQuantity: item.restockQuantity,
          })),
        },
      });
    });
    await this.executeRefund(id, adminId, "平台确认收到退货");
    return this.findOne(id, adminId, "SUPER_ADMIN");
  }

  async applyArbitration(
    id: number,
    buyerId: number,
    dto: ApplyArbitrationDto,
  ) {
    this.assertNonBlank(dto.reason, "仲裁理由不能为空");
    const result = await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      await this.lockOrder(manager, afterSale.orderId);
      if (afterSale.handlerType !== AfterSaleHandlerType.SELLER) {
        throw new BadRequestException("平台售后不进入仲裁流程");
      }
      if (afterSale.buyerId !== buyerId) {
        throw new ForbiddenException("只有买家可以申请平台仲裁");
      }
      if (
        ![
          AfterSaleStatus.HANDLER_REJECTED,
          AfterSaleStatus.HANDLER_TIMEOUT,
        ].includes(afterSale.status)
      ) {
        throw new BadRequestException("当前售后状态不能申请仲裁");
      }
      if (
        afterSale.arbitrationDeadlineAt &&
        afterSale.arbitrationDeadlineAt < new Date()
      ) {
        throw new BadRequestException("已超过仲裁申请期限");
      }
      const fromStatus = afterSale.status;
      afterSale.status = AfterSaleStatus.ARBITRATION_PENDING;
      afterSale.arbitrationReason = dto.reason.trim();
      afterSale.arbitrationEvidenceUrls = dto.evidenceUrls || [];
      afterSale.arbitrationAt = new Date();
      await manager.save(afterSale);
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.BUYER,
        operatorId: buyerId,
        action: "apply_arbitration",
        fromStatus,
        toStatus: afterSale.status,
        description: dto.reason,
      });
      return afterSale;
    });
    await this.notify(
      result.sellerId,
      NotificationScene.AFTER_SALE_ARBITRATION,
      result,
    );
    return this.findOne(id, buyerId, "USER");
  }

  async arbitrate(
    id: number,
    adminId: number,
    dto: AdminArbitrateAfterSaleDto,
  ) {
    const remark = dto.remark?.trim() || undefined;
    const supportBuyer = dto.decision === ArbitrationDecision.SUPPORT_BUYER;
    await this.dataSource.transaction(async (manager) => {
      const afterSale = await this.lockAfterSale(manager, id);
      if (
        afterSale.handlerType !== AfterSaleHandlerType.SELLER ||
        afterSale.status !== AfterSaleStatus.ARBITRATION_PENDING
      ) {
        throw new BadRequestException("该售后单不在二手待仲裁状态");
      }
      const fromStatus = afterSale.status;
      afterSale.arbitrationDecision = dto.decision;
      afterSale.arbitrationRemark = remark || null;
      afterSale.arbitratorId = adminId;
      if (supportBuyer) {
        const order = await this.lockOrder(manager, afterSale.orderId);
        const items = await this.lockItems(manager, id);
        if (!items.some((item) => item.approvedQuantity > 0)) {
          this.approveAllItems(items, order.status === OrderStatus.PAID);
        }
        afterSale.approvedAmount = this.sumApprovedAmount(items);
        if (
          order.status === OrderStatus.PAID ||
          (afterSale.handlerDecision === HandlerDecision.APPROVED &&
            afterSale.returnRequired === true)
        ) {
          for (const item of items)
            item.restockQuantity = item.approvedQuantity;
        }
        await manager.save(OrderAfterSaleItem, items);
        afterSale.status = AfterSaleStatus.REFUNDING;
        await manager.save(afterSale);
      } else {
        await this.closeWithoutRefund(manager, afterSale);
      }
      await this.writeLog(manager, afterSale, {
        operatorType: AfterSaleOperatorType.ADMIN,
        operatorId: adminId,
        action: supportBuyer
          ? "arbitration_support_buyer"
          : "arbitration_support_seller",
        fromStatus,
        toStatus: afterSale.status,
        description: remark,
      });
    });
    if (supportBuyer) await this.executeRefund(id, adminId, "平台仲裁支持买家");
    const afterSale = await this.afterSaleRepository.findOneByOrFail({ id });
    await Promise.all([
      this.notify(
        afterSale.buyerId,
        NotificationScene.AFTER_SALE_ARBITRATION_RESULT,
        afterSale,
      ),
      this.notify(
        afterSale.sellerId,
        NotificationScene.AFTER_SALE_ARBITRATION_RESULT,
        afterSale,
      ),
    ]);
    return this.findOne(id, adminId, "SUPER_ADMIN");
  }

  async retryRefund(id: number, adminId: number) {
    const afterSale = await this.afterSaleRepository.findOneBy({ id });
    if (!afterSale) throw new NotFoundException("售后单不存在");
    if (
      afterSale.status !== AfterSaleStatus.REFUNDING ||
      !afterSale.refundFailureReason
    ) {
      throw new BadRequestException("仅退款失败的售后单可以重试");
    }
    await this.executeRefund(id, adminId, "平台重试售后退款");
    return this.findOne(id, adminId, "SUPER_ADMIN");
  }

  async processTimeouts() {
    const now = new Date();
    const policy = await this.getPolicy();
    const candidates = await this.afterSaleRepository.find({
      where: [
        {
          status: AfterSaleStatus.PENDING_HANDLER,
          handlerDeadlineAt: LessThanOrEqual(now),
        },
        {
          status: AfterSaleStatus.HANDLER_REJECTED,
          arbitrationDeadlineAt: LessThanOrEqual(now),
        },
        {
          status: AfterSaleStatus.HANDLER_TIMEOUT,
          arbitrationDeadlineAt: LessThanOrEqual(now),
        },
        {
          status: AfterSaleStatus.WAITING_BUYER_RETURN,
          buyerReturnDeadlineAt: LessThanOrEqual(now),
        },
        {
          status: AfterSaleStatus.WAITING_HANDLER_RECEIPT,
          handlerReceiptDeadlineAt: LessThanOrEqual(now),
        },
      ],
    });
    let processed = 0;

    for (const candidate of candidates) {
      const changed = await this.dataSource.transaction(async (manager) => {
        const afterSale = await this.lockAfterSale(manager, candidate.id);
        const fromStatus = afterSale.status;
        let action = "handler_timeout";
        if (
          fromStatus === AfterSaleStatus.PENDING_HANDLER &&
          afterSale.handlerDeadlineAt &&
          afterSale.handlerDeadlineAt <= now
        ) {
          await this.lockOrder(manager, afterSale.orderId);
          afterSale.status = AfterSaleStatus.HANDLER_TIMEOUT;
          afterSale.handlerDeadlineAt = null;
          afterSale.arbitrationDeadlineAt =
            afterSale.handlerType === AfterSaleHandlerType.SELLER
              ? new Date(Date.now() + policy.arbitrationDays * DAY_MS)
              : null;
          await manager.save(afterSale);
        } else if (
          fromStatus === AfterSaleStatus.WAITING_HANDLER_RECEIPT &&
          afterSale.handlerReceiptDeadlineAt &&
          afterSale.handlerReceiptDeadlineAt <= now
        ) {
          await this.lockOrder(manager, afterSale.orderId);
          afterSale.status = AfterSaleStatus.HANDLER_TIMEOUT;
          afterSale.handlerReceiptDeadlineAt = null;
          afterSale.arbitrationDeadlineAt =
            afterSale.handlerType === AfterSaleHandlerType.SELLER
              ? new Date(Date.now() + policy.arbitrationDays * DAY_MS)
              : null;
          await manager.save(afterSale);
        } else if (
          fromStatus === AfterSaleStatus.WAITING_BUYER_RETURN &&
          afterSale.buyerReturnDeadlineAt &&
          afterSale.buyerReturnDeadlineAt <= now
        ) {
          action = "buyer_return_timeout_close";
          await this.closeWithoutRefund(manager, afterSale);
        } else if (
          afterSale.handlerType === AfterSaleHandlerType.SELLER &&
          [
            AfterSaleStatus.HANDLER_REJECTED,
            AfterSaleStatus.HANDLER_TIMEOUT,
          ].includes(fromStatus) &&
          afterSale.arbitrationDeadlineAt &&
          afterSale.arbitrationDeadlineAt <= now
        ) {
          action = "arbitration_timeout_close";
          await this.closeWithoutRefund(manager, afterSale);
        } else {
          return false;
        }
        await this.writeLog(manager, afterSale, {
          operatorType: AfterSaleOperatorType.SYSTEM,
          operatorId: null,
          action,
          fromStatus,
          toStatus: afterSale.status,
        });
        return true;
      });
      if (!changed) continue;
      processed += 1;
      const current = await this.afterSaleRepository.findOneBy({
        id: candidate.id,
      });
      if (current?.status === AfterSaleStatus.HANDLER_TIMEOUT) {
        const notifications = [
          this.notify(
            current.buyerId,
            NotificationScene.AFTER_SALE_SELLER_TIMEOUT,
            current,
            "buyer",
          ),
        ];
        if (current.handlerType === AfterSaleHandlerType.PLATFORM) {
          notifications.push(
            this.notifyPlatformHandlers(
              NotificationScene.AFTER_SALE_SELLER_TIMEOUT,
              current,
            ),
          );
        }
        await Promise.all(notifications);
      }
    }
    return { total: candidates.length, processed };
  }

  private async executeRefund(id: number, operatorId: number, reason: string) {
    const afterSale = await this.afterSaleRepository.findOne({
      where: { id },
      relations: ["items"],
    });
    if (
      !afterSale ||
      afterSale.status !== AfterSaleStatus.REFUNDING ||
      !afterSale.approvedAmount
    ) {
      throw new BadRequestException("售后单不在有效退款处理中");
    }
    try {
      const refund = await this.paymentService.createShopAfterSaleRefund(
        afterSale.id,
        operatorId,
        reason,
      );
      await this.dataSource.transaction(async (manager) => {
        const locked = await this.lockAfterSale(manager, id);
        if (locked.status === AfterSaleStatus.REFUNDED) return;
        if (locked.status !== AfterSaleStatus.REFUNDING) {
          throw new BadRequestException("售后状态已变化，不能完成退款");
        }
        const items = await this.lockItems(manager, id);
        await this.shopService.finalizeAfterSaleRefund(
          locked.orderId,
          items,
          manager,
          "售后退款累计达到订单实付金额",
          locked.createdAt,
        );
        const fromStatus = locked.status;
        locked.status = AfterSaleStatus.REFUNDED;
        locked.refundId = refund.refundId;
        locked.refundedAt = new Date();
        locked.refundFailureReason = null;
        await manager.save(locked);
        await this.writeLog(manager, locked, {
          operatorType: AfterSaleOperatorType.SYSTEM,
          operatorId,
          action: "refund_success",
          fromStatus,
          toStatus: locked.status,
          snapshot: { refundId: refund.refundId, refundNo: refund.refundNo },
        });
      });
    } catch (error) {
      await this.afterSaleRepository.update(id, {
        refundFailureReason: error?.message || "退款失败",
      });
      const notifications = [
        this.notify(
          afterSale.buyerId,
          NotificationScene.AFTER_SALE_REFUND_FAILED,
          afterSale,
          "buyer",
        ),
      ];
      if (afterSale.handlerType === AfterSaleHandlerType.PLATFORM) {
        notifications.push(
          this.notifyPlatformHandlers(
            NotificationScene.AFTER_SALE_REFUND_FAILED,
            afterSale,
          ),
        );
      } else {
        notifications.push(
          this.notify(
            afterSale.sellerId,
            NotificationScene.AFTER_SALE_REFUND_FAILED,
            afterSale,
            "seller",
          ),
        );
      }
      await Promise.all(notifications);
      throw error;
    }
    await Promise.all([
      this.notify(
        afterSale.buyerId,
        NotificationScene.AFTER_SALE_REFUNDED,
        afterSale,
        "buyer",
      ),
      this.notify(
        afterSale.sellerId,
        NotificationScene.AFTER_SALE_REFUNDED,
        afterSale,
        "seller",
      ),
    ]);
  }

  private async findPage(
    role: "buyer" | "seller" | "admin",
    userId: number | null,
    query: QueryAfterSaleDto,
  ) {
    const page = query.page || 1;
    const pageSize = query.pageSize || 20;
    const qb = this.afterSaleRepository
      .createQueryBuilder("afterSale")
      .leftJoinAndSelect("afterSale.order", "order")
      .leftJoinAndSelect("afterSale.items", "items")
      .leftJoinAndSelect("afterSale.buyer", "buyer")
      .leftJoinAndSelect("afterSale.seller", "seller");
    if (role === "buyer")
      qb.andWhere("afterSale.buyerId = :userId", { userId });
    if (role === "seller") {
      qb.andWhere(
        "afterSale.sellerId = :userId AND afterSale.handlerType = :sellerHandler",
        { userId, sellerHandler: AfterSaleHandlerType.SELLER },
      );
    }
    if (query.status)
      qb.andWhere("afterSale.status = :status", { status: query.status });
    if (query.orderType)
      qb.andWhere("afterSale.orderType = :orderType", {
        orderType: query.orderType,
      });
    if (query.handlerType)
      qb.andWhere("afterSale.handlerType = :handlerType", {
        handlerType: query.handlerType,
      });
    if (query.orderId)
      qb.andWhere("afterSale.orderId = :orderId", { orderId: query.orderId });
    if (query.buyerId)
      qb.andWhere("afterSale.buyerId = :buyerId", { buyerId: query.buyerId });
    if (query.productId)
      qb.andWhere("items.productId = :productId", {
        productId: query.productId,
      });
    if (query.keyword?.trim()) {
      qb.andWhere(
        "(afterSale.afterSaleNo LIKE :keyword OR order.orderNo LIKE :keyword OR buyer.username LIKE :keyword OR buyer.phone LIKE :keyword OR seller.username LIKE :keyword OR seller.phone LIKE :keyword OR items.productName LIKE :keyword)",
        { keyword: `%${query.keyword.trim()}%` },
      );
    }
    if (query.createdFrom)
      qb.andWhere("afterSale.createdAt >= :createdFrom", {
        createdFrom: new Date(query.createdFrom),
      });
    if (query.createdTo) {
      const createdTo = new Date(query.createdTo);
      createdTo.setHours(23, 59, 59, 999);
      qb.andWhere("afterSale.createdAt <= :createdTo", { createdTo });
    }
    this.applyViewFilter(qb, query.view);
    if (query.overdue) {
      const expression = `(CASE
        WHEN afterSale.status = :pendingHandler THEN afterSale.handlerDeadlineAt
        WHEN afterSale.status IN (:...disputeStatuses) THEN afterSale.arbitrationDeadlineAt
        WHEN afterSale.status = :waitingBuyerReturn THEN afterSale.buyerReturnDeadlineAt
        WHEN afterSale.status = :waitingHandlerReceipt THEN afterSale.handlerReceiptDeadlineAt
        ELSE NULL END)`;
      qb.andWhere(
        query.overdue === "true"
          ? `${expression} < CURRENT_TIMESTAMP`
          : `(${expression} IS NULL OR ${expression} >= CURRENT_TIMESTAMP)`,
        {
          pendingHandler: AfterSaleStatus.PENDING_HANDLER,
          disputeStatuses: [
            AfterSaleStatus.HANDLER_REJECTED,
            AfterSaleStatus.HANDLER_TIMEOUT,
          ],
          waitingBuyerReturn: AfterSaleStatus.WAITING_BUYER_RETURN,
          waitingHandlerReceipt: AfterSaleStatus.WAITING_HANDLER_RECEIPT,
        },
      );
    }
    qb.distinct(true)
      .orderBy("afterSale.createdAt", "DESC")
      .skip((page - 1) * pageSize)
      .take(pageSize);
    const [data, total] = await qb.getManyAndCount();
    return {
      data: data.map((item) => this.toView(item, [], role)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  private applyViewFilter(qb: any, view?: QueryAfterSaleDto["view"]) {
    if (view === "pending" || view === "second_hand_arbitration") {
      qb.andWhere(
        "afterSale.handlerType = :sellerHandler AND afterSale.status = :arbitrationPending",
        {
          sellerHandler: AfterSaleHandlerType.SELLER,
          arbitrationPending: AfterSaleStatus.ARBITRATION_PENDING,
        },
      );
    }
    if (view === "platform_pending") {
      qb.andWhere(
        "afterSale.handlerType = :platformHandler AND afterSale.status IN (:...platformPendingStatuses)",
        {
          platformHandler: AfterSaleHandlerType.PLATFORM,
          platformPendingStatuses: [
            AfterSaleStatus.PENDING_HANDLER,
            AfterSaleStatus.HANDLER_TIMEOUT,
            AfterSaleStatus.WAITING_HANDLER_RECEIPT,
          ],
        },
      );
    }
    if (view === "processing") {
      qb.andWhere("afterSale.status IN (:...processing)", {
        processing: ACTIVE_STATUSES,
      });
    }
    if (view === "finished") {
      qb.andWhere("afterSale.status IN (:...finished)", {
        finished: FINISHED_STATUSES,
      });
    }
  }

  private toView(
    afterSale: OrderAfterSale,
    logs: OrderAfterSaleLog[],
    viewRole: string,
  ) {
    const deadline = this.currentDeadline(afterSale);
    return {
      ...afterSale,
      refundAmount: afterSale.approvedAmount || afterSale.requestedAmount,
      sellerDecision: afterSale.handlerDecision,
      sellerReason: afterSale.handlerReason,
      sellerDeadlineAt: afterSale.handlerDeadlineAt,
      sellerReceiptDeadlineAt: afterSale.handlerReceiptDeadlineAt,
      buyer: afterSale.buyer ? this.userSummary(afterSale.buyer) : undefined,
      seller: afterSale.seller ? this.userSummary(afterSale.seller) : undefined,
      arbitrator: afterSale.arbitrator
        ? this.userSummary(afterSale.arbitrator)
        : undefined,
      reviewer: afterSale.reviewer
        ? this.userSummary(afterSale.reviewer)
        : undefined,
      viewRole,
      isOverdue: Boolean(deadline && deadline < new Date()),
      currentDeadlineAt: deadline,
      availableActions: this.availableActions(afterSale, viewRole),
      logs,
    };
  }

  private currentDeadline(afterSale: OrderAfterSale): Date | null {
    switch (afterSale.status) {
      case AfterSaleStatus.PENDING_HANDLER:
        return afterSale.handlerDeadlineAt;
      case AfterSaleStatus.HANDLER_REJECTED:
      case AfterSaleStatus.HANDLER_TIMEOUT:
        return afterSale.arbitrationDeadlineAt;
      case AfterSaleStatus.WAITING_BUYER_RETURN:
        return afterSale.buyerReturnDeadlineAt;
      case AfterSaleStatus.WAITING_HANDLER_RECEIPT:
        return afterSale.handlerReceiptDeadlineAt;
      default:
        return null;
    }
  }

  private availableActions(afterSale: OrderAfterSale, role: string) {
    const actions: string[] = [];
    const deadline = this.currentDeadline(afterSale);
    const beforeDeadline = !deadline || deadline >= new Date();
    if (role === "buyer") {
      if (
        [
          AfterSaleStatus.PENDING_HANDLER,
          AfterSaleStatus.HANDLER_REJECTED,
          AfterSaleStatus.HANDLER_TIMEOUT,
          AfterSaleStatus.WAITING_BUYER_RETURN,
        ].includes(afterSale.status) &&
        !this.isTimedOutAfterReturn(afterSale)
      )
        actions.push("cancel_after_sale");
      if (
        afterSale.status === AfterSaleStatus.WAITING_BUYER_RETURN &&
        beforeDeadline
      ) {
        actions.push("submit_return");
      }
      if (
        afterSale.handlerType === AfterSaleHandlerType.SELLER &&
        [
          AfterSaleStatus.HANDLER_REJECTED,
          AfterSaleStatus.HANDLER_TIMEOUT,
        ].includes(afterSale.status) &&
        beforeDeadline
      )
        actions.push("request_arbitration");
    }
    if (
      role === "seller" &&
      afterSale.handlerType === AfterSaleHandlerType.SELLER
    ) {
      if (
        afterSale.status === AfterSaleStatus.PENDING_HANDLER &&
        beforeDeadline
      ) {
        actions.push("approve_after_sale", "reject_after_sale");
      }
      if (
        afterSale.status === AfterSaleStatus.WAITING_HANDLER_RECEIPT &&
        beforeDeadline
      ) {
        actions.push("confirm_return");
      }
    }
    if (role === "admin") {
      if (
        afterSale.handlerType === AfterSaleHandlerType.PLATFORM &&
        [
          AfterSaleStatus.PENDING_HANDLER,
          AfterSaleStatus.HANDLER_TIMEOUT,
        ].includes(afterSale.status) &&
        !this.isTimedOutAfterReturn(afterSale)
      )
        actions.push("review_after_sale");
      if (
        afterSale.handlerType === AfterSaleHandlerType.PLATFORM &&
        (afterSale.status === AfterSaleStatus.WAITING_HANDLER_RECEIPT ||
          this.isTimedOutAfterReturn(afterSale))
      )
        actions.push("confirm_return");
      if (
        afterSale.handlerType === AfterSaleHandlerType.SELLER &&
        afterSale.status === AfterSaleStatus.ARBITRATION_PENDING
      )
        actions.push("arbitrate");
      if (
        afterSale.status === AfterSaleStatus.REFUNDING &&
        afterSale.refundFailureReason
      ) {
        actions.push("retry_refund");
      }
    }
    return actions;
  }

  private assertCanCreate(
    order: Order,
    buyerId: number,
    policy: AfterSalePolicy,
  ) {
    if (order.userId !== buyerId)
      throw new ForbiddenException("只有订单买家可以申请售后");
    if (order.orderType === OrderType.SECOND_HAND && !order.sellerId) {
      throw new BadRequestException("二手订单缺少卖家信息，无法申请售后");
    }
    const allowed =
      order.orderType === OrderType.NORMAL
        ? [OrderStatus.PAID, OrderStatus.SHIPPED, OrderStatus.COMPLETED]
        : [OrderStatus.PAID, OrderStatus.SHIPPED];
    if (!allowed.includes(order.status)) {
      throw new BadRequestException("当前订单状态不允许申请售后");
    }
    if (
      order.orderType === OrderType.NORMAL &&
      order.status === OrderStatus.COMPLETED
    ) {
      const deadline =
        order.afterSaleDeadlineAt ||
        (order.completedAt
          ? new Date(
              order.completedAt.getTime() + policy.normalCompletedDays * DAY_MS,
            )
          : null);
      if (!deadline || deadline < new Date()) {
        throw new BadRequestException("订单已超过售后申请期限");
      }
    }
  }

  private resolveRequestedType(order: Order, requested?: AfterSaleType) {
    if (order.orderType === OrderType.NORMAL && !requested) {
      throw new BadRequestException("请选择售后类型");
    }
    const type = requested || AfterSaleType.REFUND_ONLY;
    if (
      order.status === OrderStatus.PAID &&
      type === AfterSaleType.RETURN_REFUND
    ) {
      throw new BadRequestException("未发货订单只能申请仅退款");
    }
    return type;
  }

  private async buildRequestedLines(
    manager: any,
    order: Order,
    dto: CreateAfterSaleDto,
  ): Promise<RequestedLine[]> {
    const orderItems = order.items || [];
    if (!orderItems.length || orderItems.some((item) => !item.lineKey)) {
      throw new BadRequestException("订单商品快照不完整，请联系平台处理");
    }
    const refundedSales = await manager.find(OrderAfterSale, {
      where: { orderId: order.id, status: AfterSaleStatus.REFUNDED },
      relations: ["items"],
    });
    const refundedByLine = new Map<string, number>();
    for (const sale of refundedSales) {
      for (const item of sale.items || []) {
        refundedByLine.set(
          item.lineKey,
          (refundedByLine.get(item.lineKey) || 0) +
            Number(item.refundedQuantity || 0),
        );
      }
    }

    const selections =
      order.orderType === OrderType.SECOND_HAND && !dto.items?.length
        ? orderItems.map((item) => ({
            lineKey: item.lineKey,
            quantity: item.quantity,
          }))
        : dto.items || [];
    if (!selections.length)
      throw new BadRequestException("请选择售后商品和数量");
    if (
      new Set(selections.map((item) => item.lineKey)).size !== selections.length
    ) {
      throw new BadRequestException("售后商品行不能重复");
    }
    const orderItemMap = new Map(
      orderItems.map((item) => [item.lineKey, item]),
    );
    return selections.map((selection) => {
      const orderItem = orderItemMap.get(selection.lineKey);
      if (!orderItem) throw new BadRequestException("所选商品不属于该订单");
      const alreadyRefundedQuantity =
        refundedByLine.get(selection.lineKey) || 0;
      const remaining = orderItem.quantity - alreadyRefundedQuantity;
      if (selection.quantity < 1 || selection.quantity > remaining) {
        throw new BadRequestException(
          `${orderItem.productName}的可售后数量不足`,
        );
      }
      const paidAmount = this.amountForQuantity(
        orderItem.paidAmount,
        orderItem.quantity,
        alreadyRefundedQuantity,
        selection.quantity,
      );
      const grossAmount = toYuan(toCents(orderItem.price) * selection.quantity);
      return {
        orderItem,
        requestedQuantity: selection.quantity,
        alreadyRefundedQuantity,
        paidAmount,
        discountAmount: toYuan(toCents(grossAmount) - toCents(paidAmount)),
      };
    });
  }

  private amountForQuantity(
    totalAmount: number,
    totalQuantity: number,
    offset: number,
    quantity: number,
  ) {
    const cents = toCents(totalAmount);
    const base = Math.floor(cents / totalQuantity);
    const remainder = cents % totalQuantity;
    let selected = 0;
    for (let index = offset; index < offset + quantity; index += 1) {
      selected += base + (index < remainder ? 1 : 0);
    }
    return toYuan(selected);
  }

  private approveAllItems(items: OrderAfterSaleItem[], restock: boolean) {
    for (const item of items) {
      item.approvedQuantity = item.requestedQuantity;
      item.approvedAmount = toNumber(item.paidAmount);
      item.restockQuantity = restock ? item.approvedQuantity : 0;
    }
  }

  private applyAdminApproval(
    items: OrderAfterSaleItem[],
    dto: AdminReviewAfterSaleDto,
  ) {
    const requested = dto.approvedItems?.length
      ? dto.approvedItems
      : items.map((item) => ({
          lineKey: item.lineKey,
          quantity: item.requestedQuantity,
        }));
    if (
      new Set(requested.map((item) => item.lineKey)).size !== requested.length
    ) {
      throw new BadRequestException("审批商品行不能重复");
    }
    const approvedMap = new Map(
      requested.map((item) => [item.lineKey, item.quantity]),
    );
    for (const lineKey of approvedMap.keys()) {
      if (!items.some((item) => item.lineKey === lineKey)) {
        throw new BadRequestException("审批商品不属于该售后单");
      }
    }
    for (const item of items) {
      const quantity = approvedMap.get(item.lineKey) || 0;
      if (quantity < 0 || quantity > item.requestedQuantity) {
        throw new BadRequestException(`${item.productName}的审批数量无效`);
      }
      item.approvedQuantity = quantity;
      item.approvedAmount = quantity
        ? this.amountForQuantity(
            item.paidAmount,
            item.requestedQuantity,
            0,
            quantity,
          )
        : 0;
      item.restockQuantity = 0;
    }
    if (!items.some((item) => item.approvedQuantity > 0)) {
      throw new BadRequestException("至少需要同意一个商品数量");
    }
  }

  private applyRestockQuantities(
    items: OrderAfterSaleItem[],
    dto: AdminConfirmReturnDto,
  ) {
    if (
      new Set(dto.items.map((item) => item.lineKey)).size !== dto.items.length
    ) {
      throw new BadRequestException("回库商品行不能重复");
    }
    const restockMap = new Map(
      dto.items.map((item) => [item.lineKey, item.restockQuantity]),
    );
    for (const lineKey of restockMap.keys()) {
      if (!items.some((item) => item.lineKey === lineKey)) {
        throw new BadRequestException("回库商品不属于该售后单");
      }
    }
    for (const item of items) {
      const quantity = restockMap.get(item.lineKey) || 0;
      if (quantity < 0 || quantity > item.approvedQuantity) {
        throw new BadRequestException(`${item.productName}的回库数量无效`);
      }
      item.restockQuantity = quantity;
    }
  }

  private sumApprovedAmount(items: OrderAfterSaleItem[]) {
    return toYuan(
      items.reduce((sum, item) => sum + toCents(item.approvedAmount), 0),
    );
  }

  private isTimedOutAfterReturn(afterSale: OrderAfterSale) {
    return (
      afterSale.status === AfterSaleStatus.HANDLER_TIMEOUT &&
      afterSale.handlerDecision === HandlerDecision.APPROVED &&
      afterSale.returnRequired === true
    );
  }

  private async closeWithoutRefund(manager: any, afterSale: OrderAfterSale) {
    afterSale.status = AfterSaleStatus.CLOSED;
    afterSale.closedAt = new Date();
    await manager.save(afterSale);
    const order = await this.lockOrder(manager, afterSale.orderId);
    if (
      order.autoConfirmAt &&
      [OrderStatus.PAID, OrderStatus.SHIPPED].includes(order.status)
    ) {
      const occupiedMs = Math.max(
        afterSale.closedAt.getTime() - afterSale.createdAt.getTime(),
        0,
      );
      order.autoConfirmAt = new Date(
        order.autoConfirmAt.getTime() + occupiedMs,
      );
      await manager.save(order);
    }
  }

  private assertSellerPending(afterSale: OrderAfterSale, sellerId: number) {
    if (
      afterSale.handlerType !== AfterSaleHandlerType.SELLER ||
      afterSale.sellerId !== sellerId
    )
      throw new ForbiddenException("只有订单卖家可以处理售后");
    if (afterSale.status !== AfterSaleStatus.PENDING_HANDLER) {
      throw new BadRequestException("当前售后状态不能由卖家处理");
    }
    if (
      afterSale.handlerDeadlineAt &&
      afterSale.handlerDeadlineAt < new Date()
    ) {
      throw new BadRequestException("卖家处理期限已过，请等待系统更新售后状态");
    }
  }

  private assertNonBlank(value: string, message: string) {
    if (!value?.trim()) throw new BadRequestException(message);
  }

  private async lockOrder(manager: any, id: number): Promise<Order> {
    const order = await manager
      .createQueryBuilder(Order, "order")
      .where("order.id = :id", { id })
      .setLock("pessimistic_write")
      .getOne();
    if (!order) throw new NotFoundException("订单不存在");
    return order;
  }

  private async lockAfterSale(
    manager: any,
    id: number,
  ): Promise<OrderAfterSale> {
    const afterSale = await manager
      .createQueryBuilder(OrderAfterSale, "afterSale")
      .where("afterSale.id = :id", { id })
      .setLock("pessimistic_write")
      .getOne();
    if (!afterSale) throw new NotFoundException("售后单不存在");
    return afterSale;
  }

  private async lockItems(manager: any, afterSaleId: number) {
    return manager.find(OrderAfterSaleItem, {
      where: { afterSaleId },
      lock: { mode: "pessimistic_write" },
      order: { id: "ASC" },
    }) as Promise<OrderAfterSaleItem[]>;
  }

  private async writeLog(
    manager: any,
    afterSale: OrderAfterSale,
    input: Partial<OrderAfterSaleLog> &
      Pick<OrderAfterSaleLog, "operatorType" | "action">,
  ) {
    await manager.save(
      OrderAfterSaleLog,
      manager.create(OrderAfterSaleLog, {
        afterSaleId: afterSale.id,
        ...input,
      }),
    );
  }

  private async getPolicy(): Promise<AfterSalePolicy> {
    const primary = await this.configRepository.findOne({
      where: { configKey: POLICY_CONFIG_KEY },
    });
    const legacy = primary
      ? null
      : await this.configRepository.findOne({
          where: { configKey: LEGACY_POLICY_CONFIG_KEY },
        });
    const value = primary?.configValue || legacy?.configValue || {};
    return {
      handlerHours: Number(value.handlerHours ?? value.sellerHandleHours) || 48,
      arbitrationDays: Number(value.arbitrationDays) || 7,
      buyerReturnDays: Number(value.buyerReturnDays) || 7,
      handlerReceiptHours:
        Number(value.handlerReceiptHours ?? value.sellerReceiptHours) || 48,
      normalCompletedDays: Number(value.normalCompletedDays) || 7,
    };
  }

  private userSummary(user: any) {
    return {
      id: user.id,
      username: user.username,
      phone: user.phone,
      avatar: user.avatar,
    };
  }

  private notify(
    userId: number | null | undefined,
    scene: NotificationScene,
    value: Partial<OrderAfterSale>,
    viewRole?: "buyer" | "seller" | "admin",
  ) {
    if (!userId) return Promise.resolve(null);
    return this.notificationSender.send(userId, scene, {
      orderId: value.orderId,
      afterSaleId: value.id,
      orderType: value.orderType,
      handlerType: value.handlerType,
      viewRole: viewRole || (userId === value.sellerId ? "seller" : "buyer"),
    });
  }

  private async notifyPlatformHandlers(
    scene: NotificationScene,
    value: Partial<OrderAfterSale>,
  ) {
    const handlers = await this.dataSource.getRepository(User).find({
      select: { id: true },
      where: {
        role: In([UserRole.SUPER_ADMIN, UserRole.STAFF]),
        isActive: true,
      },
    });
    await Promise.all(
      handlers.map((handler) => this.notify(handler.id, scene, value, "admin")),
    );
    return null;
  }

  private generateAfterSaleNo() {
    return `AS${randomUUID().replace(/-/g, "").slice(0, 24).toUpperCase()}`;
  }
}
