import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ProductPending } from '../entities/product-pending.entity';
import { Product } from '../entities/product.entity';
import { ProductSku } from '../entities/product-sku.entity';
import { Order } from '../entities/order.entity';
import { WalletTransaction } from '../entities/wallet-transaction.entity';
import { Category } from '../entities/category.entity';
import { User } from '../../users/entities/user.entity';
import { SystemConfig } from '../../system-configs/entities/system-config.entity';
import { NotificationsModule } from '../../notifications/notifications.module';
import { SecondHandProductService } from '../second-hand-product.service';
import { SecondHandProductAdminController } from './second-hand-product.admin.controller';
import { AdminProductController } from '../admin-product.controller';
import { WalletService } from '../wallet.service';
import { WalletAdminController } from './wallet.admin.controller';
import { PlatformFeeService } from '../platform-fee.service';
import { PlatformFeeAdminController } from './platform-fee.admin.controller';
import { ShopModule } from '../shop.module';
import { WalletWithdrawalAdminController } from './wallet-withdrawal.admin.controller';

/**
 * 二手商品后台管理模块
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([
      ProductPending,
      Product,
      ProductSku,
      Order,
      WalletTransaction,
      Category,
      User,
      SystemConfig,
    ]),
    NotificationsModule,
    ShopModule,
  ],
  controllers: [
    SecondHandProductAdminController,
    AdminProductController,
    WalletAdminController,
    PlatformFeeAdminController,
    WalletWithdrawalAdminController,
  ],
  providers: [
    SecondHandProductService,
    WalletService,
    PlatformFeeService,
  ],
  exports: [
    SecondHandProductService,
    WalletService,
    PlatformFeeService,
  ],
})
export class ShopAdminModule {}
