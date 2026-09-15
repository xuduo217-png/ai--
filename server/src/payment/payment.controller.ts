import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Query,
  UseGuards,
  Headers,
  Req,
  RawBodyRequest,
  Logger,
  NotImplementedException,
  Res,
  HttpCode,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import type { Request, Response } from 'express';
import { PaymentService } from './payment.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { CreateRefundDto } from './dto/create-refund.dto';
import { QueryPaymentDto } from './dto/query-payment.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentUser, CurrentUserData } from '../common/decorators/current-user.decorator';
import { PaymentChannel } from './entities/payment.entity';

@ApiTags('payment')
@Controller('payment')
export class PaymentController {
  private readonly logger = new Logger(PaymentController.name);

  constructor(private readonly paymentService: PaymentService) {}

  /**
   * 创建支付（管理员诊断入口）
   * 普通用户必须走各业务模块自己的支付接口，避免越权传入关键归属字段
   */
  @Post('create')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建支付' })
  async createPayment(@Body() createPaymentDto: CreatePaymentDto) {
    return this.paymentService.createPaymentFromBusiness(createPaymentDto);
  }

  /**
   * 查询支付状态
   */
  @Get('query/:paymentNo')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '查询支付状态' })
  async queryPayment(
    @Param('paymentNo') paymentNo: string,
    @CurrentUser() user: CurrentUserData,
  ) {
    return this.paymentService.queryPaymentStatus(paymentNo, user.id, user.role);
  }

  /**
   * 关闭支付
   */
  @Post('close/:paymentNo')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '关闭支付' })
  async closePayment(@Param('paymentNo') paymentNo: string) {
    await this.paymentService.closePayment(paymentNo);
    return { success: true, message: '支付已关闭' };
  }

  /**
   * 创建退款
   * 仅供管理员诊断非商城业务；商城订单必须由有效售后单触发内部退款。
   */
  @Post('refund')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建退款' })
  async createRefund(
    @Body() createRefundDto: CreateRefundDto,
    @CurrentUser() user: CurrentUserData,
  ) {
    return this.paymentService.createRefund(createRefundDto, user.id, user.role);
  }

  /**
   * 查询支付列表（管理员）
   */
  @Get('list')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '查询支付列表' })
  async getPaymentList(@Query() query: QueryPaymentDto) {
    throw new NotImplementedException('支付列表暂未实现');
  }

  /**
   * 支付宝支付回调
   * 这个端点必须是公开的（支付宝服务器需要访问）
   * 安全修复：不返回详细错误信息，仅记录日志
   */
  @Post('callback/alipay')
  @HttpCode(200)
  @Public()
  @ApiOperation({ summary: '支付宝支付回调' })
  async alipayCallback(
    @Body() callbackData: any,
    @Res() response: Response,
  ): Promise<void> {
    try {
      await this.paymentService.handlePaymentCallback(
        PaymentChannel.ALIPAY,
        callbackData,
      );
      response.type('text/plain').send('success');
    } catch (error) {
      // 记录详细错误日志，但返回通用错误信息
      this.logger.error(`Alipay callback error: ${error.message}`, error.stack);
      response.type('text/plain').send('failure');
    }
  }

  /**
   * 微信支付回调
   * 这个端点必须是公开的（微信服务器需要访问）
   * 安全修复：不返回详细错误信息，仅记录日志
   */
  @Post('callback/wechat')
  @Public()
  @ApiOperation({ summary: '微信支付回调' })
  async wechatCallback(
    @Req() request: RawBodyRequest<Request>,
    @Headers() headers: any,
    @Res() response: Response,
  ): Promise<void> {
    try {
      if (!request.rawBody) {
        throw new Error('Missing raw callback body');
      }
      const rawBody = request.rawBody.toString('utf8');
      const callbackData = JSON.parse(rawBody);
      await this.paymentService.handlePaymentCallback(
        PaymentChannel.WECHAT,
        callbackData,
        headers,
        rawBody,
      );
      response.status(200).json({ code: 'SUCCESS', message: '成功' });
    } catch (error) {
      this.logger.error(`Wechat callback error: ${error.message}`, error.stack);
      response.status(500).json({ code: 'FAIL', message: '处理失败' });
    }
  }

  /**
   * 查询我的支付记录
   */
  @Get('my')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '查询我的支付记录' })
  async getMyPayments(@Query() query: QueryPaymentDto) {
    throw new NotImplementedException('我的支付记录暂未实现');
  }
}
