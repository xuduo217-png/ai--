import {
  IsString,
  IsInt,
  IsBoolean,
  IsOptional,
  MinLength,
  MaxLength,
  Matches,
  IsNotEmpty,
  IsArray,
  ArrayMaxSize,
  IsEnum,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { LostFoundRecordType } from '../entities/lost-found.entity';

/**
 * 创建走失招领信息 DTO
 */
export class CreateLostFoundDto {
  @ApiPropertyOptional({
    description: '宠物ID；手动填写宠物信息时不传或传 null',
    example: 1,
    nullable: true,
  })
  @IsOptional()
  @IsInt()
  @Min(1, { message: '宠物ID必须大于0' })
  petId?: number | null;

  @ApiPropertyOptional({
    description: '宠物名称；未关联宠物档案时必填',
    example: '小黑',
  })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(50, { message: '宠物名称最多50个字符' })
  petName?: string;

  @ApiPropertyOptional({
    description: '宠物类别；未关联宠物档案时必填',
    example: '狗',
  })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(50, { message: '宠物类别最多50个字符' })
  petCategory?: string;

  @ApiPropertyOptional({
    description: '宠物品种；未关联宠物档案时必填',
    example: '中华田园犬',
  })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(100, { message: '宠物品种最多100个字符' })
  petBreed?: string;

  @ApiPropertyOptional({
    description: '记录类型：LOST=走失，ADOPTION=领养',
    enum: LostFoundRecordType,
    default: LostFoundRecordType.LOST,
    example: LostFoundRecordType.LOST,
  })
  @IsOptional()
  @IsEnum(LostFoundRecordType, { message: '记录类型不正确' })
  recordType?: LostFoundRecordType;

  @ApiProperty({ description: '联系人姓名', example: '张先生' })
  @IsString()
  @MinLength(2, { message: '联系人姓名至少2个字符' })
  @MaxLength(20, { message: '联系人姓名最多20个字符' })
  @IsNotEmpty()
  contactName: string;

  @ApiProperty({ description: '联系电话', example: '13800138000' })
  @IsString()
  @Matches(/^1[3-9]\d{9}$/, { message: '请输入正确的手机号码' })
  @IsNotEmpty()
  contactPhone: string;

  @ApiProperty({
    description: '描述信息',
    example: '金毛犬，名叫旺财，3岁，身穿红色背心，于昨天下午在XX公园附近走失',
  })
  @IsString()
  @MinLength(10, { message: '描述信息至少10个字符' })
  @MaxLength(500, { message: '描述信息最多500个字符' })
  @IsNotEmpty()
  description: string;

  @ApiPropertyOptional({
    description: '图片列表（最多 9 张）',
    type: [String],
    example: ['/uploads/lost-found/1.jpg', '/uploads/lost-found/2.jpg'],
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(9, { message: '最多上传 9 张图片' })
  images?: string[];

  @ApiPropertyOptional({
    description: '视频 URL',
    example: '/uploads/lost-found/demo.mp4',
  })
  @IsOptional()
  @IsString()
  @Matches(
    /^(\/uploads\/.+\.(mp4|mov|avi|wmv|webm|mpeg)|https?:\/\/.+\.(mp4|mov|avi|wmv|webm|mpeg))$/i,
    {
      message: '视频格式不正确',
    },
  )
  video?: string;

  @ApiPropertyOptional({
    description: '视频封面图 URL',
    example: '/uploads/lost-found/demo_cover.jpg',
  })
  @IsOptional()
  @IsString({ message: '视频封面图地址必须是字符串' })
  @MaxLength(500, { message: '视频封面图地址最多500个字符' })
  videoCover?: string;

  @ApiProperty({
    description: '是否已找回',
    example: false,
    required: false,
  })
  @IsOptional()
  @IsBoolean()
  isFound?: boolean;
}
