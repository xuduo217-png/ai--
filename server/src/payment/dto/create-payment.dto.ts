import {
  IsNotEmpty,
  IsString,
  IsInt,
  IsEnum,
  IsOptional,
  IsObject,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  PaymentChannel,
  PaymentMethod,
  BusinessType,
} from '../entities/payment.entity';

/**
 * 创建支付 DTO
 * 仅供管理员通过 HTTP 入口按业务实体发起支付诊断
 */
export class CreatePaymentDto {
  @ApiProperty({ description: '支付渠道', enum: PaymentChannel })
  @IsEnum(PaymentChannel)
  @IsNotEmpty()
  channel: PaymentChannel;

  @ApiProperty({
    description: '支付方式',
    enum: PaymentMethod,
    default: PaymentMethod.APP,
  })
  @IsEnum(PaymentMethod)
  @IsOptional()
  method?: PaymentMethod;

  @ApiProperty({ description: '业务类型', enum: BusinessType })
  @IsEnum(BusinessType)
  @IsNotEmpty()
  businessType: BusinessType;

  @ApiProperty({ description: '业务ID（订单ID等）', example: 123 })
  @IsInt()
  @IsNotEmpty()
  businessId: number;

  @ApiPropertyOptional({ description: '客户端IP', example: '127.0.0.1' })
  @IsString()
  @IsOptional()
  clientIp?: string;

  @ApiPropertyOptional({ description: '过期时间（秒）', example: 900 })
  @IsInt()
  @IsOptional()
  expireIn?: number;

  @ApiPropertyOptional({
    description: '扩展信息',
    example: { productId: 123, quantity: 2 },
  })
  @IsObject()
  @IsOptional()
  metadata?: Record<string, any>;
}

/**
 * 内部创建支付请求
 * 仅供业务服务在服务端完成归属、金额和描述推导后调用
 */
export interface CreatePaymentRequest {
  channel: PaymentChannel;
  method?: PaymentMethod;
  amount: number;
  userId: number;
  businessType: BusinessType;
  businessId: number;
  subject: string;
  body?: string;
  description?: string;
  clientIp?: string;
  expireIn?: number;
  metadata?: Record<string, any>;
  outTradeNo?: string;
}

/**
 * 创建支付响应 DTO
 * 返回给客户端的支付参数
 */
export interface CreatePaymentResponse {
  paymentNo: string;
  outTradeNo: string;
  amount: number;
  channel: PaymentChannel;
  method: PaymentMethod;

  // 支付参数（根据渠道不同返回不同格式）
  paymentParams: {
    // 支付宝 APP 支付
    alipayOrderString?: string;

    // 微信 APP 支付
    wechatAppid?: string;
    wechatPartnerId?: string;
    wechatPrepayId?: string;
    wechatNonceStr?: string;
    wechatTimeStamp?: string;
    wechatSign?: string;

    // 其他支付方式的参数...
  };

  // 二维码内容（扫码支付）
  qrCodeUrl?: string;

  // 支付URL（网页支付）
  paymentUrl?: string;

  // 过期时间
  expiredAt: Date;
}
