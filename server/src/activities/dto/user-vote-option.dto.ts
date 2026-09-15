import { IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UserVoteOptionDto {
  @ApiProperty({ description: '选手图片URL（图片和视频至少传一个）', example: '/uploads/activity-option.jpg', required: false })
  @IsString()
  @IsOptional()
  image?: string;

  @ApiProperty({ description: '选手视频URL（图片和视频至少传一个）', example: '/uploads/activity-option.mp4', required: false })
  @IsString()
  @IsOptional()
  video?: string;

  @ApiProperty({ description: '选手视频缩略图URL', example: '/uploads/thumbnails/activity-option.jpg', required: false })
  @IsString()
  @IsOptional()
  videoCover?: string;

  @ApiProperty({ description: '选手标题', example: '小白' })
  @IsString()
  @IsNotEmpty({ message: '选手标题不能为空' })
  title: string;

  @ApiProperty({ description: '选手描述', example: '三岁金毛，活泼亲人', required: false })
  @IsString()
  @IsOptional()
  description?: string;
}
