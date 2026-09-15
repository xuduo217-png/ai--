# 通知系统使用文档

## 概述

通知系统提供了统一的站内消息发送功能，支持多种业务场景的通知。

## 核心组件

- **NotificationsService**: 通知基础服务，提供通知的 CRUD 操作
- **NotificationSenderService**: 通知发送服务，提供便捷的业务场景通知发送方法

## 快速开始

### 1. 在模块中导入

```typescript
import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  // ...
})
export class YourModule {}
```

### 2. 在服务中注入

```typescript
import { Injectable } from '@nestjs/common';
import { NotificationSenderService } from '../notifications/notification-sender.service';

@Injectable()
export class YourService {
  constructor(
    private readonly notificationSender: NotificationSenderService,
  ) {}
}
```

## 使用方式

### 方式一：使用快捷方法（推荐）

NotificationSenderService 为常见业务场景提供了快捷方法，直接调用即可：

```typescript
// ========== 预约相关 ==========
// 用户创建预约成功
await this.notificationSender.appointmentCreated(userId, {
  appointmentId: 123,
  hospitalName: '宠物医院A',
});

// 预约被确认
await this.notificationSender.appointmentConfirmed(userId, {
  appointmentId: 123,
  hospitalName: '宠物医院A',
  appointmentTime: '2024-01-01 10:00',
});

// 预约被拒绝
await this.notificationSender.appointmentRejected(userId, {
  appointmentId: 123,
  hospitalName: '宠物医院A',
  reason: '医生档期已满',
});

// ========== 订单相关 ==========
// 订单创建成功
await this.notificationSender.orderCreated(userId, {
  orderId: 456,
});

// 订单已支付
await this.notificationSender.orderPaid(userId, {
  orderId: 456,
});

// 订单已发货
await this.notificationSender.orderShipped(userId, {
  orderId: 456,
  trackingNumber: 'SF1234567890',
});

// 商品审核通过
await this.notificationSender.productAuditApproved(userId, {
  productId: 789,
  productName: '猫粮',
});

// ========== 聊天相关 ==========
// 收到新消息
await this.notificationSender.chatNewMessage(userId, {
  senderName: '张医生',
  content: '您好，请问有什么可以帮您？',
  conversationId: '123_456',
});

// ========== 系统相关 ==========
// 发送系统公告给所有用户
await this.notificationSender.systemAnnouncement([1, 2, 3, 4, 5], {
  title: '系统维护通知',
  content: '系统将于今晚 22:00 进行维护，预计 2 小时',
  actionData: {
    path: 'PostDetail',
    params: { postId: 10 },
  },
});
```

### 方式二：使用通用方法

如果快捷方法不满足需求，可以使用通用方法 `send()`：

```typescript
import { NotificationScene } from '../notifications/notification-sender.service';

// 发送自定义场景的通知
await this.notificationSender.send(userId, NotificationScene.ORDER_COMPLETED, {
  orderId: 456,
});
```

### 方式三：批量发送

向多个用户发送相同的通知：

```typescript
// 批量发送通知
await this.notificationSender.sendToUsers(
  [1, 2, 3, 4, 5],
  NotificationScene.SYSTEM_ANNOUNCEMENT,
  {
    title: '活动通知',
    content: '双11活动即将开始，敬请期待！',
  },
);
```

## 通知场景列表

所有支持的通知场景定义在 `NotificationScene` 枚举中：

### 预约相关
- `APPOINTMENT_CREATED` - 用户创建预约成功
- `APPOINTMENT_CONFIRMED` - 预约被确认
- `APPOINTMENT_REJECTED` - 预约被拒绝
- `APPOINTMENT_COMPLETED` - 预约已完成
- `APPOINTMENT_CANCELLED` - 预约已取消
- `APPOINTMENT_RESCHEDULED` - 预约时间变更

