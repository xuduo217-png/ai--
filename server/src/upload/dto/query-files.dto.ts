import { IsOptional, IsString, IsInt, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { PaginationDto, SortOrder } from '../../common/dto/pagination.dto';
import { FileType } from '../entities/file-record.entity';

export class QueryFilesDto extends PaginationDto {
  @ApiProperty({ description: '文件分类', required: false, example: 'avatar' })
  @IsOptional()
  @IsString()
  category?: string;

  @ApiProperty({
    description: 'MIME 类型',
    required: false,
    example: 'image/jpeg',
  })
  @IsOptional()
  @IsString()
  mimeType?: string;

  @ApiProperty({ description: '文件类型', enum: FileType, required: false })
  @IsOptional()
  @IsString()
  fileType?: FileType;

  @ApiProperty({ description: '原始文件名', required: false })
  @IsOptional()
  @IsString()
  originalName?: string;

  @ApiProperty({ description: '标签', required: false })
  @IsOptional()
  @IsString()
  tags?: string;

  @ApiProperty({
    description: '最小文件大小（字节）',
    required: false,
    example: 1024,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  minSize?: number;

  @ApiProperty({
    description: '最大文件大小（字节）',
    required: false,
    example: 10485760,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  maxSize?: number;

  @ApiProperty({
    description: '排序字段',
    required: false,
    enum: ['uploadedAt', 'size', 'originalName'],
    default: 'uploadedAt',
  })
  @IsOptional()
  @IsString()
  sortBy?: 'uploadedAt' | 'size' | 'originalName' = 'uploadedAt';

  @ApiProperty({
    description: '排序顺序',
    required: false,
    enum: SortOrder,
    default: SortOrder.DESC,
  })
  @IsOptional()
  sortOrder?: SortOrder = SortOrder.DESC;
}
