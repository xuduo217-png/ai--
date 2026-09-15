import { Injectable, Logger } from "@nestjs/common";
import { NotificationsService } from "./notifications.service";
import { NotificationType, ActionType } from "./entities/notification.entity";

/**
 * 通知场景枚举
 * 定义所有业务中需要发送通知的场景
 */
export enum NotificationScene {
  // ========== 预约相关 ==========
  /** 用户创建预约成功 */
  APPOINTMENT_CREATED = "APPOINTMENT_CREATED",
  /** 预约被确认 */
  APPOINTMENT_CONFIRMED = "APPOINTMENT_CONFIRMED",
  /** 预约被拒绝 */
  APPOINTMENT_REJECTED = "APPOINTMENT_REJECTED",
  /** 预约已完成 */
  APPOINTMENT_COMPLETED = "APPOINTMENT_COMPLETED",
  /** 预约已取消 */
  APPOINTMENT_CANCELLED = "APPOINTMENT_CANCELLED",
  /** 预约时间变更 */
  APPOINTMENT_RESCHEDULED = "APPOINTMENT_RESCHEDULED",

  // ========== 订单相关 ==========
  /** 订单创建成功 */
  ORDER_CREATED = "ORDER_CREATED",
  /** 订单已支付 */
  ORDER_PAID = "ORDER_PAID",
  /** 订单已发货 */
  ORDER_SHIPPED = "ORDER_SHIPPED",
  /** 订单已完成 */
  ORDER_COMPLETED = "ORDER_COMPLETED",
  /** 订单已取消 */
  ORDER_CANCELLED = "ORDER_CANCELLED",
  /** 订单退款成功 */
  ORDER_REFUNDED = "ORDER_REFUNDED",
  /** 买家发起售后 */
  AFTER_SALE_CREATED = "AFTER_SALE_CREATED",
  /** 卖家同意售后 */
  AFTER_SALE_APPROVED = "AFTER_SALE_APPROVED",
  /** 卖家拒绝售后 */
  AFTER_SALE_REJECTED = "AFTER_SALE_REJECTED",
  /** 卖家处理售后超时 */
  AFTER_SALE_SELLER_TIMEOUT = "AFTER_SALE_SELLER_TIMEOUT",
  /** 买家已提交退货 */
  AFTER_SALE_RETURNED = "AFTER_SALE_RETURNED",
  /** 售后进入仲裁 */
  AFTER_SALE_ARBITRATION = "AFTER_SALE_ARBITRATION",
  /** 仲裁结果 */
  AFTER_SALE_ARBITRATION_RESULT = "AFTER_SALE_ARBITRATION_RESULT",
  /** 售后退款成功 */
  AFTER_SALE_REFUNDED = "AFTER_SALE_REFUNDED",
  /** 售后退款失败 */
  AFTER_SALE_REFUND_FAILED = "AFTER_SALE_REFUND_FAILED",
  /** 售后关闭 */
  AFTER_SALE_CLOSED = "AFTER_SALE_CLOSED",
  /** 卖家收入结算完成 */
  SELLER_SETTLEMENT_APPROVED = "SELLER_SETTLEMENT_APPROVED",
  /** 卖家收入结算审核未通过 */
  SELLER_SETTLEMENT_REJECTED = "SELLER_SETTLEMENT_REJECTED",
  /** 提现申请已提交 */
  WALLET_WITHDRAWAL_SUBMITTED = "WALLET_WITHDRAWAL_SUBMITTED",
  /** 提现已到账 */
  WALLET_WITHDRAWAL_SUCCEEDED = "WALLET_WITHDRAWAL_SUCCEEDED",
  /** 提现审核拒绝 */
  WALLET_WITHDRAWAL_REJECTED = "WALLET_WITHDRAWAL_REJECTED",
  /** 提现转账失败 */
  WALLET_WITHDRAWAL_FAILED = "WALLET_WITHDRAWAL_FAILED",
  /** 商品审核通过 */
  PRODUCT_AUDIT_APPROVED = "PRODUCT_AUDIT_APPROVED",
  /** 商品审核拒绝 */
  PRODUCT_AUDIT_REJECTED = "PRODUCT_AUDIT_REJECTED",

