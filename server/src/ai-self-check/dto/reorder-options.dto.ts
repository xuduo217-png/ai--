import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsNumber, IsNotEmpty } from 'class-validator';

/**
 * 批量更新选项排序 DTO
 */
export class ReorderOptionsDto {
  @ApiProperty({
    description: '按新顺序排列的选项 ID 数组',
    example: [2, 1, 3],
    type: [Number],
  })
  @IsArray({ message: 'optionIds 必须是数组' })
  @IsNumber({}, { each: true, message: '每个 ID 必须是数字' })
  @IsNotEmpty({ message: 'optionIds 不能为空' })
  optionIds: number[];
}
