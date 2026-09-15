import { IsOptional, IsNumber, Min, Max, IsEnum, IsString, IsInt } from 'class-validator';
import { Type, Transform } from 'class-transformer';

export enum SortOrder {
  ASC = 'ASC',
  DESC = 'DESC',
}

export class PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1; // 默认第1页

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1000)
  pageSize?: number = 10; // 默认每页10条，最多1000条

  @IsOptional()
  @IsEnum(SortOrder)
  sortOrder?: SortOrder = SortOrder.DESC; // 默认降序

  @IsOptional()
  @IsString()
  sortBy?: string = 'createdAt'; // 默认按创建时间排序
}

export interface PaginatedResult<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}
