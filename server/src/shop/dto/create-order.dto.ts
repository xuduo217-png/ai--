import {
  IsNotEmpty,
  IsString,
  MaxLength,
  IsArray,
  ValidateNested,
  IsNumber,
  Min,
  IsOptional,
  IsEnum,
  IsBoolean,
  ValidateIf,
} from 'class-validator';
import { Type } from 'class-transformer';
import { PaymentChannel } from '../../payment/entities/payment.entity';

export class OrderItemDto {
  @IsNotEmpty()
  @IsNumber()
  productId: number;

  @IsOptional()
  @IsNumber()
  skuId?: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(1)
  quantity: number;
}

export class CreateOrderDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => OrderItemDto)
  items: OrderItemDto[];

  @IsNotEmpty()
  @IsString()
  @MaxLength(200)
  shippingAddress: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(50)
  receiverName: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(20)
  receiverPhone: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  remark?: string;

  /**
   * 优惠券ID（可选）
   */
  @IsOptional()
  @IsNumber()
  userCouponId?: number;

  /**
   * 支付渠道（支付宝/微信）
   */
  @IsEnum(PaymentChannel, { message: '无效的支付渠道' })
  @IsNotEmpty()
  paymentChannel: PaymentChannel;

  /**
   * 是否虚拟支付（用于测试，跳过真实支付流程）
   * 虚拟支付会直接将订单状态设为已支付
   */
  @IsOptional()
  @IsBoolean()
  isVirtualPayment?: boolean;
}
