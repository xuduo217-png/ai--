import { IsNotEmpty, IsString, IsEnum, MaxLength, IsOptional, IsInt, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { MessageType } from '../entities/friend-message.entity';

/**
 * 发送消息 DTO（HTTP 备用接口）
 */
export class SendMessageDto {
  @ApiProperty({ description: '接收人ID', example: 1 })
  @IsNotEmpty({ message: '接收人ID不能为空' })
  receiverId: number;

  @ApiProperty({ description: '消息类型', enum: MessageType, example: MessageType.TEXT })
  @IsNotEmpty({ message: '消息类型不能为空' })
  @IsEnum(MessageType, { message: '消息类型必须是 text、image、voice 或 video' })
  messageType: MessageType;

  @ApiProperty({ description: '消息内容（文本或JSON）', example: '你好' })
  @IsNotEmpty({ message: '消息内容不能为空' })
  @IsString({ message: '消息内容必须是字符串' })
  @MaxLength(5000, { message: '消息内容最多5000字符' })
  content: string;

  @ApiProperty({ description: '临时消息ID（用于乐观更新）', required: false })
  tempMessageId?: string;
}

/**
 * 标记消息已读 DTO
 */
export class MarkMessageReadDto {
  @ApiProperty({ description: '消息ID', example: 'uuid-string' })
  @IsNotEmpty({ message: '消息ID不能为空' })
  @IsString({ message: '消息ID必须是字符串' })
  messageId: string;

  @ApiProperty({ description: '会话ID', example: '123_456' })
  @IsNotEmpty({ message: '会话ID不能为空' })
  @IsString({ message: '会话ID必须是字符串' })
  conversationId: string;
}

/**
 * 查询历史消息 DTO
 */
export class QueryMessagesDto {
  @ApiProperty({ description: '页码', example: 1, required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '页码必须是整数' })
  @Min(1, { message: '页码最小为1' })
  page?: number = 1;

  @ApiProperty({ description: '每页数量', example: 50, required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '每页数量必须是整数' })
  @Min(1, { message: '每页数量最小为1' })
  pageSize?: number = 50;

  @ApiProperty({ description: '好友ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '好友ID必须是整数' })
  friendId?: number;
}

/**
 * Admin 查询消息 DTO
 */
export class AdminQueryMessagesDto {
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

  @ApiProperty({ description: '会话ID', required: false })
  @IsOptional()
  @IsString({ message: '会话ID必须是字符串' })
  conversationId?: string;

  @ApiProperty({ description: '发送人ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '发送人ID必须是整数' })
  senderId?: number;

  @ApiProperty({ description: '接收人ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: '接收人ID必须是整数' })
  receiverId?: number;

  @ApiProperty({ description: '消息类型', enum: MessageType, required: false })
  @IsOptional()
  @IsEnum(MessageType, { message: '消息类型必须是 text、image、voice 或 video' })
  messageType?: MessageType;

  @ApiProperty({ description: '开始时间', required: false })
  @IsOptional()
  @IsString({ message: '开始时间必须是字符串' })
  startTime?: string;

  @ApiProperty({ description: '结束时间', required: false })
  @IsOptional()
  @IsString({ message: '结束时间必须是字符串' })
  endTime?: string;
}
