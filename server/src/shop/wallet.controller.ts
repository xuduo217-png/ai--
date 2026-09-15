import {
  Controller,
  Get,
  UseGuards,
  Request,
  Query,
  Body,
  Headers,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WalletService } from './wallet.service';
import {
  CreateWalletWithdrawalDto,
  WalletTransactionQueryDto,
  WalletWithdrawalQueryDto,
} from './dto/wallet-withdrawal.dto';
import { WalletWithdrawalService } from './wallet-withdrawal.service';
import {
  CreateWalletRechargeDto,
  WalletRechargeQueryDto,
} from './dto/wallet-recharge.dto';
import { WalletRechargeService } from './wallet-recharge.service';

/**
 * 钱包前台 API（移动端）
 */
@Controller('shop/wallet')
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(
    private readonly walletService: WalletService,
    private readonly withdrawalService: WalletWithdrawalService,
    private readonly rechargeService: WalletRechargeService,
  ) {}

  /**
   * 钱包概况（兼容旧接口）
   * GET /shop/wallet
   */
  @Get()
  async getWalletOverview(@Request() req) {
    const userId = req.user.id;
    const wallet = await this.walletService.getWalletOverview(userId);
    return {
      success: true,
      data: wallet,
    };
  }

  /**
   * 钱包余额（新接口）
   * GET /shop/wallet/balance
   */
  @Get('balance')
  async getWalletBalance(@Request() req) {
    const userId = req.user.id;
    const wallet = await this.walletService.getWalletOverview(userId);
    return {
      success: true,
      data: wallet,
    };
  }

  /**
   * 钱包明细列表
   * GET /shop/wallet/transactions
   */
  @Get('transactions')
  async getWalletTransactions(
    @Request() req,
    @Query() query: WalletTransactionQueryDto,
  ) {
    const userId = req.user.id;
    return await this.walletService.getWalletTransactions(userId, query);
  }

  /**
   * 收益统计（移动端专用）
   * GET /shop/wallet/stats
   */
  @Get('stats')
  async getIncomeStats(@Request() req) {
    const userId = req.user.id;
    return {
      success: true,
      data: await this.walletService.getIncomeStats(userId),
    };
  }

  @Get('recharges/config')
  getRechargeConfig() {
    return this.rechargeService.getConfig();
  }

  @Post('recharges')
  async createRecharge(
    @Request() req,
    @Headers('idempotency-key') idempotencyKey: string,
    @Body() body: CreateWalletRechargeDto,
  ) {
    const parsedKey = await new ParseUUIDPipe({ version: '4' }).transform(
      idempotencyKey,
      { type: 'custom' },
    );
    return this.rechargeService.create(req.user.id, parsedKey, body);
  }

  @Get('recharges')
  getRecharges(@Request() req, @Query() query: WalletRechargeQueryDto) {
    return this.rechargeService.listForUser(req.user.id, query);
  }

  @Get('recharges/:id')
  getRecharge(@Request() req, @Param('id', ParseIntPipe) id: number) {
    return this.rechargeService.getForUser(req.user.id, id);
  }

  @Get('withdrawals/config')
  getWithdrawalConfig(@Request() req) {
    return this.withdrawalService.getUserConfig(req.user.id);
  }

  @Post('withdrawals')
  async createWithdrawal(
    @Request() req,
    @Headers('idempotency-key') idempotencyKey: string,
    @Body() body: CreateWalletWithdrawalDto,
  ) {
    const parsedKey = await new ParseUUIDPipe({ version: '4' }).transform(
      idempotencyKey,
      { type: 'custom' },
    );
    return this.withdrawalService.create(req.user.id, parsedKey, body);
  }

  @Get('withdrawals')
  getWithdrawals(@Request() req, @Query() query: WalletWithdrawalQueryDto) {
    return this.withdrawalService.listForUser(req.user.id, query);
  }

  @Get('withdrawals/:id')
  getWithdrawal(
    @Request() req,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.withdrawalService.getForUser(req.user.id, id);
  }
}
