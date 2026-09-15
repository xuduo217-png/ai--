import { IsNumber, Min, Max, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

/**
 * 查询附近医院 DTO
 * 用于接收用户位置坐标，返回距离最近的医院列表
 */
export class QueryNearbyHospitalsDto {
  @ApiProperty({
    description: '纬度',
    example: 39.9042,
    minimum: -90,
    maximum: 90,
  })
  @IsNumber({}, { message: '纬度必须是数字' })
  @Min(-90, { message: '纬度不能小于 -90' })
  @Max(90, { message: '纬度不能大于 90' })
  @Type(() => Number)
  latitude: number;

  @ApiProperty({
    description: '经度',
    example: 116.4074,
    minimum: -180,
    maximum: 180,
  })
  @IsNumber({}, { message: '经度必须是数字' })
  @Min(-180, { message: '经度不能小于 -180' })
  @Max(180, { message: '经度不能大于 180' })
  @Type(() => Number)
  longitude: number;

  @ApiProperty({
    description: '返回数量（默认 10，最大 50）',
    example: 10,
    required: false,
    minimum: 1,
    maximum: 50,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({}, { message: '返回数量必须是数字' })
  @Min(1, { message: '返回数量不能小于 1' })
  @Max(50, { message: '返回数量不能大于 50' })
  limit?: number;
}
