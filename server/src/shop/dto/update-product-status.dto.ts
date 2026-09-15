import { IsBoolean, IsOptional, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * 更新商品状态 DTO（上架/下架）
 */
export class UpdateProductStatusDto {
  @IsBoolean({ message: '无效的商品状态' })
  status: boolean;
}

/**
 * 查询我的商品列表 DTO
 */
export class QueryMyProductsDto {
  @IsOptional()
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
