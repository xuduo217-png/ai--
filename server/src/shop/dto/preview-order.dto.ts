import { IsArray, IsNumber, IsOptional, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class PreviewOrderItemDto {
  @IsNumber()
  productId: number;

  @IsOptional()
  @IsNumber()
  skuId?: number;

  @IsNumber()
  @Min(1)
  quantity: number;
}

export class PreviewOrderDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PreviewOrderItemDto)
  items: PreviewOrderItemDto[];

  @IsOptional()
  @IsNumber()
  userCouponId?: number;
}