### 订单相关
- `ORDER_CREATED` - 订单创建成功
- `ORDER_PAID` - 订单已支付
- `ORDER_SHIPPED` - 订单已发货
- `ORDER_COMPLETED` - 订单已完成
- `ORDER_CANCELLED` - 订单已取消
- `ORDER_REFUNDED` - 订单退款成功
- `PRODUCT_AUDIT_APPROVED` - 商品审核通过
- `PRODUCT_AUDIT_REJECTED` - 商品审核拒绝

### 聊天相关
- `CHAT_NEW_MESSAGE` - 收到新消息
- `CHAT_ORDER_EXPIRING` - 聊天订单即将过期

### 健康预约相关
- `HEALTH_APPOINTMENT_CREATED` - 健康预约创建成功
- `HEALTH_APPOINTMENT_COMPLETED` - 健康预约已完成

### 互动相关
- `FOLLOWER_NEW` - 收到新的关注
- `LIKE_RECEIVED` - 收到点赞
- `COMMENT_RECEIVED` - 收到评论

### 系统相关
- `SYSTEM_ANNOUNCEMENT` - 系统公告
- `ACCOUNT_SECURITY` - 账号安全提醒

## 添加新通知场景

如果需要添加新的通知场景，请按以下步骤操作：

### 1. 在枚举中添加场景

在 `notification-sender.service.ts` 中的 `NotificationScene` 枚举中添加新场景：

```typescript
export enum NotificationScene {
  // ... 现有场景
  YOUR_NEW_SCENE = 'YOUR_NEW_SCENE',
}
```

### 2. 在模板映射中添加模板

在 `NOTIFICATION_TEMPLATES` 对象中添加对应的模板配置：

```typescript
const NOTIFICATION_TEMPLATES: Record<NotificationScene, NotificationTemplate> = {
  // ... 现有模板
  [NotificationScene.YOUR_NEW_SCENE]: {
    type: NotificationType.INTERACTION, // 或 ANNOUNCEMENT、SYSTEM
    title: '通知标题',
    content: (data) => `通知内容：${data.someValue}`,
    actionType: ActionType.PAGE, // 或 ORDER、APPOINTMENT、URL、NONE
    actionDataBuilder: (data) => ({
      path: 'SomePage',
      params: { id: data.id },
    }),
    priority: 10, // 0-15，数值越大优先级越高
  },
};
```

### 3. 添加快捷方法（可选）

如果这是一个常用场景，可以在 `NotificationSenderService` 类中添加快捷方法：

```typescript
async yourNewScene(userId: number, data: { id: number; someValue: string }): Promise<void> {
  return this.send(userId, NotificationScene.YOUR_NEW_SCENE, data);
}
```

## 通知数据结构

### 跳转协议

新通知统一使用以下 `actionType` / `actionData` 组合：

| 目标 | actionType | actionData |
|------|------------|------------|
| 订单详情 | `order` | `{ "orderId": 123 }` |
| 普通预约详情 | `appointment` | `{ "appointmentId": 123, "appointmentKind": "standard" }` |
| 健康预约详情 | `appointment` | `{ "appointmentId": 123, "appointmentKind": "health" }` |
| App 页面 | `page` | `{ "path": "PostDetail", "params": { "postId": 123 } }` |
| 外部网页 | `url` | `{ "url": "https://example.com" }` |

`page.path` 当前可使用 `Home`、`PetList`、`OrderList`、`MedicalServiceOrderList`、`AddressList`、`Notifications`、`CommunityProfile`、`MyCoupons`、`MyFavorites`、`MyPublishedProducts`、`SystemConfig`、`SecuritySettings`、`MyIncome`、`OrderDetail`、`ProductDetail`、`PostDetail`、`UserProfile` 和 `Chat`。所有 ID 必须为正整数，`Chat.params.conversationId` 必须为非空字符串。

### Notification 实体

| 字段 | 类型 | 说明 |
|------|------|------|
| id | number | 通知ID |
| userId | number | 接收用户ID |
| type | NotificationType | 通知类型：system/announcement/interaction |
| title | string | 通知标题 |
| content | string | 通知内容 |
| isRead | boolean | 是否已读 |
| actionType | ActionType | 跳转类型：none/page/url/order/appointment |
| actionData | string | 跳转参数（JSON字符串） |
| priority | number | 优先级（0-15） |
| createdAt | number | 创建时间（毫秒时间戳） |
| readAt | number \| null | 阅读时间（毫秒时间戳） |

