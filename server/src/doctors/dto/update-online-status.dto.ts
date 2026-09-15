import { IsEnum, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/**
 * 更新医生在线状态 DTO
 */
export class UpdateOnlineStatusDto {
  @ApiProperty({
    description: '在线状态',
    enum: ['ONLINE', 'OFFLINE'],
    example: 'ONLINE',
  })
  @IsEnum(['ONLINE', 'OFFLINE'], {
    message: '在线状态必须是 ONLINE 或 OFFLINE',
  })
  @IsNotEmpty({ message: '在线状态不能为空' })
  onlineStatus: 'ONLINE' | 'OFFLINE';
}
