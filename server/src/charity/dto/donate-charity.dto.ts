import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNumber, Min, IsOptional } from 'class-validator';

export enum CharityDonationPaymentMethod {
  BALANCE = 'balance',
  ONLINE = 'online',
}

export class DonateCharityDto {
  @ApiProperty({ description: '捐款金额', example: 20 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @ApiPropertyOptional({
    description: '支付方式',
    enum: CharityDonationPaymentMethod,
    example: CharityDonationPaymentMethod.BALANCE,
  })
  @IsOptional()
  @IsEnum(CharityDonationPaymentMethod)
  paymentMethod?: CharityDonationPaymentMethod;
}