  // ========== 聊天相关 ==========
  /** 收到新消息 */
  CHAT_NEW_MESSAGE = "CHAT_NEW_MESSAGE",
  /** 聊天订单即将过期 */
  CHAT_ORDER_EXPIRING = "CHAT_ORDER_EXPIRING",

  // ========== 健康预约相关 ==========
  /** 健康预约创建成功 */
  HEALTH_APPOINTMENT_CREATED = "HEALTH_APPOINTMENT_CREATED",
  /** 健康预约已完成 */
  HEALTH_APPOINTMENT_COMPLETED = "HEALTH_APPOINTMENT_COMPLETED",

  // ========== 互动相关 ==========
  /** 收到新的关注 */
  FOLLOWER_NEW = "FOLLOWER_NEW",
  /** 点赞通知 */
  LIKE_RECEIVED = "LIKE_RECEIVED",
  /** 收到评论 */
  COMMENT_RECEIVED = "COMMENT_RECEIVED",

  // ========== 系统相关 ==========
  /** 系统公告 */
  SYSTEM_ANNOUNCEMENT = "SYSTEM_ANNOUNCEMENT",
  /** 账号安全提醒 */
  ACCOUNT_SECURITY = "ACCOUNT_SECURITY",
}

/**
 * 通知模板配置
 */
interface NotificationTemplate {
  type: NotificationType;
  title: string | ((data: any) => string);
  content: string | ((data: any) => string);
  actionType?: ActionType;
  actionDataBuilder?: (data: any) => Record<string, any> | undefined;
  priority?: number;
}

const buildAfterSaleAction = (data: any) => ({
  orderId: data.orderId,
  afterSaleId: data.afterSaleId,
  orderType: data.orderType,
  handlerType: data.handlerType,
  viewRole: data.viewRole || "buyer",
});

/**
 * 通知场景与模板映射
 */
