import { IsOptional, IsEnum, IsInt, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { UserRole } from '../entities/user.entity';

/**
 * 查询用户列表 DTO
 * 用于分页和筛选查询
 */
export class QueryUsersDto {
  /**
   * 页码（从 1 开始）
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  /**
   * 每页数量
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  pageSize?: number = 10;

  /**
   * 角色筛选
   */
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  /**
   * 医院ID筛选（用于查询特定医院的用户）
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  hospitalId?: number;

  /**
   * 手机号筛选（模糊查询）
   */
  @IsOptional()
  phone?: string;

  /**
   * 状态筛选
   */
  @IsOptional()
  isActive?: boolean;
}
