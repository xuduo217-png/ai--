import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { PaymentController } from './payment.controller';
import { PaymentService } from './payment.service';
import { AlipayService } from './alipay.service';
import { WechatPayService } from './wechat-pay.service';
import { Payment } from './entities/payment.entity';
import { PaymentTransaction } from './entities/payment-transaction.entity';
import { Refund } from './entities/refund.entity';
import { Order } from '../shop/entities/order.entity';
import { User } from '../users/entities/user.entity';
import { WalletTransaction } from '../shop/entities/wallet-transaction.entity';
import { OrderAfterSale } from '../shop/entities/order-after-sale.entity';
import { WalletRecharge } from '../shop/entities/wallet-recharge.entity';
import { CharityRecord } from '../charity/entities/charity-record.entity';
import { Charity } from '../charity/entities/charity.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forFeature([
      Payment,
      PaymentTransaction,
      Refund,
      Order,
      User,
      WalletTransaction,
      OrderAfterSale,
      WalletRecharge,
      CharityRecord,
      Charity,
    ]),
  ],
  controllers: [PaymentController],
  providers: [PaymentService, AlipayService, WechatPayService],
  exports: [
    PaymentService, // 导出供其他模块使用
    AlipayService,
    WechatPayService,
  ],
})
export class PaymentModule {}