const NOTIFICATION_TEMPLATES: Record<NotificationScene, NotificationTemplate> =
  {
    // ========== 预约相关 ==========
    [NotificationScene.APPOINTMENT_CREATED]: {
      type: NotificationType.INTERACTION,
      title: "预约申请已提交",
      content: (data) =>
        `您的${data.hospitalName || "医院"}预约已提交，请等待确认`,
      actionType: ActionType.APPOINTMENT,
      actionDataBuilder: (data) => ({
        appointmentId: data.appointmentId,
        appointmentKind: "standard",
      }),
      priority: 10,
    },
    [NotificationScene.APPOINTMENT_CONFIRMED]: {
      type: NotificationType.INTERACTION,
      title: "预约已确认",
      content: (data) =>
        `您的${data.hospitalName || "医院"}预约已确认，预约时间：${data.appointmentTime}`,
      actionType: ActionType.APPOINTMENT,
      actionDataBuilder: (data) => ({
        appointmentId: data.appointmentId,
        appointmentKind: "standard",
      }),
      priority: 10,
    },
    [NotificationScene.APPOINTMENT_REJECTED]: {
      type: NotificationType.INTERACTION,
      title: "预约已被拒绝",
      content: (data) =>
        `您的${data.hospitalName || "医院"}预约已被拒绝，原因：${data.reason || "暂无"}`,
      actionType: ActionType.APPOINTMENT,
      actionDataBuilder: (data) => ({
        appointmentId: data.appointmentId,
        appointmentKind: "standard",
      }),
      priority: 10,
    },
    [NotificationScene.APPOINTMENT_COMPLETED]: {
      type: NotificationType.INTERACTION,
      title: "预约已完成",
      content: (data) => `您的${data.hospitalName || "医院"}预约已完成`,
      actionType: ActionType.APPOINTMENT,
      actionDataBuilder: (data) => ({
        appointmentId: data.appointmentId,
        appointmentKind: "standard",
      }),
      priority: 5,
    },
    [NotificationScene.APPOINTMENT_CANCELLED]: {
      type: NotificationType.INTERACTION,
      title: "预约已取消",
      content: (data) => `您的${data.hospitalName || "医院"}预约已取消`,
      actionType: ActionType.APPOINTMENT,
      actionDataBuilder: (data) => ({
        appointmentId: data.appointmentId,
        appointmentKind: "standard",
      }),
      priority: 5,
    },
    [NotificationScene.APPOINTMENT_RESCHEDULED]: {
      type: NotificationType.INTERACTION,
      title: "预约时间已变更",
      content: (data) =>
        `您的${data.hospitalName || "医院"}预约时间已变更为：${data.newTime}`,
      actionType: ActionType.APPOINTMENT,
      actionDataBuilder: (data) => ({
        appointmentId: data.appointmentId,
        appointmentKind: "standard",
      }),
      priority: 10,
    },

    // ========== 订单相关 ==========
    [NotificationScene.ORDER_CREATED]: {
      type: NotificationType.INTERACTION,
      title: "订单创建成功",
      content: (data) => `您的订单已创建成功，请尽快完成支付`,
      actionType: ActionType.ORDER,
      actionDataBuilder: (data) => ({
        orderId: data.orderId,
        viewRole: data.viewRole || "buyer",
      }),
      priority: 10,
    },
    [NotificationScene.ORDER_PAID]: {
      type: NotificationType.INTERACTION,
      title: (data) =>
        data.viewRole === "seller" ? "买家已付款" : "订单已支付",
      content: (data) =>
        data.viewRole === "seller"
          ? "买家已完成付款，请尽快确认发货"
          : "您的订单已支付成功，我们将尽快为您发货",
      actionType: ActionType.ORDER,
      actionDataBuilder: (data) => ({
        orderId: data.orderId,
        viewRole: data.viewRole || "buyer",
      }),
      priority: 10,
    },
    [NotificationScene.ORDER_SHIPPED]: {
      type: NotificationType.INTERACTION,
      title: "订单已发货",
      content: (data) => `您的订单已发货，请注意查收`,
      actionType: ActionType.ORDER,
      actionDataBuilder: (data) => ({
        orderId: data.orderId,
        viewRole: data.viewRole || "buyer",
      }),
      priority: 10,
    },
    [NotificationScene.ORDER_COMPLETED]: {
      type: NotificationType.INTERACTION,
      title: "订单已完成",
      content: (data) =>
        data.viewRole === "seller"
          ? "订单已完成，销售收入已进入结算"
          : "您的订单已完成，感谢您的购买",
      actionType: ActionType.ORDER,
      actionDataBuilder: (data) => ({
        orderId: data.orderId,
        viewRole: data.viewRole || "buyer",
      }),
      priority: 5,
    },
    [NotificationScene.ORDER_CANCELLED]: {
      type: NotificationType.INTERACTION,
      title: "订单已取消",
      content: (data) =>
        `您的订单已取消${data.reason ? `，原因：${data.reason}` : ""}`,
      actionType: ActionType.ORDER,
      actionDataBuilder: (data) => ({
        orderId: data.orderId,
        viewRole: data.viewRole || "buyer",
      }),
      priority: 5,
    },
    [NotificationScene.ORDER_REFUNDED]: {
      type: NotificationType.INTERACTION,
      title: "退款成功",
      content: (data) =>
        `您的订单退款已成功处理，金额：¥${data.refundAmount || "0.00"}`,
      actionType: ActionType.ORDER,
      actionDataBuilder: (data) => ({
        orderId: data.orderId,
        viewRole: data.viewRole || "buyer",
      }),
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_CREATED]: {
      type: NotificationType.INTERACTION,
      title: (data) =>
        data.viewRole === "buyer" ? "售后申请已提交" : "收到售后申请",
      content: (data) =>
        data.viewRole === "buyer"
          ? "平台将处理您的售后申请，请留意进度"
          : "买家已提交售后申请，请及时处理",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_APPROVED]: {
      type: NotificationType.INTERACTION,
      title: "售后申请已同意",
      content: (data) =>
        `${data.handlerType === "platform" ? "平台" : "卖家"}已同意您的售后申请，请查看处理进度`,
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_REJECTED]: {
      type: NotificationType.INTERACTION,
      title: "售后申请被拒绝",
      content: (data) =>
        data.handlerType === "platform"
          ? "平台未同意本次售后申请，该售后已关闭"
          : "卖家已拒绝售后申请，您可以在期限内申请平台仲裁",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_SELLER_TIMEOUT]: {
      type: NotificationType.INTERACTION,
      title: (data) =>
        `${data.handlerType === "platform" ? "平台" : "卖家"}处理售后已超时`,
      content: (data) =>
        data.handlerType === "platform"
          ? "平台处理已超时，售后仍在处理中，不会自动退款或关闭"
          : "卖家未在期限内处理，您可以申请平台仲裁",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_RETURNED]: {
      type: NotificationType.INTERACTION,
      title: "买家已提交退货",
      content: "买家已提交退货信息，请在收到商品后确认",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_ARBITRATION]: {
      type: NotificationType.INTERACTION,
      title: "售后已申请平台仲裁",
      content: "该售后已进入平台仲裁，请等待处理结果",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_ARBITRATION_RESULT]: {
      type: NotificationType.INTERACTION,
      title: "平台仲裁已有结果",
      content: "平台已完成售后仲裁，请查看处理结果",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_REFUNDED]: {
      type: NotificationType.INTERACTION,
      title: "售后退款成功",
      content: "售后退款已完成，请查看详情",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_REFUND_FAILED]: {
      type: NotificationType.INTERACTION,
      title: "售后退款处理失败",
      content: "退款暂未完成，平台将核对后重试，请勿重复提交",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 10,
    },
    [NotificationScene.AFTER_SALE_CLOSED]: {
      type: NotificationType.INTERACTION,
      title: "售后已关闭",
      content: "该售后已关闭，请查看详情",
      actionType: ActionType.ORDER,
      actionDataBuilder: buildAfterSaleAction,
      priority: 5,
    },
    [NotificationScene.SELLER_SETTLEMENT_APPROVED]: {
      type: NotificationType.INTERACTION,
      title: "销售收入已结算",
      content: (data) =>
        `订单销售收入 ¥${data.amount || "0.00"} 已转入可用余额`,
      actionType: ActionType.ORDER,
      actionDataBuilder: (data) => ({
        orderId: data.orderId,
        viewRole: "seller",
      }),
      priority: 10,
    },
    [NotificationScene.SELLER_SETTLEMENT_REJECTED]: {
      type: NotificationType.INTERACTION,
      title: "销售收入结算未通过",
      content: (data) =>
        `订单销售收入暂未结算${data.reason ? `，原因：${data.reason}` : ""}`,
      actionType: ActionType.ORDER,
      actionDataBuilder: (data) => ({
        orderId: data.orderId,
        viewRole: "seller",
      }),
      priority: 10,
    },
    [NotificationScene.WALLET_WITHDRAWAL_SUBMITTED]: {
      type: NotificationType.INTERACTION,
      title: "提现申请已提交",
      content: (data) => `¥${data.amount || "0.00"} 提现申请正在审核中`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: "WalletWithdrawalDetail",
        params: { id: data.withdrawalId },
      }),
      priority: 10,
    },
    [NotificationScene.WALLET_WITHDRAWAL_SUCCEEDED]: {
      type: NotificationType.INTERACTION,
      title: "提现已到账",
      content: (data) => `¥${data.amount || "0.00"} 已转入您的支付宝账户`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: "WalletWithdrawalDetail",
        params: { id: data.withdrawalId },
      }),
      priority: 10,
    },
    [NotificationScene.WALLET_WITHDRAWAL_REJECTED]: {
      type: NotificationType.INTERACTION,
      title: "提现申请未通过",
      content: (data) =>
        `¥${data.amount || "0.00"} 已退回可提现余额${data.reason ? `，原因：${data.reason}` : ""}`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: "WalletWithdrawalDetail",
        params: { id: data.withdrawalId },
      }),
      priority: 10,
    },
    [NotificationScene.WALLET_WITHDRAWAL_FAILED]: {
      type: NotificationType.INTERACTION,
      title: "提现转账失败",
      content: (data) => `¥${data.amount || "0.00"} 已退回可提现余额`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: "WalletWithdrawalDetail",
        params: { id: data.withdrawalId },
      }),
      priority: 10,
    },
    [NotificationScene.PRODUCT_AUDIT_APPROVED]: {
      type: NotificationType.INTERACTION,
      title: "商品审核通过",
      content: (data) =>
        `您发布的商品「${data.productName}」已通过审核，已上架`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: "ProductDetail",
        params: { id: data.productId },
      }),
      priority: 10,
    },
    [NotificationScene.PRODUCT_AUDIT_REJECTED]: {
      type: NotificationType.INTERACTION,
      title: "商品审核未通过",
      content: (data) =>
        `您发布的商品「${data.productName}」未通过审核，原因：${data.reason || "请查看详情"}`,
      actionType: ActionType.PAGE,
      actionDataBuilder: () => ({ path: "MyPublishedProducts" }),
      priority: 10,
    },

    // ========== 聊天相关 ==========
    [NotificationScene.CHAT_NEW_MESSAGE]: {
      type: NotificationType.INTERACTION,
      title: (data) => `${data.senderName || "对方"}发来新消息`,
      content: (data) => `${data.content || "点击查看详情"}`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: "Chat",
        params: { conversationId: data.conversationId },
      }),
      priority: 8,
    },
    [NotificationScene.CHAT_ORDER_EXPIRING]: {
      type: NotificationType.INTERACTION,
      title: "聊天订单即将过期",
      content: (data) =>
        `您的聊天订单将在${data.minutes || 30}分钟后过期，请尽快使用`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: "Chat",
        params: { conversationId: data.conversationId },
      }),
      priority: 10,
    },

    // ========== 健康预约相关 ==========
    [NotificationScene.HEALTH_APPOINTMENT_CREATED]: {
      type: NotificationType.INTERACTION,
      title: "健康预约已创建",
      content: (data) =>
        `您的健康预约已创建，预约时间：${data.appointmentTime}`,
      actionType: ActionType.APPOINTMENT,
      actionDataBuilder: (data) => ({
        appointmentId: data.appointmentId,
        appointmentKind: "health",
      }),
      priority: 10,
    },
    [NotificationScene.HEALTH_APPOINTMENT_COMPLETED]: {
      type: NotificationType.INTERACTION,
      title: "健康预约已完成",
      content: (data) => `您的健康预约已完成`,
      actionType: ActionType.APPOINTMENT,
      actionDataBuilder: (data) => ({
        appointmentId: data.appointmentId,
        appointmentKind: "health",
      }),
      priority: 5,
    },

    // ========== 互动相关 ==========
    [NotificationScene.FOLLOWER_NEW]: {
      type: NotificationType.INTERACTION,
      title: "新增关注",
      content: (data) => `${data.followerName || "用户"}关注了你`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: "UserProfile",
        params: { userId: data.followerId },
      }),
      priority: 5,
    },
    [NotificationScene.LIKE_RECEIVED]: {
      type: NotificationType.INTERACTION,
      title: "收到点赞",
      content: (data) =>
        `${data.likerName || "用户"}赞了你的${data.contentType || "内容"}`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: data.path || "Home",
        params: data.params,
      }),
      priority: 3,
    },
    [NotificationScene.COMMENT_RECEIVED]: {
      type: NotificationType.INTERACTION,
      title: "收到评论",
      content: (data) =>
        `${data.commenterName || "用户"}评论了你的${data.contentType || "内容"}：${data.comment}`,
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => ({
        path: data.path || "Home",
        params: data.params,
      }),
      priority: 5,
    },

    // ========== 系统相关 ==========
    [NotificationScene.SYSTEM_ANNOUNCEMENT]: {
      type: NotificationType.ANNOUNCEMENT,
      title: (data) => data.title || "系统公告",
      content: (data) => data.content || "点击查看详情",
      actionType: ActionType.PAGE,
      actionDataBuilder: (data) => data.actionData || { path: "Home" },
      priority: 15,
    },
    [NotificationScene.ACCOUNT_SECURITY]: {
      type: NotificationType.SYSTEM,
      title: "账号安全提醒",
      content: (data) => data.content || "您的账号存在安全风险，请及时修改密码",
      actionType: ActionType.PAGE,
      actionDataBuilder: () => ({ path: "SecuritySettings" }),
      priority: 15,
    },
  };

