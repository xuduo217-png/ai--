import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ShopService } from '../shop.service';
import { WalletService } from '../wallet.service';
import { AfterSaleService } from '../after-sale.service';
import { WalletWithdrawalService } from '../wallet-withdrawal.service';

/**
 * 定时任务服务
 * 处理二手商品交易的定时任务
 */
@Injectable()
export class ScheduleJobs {
  private readonly logger = new Logger(ScheduleJobs.name);

  constructor(
    private readonly shopService: ShopService,
    private readonly walletService: WalletService,
    private readonly afterSaleService: AfterSaleService,
    private readonly walletWithdrawalService: WalletWithdrawalService,
  ) {}

  @Cron(CronExpression.EVERY_10_MINUTES)
  async handleWalletWithdrawalReconciliation() {
    this.logger.log('开始执行支付宝提现对账任务...');
    try {
      const result = await this.walletWithdrawalService.reconcilePending();
      this.logger.log(
        `支付宝提现对账完成：总数=${result.total}, 已终结=${result.resolved}, 待确认=${result.unknown}`,
      );
    } catch (error) {
      this.logger.error('支付宝提现对账任务执行失败', error.stack);
    }
  }

  /**
   * 普通订单未支付自动取消（每10分钟）
   */
  @Cron(CronExpression.EVERY_10_MINUTES)
  async handleAutoCancelShopPendingOrders() {
    this.logger.log('开始执行商城订单未支付自动取消任务...');
    try {
      const result = await this.shopService.autoCancelPendingOrders();
      this.logger.log(
        `商城订单自动取消完成：处理 ${result.processed}/${result.total} 个订单`,
      );
    } catch (error) {
      this.logger.error('商城订单自动取消任务执行失败', error.stack);
    }
  }

  /**
   * 普通订单已发货自动确认收货（每小时）
   */
  @Cron(CronExpression.EVERY_HOUR)
  async handleAutoConfirmShopShippedOrders() {
    this.logger.log('开始执行商城订单自动确认收货任务...');
    try {
      const result = await this.shopService.autoConfirmShippedOrders();
      this.logger.log(
        `商城订单自动确认收货完成：处理 ${result.processed}/${result.total} 个订单`,
      );
    } catch (error) {
      this.logger.error('商城订单自动确认收货任务执行失败', error.stack);
    }
  }

  @Cron(CronExpression.EVERY_HOUR)
  async handleAfterSaleTimeouts() {
    this.logger.log('开始执行商城统一售后超时任务...');
    try {
      const result = await this.afterSaleService.processTimeouts();
      this.logger.log(
        `商城统一售后超时任务完成：处理 ${result.processed}/${result.total} 个售后单`,
      );
    } catch (error) {
      this.logger.error('商城统一售后超时任务执行失败', error.stack);
    }
  }

  /**
   * 自动审核钱包交易定时任务
   * 每小时执行一次，自动审核超过7天的待审核交易
   */
  @Cron(CronExpression.EVERY_HOUR)
  async handleAutoApproveWalletTransactions() {
    this.logger.log('开始执行自动审核钱包交易任务...');

    try {
      const result = await this.walletService.autoApproveExpiredTransactions();
      this.logger.log(
        `自动审核钱包交易任务完成：总数=${result.total}, 成功=${result.success}, 失败=${result.failed}`,
      );
    } catch (error) {
      this.logger.error('自动审核钱包交易任务执行失败', error.stack);
    }
  }
}
