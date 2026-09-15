import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

/**
 * 签到打卡 DTO
 * 支持任务型打卡的额外信息
 */
export class CheckInDto {
  @ApiPropertyOptional({ description: '任务类型', example: 'share' })
  @IsOptional()
  @IsString()
  taskType?: string;

  @ApiPropertyOptional({ description: '任务证据(如分享链接)', example: 'https://...' })
  @IsOptional()
  @IsString()
  taskEvidence?: string;
}
