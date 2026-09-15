import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto';

/**
 * 查询宠物类别 DTO
 */
export class QueryPetCategoriesDto extends PaginationDto {
  @ApiProperty({
    description: '分类名称（模糊搜索）',
    example: '金',
    required: false,
  })
  @IsOptional()
  @IsString({ message: '分类名称必须是字符串' })
  name?: string;
}
