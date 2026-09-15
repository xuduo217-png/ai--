import { IsInt, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/**
 * 线上活动投票 DTO
 */
export class VoteActivityDto {
  @ApiProperty({ description: '投票选手ID', example: 1 })
  @IsInt()
  @Min(1, { message: '选手ID必须大于0' })
  optionId: number;
}
