import { IsString, IsNotEmpty, IsOptional, IsBoolean, IsArray } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/**
 * 发布文章 DTO
 * 用于向活动参与者发布文章
 */
export class PublishArticleDto {
  @ApiProperty({ description: '文章标题', example: '恭喜完成30天打卡挑战！' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: '文章内容(支持HTML或Markdown)', example: '<p>恭喜你完成挑战！</p>' })
  @IsString()
  @IsNotEmpty()
  content: string;

  @ApiPropertyOptional({ description: '是否发送系统通知', default: true })
  @IsOptional()
  @IsBoolean()
  sendNotification?: boolean;

  @ApiPropertyOptional({
    description: '目标用户ID列表(留空表示推送给所有参与者)',
    example: [1, 2, 3],
    type: [Number],
  })
  @IsOptional()
  @IsArray()
  targetUserIds?: number[];
}
