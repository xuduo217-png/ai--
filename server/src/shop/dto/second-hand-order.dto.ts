import { IsNumber, IsOptional, IsEnum, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';
import { OrderStatus } from '../entities/order.entity';

/**
 * 创建二手商品订单 DTO
 */
export class CreateSecondHandOrderDto {
  @IsNumber({}, { message: '商品ID必须是数字' })
  @Min(1, { message: '商品ID必须大于0' })
  productId: number;
}

/**
 * 查询我的订单列表 DTO
 */
export class QueryMyOrdersDto {
  @IsOptional()
  @IsEnum([...Object.values(OrderStatus), 'all'], { message: '无效的状态筛选' })
  status?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '页码必须是整数' })
  @Min(1, { message: '页码最小为1' })
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '每页数量必须是整数' })
  @Min(1, { message: '每页数量最小为1' })
  @Max(100, { message: '每页数量最大为100' })
  limit?: number;
}
