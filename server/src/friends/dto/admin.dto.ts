import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsNumber, IsInt, Min, IsString, IsIn } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Admin 查询好友关系 DTO
 */
export class AdminQueryFriendshipsDto {
  @ApiProperty({ description: '页码', example: 1, required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '页码必须是整数' })
  @Min(1, { message: '页码最小为1' })
  page?: number = 1;

  @ApiProperty({ description: '每页数量', example: 20, required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '每页数量必须是整数' })
  @Min(1, { message: '每页数量最小为1' })
  pageSize?: number = 20;

  @ApiProperty({ description: '用户ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '用户ID必须是整数' })
  userId?: number;

  @ApiProperty({ description: '好友ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '好友ID必须是整数' })
  friendId?: number;
}

/**
 * Admin 查询好友申请 DTO
 */
export class AdminQueryFriendRequestsDto {
  @ApiProperty({ description: '页码', example: 1, required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '页码必须是整数' })
  @Min(1, { message: '页码最小为1' })
  page?: number = 1;

  @ApiProperty({ description: '每页数量', example: 20, required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '每页数量必须是整数' })
  @Min(1, { message: '每页数量最小为1' })
  pageSize?: number = 20;

  @ApiProperty({ description: '申请状态', enum: ['pending', 'accepted', 'rejected', 'expired'], required: false })
  @IsOptional()
  @IsString({ message: '状态必须是字符串' })
  @IsIn(['pending', 'accepted', 'rejected', 'expired'], { message: '状态值无效' })
  status?: string;

  @ApiProperty({ description: '申请人ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '申请人ID必须是整数' })
  requesterId?: number;

  @ApiProperty({ description: '接收人ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '接收人ID必须是整数' })
  receiverId?: number;
}
