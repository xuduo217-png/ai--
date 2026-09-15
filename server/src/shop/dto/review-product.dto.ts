import { IsBoolean, IsString, IsOptional, IsInt, Min, Max, IsIn, MaxLength } from 'class-validator';
import { Type } from 'class-transformer';
import { PendingProductStatus } from '../entities/product-pending.entity';

/**
 * 商品审核 DTO
 */
export class ReviewProductDto {
  @IsBoolean({ message: '必须指定是否通过' })
  approved: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500, { message: '拒绝原因最多500字' })
  rejectReason?: string;
}

/**
 * 查询待审核商品列表 DTO
 */
export class QueryPendingProductsDto {
  @IsOptional()
  @IsIn(Object.values(PendingProductStatus), { message: '无效的审核状态' })
  status?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '分类ID必须是整数' })
  @Min(1, { message: '分类ID最小为1' })
  categoryId?: number;

  @IsOptional()
  @IsString()
  @MaxLength(50, { message: '关键词最多50字' })
  keyword?: string;

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
