import {
  IsString,
  IsOptional,
  IsInt,
  IsNumber,
  IsBoolean,
  IsEnum,
  Min,
  IsNotEmpty,
  ValidateIf,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ParticipantType, CharityStatus } from '../entities/charity.entity';

/**
 * 创建公益 DTO
 */
export class CreateCharityDto {
  @ApiProperty({ description: '公益名称', example: '每日签到打卡公益' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: '公益描述', example: '完成每天的健康任务，养成好习惯' })
  @IsString()
  @IsNotEmpty()
  description: string;

  @ApiPropertyOptional({
    description: '公益详情（富文本内容）',
    example: '<p>详细的公益规则和说明</p>'
  })
  @IsOptional()
  @IsString()
  details?: string;

  @ApiPropertyOptional({ description: '封面图片URL', example: 'https://example.com/image.jpg' })
  @IsOptional()
  @IsString()
  coverImage?: string;

  @ApiPropertyOptional({ description: '开始时间(留空表示立即开始)', type: Date })
  @IsOptional()
  startTime?: Date;

  @ApiPropertyOptional({ description: '结束时间(留空表示永久公益)', type: Date })
  @IsOptional()
  endTime?: Date;

  @ApiPropertyOptional({ description: '目标打卡次数(打卡类型必填，达标后可发布文章)', example: 30 })
  @ValidateIf((object) => object.participantType !== ParticipantType.DONATION)
  @IsInt()
  @Min(1)
  targetCheckIns?: number;

  @ApiProperty({ description: '参与方式', enum: ParticipantType, default: ParticipantType.CHECKIN })
  @IsEnum(ParticipantType)
  participantType: ParticipantType;

  @ApiPropertyOptional({ description: '是否为商城订单自动公益活动，同一时间只能有一个', default: false })
  @IsOptional()
  @IsBoolean()
  isMallAutoDonation?: boolean;

  @ApiPropertyOptional({ description: '商城自动公益比例（百分比，1.5 表示 1.5%）', example: 1.5, minimum: 0, maximum: 100 })
  @ValidateIf((object) => object.isMallAutoDonation === true)
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  donationRate?: number;

  @ApiPropertyOptional({ description: '是否置顶展示', default: false })
  @IsOptional()
  @IsBoolean()
  isPinned?: boolean;

  @ApiPropertyOptional({
    description: '任务配置(JSON)',
    example: { taskType: 'share', targetUrl: 'https://...' },
  })
  @IsOptional()
  taskConfig?: Record<string, any>;

  @ApiPropertyOptional({ description: '公益状态', enum: CharityStatus, default: CharityStatus.ACTIVE })
  @IsOptional()
  @IsEnum(CharityStatus)
  status?: CharityStatus;
}
