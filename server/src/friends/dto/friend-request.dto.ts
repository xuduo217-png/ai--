import { IsNotEmpty, IsString, MaxLength, IsOptional, IsInt, Min, IsIn } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';

/**
 * 通过手机号搜索用户 DTO
 */
export class SearchUserByPhoneDto {
  @ApiProperty({ description: '手机号', example: '13800138000' })
  @IsNotEmpty({ message: '手机号不能为空' })
  @IsString({ message: '手机号必须是字符串' })
  phone: string;
}

/**
 * 发送好友申请 DTO
 */
export class SendFriendRequestDto {
  @ApiProperty({ description: '接收人ID', example: 1 })
  @IsNotEmpty({ message: '接收人ID不能为空' })
  receiverId: number;

  @ApiProperty({ description: '申请附言（最多50字符）', example: '你好，我是张三', required: false })
  @IsString({ message: '申请附言必须是字符串' })
  @MaxLength(50, { message: '申请附言最多50字符' })
  message?: string;
}

/**
 * 接受好友申请 DTO
 */
export class AcceptFriendRequestDto {
  // 空对象，仅用于 Swagger 文档
}

/**
 * 拒绝好友申请 DTO
 */
export class RejectFriendRequestDto {
  @ApiProperty({ description: '拒绝原因（历史兼容字段，可不传）', example: '暂时不想添加好友', required: false })
  @IsOptional()
  @IsString({ message: '拒绝原因必须是字符串' })
  @MaxLength(200, { message: '拒绝原因最多200字符' })
  reason?: string;
}

/**
 * 修改好友备注 DTO
 */
export class UpdateFriendRemarkDto {
  @ApiProperty({ description: '备注名', example: '张三（同事）' })
  @IsNotEmpty({ message: '备注名不能为空' })
  @IsString({ message: '备注名必须是字符串' })
  @MaxLength(100, { message: '备注名最多100字符' })
  remark: string;
}

/**
 * 查询好友列表 DTO
 */
export class QueryFriendsDto {
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

  @ApiProperty({ description: '搜索关键词（昵称/备注）', required: false })
  @IsOptional()
  @IsString({ message: '搜索关键词必须是字符串' })
  search?: string;
}

/**
 * 查询好友申请列表 DTO
 */
export class QueryFriendRequestsDto {
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
}
