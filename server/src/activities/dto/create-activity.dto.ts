import {
  IsArray,
  IsInt,
  IsEnum,
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { ActivityType } from '../entities/activity.entity';

export class ActivityVoteOptionDto {
  @ApiProperty({ description: '选手ID，更新时可传', example: 1, required: false })
  @IsInt()
  @Min(1)
  @IsOptional()
  id?: number;

  @ApiProperty({ description: '选手图片URL（图片和视频至少传一个）', example: '/uploads/activity-option-1.jpg', required: false })
  @IsString()
  @IsOptional()
  image?: string;

  @ApiProperty({ description: '选手视频URL（图片和视频至少传一个）', example: '/uploads/activity-option-1.mp4', required: false })
  @IsString()
  @IsOptional()
  video?: string;

  @ApiProperty({ description: '选手视频缩略图URL', example: '/uploads/thumbnails/activity-option-1.jpg', required: false })
  @IsString()
  @IsOptional()
  videoCover?: string;

  @ApiProperty({ description: '选手标题', example: '小白' })
  @IsString()
  @IsNotEmpty({ message: '选手标题不能为空' })
  title: string;

  @ApiProperty({ description: '选手描述', example: '三岁金毛，温顺亲人', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ description: '已有票数，新增时默认 0', example: 0, required: false })
  @IsInt()
  @Min(0)
  @IsOptional()
  voteCount?: number;

  @ApiProperty({ description: '排序值', example: 0, required: false })
  @IsInt()
  @Min(0)
  @IsOptional()
  sortOrder?: number;

  @ApiProperty({ description: '所属用户ID，用户端报名添加时由服务端写入', example: 12, required: false })
  @IsInt()
  @Min(1)
  @IsOptional()
  ownerUserId?: number;
}

/**
 * 创建活动 DTO
 */
export class CreateActivityDto {
  @ApiProperty({ description: '活动名称', example: '宠物健康讲座' })
  @IsString()
  @IsNotEmpty({ message: '活动名称不能为空' })
  title: string;

  @ApiProperty({ description: '开始日期（YYYY-MM-DD）', example: '2026-02-10' })
  @IsString()
  @IsNotEmpty({ message: '开始时间不能为空' })
  startTime: string;

  @ApiProperty({ description: '结束日期（YYYY-MM-DD）', example: '2026-02-15' })
  @IsString()
  @IsNotEmpty({ message: '结束时间不能为空' })
  endTime: string;

  @ApiProperty({
    description: '活动类型',
    enum: ActivityType,
    example: ActivityType.OFFLINE,
  })
  @IsEnum(ActivityType)
  activityType: ActivityType;

  @ApiProperty({
    description: '是否展示到首页',
    example: false,
    default: false,
    required: false,
  })
  @IsOptional()
  @Transform(({ value }) => {
    if (value === undefined || value === null || value === '') return undefined;
    return value === true || value === 'true' || value === '1' || value === 1;
  })
  @IsBoolean()
  showOnHome?: boolean;

  @ApiProperty({
    description: '活动地点（线下活动必填，线上活动可为空）',
    example: '北京市朝阳区XX路XX号',
    required: false,
  })
  @IsString()
  @IsOptional()
  location?: string;

  @ApiProperty({ description: '活动简介', example: '专业兽医讲解宠物健康知识' })
  @IsString()
  @IsNotEmpty({ message: '活动简介不能为空' })
  summary: string;

  @ApiProperty({
    description: '活动详情（富文本 HTML）',
    example: '<p>详细的活动内容和安排</p>'
  })
  @IsString()
  @IsNotEmpty({ message: '活动详情不能为空' })
  description: string;

  @ApiProperty({
    description: '活动封面图片URL',
    example: '/uploads/activity-cover.jpg',
    required: false,
  })
  @IsString()
  @IsOptional()
  coverImage?: string;

  @ApiProperty({
    description: '活动分享海报图片URL（9:16）',
    example: '/uploads/activity-share-poster.jpg',
    required: false,
  })
  @IsString()
  @IsOptional()
  sharePosterImage?: string;

  @ApiProperty({
    description: '活动分享海报提示标题，最多10个字',
    example: '扫码参与',
    required: false,
    maxLength: 10,
  })
  @IsString()
  @MaxLength(10, { message: '海报提示标题最多10个字' })
  @IsOptional()
  sharePosterTitle?: string;

  @ApiProperty({
    description: '活动分享海报提示信息，最多30个字',
    example: '长按识别二维码查看活动详情',
    required: false,
    maxLength: 30,
  })
  @IsString()
  @MaxLength(30, { message: '海报提示信息最多30个字' })
  @IsOptional()
  sharePosterDescription?: string;

  @ApiProperty({ description: '关联医院ID', example: 1 })
  @IsInt()
  @Min(1, { message: '医院ID必须大于0' })
  @IsNotEmpty({ message: '医院ID不能为空' })
  hospitalId: number;

  @ApiProperty({
    description: '线上投票选手列表（可为空，已添加的选手必须填写完整）',
    type: [ActivityVoteOptionDto],
    required: false,
  })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ActivityVoteOptionDto)
  @IsOptional()
  voteOptions?: ActivityVoteOptionDto[];
}