/**
 * 统一的通知发送服务
 * 提供便捷的方法来发送各种业务场景的通知
 */
@Injectable()
export class NotificationSenderService {
  private readonly logger = new Logger(NotificationSenderService.name);

  constructor(private readonly notificationsService: NotificationsService) {}

  /**
   * 发送通知（核心方法）
   * @param userId 接收通知的用户ID
   * @param scene 通知场景
   * @param data 通知数据（用于填充模板）
   */
  async send(
    userId: number,
    scene: NotificationScene,
    data: Record<string, any> = {},
  ): Promise<void> {
    try {
      const template = NOTIFICATION_TEMPLATES[scene];

      if (!template) {
        this.logger.warn(`未找到通知场景模板: ${scene}`);
        return;
      }

      // 解析模板
      const title =
        typeof template.title === "function"
          ? template.title(data)
          : template.title;
      const content =
        typeof template.content === "function"
          ? template.content(data)
          : template.content;
      const actionData = template.actionDataBuilder
        ? template.actionDataBuilder(data)
        : undefined;

      // 创建通知
      await this.notificationsService.create({
        userId,
        type: template.type,
        title,
        content,
        actionType: template.actionType,
        actionData: actionData,
        priority: template.priority || 0,
      });

      this.logger.log(
        `✅ 通知发送成功: userId=${userId}, scene=${scene}, title=${title}`,
      );
    } catch (error) {
      this.logger.error(
        `❌ 通知发送失败: userId=${userId}, scene=${scene}`,
        error.stack,
      );
      // 不抛出异常，避免影响主业务流程
    }
  }

