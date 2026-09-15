import { ApiProperty } from '@nestjs/swagger';

/**
 * 附近医院响应 DTO
 * 包含医院基本信息和计算后的距离
 */
export class NearbyHospitalResponseDto {
  @ApiProperty({ description: '医院 ID', example: 1 })
  id: number;

  @ApiProperty({ description: '医院名称', example: '爱宠宠物医院' })
  name: string;

  @ApiProperty({ description: '医院 Logo', example: 'https://example.com/logo.png', required: false })
  logo?: string;

  @ApiProperty({ description: '医院描述', example: '专业宠物医疗服务', required: false })
  description?: string;

  @ApiProperty({ description: '省份', example: '北京市' })
  province: string;

  @ApiProperty({ description: '城市', example: '北京市' })
  city: string;

  @ApiProperty({ description: '区/县', example: '朝阳区' })
  county: string;

  @ApiProperty({ description: '详细地址', example: '北京市朝阳区望京街道阜通东大街6号院' })
  address: string;

  @ApiProperty({ description: '联系电话', example: '010-12345678' })
  phone: string;

  @ApiProperty({ description: '邮箱', example: 'contact@example.com', required: false })
  email?: string;

  @ApiProperty({ description: '纬度', example: 39.9042 })
  latitude: number;

  @ApiProperty({ description: '经度', example: 116.4074 })
  longitude: number;

  @ApiProperty({ description: '医院状态', example: 'active', enum: ['active', 'inactive', 'suspended'] })
  status: string;

  @ApiProperty({ description: '营业状态文本（前端友好）', example: '营业中' })
  businessStatusText: string;

  @ApiProperty({ description: '评分（0-5）', example: 4.5 })
  rating: number;

  @ApiProperty({ description: '评论数', example: 128 })
  reviewCount: number;

  @ApiProperty({ description: '距离（单位：公里）', example: 1.2 })
  distance: number;

  @ApiProperty({ description: '设施服务（JSON 数组）', example: '["急诊", "手术", "住院"]', required: false })
  facilities?: string;
}
