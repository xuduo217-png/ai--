import { IsOptional, IsEnum, IsString } from 'class-validator';
import { OrderStatus, OrderType } from '../entities/order.entity';
import { PaginationDto } from '../../common/dto/pagination.dto';

/**
 * 查询订单 DTO
 * 支持按状态筛选订单的分页查询
 */
export class QueryOrderDto extends PaginationDto {
  @IsOptional()
  @IsEnum(OrderStatus, { message: '无效的订单状态' })
  status?: OrderStatus;

  @IsOptional()
  @IsEnum(OrderType, { message: '无效的订单类型' })
  orderType?: OrderType;

  @IsOptional()
  @IsString()
  afterSaleStatus?: string;
}
