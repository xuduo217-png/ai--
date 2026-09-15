import { IsString, IsNotEmpty, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/**
 * 报名活动 DTO
 */
export class RegisterActivityDto {
  @ApiProperty({ description: '联系电话', example: '13800138000' })
  @IsString()
  @IsNotEmpty({ message: '联系电话不能为空' })
  @Matches(/^1[3-9]\d{9}$/, { message: '请输入正确的手机号' })
  phone: string;
}