  /**
   * 批量发送通知给多个用户
   * @param userIds 接收通知的用户ID数组
   * @param scene 通知场景
   * @param data 通知数据
   */
  async sendToUsers(
    userIds: number[],
    scene: NotificationScene,
    data: Record<string, any> = {},
  ): Promise<void> {
    const promises = userIds.map((userId) => this.send(userId, scene, data));
    await Promise.allSettled(promises);
    this.logger.log(`批量发送通知: count=${userIds.length}, scene=${scene}`);
  }

  /**
   * ========== 预约相关快捷方法 ==========
   */

  /** 用户创建预约成功 */
  async appointmentCreated(
    userId: number,
    data: { appointmentId: number; hospitalName?: string },
  ): Promise<void> {
    return this.send(userId, NotificationScene.APPOINTMENT_CREATED, data);
  }

  /** 预约被确认 */
  async appointmentConfirmed(
    userId: number,
    data: {
      appointmentId: number;
      hospitalName?: string;
      appointmentTime?: string;
    },
  ): Promise<void> {
    return this.send(userId, NotificationScene.APPOINTMENT_CONFIRMED, data);
  }

  /** 预约被拒绝 */
  async appointmentRejected(
    userId: number,
    data: { appointmentId: number; hospitalName?: string; reason?: string },
  ): Promise<void> {
    return this.send(userId, NotificationScene.APPOINTMENT_REJECTED, data);
  }

