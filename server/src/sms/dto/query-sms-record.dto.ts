import {
  IsOptional,
  IsString,
  IsDateString,
  IsEnum,
  IsInt,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { PaginationDto, SortOrder } from '../../common/dto/pagination.dto';
import { SmsType, SmsStatus } from '../entities/sms-record.entity';

export class QuerySmsRecordDto extends PaginationDto {
  @ApiProperty({ description: '手机号', required: false })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiProperty({ description: '短信类型', enum: SmsType, required: false })
  @IsOptional()
  @IsEnum(SmsType)
  type?: SmsType;

  @ApiProperty({ description: '发送状态', enum: SmsStatus, required: false })
  @IsOptional()
  @IsEnum(SmsStatus)
  status?: SmsStatus;

  @ApiProperty({
    description: '开始日期',
    required: false,
    example: '2024-01-01',
  })
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @ApiProperty({
    description: '结束日期',
    required: false,
    example: '2024-12-31',
  })
  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ApiProperty({
    description: '排序字段',
    required: false,
    enum: ['sentAt', 'phone', 'status'],
    default: 'sentAt',
  })
  @IsOptional()
  @IsString()
  sortBy?: 'sentAt' | 'phone' | 'status' = 'sentAt';

  @ApiProperty({
    description: '排序顺序',
    required: false,
    enum: SortOrder,
    default: SortOrder.DESC,
  })
  @IsOptional()
  sortOrder?: SortOrder = SortOrder.DESC;
}
