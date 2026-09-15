import { IsOptional, IsString, MaxLength, IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UploadFileDto {
  @ApiProperty({ description: '文件分类', required: false, example: 'avatar' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  category?: string;

  @ApiProperty({
    description: '文件描述',
    required: false,
    example: '用户头像',
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  description?: string;

  @ApiProperty({
    description: '文件标签',
    required: false,
    example: 'profile,image',
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  tags?: string;

  @ApiProperty({
    description: '是否自动压缩（图片同步处理，支持的视频异步处理）',
    required: false,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  compress?: boolean;

  @ApiProperty({
    description: '是否生成缩略图（支持图片和视频）',
    required: false,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  generateThumbnail?: boolean;
}