  /** 预约已完成 */
  async appointmentCompleted(
    userId: number,
    data: { appointmentId: number; hospitalName?: string },
  ): Promise<void> {
    return this.send(userId, NotificationScene.APPOINTMENT_COMPLETED, data);
  }

  /** 预约已取消 */
  async appointmentCancelled(
    userId: number,
    data: { appointmentId: number; hospitalName?: string },
  ): Promise<void> {
    return this.send(userId, NotificationScene.APPOINTMENT_CANCELLED, data);
  }

  /**
   * ========== 订单相关快捷方法 ==========
   */

  /** 订单创建成功 */
  async orderCreated(userId: number, data: { orderId: number }): Promise<void> {
    return this.send(userId, NotificationScene.ORDER_CREATED, data);
  }

  /** 订单已支付 */
  async orderPaid(
    userId: number,
    data: { orderId: number; viewRole?: "buyer" | "seller" },
  ): Promise<void> {
    return this.send(userId, NotificationScene.ORDER_PAID, data);
  }

  /** 订单已发货 */
  async orderShipped(userId: number, data: { orderId: number }): Promise<void> {
    return this.send(userId, NotificationScene.ORDER_SHIPPED, data);
  }

  /** 订单已完成 */
  async orderCompleted(
    userId: number,
    data: { orderId: number; viewRole?: "buyer" | "seller" },
  ): Promise<void> {
    return this.send(userId, NotificationScene.ORDER_COMPLETED, data);
  }

