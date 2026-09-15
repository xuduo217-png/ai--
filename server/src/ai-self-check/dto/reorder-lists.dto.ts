import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsNumber, IsNotEmpty } from 'class-validator';

/**
 * 批量更新自查表排序 DTO
 */
export class ReorderListsDto {
  @ApiProperty({
    description: '按新顺序排列的自查表 ID 数组',
    example: [5, 2, 8, 1],
    type: [Number],
  })
  @IsArray({ message: 'listIds 必须是数组' })
  @IsNumber({}, { each: true, message: '每个 ID 必须是数字' })
  @IsNotEmpty({ message: 'listIds 不能为空' })
  listIds: number[];
}
