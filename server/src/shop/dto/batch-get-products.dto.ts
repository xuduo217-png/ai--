import { IsOptional, IsNumber, IsString, IsIn, IsBoolean } from 'class-validator'
import { ApiPropertyOptional } from '@nestjs/swagger'
import { Transform } from 'class-transformer'

/**
 * 批量获取商品 DTO（完整分类树版本）
 * 后端返回所有一级分类、二级分类及商品，前端自行处理展示逻辑
 */
export class BatchGetProductsDto {
  @ApiPropertyOptional({
    description: '是否包含空商品的分类（默认 false）',
    example: false,
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => value === 'true' || value === true)
  includeEmpty?: boolean = false

  @ApiPropertyOptional({
    description: '每个分类最多返回的商品数量（0 表示全部）',
    example: 50,
    default: 50,
  })
  @IsOptional()
  @IsNumber()
  @Transform(({ value }) => parseInt(value))
  limit?: number = 50

  @ApiPropertyOptional({
    description: '排序字段',
    example: 'createdAt',
    enum: ['isTop', 'isHot', 'createdAt', 'price', 'name', 'sortOrder'],
    default: 'sortOrder',
  })
  @IsOptional()
  @IsString()
  sortBy?: string = 'sortOrder'

  @ApiPropertyOptional({
    description: '排序方向',
    example: 'ASC',
    enum: ['ASC', 'DESC'],
    default: 'ASC',
  })
  @IsOptional()
  @IsIn(['ASC', 'DESC'])
  sortOrder?: 'ASC' | 'DESC' = 'ASC'
}
