import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsNumber, IsNotEmpty } from 'class-validator';

/**
 * 批量更新问题排序 DTO
 */
export class ReorderQuestionsDto {
  @ApiProperty({
    description: '按新顺序排列的问题 ID 数组',
    example: [3, 1, 4, 2],
    type: [Number],
  })
  @IsArray({ message: 'questionIds 必须是数组' })
  @IsNumber({}, { each: true, message: '每个 ID 必须是数字' })
  @IsNotEmpty({ message: 'questionIds 不能为空' })
  questionIds: number[];
}
