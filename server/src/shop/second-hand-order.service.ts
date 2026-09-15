import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { NotificationSenderService } from '../notifications/notification-sender.service';
import {
  ShipSecondHandOrderDto,
  UpdateSecondHandTrackingDto,
} from './dto/after-sale.dto';
import { QueryOrderDto } from './dto/query-order.dto';
import {
  ACTIVE_AFTER_SALE_STATUSES,
  OrderAfterSale,
} from './entities/order-after-sale.entity';
import { Order, OrderStatus, OrderType } from './entities/order.entity';
import { ShopService } from './shop.service';

@Injectable()
export class SecondHandOrderService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(OrderAfterSale)
    private readonly afterSaleRepository: Repository<OrderAfterSale>,
    private readonly dataSource: DataSource,
    private readonly shopService: ShopService,
    private readonly notificationSender: NotificationSenderService,
  ) {}

  findSales(sellerId: number, query: QueryOrderDto) {
    return this.shopService.findMyOrdersPaginated(sellerId, query, 'seller');
  }

  async ship(orderId: number, sellerId: number, dto: ShipSecondHandOrderDto) {
    const order = await this.dataSource.transaction(async (manager) => {
      const locked = await manager
        .createQueryBuilder(Order, 'order')
        .where('order.id = :orderId', { orderId })
        .setLock('pessimistic_write')
        .getOne();
      this.assertSellerOrder(locked, sellerId);
      if (locked.status !== OrderStatus.PAID) {
        throw new BadRequestException('只有已付款的订单可以确认发货');
      }
      const activeAfterSale = await manager.count(OrderAfterSale, {
        where: {
          orderId,
          status: In([...ACTIVE_AFTER_SALE_STATUSES]),
        },
      });
      if (activeAfterSale > 0) {
        throw new BadRequestException('订单存在进行中的售后，不能发货');
      }

      const now = new Date();
      locked.status = OrderStatus.SHIPPED;
      locked.shippedAt = now;
      locked.autoConfirmAt = new Date(now.getTime() + 10 * 24 * 60 * 60 * 1000);
      locked.trackingNumber = dto.trackingNumber?.trim() || null;
      return manager.save(locked);
    });

    await this.notificationSender.orderShipped(order.userId, {
      orderId,
      viewRole: 'buyer',
    } as any);
    return this.shopService.findOneOrder(orderId, sellerId, 'USER');
  }

  async updateTracking(
    orderId: number,
    sellerId: number,
    dto: UpdateSecondHandTrackingDto,
  ) {
    await this.dataSource.transaction(async (manager) => {
      const order = await manager
        .createQueryBuilder(Order, 'order')
        .where('order.id = :orderId', { orderId })
        .setLock('pessimistic_write')
        .getOne();
      this.assertSellerOrder(order, sellerId);
      if (order.status !== OrderStatus.SHIPPED) {
        throw new BadRequestException('只有已发货订单可以修改物流单号');
      }
      order.trackingNumber = dto.trackingNumber?.trim() || null;
      await manager.save(order);
    });
    return this.shopService.findOneOrder(orderId, sellerId, 'USER');
  }

  private assertSellerOrder(order: Order | null, sellerId: number): asserts order is Order {
    if (!order) throw new NotFoundException('订单不存在');
    if (order.orderType !== OrderType.SECOND_HAND) {
      throw new BadRequestException('该订单不是二手订单');
    }
    if (order.sellerId !== sellerId) {
      throw new ForbiddenException('只有订单卖家可以执行该操作');
    }
  }
}
