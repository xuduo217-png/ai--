import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ShopService } from './shop.service';
import { ShopController } from './shop.controller';
import { CouponService } from './coupon.service';
import { CouponController } from './coupon.controller';
import { CategoryService } from './category.service';
import { CategoryController } from './category.controller';
import { ShoppingCartService } from './shopping-cart.service';
import { ShoppingCartController } from './shopping-cart.controller';
import { ProductFavoriteService } from './product-favorite.service';
import { ProductFavoriteController } from './product-favorite.controller';
import { Product } from './entities/product.entity';
import { ProductSku } from './entities/product-sku.entity';
import { Order } from './entities/order.entity';
import { Coupon } from './entities/coupon.entity';
import { CouponProduct } from './entities/coupon-product.entity';
import { UserCoupon } from './entities/user-coupon.entity';
import { Category } from './entities/category.entity';
import { ShoppingCart } from './entities/shopping-cart.entity';
import { ProductFavorite } from './entities/product-favorite.entity';
import { User } from '../users/entities/user.entity';
import { SystemConfig } from '../system-configs/entities/system-config.entity';
import { PaymentModule } from '../payment/payment.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { LogisticsModule } from '../logistics/logistics.module';
// 二手商品相关导入
import { ProductPending } from './entities/product-pending.entity';
import { WalletTransaction } from './entities/wallet-transaction.entity';
import { SecondHandProductService } from './second-hand-product.service';
import { SecondHandProductController } from './second-hand-product.controller';
import { SecondHandOrderService } from './second-hand-order.service';
import { SecondHandOrderController } from './second-hand-order.controller';
import { WalletService } from './wallet.service';
import { WalletController } from './wallet.controller';
import { PlatformFeeService } from './platform-fee.service';
import { ScheduleJobs } from './jobs/schedule.jobs';
import { ModerationModule } from '../moderation/moderation.module';
import { OrderAfterSale } from './entities/order-after-sale.entity';
import { OrderAfterSaleLog } from './entities/order-after-sale-log.entity';
import { OrderAfterSaleItem } from './entities/order-after-sale-item.entity';
import { AfterSaleService } from './after-sale.service';
import { AfterSaleController } from './after-sale.controller';
import { AfterSaleAdminController } from './admin/after-sale.admin.controller';
import { WalletWithdrawal } from './entities/wallet-withdrawal.entity';
import { WalletWithdrawalLog } from './entities/wallet-withdrawal-log.entity';
import { WalletPiiService } from './wallet-pii.service';
import { WalletWithdrawalConfigService } from './wallet-withdrawal-config.service';
import { WalletWithdrawalService } from './wallet-withdrawal.service';
import { WalletRecharge } from './entities/wallet-recharge.entity';
import { WalletRechargeService } from './wallet-recharge.service';
import { CharityRecord } from '../charity/entities/charity-record.entity';
import { Charity } from '../charity/entities/charity.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Product,
      ProductSku,
      Order,
      Coupon,
      CouponProduct,
      UserCoupon,
      Category,
      ShoppingCart,
      ProductFavorite,
      // 二手商品相关实体
      ProductPending,
      WalletTransaction,
      SystemConfig, // 平台手续费服务需要使用 SystemConfig 实体
      OrderAfterSale,
      OrderAfterSaleLog,
      OrderAfterSaleItem,
      WalletWithdrawal,
      WalletWithdrawalLog,
      WalletRecharge,
      CharityRecord,
      Charity,
    ]),
    TypeOrmModule.forFeature([User]), // 钱包需要使用 User 实体
    PaymentModule, // 导入支付模块
    NotificationsModule, // 导入通知模块
    LogisticsModule, // 导入物流模块
    ModerationModule,
  ],
  controllers: [
    ShopController,
    CouponController,
    CategoryController,
    ShoppingCartController,
    ProductFavoriteController,
    // 二手商品相关控制器
    SecondHandProductController,
    SecondHandOrderController,
    WalletController,
    AfterSaleController,
    AfterSaleAdminController,
  ],
  providers: [
    ShopService,
    CouponService,
    CategoryService,
    ShoppingCartService,
    ProductFavoriteService,
    // 二手商品相关服务
    SecondHandProductService,
    SecondHandOrderService,
    WalletService,
    PlatformFeeService,
    ScheduleJobs, // 定时任务
    AfterSaleService,
    WalletPiiService,
    WalletWithdrawalConfigService,
    WalletWithdrawalService,
    WalletRechargeService,
  ],
  exports: [
    ShopService,
    CouponService,
    CategoryService,
    ShoppingCartService,
    ProductFavoriteService,
    SecondHandProductService,
    SecondHandOrderService,
    WalletService,
    PlatformFeeService,
    AfterSaleService,
    WalletWithdrawalConfigService,
    WalletWithdrawalService,
    WalletRechargeService,
  ],
})
export class ShopModule {
  constructor(
    private shopService: ShopService,
    private couponService: CouponService,
  ) {
    // 解决循环依赖，注入CouponService到ShopService
    shopService.setCouponService(couponService);
  }
}
