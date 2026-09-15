import { IsNumber, IsOptional, IsBoolean, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/**
 * 获取附近的人列表 DTO
 */
export class GetNearbyUsersDto {
  @ApiProperty({ description: '当前用户纬度', example: 39.9042 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @ApiProperty({ description: '当前用户经度', example: 116.4074 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;

  @ApiPropertyOptional({
    description: '搜索半径（米），0 表示同城不限距离',
    example: 5000,
    default: 5000,
  })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100000)
  radius?: number = 5000;

  @ApiPropertyOptional({ description: '页码', example: 1, default: 1 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ description: '每页数量', example: 20, default: 20 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(100)
  pageSize?: number = 20;
}

/**
 * 更新位置 DTO
 */
export class UpdateLocationDto {
  @ApiProperty({ description: '纬度', example: 39.9042 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @ApiProperty({ description: '经度', example: 116.4074 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;

  @ApiPropertyOptional({ description: '城市名称', example: '北京市' })
  @IsOptional()
  city?: string;
}

/**
 * 切换发现开关 DTO
 */
export class ToggleDiscoveryDto {
  @ApiProperty({ description: '是否开启发现', example: true })
  @IsBoolean()
  enabled: boolean;
}

/**
 * 附近用户响应 DTO
 */
export class NearbyUserDto {
  @ApiProperty({ description: '用户 ID', example: 123 })
  userId: number;

  @ApiProperty({ description: '用户昵称', example: '宠物爱好者' })
  username: string;

  @ApiPropertyOptional({ description: '用户头像', example: 'https://example.com/avatar.jpg' })
  avatar?: string;

  @ApiPropertyOptional({ description: '个性签名', example: '养猫 3 年，喜欢交朋友' })
  signature?: string;

  @ApiProperty({ description: '距离（米）', example: 1250 })
  distance: number;

  @ApiPropertyOptional({ description: '最后活跃时间', example: '2025-02-09T10:30:00Z' })
  lastActiveAt?: Date;

  @ApiPropertyOptional({ description: '宠物类型标签', example: ['猫', '狗'], type: [String] })
  petTypes?: string[];

  @ApiProperty({ description: '是否已经是好友', example: false })
  isFriend: boolean;
}

/**
 * 当前位置信息 DTO
 */
export class CurrentLocationDto {
  @ApiProperty({ description: '纬度', example: 39.9042 })
  latitude: number;

  @ApiProperty({ description: '经度', example: 116.4074 })
  longitude: number;

  @ApiPropertyOptional({ description: '城市名称', example: '北京市' })
  city?: string;

  @ApiProperty({ description: '更新时间', example: '2025-02-09T10:30:00Z' })
  updatedAt: Date;
}

/**
 * 用户位置设置响应 DTO
 */
export class LocationSettingsDto {
  @ApiProperty({ description: '是否允许被附近的人发现', example: true })
  discoveryEnabled: boolean;

  @ApiPropertyOptional({
    description: '当前保存的位置信息',
    type: CurrentLocationDto,
  })
  currentLocation?: CurrentLocationDto;
}
