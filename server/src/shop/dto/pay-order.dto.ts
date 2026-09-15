import { IsNotEmpty, IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { PaymentChannel } from '../../payment/entities/payment.entity';

/**
 * 订单支付 DTO
 * 用于发起订单支付
 */
export class PayOrderDto {
  @ApiProperty({
    description: '支付渠道',
    enum: PaymentChannel,
    example: PaymentChannel.ALIPAY_WAP,
  })
  @IsEnum(PaymentChannel, { message: '无效的支付渠道' })
  @IsNotEmpty()
  paymentChannel: PaymentChannel;
}