  /** 商品审核通过 */
  async productAuditApproved(
    userId: number,
    data: { productId: number; productName: string },
  ): Promise<void> {
    return this.send(userId, NotificationScene.PRODUCT_AUDIT_APPROVED, data);
  }

  /** 商品审核拒绝 */
  async productAuditRejected(
    userId: number,
    data: { productId: number; productName: string; reason: string },
  ): Promise<void> {
    return this.send(userId, NotificationScene.PRODUCT_AUDIT_REJECTED, data);
  }

  /**
   * ========== 聊天相关快捷方法 ==========
   */

  /** 收到新消息 */
  async chatNewMessage(
    userId: number,
    data: { senderName: string; content: string; conversationId: string },
  ): Promise<void> {
    return this.send(userId, NotificationScene.CHAT_NEW_MESSAGE, data);
  }

  /**
   * ========== 社区互动快捷方法 ==========
   */

  /** 收到新的关注 */
  async followerNew(
    userId: number,
    data: { followerId: number; followerName?: string },
  ): Promise<void> {
    return this.send(userId, NotificationScene.FOLLOWER_NEW, data);
  }

  /** 收到点赞 */
  async likeReceived(
    userId: number,
    data: {
      likerName?: string;
      contentType?: string;
      path?: string;
      params?: Record<string, any>;
    },
  ): Promise<void> {
    return this.send(userId, NotificationScene.LIKE_RECEIVED, data);
  }

  /** 收到评论 */
  async commentReceived(
    userId: number,
    data: {
      commenterName?: string;
      comment: string;
      contentType?: string;
      path?: string;
      params?: Record<string, any>;
    },
  ): Promise<void> {
    return this.send(userId, NotificationScene.COMMENT_RECEIVED, data);
  }

  /**
   * ========== 系统相关快捷方法 ==========
   */

  /** 发送系统公告 */
  async systemAnnouncement(
    userIds: number[],
    data: { title: string; content: string; actionData?: Record<string, any> },
  ): Promise<void> {
    return this.sendToUsers(
      userIds,
      NotificationScene.SYSTEM_ANNOUNCEMENT,
      data,
    );
  }
}
