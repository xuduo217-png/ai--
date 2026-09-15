import { IsString, IsOptional, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/**
 * 更新公益文章 DTO
 * 用于编辑已发布的活动文章
 */
export class UpdateCharityArticleDto {
  @ApiPropertyOptional({ description: '文章标题', example: '恭喜完成30天打卡挑战！' })
  @IsOptional()
  @IsString()
  title?: string;

  @ApiPropertyOptional({ description: '文章内容(支持HTML或Markdown)', example: '<p>恭喜你完成挑战！</p>' })
  @IsOptional()
  @IsString()
  content?: string;

  @ApiPropertyOptional({ description: '是否发送系统通知', default: true })
  @IsOptional()
  @IsBoolean()
  sendNotification?: boolean;
}
