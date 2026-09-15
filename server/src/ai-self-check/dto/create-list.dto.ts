import { IsString, IsEnum, IsOptional, IsInt, Min } from 'class-validator';

/**
 * 创建自查表 DTO
 */
export class CreateListDto {
  /**
   * 自查表标题
   */
  @IsString()
  title: string;

  /**
   * 类型：公共项/特定项
   */
  @IsEnum(['PUBLIC', 'SPECIFIC'])
  type: 'PUBLIC' | 'SPECIFIC';

  /**
   * 关联的宠物一级分类ID（仅特定项需要）
   */
  @IsOptional()
  @IsInt()
  @Min(1)
  categoryId?: number;

  /**
   * 状态：启用/禁用
   */
  @IsEnum(['ACTIVE', 'INACTIVE'])
  status: 'ACTIVE' | 'INACTIVE';

  /**
   * 排序序号
   */
  @IsInt()
  @Min(0)
  sortOrder: number;
}