### actionData 格式

根据 `actionType` 不同，`actionData` 的格式也不同：

#### ActionType.PAGE
跳转到页面
```json
{
  "path": "OrderDetail",
  "params": { "id": 123 }
}
```

#### ActionType.ORDER
跳转到订单详情
```json
{
  "orderId": 123
}
```

#### ActionType.APPOINTMENT
跳转到预约详情
```json
{
  "appointmentId": 456
}
```

#### ActionType.URL
打开 URL
```json
{
  "url": "https://example.com"
}
```

## 集成示例

### 在预约服务中集成

```typescript
// appointments.service.ts

import { Injectable } from '@nestjs/common';
import { NotificationSenderService } from '../notifications/notification-sender.service';

@Injectable()
export class AppointmentsService {
  constructor(
    private readonly notificationSender: NotificationSenderService,
  ) {}

  async create(createAppointmentDto: CreateAppointmentDto, userId: number) {
    const appointment = await this.appointmentRepository.save({
      ...createAppointmentDto,
      userId,
      status: AppointmentStatus.PENDING,
    });

    // 发送预约创建成功通知
    await this.notificationSender.appointmentCreated(userId, {
      appointmentId: appointment.id,
      hospitalName: appointment.hospital.name,
    });

    return appointment;
  }

  async confirmAppointment(id: number, staffUserId: number) {
    const appointment = await this.appointmentRepository.findOne({ where: { id } });

    await this.appointmentRepository.update(id, {
      status: AppointmentStatus.CONFIRMED,
      confirmedBy: staffUserId,
    });

    // 发送预约确认通知
    await this.notificationSender.appointmentConfirmed(appointment.userId, {
      appointmentId: appointment.id,
      hospitalName: appointment.hospital.name,
      appointmentTime: appointment.appointmentTime.toISOString(),
    });

    return this.findOne(id);
  }
}
```

### 在订单服务中集成

```typescript
// shop.service.ts

import { Injectable } from '@nestjs/common';
import { NotificationSenderService } from '../notifications/notification-sender.service';

@Injectable()
export class ShopService {
  constructor(
    private readonly notificationSender: NotificationSenderService,
  ) {}

  async createOrder(createOrderDto: CreateOrderDto, userId: number) {
    const order = await this.orderRepository.save({
      ...createOrderDto,
      userId,
      status: OrderStatus.PENDING,
    });

    // 发送订单创建成功通知
    await this.notificationSender.orderCreated(userId, {
      orderId: order.id,
    });

    return order;
  }

  async updateOrderStatus(orderId: number, status: OrderStatus) {
    const order = await this.orderRepository.findOne({ where: { id: orderId } });

    await this.orderRepository.update(orderId, { status });

    // 根据订单状态发送不同通知
    switch (status) {
      case OrderStatus.PAID:
        await this.notificationSender.orderPaid(order.userId, { orderId: order.id });
        break;
      case OrderStatus.SHIPPED:
        await this.notificationSender.orderShipped(order.userId, {
          orderId: order.id,
          trackingNumber: order.trackingNumber,
        });
        break;
      case OrderStatus.COMPLETED:
        await this.notificationSender.orderCompleted(order.userId, { orderId: order.id });
        break;
    }

    return this.findOne(orderId);
  }
}
```

## 注意事项

1. **错误处理**: 通知发送失败不会影响主业务流程，错误会被记录到日志中
2. **性能考虑**: 通知发送是异步操作，不会阻塞主业务
3. **批量发送**: 批量发送通知时使用 `sendToUsers()` 方法，可以一次性向多个用户发送相同通知
4. **优先级**: 根据通知重要性设置合适的优先级（0-15）
5. **数据验证**: 传递给通知方法的数据应该经过验证，避免发送无效通知
