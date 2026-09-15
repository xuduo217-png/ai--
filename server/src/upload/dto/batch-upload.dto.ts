import { IsOptional, IsBoolean, ArrayMinSize, IsArray } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { UploadFileDto } from './upload-file.dto';

export class BatchUploadDto {
  @ApiProperty({
    description: '是否自动压缩图片（仅图片）',
    required: false,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  compress?: boolean;

  @ApiProperty({
    description: '是否生成缩略图（仅图片）',
    required: false,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  generateThumbnail?: boolean;

  @ApiProperty({
    description: '文件分类（应用于所有文件）',
    required: false,
    example: 'chat-images',
  })
  @IsOptional()
  category?: string;
}
