import {
  IsString,
  IsNotEmpty,
  MinLength,
  MaxLength,
  IsOptional,
  IsBoolean,
  Matches,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateAddressDto {
  @ApiProperty({
    description: '收货人姓名',
    example: '张三',
    minLength: 2,
    maxLength: 20,
  })
  @IsString({ message: '收货人姓名必须是字符串' })
  @MinLength(2, { message: '收货人姓名至少2个字符' })
  @MaxLength(20, { message: '收货人姓名最多20个字符' })
  @IsNotEmpty({ message: '请输入收货人姓名' })
  receiverName: string;

  @ApiProperty({
    description: '收货人手机号',
    example: '13800138000',
    pattern: '^1[3-9]\\d{9}$',
  })
  @IsString({ message: '手机号必须是字符串' })
  @Matches(/^1[3-9]\d{9}$/, { message: '请输入正确的手机号' })
  @IsNotEmpty({ message: '请输入手机号' })
  receiverPhone: string;

  @ApiProperty({
    description: '省份代码（行政区划代码）',
    example: '110000',
  })
  @IsString({ message: '省份代码必须是字符串' })
  @IsNotEmpty({ message: '请选择所在地区' })
  provinceCode: string;

  @ApiProperty({
    description: '省份名称',
    example: '北京市',
  })
  @IsString({ message: '省份名称必须是字符串' })
  @IsNotEmpty({ message: '省份名称不能为空' })
  provinceName: string;

  @ApiProperty({
    description: '城市代码（行政区划代码）',
    example: '110100',
  })
  @IsString({ message: '城市代码必须是字符串' })
  @IsNotEmpty({ message: '城市代码不能为空' })
  cityCode: string;

  @ApiProperty({
    description: '城市名称',
    example: '北京市',
  })
  @IsString({ message: '城市名称必须是字符串' })
  @IsNotEmpty({ message: '城市名称不能为空' })
  cityName: string;

  @ApiProperty({
    description: '区县代码（行政区划代码）',
    example: '110101',
  })
  @IsString({ message: '区县代码必须是字符串' })
  @IsNotEmpty({ message: '区县代码不能为空' })
  districtCode: string;

  @ApiProperty({
    description: '区县名称',
    example: '东城区',
  })
  @IsString({ message: '区县名称必须是字符串' })
  @IsNotEmpty({ message: '区县名称不能为空' })
  districtName: string;

  @ApiProperty({
    description: '详细地址',
    example: '望京街道xx号楼xx单元xx室',
    minLength: 5,
    maxLength: 200,
  })
  @IsString({ message: '详细地址必须是字符串' })
  @MinLength(5, { message: '详细地址至少5个字符' })
  @MaxLength(200, { message: '详细地址最多200个字符' })
  @IsNotEmpty({ message: '请输入详细地址' })
  detailAddress: string;

  @ApiPropertyOptional({
    description: '是否为默认地址',
    example: false,
  })
  @IsOptional()
  @IsBoolean({ message: '是否默认地址必须是布尔值' })
  isDefault?: boolean;
}
