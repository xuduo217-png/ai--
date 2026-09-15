import { IsString, IsNotEmpty, IsEnum, IsOptional, IsBoolean } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { WordSeverity } from '../entities/sensitive-word.entity';

/**
 * 创建敏感词 DTO
 */
export class CreateSensitiveWordDto {
  @ApiProperty({ description: '敏感词', example: '测试敏感词' })
  @IsString()
  @IsNotEmpty()
  word: string;

  @ApiPropertyOptional({
    description: '敏感等级',
    enum: WordSeverity,
    example: WordSeverity.LOW
  })
  @IsEnum(WordSeverity)
  @IsOptional()
  severity?: WordSeverity = WordSeverity.LOW;

  @ApiPropertyOptional({ description: '替换词', example: '***' })
  @IsString()
  @IsOptional()
  replacement?: string;

  @ApiPropertyOptional({ description: '分类', example: '广告' })
  @IsString()
  @IsOptional()
  category?: string;

  @ApiPropertyOptional({ description: '是否启用', example: true })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

/**
 * 更新敏感词 DTO
 */
export class UpdateSensitiveWordDto {
  @ApiPropertyOptional({ description: '敏感词', example: '测试敏感词' })
  @IsString()
  @IsOptional()
  word?: string;

  @ApiPropertyOptional({
    description: '敏感等级',
    enum: WordSeverity,
    example: WordSeverity.LOW
  })
  @IsEnum(WordSeverity)
  @IsOptional()
  severity?: WordSeverity;

  @ApiPropertyOptional({ description: '替换词', example: '***' })
  @IsString()
  @IsOptional()
  replacement?: string;

  @ApiPropertyOptional({ description: '分类', example: '广告' })
  @IsString()
  @IsOptional()
  category?: string;

  @ApiPropertyOptional({ description: '是否启用', example: true })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

/**
 * 批量导入敏感词 DTO
 */
export class BatchImportSensitiveWordsDto {
  @ApiProperty({
    description: '敏感词列表（每行一个词）',
    type: [String],
    example: ['敏感词1', '敏感词2', '敏感词3']
  })
  @IsString({ each: true })
  @IsNotEmpty({ each: true })
  words: string[];
}

/**
 * 审核拒绝 DTO
 */
export class RejectPostDto {
  @ApiProperty({ description: '拒绝原因', example: '内容包含违规信息' })
  @IsString()
  @IsNotEmpty()
  rejectReason: string;
}
